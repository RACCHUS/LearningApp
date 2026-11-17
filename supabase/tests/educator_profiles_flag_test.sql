-- pgTAP: learning.educator_profiles is a UI-only gate (it only adds entry
-- points; public reads and writes are already gated by RLS), so the server
-- contract is that it ships OFF.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(2);

select is(
  (select enabled or release_ready from private.site_feature_controls
    where feature_key = 'learning.educator_profiles'),
  false, 'learning.educator_profiles is seeded OFF');
select is(
  (get_site_feature_snapshot() -> 'learning.educator_profiles' ->> 'enabled')::boolean,
  false, 'the public snapshot reports it disabled');

select * from finish();
rollback;
