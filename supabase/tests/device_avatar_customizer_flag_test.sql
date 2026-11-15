-- pgTAP: learning.avatar_customizer is a UI-only gate (avatars stay in the
-- browser; no server write exists to guard). It must ship seeded OFF.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(2);

select is(
  (select enabled or release_ready from private.site_feature_controls
    where feature_key = 'learning.avatar_customizer'),
  false, 'learning.avatar_customizer is seeded OFF');
select is(
  (get_site_feature_snapshot() -> 'learning.avatar_customizer' ->> 'enabled')::boolean,
  false, 'the public snapshot reports it disabled');

select * from finish();
rollback;
