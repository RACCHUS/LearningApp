-- pgTAP Community Q&A Security & Integrity Test Suite (ECO-01 Hardened)
-- Validates concept-scoped Q&A schema, anonymous read access (no 42501 errors),
-- parent-question publication constraints on answers, tamper-prevention triggers,
-- atomic upvoting, answer counting triggers, and moderation integration.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(79);

-- 1. Setup synthetic test users
insert into auth.users (id, email) values
  ('7f7c1a20-0000-4000-8000-000000000001', 'qa-admin@example.invalid'),
  ('7f7c1a20-0000-4000-8000-000000000002', 'qa-learner-a@example.invalid'),
  ('7f7c1a20-0000-4000-8000-000000000003', 'qa-learner-b@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('7f7c1a20-0000-4000-8000-000000000001', 'qa-admin@example.invalid'),
  ('7f7c1a20-0000-4000-8000-000000000002', 'qa-learner-a@example.invalid'),
  ('7f7c1a20-0000-4000-8000-000000000003', 'qa-learner-b@example.invalid')
on conflict (id) do nothing;

insert into public.moderation_roles (user_id, role, granted_by)
values ('7f7c1a20-0000-4000-8000-000000000001', 'admin', '7f7c1a20-0000-4000-8000-000000000001')
on conflict (user_id) do update set role = 'admin';

-- -----------------------------------------------------------------------------
-- 1. Schema Structure Checks (8 tests)
-- -----------------------------------------------------------------------------
select has_table('public', 'community_questions', 'Table public.community_questions exists');
select has_table('public', 'community_answers', 'Table public.community_answers exists');
select has_table('public', 'community_votes', 'Table public.community_votes exists');
select has_table('public', 'community_config', 'Table public.community_config exists');
select has_table('public', 'community_review_audit', 'Table public.community_review_audit exists');
select has_function('public', 'cast_community_vote', Array['text', 'uuid'], 'RPC cast_community_vote exists');
select has_function('public', 'handle_community_answer_count', 'Trigger function handle_community_answer_count exists');
select has_function('private', 'is_community_ugc_public_enabled', 'Function private.is_community_ugc_public_enabled exists');

-- -----------------------------------------------------------------------------
-- 2. Unauthenticated Access & Anonymous Read Permissions (2 tests)
-- -----------------------------------------------------------------------------
set local role anon;

select throws_ok(
  $$ select public.cast_community_vote('question', '00000000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  null,
  'Unauthenticated voting rejected with 42501'
);

-- Anonymous SELECT must execute without permission denied on private.is_admin()
select lives_ok(
  $$ select count(*) from public.community_questions where status = 'published' $$,
  'Anonymous role can SELECT published questions without 42501 is_admin error'
);

-- -----------------------------------------------------------------------------
-- 3. Phase 1 Gate & RLS Enforcement: Non-Admin Public UGC Disabled (4 tests)
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000002', true);

-- Learner A attempting to publish directly to public feed must be blocked by RLS
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status
    ) values (
      '00000000-0000-0000-0000-000000000101',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Unauthorized Public Question',
      'This question should not be directly published by non-admin.',
      'published'
    )
  $$,
  '42501',
  null,
  'Non-admin learner cannot publish questions directly (RLS blocks status=published)'
);

-- Learner A attempting to mark question as is_seeded must be blocked
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, is_seeded
    ) values (
      '00000000-0000-0000-0000-000000000102',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Unauthorized Seeded Question',
      'This question should not be marked seeded by non-admin.',
      'draft',
      true
    )
  $$,
  '42501',
  null,
  'Non-admin learner cannot mark questions as seeded'
);

-- Learner A authoring private draft question succeeds
select lives_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, concept_id
    ) values (
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'How does phonics blending work?',
      'I am trying to understand the blending of CVC words.',
      'draft',
      'literacy.phonics.blending'
    )
  $$,
  'Learner A successfully creates private draft question'
);

-- Direct writes to community_votes by authenticated user are revoked
select throws_ok(
  $$
    insert into public.community_votes (user_id, target_type, target_id)
    values ('7f7c1a20-0000-4000-8000-000000000002', 'question', '00000000-0000-0000-0000-000000000103')
  $$,
  '42501',
  null,
  'Direct insert to community_votes by authenticated client is revoked (42501)'
);

-- -----------------------------------------------------------------------------
-- 4. Admin Question Seeding & Publishing (3 tests)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000001', true);

select lives_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, is_seeded, concept_id
    ) values (
      '00000000-0000-0000-0000-000000000201',
      '7f7c1a20-0000-4000-8000-000000000001',
      'Official Seed FAQ: What is a CVC word?',
      'A CVC word is a three-letter word following the Consonant-Vowel-Consonant pattern.',
      'published',
      true,
      'literacy.cvc.basics'
    )
  $$,
  'Admin successfully seeds and publishes official FAQ question'
);

-- Admin adds published answer to the seed FAQ
select lives_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, is_ai_generated, is_accepted, status
    ) values (
      '00000000-0000-0000-0000-000000000301',
      '00000000-0000-0000-0000-000000000201',
      '7f7c1a20-0000-4000-8000-000000000001',
      'Examples of CVC words include cat, dog, and sun. They are foundational for emergent readers.',
      false,
      true,
      'published'
    )
  $$,
  'Admin publishes official answer for seed FAQ'
);

-- Verify answer count increment trigger
select is(
  (select answer_count from public.community_questions where id = '00000000-0000-0000-0000-000000000201'),
  1,
  'community_questions.answer_count atomically incremented to 1 by trigger'
);

-- -----------------------------------------------------------------------------
-- 5. Tenant Isolation & Anonymous Visibility (6 tests)
-- -----------------------------------------------------------------------------
-- Switch to Learner B
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000003', true);

-- Learner B can see published seed FAQ
select is(
  (select count(*)::int from public.community_questions where id = '00000000-0000-0000-0000-000000000201'),
  1,
  'Learner B can read published seed FAQ question'
);

-- Learner B can see published answer
select is(
  (select count(*)::int from public.community_answers where id = '00000000-0000-0000-0000-000000000301'),
  1,
  'Learner B can read published answer on seed FAQ'
);

-- Learner B CANNOT see Learner A draft question (Tenant isolation)
select is(
  (select count(*)::int from public.community_questions where id = '00000000-0000-0000-0000-000000000103'),
  0,
  'Learner B cannot see Learner A private draft question'
);

-- Switch to anon
set local role anon;

-- Anon CAN see published seed FAQ
select is(
  (select count(*)::int from public.community_questions where id = '00000000-0000-0000-0000-000000000201'),
  1,
  'Anon can read published seed FAQ question'
);

-- Anon CANNOT see Learner A draft question
select is(
  (select count(*)::int from public.community_questions where id = '00000000-0000-0000-0000-000000000103'),
  0,
  'Anon cannot read private draft question'
);

-- Anon CAN see published answer on published seed FAQ
select is(
  (select count(*)::int from public.community_answers where id = '00000000-0000-0000-0000-000000000301'),
  1,
  'Anon can read published answer on published seed FAQ'
);

-- -----------------------------------------------------------------------------
-- 6. Parent Question Publication Constraints on Answers (6 tests)
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000001', true);

-- Admin creates unpublished draft question
select lives_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, is_seeded
    ) values (
      '00000000-0000-0000-0000-000000000401',
      '7f7c1a20-0000-4000-8000-000000000001',
      'Unpublished Draft Admin Question',
      'This question is in draft status.',
      'draft',
      false
    )
  $$,
  'Admin creates draft question'
);

-- Admin attaches answer marked published to that draft question
select lives_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, status
    ) values (
      '00000000-0000-0000-0000-000000000402',
      '00000000-0000-0000-0000-000000000401',
      '7f7c1a20-0000-4000-8000-000000000001',
      'Answer to an unpublished draft question.',
      'published'
    )
  $$,
  'Admin creates answer on draft question'
);

-- Anon must NOT be able to see answer to unpublished draft question
set local role anon;
select is(
  (select count(*)::int from public.community_answers where id = '00000000-0000-0000-0000-000000000402'),
  0,
  'Anon cannot see answer to unpublished parent question even if answer has status=published'
);

-- Learner B must NOT be able to see answer to unpublished draft question
set local role authenticated;
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000003', true);
select is(
  (select count(*)::int from public.community_answers where id = '00000000-0000-0000-0000-000000000402'),
  0,
  'Learner B cannot see answer to unpublished parent question'
);

-- Voting on answer to unpublished question must fail with P0002
select throws_ok(
  $$ select public.cast_community_vote('answer', '00000000-0000-0000-0000-000000000402'::uuid) $$,
  'P0002',
  null,
  'Voting on answer to unpublished parent question rejected with P0002'
);

-- Reporting answer to unpublished question must fail with P0002
select throws_ok(
  $$ select public.submit_moderation_report('community_answer', '00000000-0000-0000-0000-000000000402'::uuid, 'spam', 'Spam report') $$,
  'P0002',
  null,
  'Reporting answer to unpublished parent question rejected with P0002'
);

-- -----------------------------------------------------------------------------
-- 7. Atomic Upvoting RPC (6 tests)
-- -----------------------------------------------------------------------------
-- Learner B upvotes seed FAQ question
select is(
  (public.cast_community_vote('question', '00000000-0000-0000-0000-000000000201'::uuid)->>'voted')::boolean,
  true,
  'Learner B casts upvote on seed FAQ'
);

select is(
  (select upvote_count from public.community_questions where id = '00000000-0000-0000-0000-000000000201'),
  1,
  'Upvote count incremented to 1'
);

-- Learner B upvotes again (toggle off)
select is(
  (public.cast_community_vote('question', '00000000-0000-0000-0000-000000000201'::uuid)->>'voted')::boolean,
  false,
  'Learner B removes upvote on second call'
);

select is(
  (select upvote_count from public.community_questions where id = '00000000-0000-0000-0000-000000000201'),
  0,
  'Upvote count decremented to 0'
);

-- Voting on nonexistent target fails with P0002
select throws_ok(
  $$ select public.cast_community_vote('question', '00000000-0000-0000-0000-999999999999'::uuid) $$,
  'P0002',
  null,
  'Voting on nonexistent question raises P0002'
);

-- Voting on inaccessible draft question fails with P0002
select throws_ok(
  $$ select public.cast_community_vote('question', '00000000-0000-0000-0000-000000000103'::uuid) $$,
  'P0002',
  null,
  'Learner B voting on Learner A draft question raises P0002'
);

-- -----------------------------------------------------------------------------
-- 8. Moderation Reporting Integration (3 tests)
-- -----------------------------------------------------------------------------
-- Learner B can report published community question
select lives_ok(
  $$
    select public.submit_moderation_report(
      'community_question',
      '00000000-0000-0000-0000-000000000201'::uuid,
      'misinformation',
      'Feedback on seed question accuracy'
    )
  $$,
  'Learner B can submit moderation report on visible community question'
);

-- Reporting inaccessible draft raises P0002
select throws_ok(
  $$
    select public.submit_moderation_report(
      'community_question',
      '00000000-0000-0000-0000-000000000103'::uuid,
      'spam',
      'Reporting inaccessible draft'
    )
  $$,
  'P0002',
  null,
  'Submitting report on inaccessible draft community question raises P0002'
);

-- Reporting published community answer succeeds
select lives_ok(
  $$
    select public.submit_moderation_report(
      'community_answer',
      '00000000-0000-0000-0000-000000000301'::uuid,
      'inappropriate',
      'Feedback on answer'
    )
  $$,
  'Learner B can submit moderation report on visible community answer'
);

-- -----------------------------------------------------------------------------
-- 9. Authoritative Counter & System Field Tamper-Proofing (5 tests)
-- -----------------------------------------------------------------------------
-- Switch to Learner A
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000002', true);

-- Learner A attempting to directly mutate upvote_count on own draft question is blocked
select throws_ok(
  $$
    update public.community_questions
       set upvote_count = 999
     where id = '00000000-0000-0000-0000-000000000103'
  $$,
  '42501',
  null,
  'Learner directly updating upvote_count on community question rejected by tamper trigger (42501)'
);

-- Learner A attempting to directly mutate is_seeded on own draft question is blocked
select throws_ok(
  $$
    update public.community_questions
       set is_seeded = true
     where id = '00000000-0000-0000-0000-000000000103'
  $$,
  '42501',
  null,
  'Learner directly updating is_seeded on community question rejected by tamper trigger (42501)'
);

-- Learner A creates draft answer to own draft question
select lives_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, status
    ) values (
      '00000000-0000-0000-0000-000000000501',
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Learner A draft answer note.',
      'draft'
    )
  $$,
  'Learner A creates draft answer'
);

-- Learner A attempting to directly set is_accepted on answer is blocked
select throws_ok(
  $$
    update public.community_answers
       set is_accepted = true
     where id = '00000000-0000-0000-0000-000000000501'
  $$,
  '42501',
  null,
  'Learner directly updating is_accepted on community answer rejected by tamper trigger (42501)'
);

-- Learner A attempting to directly set upvote_count on answer is blocked
select throws_ok(
  $$
    update public.community_answers
       set upvote_count = 50
     where id = '00000000-0000-0000-0000-000000000501'
  $$,
  '42501',
  null,
  'Learner directly updating upvote_count on community answer rejected by tamper trigger (42501)'
);

-- -----------------------------------------------------------------------------
-- 10. INSERT Tamper-Proofing on Questions & Answers (8 tests)
-- -----------------------------------------------------------------------------
-- Learner A attempting to explicitly specify upvote_count on question INSERT is blocked
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, upvote_count
    ) values (
      '00000000-0000-0000-0000-000000000502',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Question with forged upvotes',
      'Body text for testing upvote forge on insert.',
      'draft',
      50
    )
  $$,
  '42501',
  null,
  'Learner inserting community question with explicit upvote_count is rejected (42501)'
);

-- Learner A attempting to explicitly specify view_count on question INSERT is blocked
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, view_count
    ) values (
      '00000000-0000-0000-0000-000000000503',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Question with forged views',
      'Body text for testing view forge on insert.',
      'draft',
      100
    )
  $$,
  '42501',
  null,
  'Learner inserting community question with explicit view_count is rejected (42501)'
);

-- Learner A attempting to explicitly specify answer_count on question INSERT is blocked
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, answer_count
    ) values (
      '00000000-0000-0000-0000-000000000504',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Question with forged answers',
      'Body text for testing answer count forge on insert.',
      'draft',
      10
    )
  $$,
  '42501',
  null,
  'Learner inserting community question with explicit answer_count is rejected (42501)'
);

-- Learner A attempting to explicitly specify created_at on question INSERT is blocked
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, created_at
    ) values (
      '00000000-0000-0000-0000-000000000505',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Question with forged timestamp',
      'Body text for testing timestamp forge on insert.',
      'draft',
      '2020-01-01 00:00:00+00'::timestamptz
    )
  $$,
  '42501',
  null,
  'Learner inserting community question with explicit created_at is rejected (42501)'
);

-- Learner A attempting to explicitly specify is_accepted on answer INSERT is blocked
select throws_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, status, is_accepted
    ) values (
      '00000000-0000-0000-0000-000000000506',
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Forged accepted answer body text.',
      'draft',
      true
    )
  $$,
  '42501',
  null,
  'Learner inserting community answer with explicit is_accepted is rejected (42501)'
);

-- Learner A attempting to explicitly specify upvote_count on answer INSERT is blocked
select throws_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, status, upvote_count
    ) values (
      '00000000-0000-0000-0000-000000000507',
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Forged upvote answer body text.',
      'draft',
      25
    )
  $$,
  '42501',
  null,
  'Learner inserting community answer with explicit upvote_count is rejected (42501)'
);

-- Learner A attempting to explicitly specify is_ai_generated on answer INSERT is blocked
select throws_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, status, is_ai_generated
    ) values (
      '00000000-0000-0000-0000-000000000508',
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Forged AI flag answer body text.',
      'draft',
      true
    )
  $$,
  '42501',
  null,
  'Learner inserting community answer with explicit is_ai_generated is rejected (42501)'
);

-- Learner A attempting to explicitly specify created_at on answer INSERT is blocked
select throws_ok(
  $$
    insert into public.community_answers (
      id, question_id, author_id, body_markdown, status, created_at
    ) values (
      '00000000-0000-0000-0000-000000000509',
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Forged timestamp answer body text.',
      'draft',
      '2020-01-01 00:00:00+00'::timestamptz
    )
  $$,
  '42501',
  null,
  'Learner inserting community answer with explicit created_at is rejected (42501)'
);

-- -----------------------------------------------------------------------------
-- 11. Trigger Function Execution Revocation (3 tests)
-- -----------------------------------------------------------------------------
select ok(
  not has_function_privilege('authenticated', 'public.handle_community_answer_count()', 'execute'),
  'Authenticated role has no EXECUTE privilege on handle_community_answer_count'
);

select ok(
  not has_function_privilege('authenticated', 'public.prevent_community_question_tampering()', 'execute'),
  'Authenticated role has no EXECUTE privilege on prevent_community_question_tampering'
);

select ok(
  not has_function_privilege('authenticated', 'public.prevent_community_answer_tampering()', 'execute'),
  'Authenticated role has no EXECUTE privilege on prevent_community_answer_tampering'
);

-- -----------------------------------------------------------------------------
-- 12. ECO-02 Moderator Review Workflow & FAQ Seeding (14 tests)
-- -----------------------------------------------------------------------------
reset role;

-- Function existence checks (4 tests)
select has_function('public', 'review_community_question', Array['uuid', 'text', 'text'], 'RPC review_community_question exists');
select has_function('public', 'review_community_answer', Array['uuid', 'text', 'text'], 'RPC review_community_answer exists');
select has_function('public', 'accept_community_answer', Array['uuid'], 'RPC accept_community_answer exists');
select has_function('public', 'seed_pilot_community_faqs', Array['uuid'], 'RPC seed_pilot_community_faqs exists');

-- Provision moderator user
insert into auth.users (id, email) values
  ('7f7c1a20-0000-4000-8000-000000000004', 'qa-moderator@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('7f7c1a20-0000-4000-8000-000000000004', 'qa-moderator@example.invalid')
on conflict (id) do nothing;

insert into public.moderation_roles (user_id, role, granted_by)
values ('7f7c1a20-0000-4000-8000-000000000004', 'moderator', '7f7c1a20-0000-4000-8000-000000000001')
on conflict (user_id) do update set role = 'moderator';

-- Test question for review workflow
insert into public.community_questions (
  id, author_id, title, body_markdown, status
) values (
  '00000000-0000-0000-0000-000000000601',
  '7f7c1a20-0000-4000-8000-000000000002',
  'Question awaiting review',
  'Learner A submitted this question for educator review.',
  'under_review'
) on conflict (id) do nothing;

-- Non-moderator learner calling review_community_question throws 42501 (1 test)
set local role authenticated;
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000002', true);

select throws_ok(
  $$ select public.review_community_question('00000000-0000-0000-0000-000000000601'::uuid, 'publish') $$,
  '42501',
  null,
  'Non-moderator cannot call review_community_question (42501)'
);

-- Non-moderator learner calling review_community_answer throws 42501 (1 test)
select throws_ok(
  $$ select public.review_community_answer('00000000-0000-0000-0000-000000000301'::uuid, 'publish') $$,
  '42501',
  null,
  'Non-moderator cannot call review_community_answer (42501)'
);

-- Non-author, non-moderator calling accept_community_answer throws 42501 (1 test)
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000003', true);
select throws_ok(
  $$ select public.accept_community_answer('00000000-0000-0000-0000-000000000301'::uuid) $$,
  '42501',
  null,
  'Non-author, non-moderator learner cannot accept answers (42501)'
);

-- Switch to Moderator session
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000004', true);

-- Moderator can SELECT under-review questions by other users via RLS (1 test)
select is(
  (select count(*)::integer from public.community_questions where id = '00000000-0000-0000-0000-000000000601'),
  1,
  'Moderator can select under_review question authored by another learner'
);

-- Invalid review action throws 22023 (1 test)
select throws_ok(
  $$ select public.review_community_question('00000000-0000-0000-0000-000000000601'::uuid, 'invalid_action') $$,
  '22023',
  null,
  'Invalid question review action rejected with 22023'
);

-- UGC Launch Gate: Moderator cannot publish non-seeded learner question while public UGC is disabled (1 test)
select throws_ok(
  $$ select public.review_community_question('00000000-0000-0000-0000-000000000601'::uuid, 'publish') $$,
  '22000',
  null,
  'Moderator cannot publish learner question while public UGC launch gate is closed (22000)'
);

-- Moderator can archive learner question (1 test)
select lives_ok(
  $$ select public.review_community_question('00000000-0000-0000-0000-000000000601'::uuid, 'archive', 'Archived due to UGC gate') $$,
  'Moderator archiving learner question succeeds'
);

select is(
  (select status from public.community_questions where id = '00000000-0000-0000-0000-000000000601'),
  'archived',
  'Question status transitioned to archived'
);

-- Durable audit trail check for question review (1 test)
select is(
  (select count(*)::integer from public.community_review_audit where target_type = 'question' and target_id = '00000000-0000-0000-0000-000000000601' and action = 'archive' and notes = 'Archived due to UGC gate'),
  1,
  'Append-only review audit record created for question review'
);

-- Moderator creates second draft answer on published seeded question 201
insert into public.community_answers (
  id, question_id, author_id, body_markdown, status, is_accepted
) values (
  '00000000-0000-0000-0000-000000000602',
  '00000000-0000-0000-0000-000000000201',
  '7f7c1a20-0000-4000-8000-000000000004',
  'Second verified explanatory answer submitted for review.',
  'under_review',
  false
) on conflict (id) do nothing;

-- Moderator publishes the answer via review_community_answer (seeded parent question allows publishing) (1 test)
select lives_ok(
  $$ select public.review_community_answer('00000000-0000-0000-0000-000000000602'::uuid, 'publish', 'Verified educator explanation') $$,
  'Moderator publishing under-review answer for seeded question succeeds'
);

-- Durable audit trail check for answer review (1 test)
select is(
  (select count(*)::integer from public.community_review_audit where target_type = 'answer' and target_id = '00000000-0000-0000-0000-000000000602' and action = 'publish'),
  1,
  'Append-only review audit record created for answer review'
);

-- Question author accepts second answer (1 test)
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000001', true);
select lives_ok(
  $$ select public.accept_community_answer('00000000-0000-0000-0000-000000000602'::uuid) $$,
  'Question author can accept published answer'
);

-- Single accepted answer invariant: 301 was accepted, now 602 is accepted and 301 is not (2 tests)
select is(
  (select is_accepted from public.community_answers where id = '00000000-0000-0000-0000-000000000602'),
  true,
  'Newly accepted answer has is_accepted = true'
);

select is(
  (select is_accepted from public.community_answers where id = '00000000-0000-0000-0000-000000000301'),
  false,
  'Previously accepted answer automatically transitioned to is_accepted = false'
);

-- Audit table permissions and RLS (2 tests)
set local role authenticated;
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000002', true);
select is(
  (select count(*)::integer from public.community_review_audit),
  0,
  'Learner cannot select records from community_review_audit (RLS returns 0 rows)'
);

select throws_ok(
  $$ insert into public.community_review_audit (target_type, target_id, action, previous_status, new_status) values ('question', '00000000-0000-0000-0000-000000000601', 'publish', 'under_review', 'published') $$,
  '42501',
  null,
  'Direct insert to community_review_audit by authenticated learner is revoked (42501)'
);

-- Seeding RPC authorization check: learner cannot call seed_pilot_community_faqs (1 test)
select throws_ok(
  $$ select public.seed_pilot_community_faqs('7f7c1a20-0000-4000-8000-000000000002'::uuid) $$,
  '42501',
  null,
  'Learner calling seed_pilot_community_faqs is rejected with 42501'
);

-- Admin calling seed_pilot_community_faqs succeeds (1 test)
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000001', true);
select ok(
  (select public.seed_pilot_community_faqs('7f7c1a20-0000-4000-8000-000000000001'::uuid)) >= 18,
  'Admin calling seed_pilot_community_faqs successfully seeds at least 18 reference FAQs'
);

-- Idempotency check: second invocation returns 0 (1 test)
select is(
  (select public.seed_pilot_community_faqs('7f7c1a20-0000-4000-8000-000000000001'::uuid)),
  0,
  'Second invocation of seed_pilot_community_faqs is idempotent and returns 0 new questions'
);

-- Exactly 18 pilot reference FAQs seeded (1 test)
select is(
  (select count(*)::integer from public.community_questions where is_seeded = true and id <> '00000000-0000-0000-0000-000000000201'),
  18,
  'Exactly 18 pilot reference FAQs seeded'
);

-- Answer count trigger integrity: all seeded pilot FAQs must have answer_count = 1 (1 test)
select is(
  (select count(*)::integer from public.community_questions where is_seeded = true and id <> '00000000-0000-0000-0000-000000000201' and answer_count <> 1),
  0,
  'All 18 seeded pilot FAQs have answer_count exactly equal to 1'
);

rollback;
