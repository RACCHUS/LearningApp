-- ANA-008: Learning evidence must be written only through validated server RPCs.
-- This additive, data-preserving migration removes public client DML on
-- learning_events. The approved record_events(jsonb[]) SECURITY DEFINER RPC
-- is deliberately unchanged: it retains authenticated EXECUTE and the table
-- owner/service role can still write authoritative evidence.
--
-- RLS alone was insufficient: learning_events_insert_own allowed a client
-- to create arbitrary evidence records for their own user_id, bypassing the
-- validation, idempotency and scoring rules in public.record_events.

REVOKE ALL PRIVILEGES ON TABLE public.learning_events
  FROM PUBLIC, anon, authenticated;

-- Preserve the existing owner-scoped SELECT RLS policy. Anonymous guests
-- sign in as authenticated; they retain owner-only reads of existing evidence.
GRANT SELECT ON TABLE public.learning_events TO authenticated;

-- No client INSERT policy should survive an accidental future grant.
DROP POLICY IF EXISTS learning_events_insert_own ON public.learning_events;

-- Keep the trusted administrative path functional without exposing DML
-- to browser roles. This is not a grant to authenticated/anon.
GRANT ALL PRIVILEGES ON TABLE public.learning_events TO service_role;

-- public.record_events(jsonb[]) remains SECURITY DEFINER (with its existing
-- fixed search_path) and is executable by authenticated. Its privileges and
-- definition are intentionally not changed by this migration.
