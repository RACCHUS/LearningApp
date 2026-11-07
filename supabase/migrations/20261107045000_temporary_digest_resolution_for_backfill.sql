-- Hosted deploys run as the CLI's temporary login role (cli_login_postgres),
-- whose search_path lacks the extensions schema, so the unqualified top-level
-- digest() in 20261107050000 cannot resolve pgcrypto. Provide a temporary
-- pass-through only where digest(bytea, text) is unresolvable; elsewhere this is
-- a no-op. 20261107110000 drops it after 20261107050000 has run.
DO $$
BEGIN
  IF to_regprocedure('digest(bytea,text)') IS NULL THEN
    CREATE FUNCTION public.digest(bytea, text)
    RETURNS bytea
    LANGUAGE sql
    IMMUTABLE STRICT PARALLEL SAFE
    AS 'SELECT extensions.digest($1, $2)';
    COMMENT ON FUNCTION public.digest(bytea, text) IS 'learningapp:temporary-deploy-shim';
  END IF;
END
$$;
