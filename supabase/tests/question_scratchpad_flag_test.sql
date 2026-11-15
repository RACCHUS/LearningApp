-- pgTAP: learning.scratchpad is a UI-only gate (nothing is stored or sent),
-- so the server contract is just that it ships OFF.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(2);

select is(
  (select enabled or release_ready from private.site_feature_controls
    where feature_key = 'learning.scratchpad'),
  false, 'learning.scratchpad is seeded OFF');
select is(
  (get_site_feature_snapshot() -> 'learning.scratchpad' ->> 'enabled')::boolean,
  false, 'the public snapshot reports it disabled');

select * from finish();
rollback;
