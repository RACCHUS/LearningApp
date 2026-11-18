-- pgTAP: learning.scratchpad is a UI-only gate. Seeded OFF, then activated with the
-- owner's approval by 20261117230000, which also writes the audit row.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(3);

select is(
  (select enabled and release_ready from private.site_feature_controls
    where feature_key = 'learning.scratchpad'),
  true, 'learning.scratchpad is activated (owner approval, 20261117230000)');
select is(
  (get_site_feature_snapshot() -> 'learning.scratchpad' ->> 'enabled')::boolean,
  true, 'the public snapshot reports it enabled');
select ok(
  exists (select 1 from private.site_feature_change_audit
           where feature_key = 'learning.scratchpad' and next_enabled
             and reason like 'Owner-approved activation 2026-11-17%'),
  'the activation is in the audit log');

select * from finish();
rollback;
