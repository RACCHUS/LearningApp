-- Remove the temporary digest pass-through from 20261107045000 (only if it is
-- that shim, identified by its marker comment) so pgcrypto's
-- extensions.digest() is the sole implementation again.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.oid = to_regprocedure('public.digest(bytea,text)')
      AND obj_description(p.oid, 'pg_proc') = 'learningapp:temporary-deploy-shim'
  ) THEN
    DROP FUNCTION public.digest(bytea, text);
  END IF;
END
$$;
