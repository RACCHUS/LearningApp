-- pgTAP Educator Profiles & Verification Architecture Test Suite (ECO-04)
-- Validates schema, Gate 2 private launch gate, least-privilege RLS policies,
-- subject affiliations, credential verification privilege guard, and follow mechanics.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(62);

-- 1. Setup synthetic test users
insert into auth.users (id, email) values
  ('8f8c1a20-0000-4000-8000-000000000001', 'edu-admin@example.invalid'),
  ('8f8c1a20-0000-4000-8000-000000000002', 'edu-teacher-a@example.invalid'),
  ('8f8c1a20-0000-4000-8000-000000000003', 'edu-learner-b@example.invalid'),
  ('8f8c1a20-0000-4000-8000-000000000004', 'edu-moderator-b@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('8f8c1a20-0000-4000-8000-000000000001', 'edu-admin@example.invalid'),
  ('8f8c1a20-0000-4000-8000-000000000002', 'edu-teacher-a@example.invalid'),
  ('8f8c1a20-0000-4000-8000-000000000003', 'edu-learner-b@example.invalid'),
  ('8f8c1a20-0000-4000-8000-000000000004', 'edu-moderator-b@example.invalid')
on conflict (id) do nothing;

insert into public.moderation_roles (user_id, role, granted_by)
values
  ('8f8c1a20-0000-4000-8000-000000000001', 'admin', '8f8c1a20-0000-4000-8000-000000000001'),
  ('8f8c1a20-0000-4000-8000-000000000004', 'moderator', '8f8c1a20-0000-4000-8000-000000000001')
on conflict (user_id) do update set role = excluded.role;

-- -----------------------------------------------------------------------------
-- 1. Schema Structure Checks (11 tests)
-- -----------------------------------------------------------------------------
select has_table('public', 'educator_profiles', 'Table public.educator_profiles exists');
select has_table('public', 'educator_subjects', 'Table public.educator_subjects exists');
select has_table('public', 'educator_verifications', 'Table public.educator_verifications exists');
select has_table('public', 'educator_verification_audits', 'Table public.educator_verification_audits exists');
select has_column('public', 'educator_verifications', 'verified_by', 'Column educator_verifications.verified_by exists');
select has_column('public', 'educator_verification_audits', 'internal_notes', 'Column educator_verification_audits.internal_notes exists');
select has_table('public', 'educator_follows', 'Table public.educator_follows exists');
select has_function('private', 'is_educator_profiles_public_enabled', 'Function private.is_educator_profiles_public_enabled exists');
select has_function('public', 'upsert_my_educator_profile', Array['text', 'text', 'text', 'text', 'text[]', 'boolean', 'text'], 'RPC upsert_my_educator_profile exists');
select has_function('public', 'verify_educator_credential', Array['uuid', 'text', 'timestamp with time zone', 'text', 'text'], 'RPC verify_educator_credential exists');
select has_function('public', 'fetch_my_credential_feedback', Array['uuid'], 'RPC fetch_my_credential_feedback exists');


-- -----------------------------------------------------------------------------
-- 2. Gate 2 Launch Gate Default Invariant (2 tests)
-- -----------------------------------------------------------------------------
select is(
  (select private.is_educator_profiles_public_enabled()),
  false,
  'Gate 2 launch gate: educator_profiles_public_enabled defaults to false'
);

set local role anon;
select is(
  (select count(*)::integer from public.educator_profiles),
  0,
  'Anonymous user receives 0 educator profiles while Gate 2 is closed'
);

-- -----------------------------------------------------------------------------
-- 3. Anonymous Mutation Guard (2 tests)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$
    insert into public.educator_profiles (id, display_name)
    values ('8f8c1a20-0000-4000-8000-000000000002', 'Anonymous Hack')
  $$,
  '42501',
  null,
  'Anonymous user cannot insert into educator_profiles (42501)'
);

select throws_ok(
  $$
    select public.upsert_my_educator_profile('Anon Teacher')
  $$,
  '42501',
  null,
  'Anonymous RPC invocation rejected with 42501'
);

-- -----------------------------------------------------------------------------
-- 4. Educator Profile Lifecycle & Owner RLS (5 tests)
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);

-- Teacher A upserts their educator profile
select lives_ok(
  $$
    select public.upsert_my_educator_profile(
      'Dr. Alice Phonics',
      'Early Literacy & Phonics Specialist',
      'Over 10 years of experience teaching foundational reading.',
      null,
      array['en', 'es']::text[],
      true,
      'active'
    )
  $$,
  'Teacher A can create and activate their educator profile via RPC'
);

select is(
  (select display_name from public.educator_profiles where id = '8f8c1a20-0000-4000-8000-000000000002'),
  'Dr. Alice Phonics',
  'Teacher A profile display_name matches inserted value'
);

select is(
  (select status from public.educator_profiles where id = '8f8c1a20-0000-4000-8000-000000000002'),
  'active',
  'Teacher A profile status is active'
);

-- Teacher A attempting to hijack Teacher B profile id is blocked
select throws_ok(
  $$
    insert into public.educator_profiles (id, display_name)
    values ('8f8c1a20-0000-4000-8000-000000000003', 'Imposter')
  $$,
  '42501',
  null,
  'Authenticated user cannot create profile for another user ID (RLS blocked)'
);

-- Learner B perspective: cannot see Teacher A profile while Gate 2 is closed
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000003', true);
select is(
  (select count(*)::integer from public.educator_profiles where id = '8f8c1a20-0000-4000-8000-000000000002'),
  0,
  'Learner B cannot see Teacher A active profile while Gate 2 is closed (Isolation Enforced)'
);

-- -----------------------------------------------------------------------------
-- 5. Educator Subject Associations (Teacher does not own course) (4 tests)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);

select lives_ok(
  $$
    insert into public.educator_subjects (
      educator_id, subject_id, subject_name, experience_summary
    ) values (
      '8f8c1a20-0000-4000-8000-000000000002',
      'literacy.cvc',
      'Early Literacy & CVC Phonics',
      'Taught 500+ beginning readers CVC blending and phonemic awareness.'
    )
  $$,
  'Teacher A can associate with canonical subject literacy.cvc'
);

select is(
  (select count(*)::integer from public.educator_subjects where educator_id = '8f8c1a20-0000-4000-8000-000000000002'),
  1,
  'Teacher A has exactly 1 subject association'
);

-- Duplicate subject association blocked by unique constraint
select throws_ok(
  $$
    insert into public.educator_subjects (
      educator_id, subject_id, subject_name
    ) values (
      '8f8c1a20-0000-4000-8000-000000000002',
      'literacy.cvc',
      'Duplicate Subject'
    )
  $$,
  '23505',
  null,
  'Duplicate subject association rejected with 23505 unique violation'
);

-- Learner B cannot associate subjects for Teacher A
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000003', true);
select throws_ok(
  $$
    insert into public.educator_subjects (
      educator_id, subject_id, subject_name
    ) values (
      '8f8c1a20-0000-4000-8000-000000000002',
      'unauthorized.subject',
      'Unauthorized'
    )
  $$,
  '42501',
  null,
  'Learner B cannot insert subject associations on Teacher A profile (42501)'
);

-- -----------------------------------------------------------------------------
-- 6. Credential Verification Claims & Moderator Privilege (6 tests)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);

-- Teacher A submits a credential claim with status='pending'
insert into public.educator_verifications (
  id, educator_id, verification_type, jurisdiction, issuer, credential_reference, status
) values (
  '00000000-0000-4000-8000-000000000011',
  '8f8c1a20-0000-4000-8000-000000000002',
  'licensed_credential',
  'FL',
  'Florida Department of Education',
  'FL-CERT-987654',
  'pending'
);

select is(
  (select status from public.educator_verifications where id = '00000000-0000-4000-8000-000000000011'),
  'pending',
  'Teacher A submitted credential has status pending'
);

-- Tamper prevention: Teacher A attempting to self-verify credential is BLOCKED
select throws_ok(
  $$
    update public.educator_verifications
       set status = 'verified', verified_at = now()
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  null,
  'Non-moderator self-verification rejected with 42501'
);

-- Non-moderator calling verify_educator_credential RPC is BLOCKED
select throws_ok(
  $$
    select public.verify_educator_credential(
      '00000000-0000-4000-8000-000000000011'::uuid,
      'verified'
    )
  $$,
  '42501',
  null,
  'Non-moderator RPC invocation rejected with 42501'
);

-- Admin/Moderator reviews and verifies credential
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000001', true);
select lives_ok(
  $$
    select public.verify_educator_credential(
      '00000000-0000-4000-8000-000000000011'::uuid,
      'verified',
      now() + interval '2 years',
      'Credential documents validated.',
      'Internal verification note: Registry confirmed.'
    )
  $$,
  'Moderator successfully verifies educator credential'
);

select is(
  (select status from public.educator_verifications where id = '00000000-0000-4000-8000-000000000011'),
  'verified',
  'Credential status is now verified'
);

select ok(
  (select verified_at is not null from public.educator_verifications where id = '00000000-0000-4000-8000-000000000011'),
  'verified_at timestamp populated upon verification'
);

select is(
  (select verified_by from public.educator_verifications where id = '00000000-0000-4000-8000-000000000011'),
  '8f8c1a20-0000-4000-8000-000000000001'::uuid,
  'verified_by records reviewer admin ID'
);

select is(
  (select count(*)::integer from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and action = 'verified' and reviewer_id = '8f8c1a20-0000-4000-8000-000000000001'),
  1,
  'Verification audit trail entry logged with reviewer attribution'
);

-- Regressions: Teacher A attempts to modify trust-bearing fields on verified credential -> BLOCKED (42501)
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);

select throws_ok(
  $$
    update public.educator_verifications
       set issuer = 'Fraudulent University'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified credentials are immutable to non-moderators',
  'Owner cannot change issuer on verified credential (42501)'
);

select throws_ok(
  $$
    update public.educator_verifications
       set credential_reference = 'FRAUD-999'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified credentials are immutable to non-moderators',
  'Owner cannot change credential_reference on verified credential (42501)'
);

select throws_ok(
  $$
    update public.educator_verifications
       set verification_type = 'platform_vetted'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified credentials are immutable to non-moderators',
  'Owner cannot change verification_type on verified credential (42501)'
);

select throws_ok(
  $$
    update public.educator_verifications
       set jurisdiction = 'CA'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified credentials are immutable to non-moderators',
  'Owner cannot change jurisdiction on verified credential (42501)'
);

select throws_ok(
  $$
    update public.educator_verifications
       set subject_id = 'math.calculus'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified credentials are immutable to non-moderators',
  'Owner cannot change subject_id on verified credential (42501)'
);

select throws_ok(
  $$
    delete from public.educator_verifications
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified, rejected, or revoked credentials cannot be deleted by non-moderators',
  'Owner cannot delete verified credential (42501)'
);

-- -----------------------------------------------------------------------------
-- 6.1 Audit Access Separation (Finding 4) (2 tests)
-- -----------------------------------------------------------------------------
-- Teacher A cannot directly select from educator_verification_audits (RLS blocks confidential staff notes)
select is(
  (select count(*)::integer from public.educator_verification_audits),
  0,
  'Teacher A receives 0 rows from direct select on educator_verification_audits (internal notes shielded)'
);

-- Teacher A can fetch author-facing feedback through fetch_my_credential_feedback RPC
select is(
  (select feedback from public.fetch_my_credential_feedback('00000000-0000-4000-8000-000000000011'::uuid) limit 1),
  'Credential documents validated.',
  'Teacher A can retrieve author-facing feedback via RPC without exposing reviewer or internal notes'
);

-- -----------------------------------------------------------------------------
-- 6.2 Direct Moderator Update Audit Accountability (Finding 2) (5 tests)
-- Moderator B directly revokes Teacher A's credential originally verified by Moderator A
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000004', true);

select lives_ok(
  $$
    update public.educator_verifications
       set status = 'revoked'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  'Moderator B directly revokes credential originally verified by Moderator A'
);

select is(
  (select count(*)::integer from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and new_status = 'revoked'),
  1,
  'Database trigger automatically recorded audit entry for direct revocation'
);

select is(
  (select reviewer_id from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and new_status = 'revoked'),
  '8f8c1a20-0000-4000-8000-000000000004'::uuid,
  'Direct revocation records Moderator B as audit reviewer instead of original verifier'
);

select is(
  (select metadata->>'original_verified_by' from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and new_status = 'revoked'),
  '8f8c1a20-0000-4000-8000-000000000001',
  'Original verifier Moderator A preserved in audit metadata'
);

select is(
  (select action from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and new_status = 'revoked'),
  'revoked',
  'Audit record action accurately reflects revoked status'
);

-- -----------------------------------------------------------------------------
-- 6.3 Lifecycle Status Transitions & Decision Authorization (Finding 3) (6 tests)
-- -----------------------------------------------------------------------------
-- 1. Owner cannot delete revoked credential
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);

select throws_ok(
  $$
    delete from public.educator_verifications
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: verified, rejected, or revoked credentials cannot be deleted by non-moderators',
  'Owner cannot delete revoked credential (42501)'
);

-- 2. Teacher A resubmits revoked credential by transitioning status to 'pending'
select lives_ok(
  $$
    update public.educator_verifications
       set status = 'pending'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  'Teacher A can resubmit revoked credential by transitioning status to pending'
);

select is(
  (select count(*)::integer from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and new_status = 'pending' and action = 'pending'),
  1,
  'Status transition to pending creates valid audit record with action = pending'
);

-- 3. Moderator resets credential to 'unverified'
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000001', true);
select lives_ok(
  $$
    update public.educator_verifications
       set status = 'unverified'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  'Moderator can reset credential status to unverified'
);

select is(
  (select count(*)::integer from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011' and new_status = 'unverified' and action = 'unverified'),
  1,
  'Status transition to unverified creates valid audit record with action = unverified'
);

-- 4. Non-moderator cannot make unilateral moderation decisions (e.g. setting status to 'rejected')
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);
select throws_ok(
  $$
    update public.educator_verifications
       set status = 'rejected'
     where id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  'Access denied: only moderators can make moderation decisions (verified, rejected, expired, revoked)',
  'Non-moderator cannot set status to rejected (42501)'
);

-- -----------------------------------------------------------------------------
-- 6.4 Append-Only Audit Integrity & service_role Protection (Finding 1) (4 tests)
-- -----------------------------------------------------------------------------
-- Authenticated user cannot update audit rows
select throws_ok(
  $$
    update public.educator_verification_audits
       set notes = 'tampered'
     where verification_id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  null,
  'Authenticated role cannot update educator_verification_audits (42501)'
);

-- Authenticated user cannot delete audit rows
select throws_ok(
  $$
    delete from public.educator_verification_audits
     where verification_id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  null,
  'Authenticated role cannot delete educator_verification_audits (42501)'
);

-- service_role cannot update audit rows (trigger and privileges enforce append-only)
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select throws_ok(
  $$
    update public.educator_verification_audits
       set notes = 'tampered by service_role'
     where verification_id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  null,
  'service_role cannot update educator_verification_audits (42501 append-only guard)'
);

-- service_role cannot delete audit rows
select throws_ok(
  $$
    delete from public.educator_verification_audits
     where verification_id = '00000000-0000-4000-8000-000000000011'
  $$,
  '42501',
  null,
  'service_role cannot delete educator_verification_audits (42501 append-only guard)'
);

set local role postgres;

-- -----------------------------------------------------------------------------
-- 6.5 Audit Durability on Claim Deletion (1 test)
-- -----------------------------------------------------------------------------
-- Claim deletion does not cascade-delete audit history
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000001', true);
delete from public.educator_verifications where id = '00000000-0000-4000-8000-000000000011';

select ok(
  (select count(*)::integer from public.educator_verification_audits where verification_id = '00000000-0000-4000-8000-000000000011') >= 3,
  'Verification audits are preserved independently after credential claim deletion (no cascading delete)'
);


-- -----------------------------------------------------------------------------
-- 7. Follows & Anti-Self-Follow Checks (4 tests)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000003', true);

-- Learner B follows Teacher A
select lives_ok(
  $$
    insert into public.educator_follows (follower_id, educator_id)
    values ('8f8c1a20-0000-4000-8000-000000000003', '8f8c1a20-0000-4000-8000-000000000002')
  $$,
  'Learner B can follow Teacher A'
);

select is(
  (select count(*)::integer from public.educator_follows where follower_id = '8f8c1a20-0000-4000-8000-000000000003'),
  1,
  'Learner B has exactly 1 follow record'
);

-- Duplicate follow rejected
select throws_ok(
  $$
    insert into public.educator_follows (follower_id, educator_id)
    values ('8f8c1a20-0000-4000-8000-000000000003', '8f8c1a20-0000-4000-8000-000000000002')
  $$,
  '23505',
  null,
  'Duplicate follow rejected with 23505'
);

-- Self-follow rejected by check constraint
select set_config('request.jwt.claim.sub', '8f8c1a20-0000-4000-8000-000000000002', true);
select throws_ok(
  $$
    insert into public.educator_follows (follower_id, educator_id)
    values ('8f8c1a20-0000-4000-8000-000000000002', '8f8c1a20-0000-4000-8000-000000000002')
  $$,
  '23514',
  null,
  'Self-follow rejected with 23514 check constraint violation'
);

rollback;
