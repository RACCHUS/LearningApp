-- pgTAP Community Q&A Security & Integrity Test Suite (ECO-01)
-- Validates concept-scoped Q&A schema, RLS boundaries (public UGC disabled for non-admins),
-- atomic upvoting, answer counting triggers, and moderation integration.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(28);

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
-- Schema Structure Checks
-- -----------------------------------------------------------------------------
select has_table('public', 'community_questions', 'Table public.community_questions exists');
select has_table('public', 'community_answers', 'Table public.community_answers exists');
select has_table('public', 'community_votes', 'Table public.community_votes exists');
select has_function('public', 'cast_community_vote', Array['text', 'uuid'], 'RPC cast_community_vote exists');
select has_function('public', 'handle_community_answer_count', 'Trigger function handle_community_answer_count exists');

-- -----------------------------------------------------------------------------
-- Unauthenticated Access
-- -----------------------------------------------------------------------------
set local role anon;

select throws_ok(
  $$ select public.cast_community_vote('question', '00000000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  null,
  'Unauthenticated voting rejected with 42501'
);

-- -----------------------------------------------------------------------------
-- Phase 1 Gate & RLS Enforcement: Non-Admin Public UGC Disabled
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '7f7c1a20-0000-4000-8000-000000000002', true);

-- Learner A attempting to publish directly to public feed must be blocked by RLS
select throws_ok(
  $$
    insert into public.community_questions (
      id, author_id, title, body_markdown, status, is_seeded
    ) values (
      '00000000-0000-0000-0000-000000000101',
      '7f7c1a20-0000-4000-8000-000000000002',
      'Unauthorized Public Question',
      'This question should not be directly published by non-admin.',
      'published',
      false
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
      id, author_id, title, body_markdown, status, is_seeded, concept_id
    ) values (
      '00000000-0000-0000-0000-000000000103',
      '7f7c1a20-0000-4000-8000-000000000002',
      'How does phonics blending work?',
      'I am trying to understand the blending of CVC words.',
      'draft',
      false,
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
-- Admin Question Seeding & Publishing
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
-- Tenant Isolation & Visibility
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

-- -----------------------------------------------------------------------------
-- Atomic Upvoting RPC
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
-- Moderation Reporting Integration
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

rollback;
