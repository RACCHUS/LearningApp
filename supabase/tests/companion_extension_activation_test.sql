-- pgTAP: activation of content.companion_extension (migration
-- 20261126040000, companion plan v1.0 EX-9). On, release-ready, one audit
-- row for it, and a client-only switch: the saves it leads to stay gated by
-- content.learner_resources.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(5);

select ok(
  (select enabled and release_ready from private.site_feature_controls
   where feature_key = 'content.companion_extension'),
  'the extension route is on and release-ready'
);

select is(
  (select count(*)::int from private.site_feature_change_audit
   where feature_key = 'content.companion_extension'
     and reason like '%migration 20261126040000%'),
  1,
  'the activation wrote exactly one audit row'
);

select is(
  (select revision from private.site_feature_controls
   where feature_key = 'content.companion_extension'),
  (select new_revision from private.site_feature_change_audit
   where feature_key = 'content.companion_extension'
     and reason like '%migration 20261126040000%'),
  'the audit row records the current revision'
);

select is(
  (select maturity from private.site_feature_controls
   where feature_key = 'content.companion_extension'),
  'experimental',
  'maturity is unchanged by the activation'
);

select ok(
  (select enabled from private.site_feature_controls
   where feature_key = 'content.learner_resources'),
  'saves still go through content.learner_resources, which is on'
);

select * from finish();
rollback;
