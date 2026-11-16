-- pgTAP: learning.reinforcement_suggestions is a UI-only gate (the list
-- reads through existing RLS and writes nothing), so the server contract is
-- that it ships OFF.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(2);

select is(
  (select enabled or release_ready from private.site_feature_controls
    where feature_key = 'learning.reinforcement_suggestions'),
  false, 'learning.reinforcement_suggestions is seeded OFF');
select is(
  (get_site_feature_snapshot() -> 'learning.reinforcement_suggestions' ->> 'enabled')::boolean,
  false, 'the public snapshot reports it disabled');

select * from finish();
rollback;
