-- ANA-001A RED CONTRACT: these invariants must FAIL on today's legacy
-- migration chain and PASS only after ANA-001B implements the reviewed
-- canonical progress schema and RPC. Kept on a DRAFT PR until green.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

select ok(to_regclass('public.learner_activity_progress') is not null,
  'New typed, version-aware learner progress projection exists');

select ok(to_regprocedure('public.record_learner_progress(jsonb[])') is not null,
  'Dedicated authenticated progress ingest RPC exists');

select ok(
  (select count(*)=7
     from information_schema.columns
    where table_schema='public' and table_name='learner_activity_progress'
      and column_name in ('user_id','content_kind','content_id',
        'version_key','reporting_date_utc','completed','active_seconds')),
  'Projection has all seven required contract columns');

select ok(
  exists (
    select 1 from pg_constraint c
     where c.conrelid=to_regclass('public.learner_activity_progress')
       and c.contype='f'
       and c.confrelid='auth.users'::regclass
  ),
  'Learner progress references auth.users rather than a legacy profile row');

select ok(
  not exists (
    select 1 from pg_constraint c
     where c.conrelid=to_regclass('public.learner_activity_progress')
       and c.contype='f'
       and c.confrelid='public.users'::regclass
  ) and to_regclass('public.learner_activity_progress') is not null,
  'Canonical learner progress does not depend on public.users profiles');

select ok(
  exists (
    select 1 from pg_constraint c
     where c.conrelid=to_regclass('public.learner_activity_progress')
       and c.contype='u'
       and pg_get_constraintdef(c.oid) ilike
         '%(user_id, content_kind, content_id, version_key, reporting_date_utc)%'
  ),
  'Five-part user/content/version/UTC-day key is unique');

select ok(
  to_regclass('public.learner_activity_progress') is not null
  and not coalesce(has_table_privilege('authenticated',to_regclass('public.learner_activity_progress'),'INSERT'),true),
  'Authenticated browser users cannot bypass the ingest RPC via direct INSERT');

select ok(
  to_regprocedure('public.record_learner_progress(jsonb[])') is not null
  and has_function_privilege('authenticated',
    to_regprocedure('public.record_learner_progress(jsonb[])'),'EXECUTE'),
  'Authenticated learners can execute the vetted progress ingestion RPC');

select * from finish();
rollback;
