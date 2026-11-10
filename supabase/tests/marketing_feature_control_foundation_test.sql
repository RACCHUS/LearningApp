-- FLAG-001..004. Uses a rollback-only synthetic admin identity.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(15);

SELECT has_table('private', 'site_feature_controls', 'Private feature registry exists');
SELECT has_table('private', 'site_feature_change_audit', 'Private feature audit exists');
SELECT is((SELECT enabled FROM private.site_feature_controls WHERE feature_key='tel.fast'),
          true, 'Fast remains enabled after registry installation');
SELECT is((SELECT enabled FROM private.site_feature_controls WHERE feature_key='ai.byok'),
          false, 'BYOK seeded off');
SELECT is(private.site_feature_enabled('ai.byok'), false,
          'Direct BYOK server gate is closed');
SELECT is(private.site_feature_enabled('undefined.feature'), false,
          'Unknown features fail closed');
SELECT is(public.get_site_feature_snapshot() #>> '{tel.fast,enabled}',
          'true', 'Public Fast read reflects explicit available default');
SELECT is(public.get_site_feature_snapshot() #>> '{ai.byok,enabled}',
          'false', 'Public BYOK read stays off');

SET LOCAL ROLE anon;
SELECT throws_ok(
  $$ SELECT public.admin_list_site_features() $$,
  '42501', NULL, 'Anonymous callers cannot manage feature registry');
RESET ROLE;

INSERT INTO auth.users(id,email,is_anonymous)
VALUES ('f1a60000-0000-4000-8000-000000000001',
        'feature-owner@example.invalid',false)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.moderation_roles(user_id,role)
VALUES ('f1a60000-0000-4000-8000-000000000001','admin')
ON CONFLICT (user_id) DO UPDATE SET role='admin';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'f1a60000-0000-4000-8000-000000000001', true);
SELECT is(jsonb_array_length(public.admin_list_site_features()) > 10,
          true, 'Admin can list seeded registry');
SELECT throws_ok(
  $$ SELECT public.admin_set_site_feature('ai.byok', true,
       'experimental', 0, 'Unapproved BYOK enable') $$,
  '42501', NULL, 'Admin cannot reactivate BYOK');
SELECT throws_ok(
  $$ SELECT public.admin_set_site_feature('mcp.remote', true,
       'experimental', 0, 'Unapproved remote launch') $$,
  '42501', NULL, 'Admin cannot enable an unready feature');
SELECT is(public.admin_set_site_feature(
  'tel.fast', false, 'experimental', 0, 'Emergency Fast shutdown test'
)->>'enabled', 'false', 'Admin can shut off an eligible feature');
SELECT is(public.get_site_feature_snapshot() #>> '{tel.fast,enabled}',
          'false', 'Fast snapshot reflects disabled state');
SELECT throws_ok(
  $$ SELECT public.admin_set_site_feature('tel.fast', true,
       'experimental', 0, 'Stale reopen attempt') $$,
  '40001', NULL, 'Stale admin revision is rejected');
SELECT * FROM finish();
ROLLBACK;
