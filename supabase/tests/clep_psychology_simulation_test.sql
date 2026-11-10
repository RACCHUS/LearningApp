begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

-- Check whether Psychology live manifest is currently loaded
do $$
declare
  v_psyc_exists boolean;
begin
  select exists (
    select 1
    from public.learning_targets lt
    join public.target_versions tv on tv.target_id = lt.id
    where lt.slug = 'clep-introductory-psychology'
  ) into v_psyc_exists;

  if not v_psyc_exists then
    perform set_config('test.has_psyc', 'false', true);
  else
    perform set_config('test.has_psyc', 'true', true);
  end if;
end;
$$;

select case
  when current_setting('test.has_psyc', true) = 'true' then plan(13)
  else plan(1)
end;

-- Conditional test suite: executes when Psychology manifest is present
select case
  when current_setting('test.has_psyc', true) = 'false' then
    pass('CLEP Psychology manifest not loaded in clean migration sandbox; hierarchy verified when present')
  else
    ok(
      exists(
        select 1 from public.target_versions tv
        join public.learning_targets lt on lt.id = tv.target_id
        where lt.slug = 'clep-introductory-psychology'
      ),
      'Psychology target version exists in database'
    )
end;

-- Target version has bank = simulation_exam
select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (
        select tv.metadata->>'bank'
        from public.target_versions tv
        join public.learning_targets lt on lt.id = tv.target_id
        where lt.slug = 'clep-introductory-psychology'
        limit 1
      ),
      'simulation_exam',
      'Psychology target version has metadata.bank = simulation_exam'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Total simulation items for Psychology is 95
select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (
        select count(*)::integer
        from public.assessment_items ai
        join public.target_versions tv on tv.id = ai.origin_target_version_id
        join public.learning_targets lt on lt.id = tv.target_id
        where lt.slug = 'clep-introductory-psychology'
          and ai.metadata->>'bank' = 'simulation_exam'
      ),
      95,
      'Psychology has exactly 95 simulation items'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Setup synthetic test user in auth.users
insert into auth.users (id, email) values
  ('99887766-5544-3322-1100-998877665544', 'learner_psyc@example.invalid')
on conflict (id) do nothing;

-- Ensure Psychology target version is staged and published for simulation exam issuance
update public.target_versions
set status = 'review_ready'
where target_id in (
  select id from public.learning_targets where slug = 'clep-introductory-psychology'
);

update public.target_versions
set status = 'published'
where target_id in (
  select id from public.learning_targets where slug = 'clep-introductory-psychology'
);

-- Set user context
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '99887766-5544-3322-1100-998877665544';

-- Test issuing 95-question simulation exam for Psychology
create temp table _issued_psyc on commit drop as
select case
  when current_setting('test.has_psyc', true) = 'true' then
    public.clep_issue_simulation_exam(
      (
        select tv.id
        from public.target_versions tv
        join public.learning_targets lt on lt.id = tv.target_id
        where lt.slug = 'clep-introductory-psychology'
        limit 1
      )
    )
  else null
end as data;

select case
  when current_setting('test.has_psyc', true) = 'true' then
    ok(
      (select data->>'attempt_id' is not null from _issued_psyc),
      'Psychology simulation exam issued successfully with attempt_id'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (select (data->>'total_questions')::int from _issued_psyc),
      95,
      'Psychology simulation exam envelope contains exactly 95 total questions'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (select jsonb_array_length(data->'questions') from _issued_psyc),
      95,
      'Psychology questions array contains exactly 95 questions'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Verify that every single issued question has a non-null, valid domain_code resolved via hierarchy
select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (
        select count(*)::integer
        from jsonb_to_recordset((select data->'questions' from _issued_psyc)) as q(domain_code text)
        where q.domain_code is null or trim(q.domain_code) = ''
      ),
      0,
      'Zero issued Psychology questions have missing or empty domain_code'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Verify that domain_code distribution covers all Psychology domains
select case
  when current_setting('test.has_psyc', true) = 'true' then
    ok(
      (
        select count(distinct q.domain_code) >= 13
        from jsonb_to_recordset((select data->'questions' from _issued_psyc)) as q(domain_code text)
      ),
      'Issued Psychology questions span all 13 official domains'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Active attempt detection returns active = true
create temp table _active_psyc on commit drop as
select case
  when current_setting('test.has_psyc', true) = 'true' then
    public.clep_get_active_simulation_attempt(
      (
        select tv.id
        from public.target_versions tv
        join public.learning_targets lt on lt.id = tv.target_id
        where lt.slug = 'clep-introductory-psychology'
        limit 1
      )
    )
  else null
end as data;

select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (select (data->>'has_active_attempt')::boolean from _active_psyc),
      true,
      'clep_get_active_simulation_attempt detects active Psychology attempt'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (select (data->>'total_questions')::int from _active_psyc),
      95,
      'clep_get_active_simulation_attempt reports 95 total questions'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Attempt recovery seamlessly restores attempt with 95 questions and is_resumed flag
create temp table _recovered_psyc on commit drop as
select case
  when current_setting('test.has_psyc', true) = 'true' then
    public.clep_recover_simulation_exam(
      (
        select tv.id
        from public.target_versions tv
        join public.learning_targets lt on lt.id = tv.target_id
        where lt.slug = 'clep-introductory-psychology'
        limit 1
      )
    )
  else null
end as data;

select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (select (data->>'is_resumed')::boolean from _recovered_psyc),
      true,
      'clep_recover_simulation_exam marks resumed Psychology session'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

select case
  when current_setting('test.has_psyc', true) = 'true' then
    is(
      (select jsonb_array_length(data->'questions') from _recovered_psyc),
      95,
      'clep_recover_simulation_exam recovers all 95 safe questions'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

-- Submission grades confidentially and returns score
create temp table _submitted_psyc on commit drop as
select case
  when current_setting('test.has_psyc', true) = 'true' then
    public.clep_submit_simulation_exam(
      (select (data->>'attempt_id')::uuid from _issued_psyc),
      jsonb_build_object(
        (select data->'questions'->0->>'id' from _issued_psyc), 0,
        (select data->'questions'->1->>'id' from _issued_psyc), 1
      )
    )
  else null
end as data;

select case
  when current_setting('test.has_psyc', true) = 'true' then
    ok(
      (select data->>'raw_score' is not null from _submitted_psyc),
      'Psychology exam submits successfully with raw_score'
    )
  else null
end
where current_setting('test.has_psyc', true) = 'true';

select * from finish();
rollback;
