-- pgTAP: activation of content.companion_embeds (migration 20261126060000,
-- companion plan v1.0 EX-7). On, release-ready, one audit row for it, the
-- description names the published wording, and a client-only switch: outline
-- saves stay gated by content.learner_resources.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

select ok(
  (select enabled and release_ready from private.site_feature_controls
   where feature_key = 'content.companion_embeds'),
  'the in-app player is on and release-ready'
);

select is(
  (select count(*)::int from private.site_feature_change_audit
   where feature_key = 'content.companion_embeds'
     and reason like '%migration 20261126060000%'),
  1,
  'the activation wrote exactly one audit row'
);

select is(
  (select revision from private.site_feature_controls
   where feature_key = 'content.companion_embeds'),
  (select new_revision from private.site_feature_change_audit
   where feature_key = 'content.companion_embeds'
     and reason like '%migration 20261126060000%'),
  'the audit row records the current revision'
);

select is(
  (select maturity from private.site_feature_controls
   where feature_key = 'content.companion_embeds'),
  'experimental',
  'maturity is unchanged by the activation'
);

select ok(
  (select description like '%/outside-study-privacy.html%'
   from private.site_feature_controls
   where feature_key = 'content.companion_embeds'),
  'the description points at the published provider wording'
);

select ok(
  (select enabled from private.site_feature_controls
   where feature_key = 'content.learner_resources'),
  'outline saves still go through content.learner_resources, which is on'
);

select * from finish();
rollback;
