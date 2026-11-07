-- Excel pilot: private storage bucket with authenticated owner/session/path gate.
-- No learner-facing file upload or worker processing is released here.
-- All issued attempts remain upload_enabled=false; only trusted server
-- orchestration can opt in after the independent retention/security review.
-- Objects must be deleted using Storage API, never SQL metadata DELETE.
BEGIN;

ALTER TABLE public.software_learning_attempts
  ADD COLUMN upload_enabled boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.software_learning_attempts.upload_enabled IS
  'Server-only release gate; default false, not changeable by learners. An enabled attempt still requires active original Auth session and exact path.';

-- Reserve a NEW bucket ID only: never silently adopt/modify a pre-existing
-- object bucket that might contain learner files or have public settings.
DO $reserved_bucket$
BEGIN
  IF EXISTS (SELECT 1 FROM storage.buckets b
             WHERE b.id='learningapp-excel-private') THEN
    RAISE EXCEPTION 'Excel storage bucket already exists; require manual review'
      USING ERRCODE='55000';
  END IF;
END
$reserved_bucket$;

INSERT INTO storage.buckets
  (id,name,public,file_size_limit,allowed_mime_types)
VALUES (
  'learningapp-excel-private',
  'learningapp-excel-private',
  false,
  10485760,
  ARRAY['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']::text[]
);

-- Safe boolean for Storage RLS: never returns an attempt record or private
-- expected inputs. PostgREST must verify JWT signature; this method also
-- verifies permanent-account status, the still-active Auth session and
-- the one exact canonical workbook path for an explicitly enabled attempt.
CREATE FUNCTION public.sl_excel_storage_upload_authorized(p_object_name text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog
AS $gate$
DECLARE
  v_actor uuid;
  v_session uuid;
BEGIN
  v_actor := (SELECT auth.uid());
  IF p_object_name IS NULL OR octet_length(p_object_name)>100
     OR v_actor IS NULL
     OR (auth.jwt()->>'role') IS DISTINCT FROM 'authenticated'
     OR (auth.jwt()->>'is_anonymous') IS DISTINCT FROM 'false'
     OR coalesce(auth.jwt()->>'session_id','') !~
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  THEN
    RETURN false;
  END IF;
  v_session := (auth.jwt()->>'session_id')::uuid;
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=v_session AND s.user_id=v_actor
      AND (s.not_after IS NULL OR s.not_after>now())
  ) THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.software_learning_attempts a
    WHERE a.owner_id=v_actor AND a.issued_session_id=v_session
      AND a.status='issued' AND a.expires_at>now()
      AND a.upload_enabled IS true
      AND p_object_name=v_actor::text || '/' || a.id::text || '/workbook.xlsx'
  );
END
$gate$;
REVOKE ALL ON FUNCTION public.sl_excel_storage_upload_authorized(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sl_excel_storage_upload_authorized(text)
  TO authenticated;

-- A restrictive gate is essential: a pre-existing permissive bucket INSERT
-- policy must not authorize uploads to the reserved Excel bucket.
CREATE POLICY sl_excel_insert_enforce ON storage.objects
AS RESTRICTIVE FOR INSERT TO anon,authenticated
WITH CHECK (
  bucket_id <> 'learningapp-excel-private'
  OR public.sl_excel_storage_upload_authorized(name)
);

-- Explicit client-side direct upload permission only if a trusted operator
-- later sets the attempt's server-only gate. No signed URL or upsert flows.
CREATE POLICY sl_excel_insert_owner ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'learningapp-excel-private'
  AND public.sl_excel_storage_upload_authorized(name)
);

-- Block all learner reads, overwrites, and deletions for this bucket even
-- if other RLS policies become more permissive later. A scoped trusted
-- processor must use the authenticated Storage API for read/delete.
CREATE POLICY sl_excel_deny_read ON storage.objects
AS RESTRICTIVE FOR SELECT TO anon,authenticated
USING (bucket_id <> 'learningapp-excel-private');

CREATE POLICY sl_excel_deny_update ON storage.objects
AS RESTRICTIVE FOR UPDATE TO anon,authenticated
USING (bucket_id <> 'learningapp-excel-private')
WITH CHECK (bucket_id <> 'learningapp-excel-private');

CREATE POLICY sl_excel_deny_delete ON storage.objects
AS RESTRICTIVE FOR DELETE TO anon,authenticated
USING (bucket_id <> 'learningapp-excel-private');

-- A DB-only deletion must never leave actual bytes in object storage.
-- Until the Storage-API cleanup orchestration is implemented, refuse
-- deleting an attempt whose canonical uploaded object still exists.
CREATE FUNCTION software_learning_private.sl_excel_prevent_orphan_delete()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog
AS $protect$
BEGIN
  IF EXISTS (
    SELECT 1 FROM storage.objects o
    WHERE o.bucket_id='learningapp-excel-private'
      AND o.name=old.owner_id::text || '/' || old.id::text || '/workbook.xlsx'
  ) THEN
    RAISE EXCEPTION
      'Remove Excel workbook via Storage API before erasing attempt metadata'
      USING ERRCODE='55000';
  END IF;
  RETURN old;
END
$protect$;
REVOKE ALL ON FUNCTION software_learning_private.sl_excel_prevent_orphan_delete()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER sl_excel_prevent_orphan_delete
  BEFORE DELETE ON public.software_learning_attempts
  FOR EACH ROW
  EXECUTE FUNCTION software_learning_private.sl_excel_prevent_orphan_delete();

COMMENT ON FUNCTION public.sl_excel_storage_upload_authorized(text) IS
  'Default-deny permanent-session and owner-bound canonical Excel Storage path check. Never a skill/evidence authority.';
COMMENT ON FUNCTION software_learning_private.sl_excel_prevent_orphan_delete() IS
  'Fail-closed protection against SQL-only erasure of workbook metadata while bytes remain in Storage.';
COMMIT;
