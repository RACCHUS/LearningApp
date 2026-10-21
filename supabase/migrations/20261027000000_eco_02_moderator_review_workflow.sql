-- =============================================================================
-- Migration 58: ECO-02 Pilot FAQ Seeding & Review Workflow
-- Description:
--   1. Implements Moderator Review RPCs:
--      - public.review_community_question: review, publish, reject, or archive queued questions.
--      - public.review_community_answer: review, publish, reject, or archive queued answers.
--      - public.accept_community_answer: accept an answer (restricted to question author or moderator).
--   2. Extends community RLS policies so that moderators (private.is_moderator())
--      can view questions and answers under review.
--   3. Provides idempotent public.seed_pilot_community_faqs RPC to seed reference
--      pilot FAQs with accepted answers across Literacy, Workplace Safety, and Florida Licensure.
--   4. Safely calls seeding only when an author is present in auth.users (preserving clean-slate CI).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extend RLS SELECT Policies to Permit Moderator Access
-- -----------------------------------------------------------------------------
drop policy if exists community_questions_auth_select_policy on public.community_questions;
create policy community_questions_auth_select_policy on public.community_questions
  for select
  to authenticated
  using (author_id = auth.uid() or private.is_moderator());

drop policy if exists community_answers_auth_select_policy on public.community_answers;
create policy community_answers_auth_select_policy on public.community_answers
  for select
  to authenticated
  using (
    (author_id = auth.uid() and exists (
      select 1 from public.community_questions q
       where q.id = question_id
         and (q.status = 'published' or q.author_id = auth.uid() or private.is_moderator())
    ))
    or private.is_moderator()
  );

-- -----------------------------------------------------------------------------
-- 2. Question Review RPC (review_community_question)
-- -----------------------------------------------------------------------------
create or replace function public.review_community_question(
  p_question_id uuid,
  p_action text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_current_status text;
  v_new_status text;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null or not private.is_moderator() then
    raise exception 'Access denied: caller does not possess moderator privileges'
      using errcode = '42501';
  end if;

  if p_action not in ('publish', 'reject', 'archive') then
    raise exception 'Invalid review action: %', p_action
      using errcode = '22023';
  end if;

  select status into v_current_status
    from public.community_questions
   where id = p_question_id
     for update;

  if not found then
    raise exception 'Question % not found', p_question_id
      using errcode = 'P0002';
  end if;

  v_new_status := case
    when p_action = 'publish' then 'published'
    when p_action = 'reject' then 'archived'
    when p_action = 'archive' then 'archived'
  end;

  -- Allow internal modification of status and updated_at
  perform set_config('community.internal_counter_update', 'true', true);

  update public.community_questions
     set status = v_new_status,
         updated_at = now()
   where id = p_question_id;

  return jsonb_build_object(
    'success', true,
    'question_id', p_question_id,
    'action', p_action,
    'previous_status', v_current_status,
    'status', v_new_status,
    'notes', p_notes
  );
end;
$$;

revoke all on function public.review_community_question(uuid, text, text) from public, anon;
grant execute on function public.review_community_question(uuid, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. Answer Review RPC (review_community_answer)
-- -----------------------------------------------------------------------------
create or replace function public.review_community_answer(
  p_answer_id uuid,
  p_action text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_answer record;
  v_parent_status text;
  v_new_status text;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null or not private.is_moderator() then
    raise exception 'Access denied: caller does not possess moderator privileges'
      using errcode = '42501';
  end if;

  if p_action not in ('publish', 'reject', 'archive', 'flag') then
    raise exception 'Invalid review action: %', p_action
      using errcode = '22023';
  end if;

  select * into v_answer
    from public.community_answers
   where id = p_answer_id
     for update;

  if not found then
    raise exception 'Answer % not found', p_answer_id
      using errcode = 'P0002';
  end if;

  if p_action = 'publish' then
    select status into v_parent_status
      from public.community_questions
     where id = v_answer.question_id;

    if v_parent_status <> 'published' then
      raise exception 'Cannot publish answer for non-published parent question'
        using errcode = '22000';
    end if;
    v_new_status := 'published';
  elsif p_action = 'reject' or p_action = 'archive' then
    v_new_status := 'archived';
  elsif p_action = 'flag' then
    v_new_status := 'flagged';
  end if;

  perform set_config('community.internal_counter_update', 'true', true);

  update public.community_answers
     set status = v_new_status,
         updated_at = now()
   where id = p_answer_id;

  return jsonb_build_object(
    'success', true,
    'answer_id', p_answer_id,
    'action', p_action,
    'status', v_new_status,
    'notes', p_notes
  );
end;
$$;

revoke all on function public.review_community_answer(uuid, text, text) from public, anon;
grant execute on function public.review_community_answer(uuid, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. Answer Acceptance RPC (accept_community_answer)
-- -----------------------------------------------------------------------------
create or replace function public.accept_community_answer(
  p_answer_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_answer record;
  v_question record;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select * into v_answer
    from public.community_answers
   where id = p_answer_id
     for update;

  if not found then
    raise exception 'Answer % not found', p_answer_id
      using errcode = 'P0002';
  end if;

  select * into v_question
    from public.community_questions
   where id = v_answer.question_id
     for update;

  if not found then
    raise exception 'Parent question not found'
      using errcode = 'P0002';
  end if;

  -- Caller must be question author OR a moderator/admin
  if v_question.author_id <> v_caller_id and not private.is_moderator() then
    raise exception 'Only the question author or a moderator may accept an answer'
      using errcode = '42501';
  end if;

  if v_answer.status <> 'published' or v_question.status <> 'published' then
    raise exception 'Only published answers to published questions can be accepted'
      using errcode = '22000';
  end if;

  perform set_config('community.internal_counter_update', 'true', true);

  -- Unaccept any previously accepted answers for this question
  update public.community_answers
     set is_accepted = false,
         updated_at = now()
   where question_id = v_answer.question_id
     and id <> p_answer_id
     and is_accepted = true;

  -- Accept target answer
  update public.community_answers
     set is_accepted = true,
         updated_at = now()
   where id = p_answer_id;

  return jsonb_build_object(
    'success', true,
    'answer_id', p_answer_id,
    'question_id', v_answer.question_id,
    'is_accepted', true
  );
end;
$$;

revoke all on function public.accept_community_answer(uuid) from public, anon;
grant execute on function public.accept_community_answer(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. Seed Pilot FAQs RPC (seed_pilot_community_faqs)
-- -----------------------------------------------------------------------------
create or replace function public.seed_pilot_community_faqs(p_author_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author_id uuid;
  v_count integer := 0;
  v_q_id uuid;
  v_seed record;
begin
  -- Resolve author id
  if p_author_id is not null then
    v_author_id := p_author_id;
  else
    select user_id into v_author_id
      from public.moderation_roles
     where role = 'admin'
     limit 1;
  end if;

  if v_author_id is null then
    return 0;
  end if;

  -- Check existence in auth.users
  if not exists (select 1 from auth.users where id = v_author_id) then
    return 0;
  end if;

  perform set_config('community.internal_counter_update', 'true', true);

  -- 18 Authoritative Pilot FAQs across Literacy, Workplace Safety, and Florida Licensure
  for v_seed in (
    select
      'What is the CVC pattern in phonics and how is it taught?' as title,
      'What does the CVC acronym stand for, and why is it considered the foundational pattern in early phonics instruction?' as body,
      'literacy.cvc.basics' as concept_id,
      'CVC stands for Consonant-Vowel-Consonant (e.g., ''cat'', ''pin'', ''sun'', ''bed'', ''fog''). In CVC words, the single vowel in the middle always makes its short vowel sound. Blending these three distinct phonemes (onset, vowel nucleus, and coda) is the core initial milestone in phonemic decoding before learners progress to consonant blends, vowel teams, or silent-e patterns.' as answer_body
    union all select
      'How do sight words differ from decodable words?',
      'Why are high-frequency words often called sight words, and should learners sound them out or memorize them?',
      'literacy.sight_words',
      'Decodable words follow transparent phonetic rules that learners can sound out letter by letter using taught grapheme-phoneme correspondences. High-frequency ''sight words'' (such as ''the'', ''was'', ''said'', ''of'') often contain irregular or advanced spelling patterns. Modern evidence-based reading instruction recommends ''orthographic mapping''—pointing out the regular sound parts while explicitly highlighting the irregular ''heart'' sounds, enabling instantaneous word retrieval without pure rote memorization.'
    union all select
      'What is the difference between continuous blending and segmented blending?',
      'When teaching a struggling reader to blend letter sounds into words, what is continuous blending and why is it recommended?',
      'literacy.phonics.blending',
      'Segmented blending pauses between each individual sound (e.g., /s/ ... /a/ ... /t/), which places heavy demands on working memory. Continuous blending (also called additive or connected phonation) stretches continuous sounds smoothly into one another without pausing (e.g., ''ssssaaaat''). Research indicates continuous blending significantly reduces memory drop-off and error rates for early and struggling readers.'
    union all select
      'What is a consonant digraph versus a consonant blend?',
      'What distinguishes consonant digraphs like ''sh'' and ''th'' from consonant blends like ''bl'' and ''st''?',
      'literacy.digraphs',
      'A consonant digraph consists of two letters that team together to represent a single, unique phoneme (e.g., ''sh'' in ''ship'', ''th'' in ''thin'', ''ch'' in ''chin'', ''ck'' in ''duck''). In contrast, a consonant blend consists of two or three consonants where each letter retains its own distinct individual sound that can still be heard when spoken together (e.g., /b/ and /l/ in ''black'', /s/ and /t/ in ''stop'').'
    union all select
      'How does onset-rime awareness support phonological development?',
      'Why is dividing words into onset and rime beneficial for pre-readers and developing spellers?',
      'literacy.rhyming',
      'In phonological awareness, the ''onset'' is the initial consonant sound before the vowel (e.g., /c/ in ''cat''), and the ''rime'' is the vowel and any subsequent consonants (e.g., ''-at''). Recognizing common rimes (word families like ''-at'', ''-in'', ''-op'') accelerates reading fluency because learners can rapidly map and read dozens of new words by simply swapping the onset consonant.'
    union all select
      'How does the split vowel digraph or silent-e rule function?',
      'What is the phonetic mechanic behind the final silent-e in words like ''cake'', ''ride'', and ''rope''?',
      'literacy.silent_e',
      'The final ''e'' in CVCe words (Consonant-Vowel-Consonant-e) is historically a marker indicating that the preceding vowel sound is ''long'' (it pronounces its alphabet name). Linguistically, this is a split vowel digraph (e.g., a_e, i_e, o_e, u_e). Teaching this rule helps readers transition from short vowel decoding (''cap'' to ''cape'', ''pin'' to ''pine'').'
    union all select
      'What are the standard OSHA requirements for Personal Protective Equipment (PPE)?',
      'Under OSHA general industry guidelines, when must an employer provide PPE and what gear is mandated?',
      'workplace.safety.ppe',
      'Under OSHA 29 CFR 1910 Subpart I, employers must assess the workplace to identify hazards that necessitate PPE. When engineering or administrative controls are insufficient, employers must provide appropriate PPE at no cost to workers. Standard general industry PPE includes ANSI Z87.1 approved eye protection, hard hats conforming to ANSI Z89.1, puncture- and impact-resistant safety footwear (ASTM F2413), and hearing protection in zones exceeding 85 dBA TWA.'
    union all select
      'What information must be included in a Safety Data Sheet (SDS) under GHS?',
      'How is an OSHA Hazard Communication Safety Data Sheet structured, and which sections are critical for immediate chemical spills?',
      'workplace.safety.hazcom',
      'OSHA''s Hazard Communication Standard (29 CFR 1910.1200) aligns with the Globally Harmonized System (GHS) and mandates a standardized 16-section Safety Data Sheet (SDS). For immediate emergencies, Section 1 (Identification), Section 2 (Hazard Identification with pictograms and signal words), Section 4 (First-Aid Measures), Section 5 (Fire-Fighting Measures), and Section 6 (Accidental Release Measures) provide the essential rapid-response instructions.'
    union all select
      'What does the PASS acronym stand for when operating a fire extinguisher?',
      'What is the proper procedural technique for safely deploying a portable workplace fire extinguisher?',
      'workplace.safety.fire',
      'The PASS technique describes the 4-step sequence for operating a portable fire extinguisher: 1) Pull the pin to break the tamper seal. 2) Aim low, pointing the nozzle or hose at the base of the fire, not the flames. 3) Squeeze the handle or lever slowly to discharge the extinguishing agent. 4) Sweep the nozzle from side to side across the base of the fuel until the flames are fully extinguished.'
    union all select
      'What is Lockout/Tagout (LOTO) and why is it mandatory during machinery maintenance?',
      'Under OSHA standard 29 CFR 1910.147, what is the primary purpose of hazardous energy control procedures?',
      'workplace.safety.lockout_tagout',
      'Lockout/Tagout (LOTO) establishes minimum performance requirements to prevent unexpected energization, startup, or release of stored energy during servicing or maintenance of machines and equipment. A designated lockout device physically holds the energy-isolating mechanism in a safe position, while a standardized tagout warning tag indicates the equipment must not be energized until the authorized technician removes the lock.'
    union all select
      'What are the primary OSHA walking-working surface requirements for housekeeping?',
      'How should walkways, aisles, and floors be maintained in commercial and industrial workspaces to prevent fall injuries?',
      'workplace.safety.slips_trips_falls',
      'Under OSHA 29 CFR 1910.22, all places of employment, passageways, storerooms, and service rooms must be kept clean, orderly, and in a sanitary condition. Floors must be kept dry and clear of debris, electrical cords, and protrusions. Where wet processes are used, employers must provide adequate drainage, non-slip mats, or false floors to maintain traction.'
    union all select
      'What core components are required in an OSHA Emergency Action Plan (EAP)?',
      'When an employer is required to have an Emergency Action Plan under 29 CFR 1910.38, what procedures must be documented?',
      'workplace.safety.emergency_action',
      'An OSHA Emergency Action Plan must document: 1) Procedures for reporting fires and other emergencies; 2) Emergency evacuation procedures, including designated exit route assignments; 3) Procedures for employees who remain to operate critical operations before evacuation; 4) Procedures to account for all employees after evacuation; 5) Rescue and medical duties for assigned workers; and 6) Preferred names or job titles of individuals to contact for further information.'
    union all select
      'What are the continuing education (CE) requirements for Florida Cosmetology license renewal?',
      'How many continuing education hours are required by the Florida Board of Cosmetology for biennial license renewal?',
      'licensure.cosmetology.ce',
      'Under Florida Administrative Code Rule 61G5-20, licensed cosmetologists must complete 10 hours of board-approved continuing education prior to their biennial license expiration (October 31st of even-numbered years). The 10 hours must include: 1 hour of HIV/AIDS education, 3 hours of sanitation and sterilization, 1 hour of OSHA/chemical hazards, 1 hour of workers'' compensation, 2 hours of Florida cosmetology laws and rules, and 2 hours of general cosmetology topics.'
    union all select
      'What are the work and in-service training requirements to renew a Florida CNA certificate?',
      'How does a Certified Nursing Assistant maintain an active license with the Florida Board of Nursing?',
      'licensure.cna.renewal',
      'Under Florida Statutes Chapter 464 and Rule 64B9-15, a Certified Nursing Assistant (CNA) license renews biennially. To qualify for active renewal, the CNA must perform nursing-related services for monetary compensation within the 24-month renewal cycle and complete a minimum of 24 hours of in-service training (12 hours per calendar year) covering mandatory topics such as medical error prevention, infection control, CPR, patient rights, and HIPAA compliance.'
    union all select
      'What is the first-renewal post-licensing requirement for Florida Real Estate Sales Associates?',
      'What coursework must a newly licensed Florida real estate sales associate complete before their initial license expiration date?',
      'licensure.real_estate.post_licensing',
      'Florida Real Estate Commission (FREC) Rule 61J2-3 requires all newly licensed sales associates to satisfactorily complete a commission-approved 45-hour post-licensing education course prior to their first biennial license expiration date. There is no grace period in Florida: failure to complete the 45-hour post-licensing course before the expiration date renders the license null and void by operation of law.'
    union all select
      'How does license reciprocity work for Florida Certified Electrical Contractors?',
      'Does the Florida Electrical Contractors'' Licensing Board (ECLB) grant reciprocal recognition to electrical licenses from other states?',
      'licensure.electrical.reciprocity',
      'The Florida Electrical Contractors'' Licensing Board (ECLB) offers licensure by endorsement to applicants who hold a valid, current electrical contractor license from jurisdictions with substantially similar examination and experience standards. Florida currently maintains formal endorsement agreements with select states (including Georgia, North Carolina, and California). Endorsement applicants must still satisfy Florida financial responsibility requirements, criminal background checks, and submit proof of active workers'' compensation coverage.'
    union all select
      'What training hours are required for the Florida Class D Security Officer License?',
      'Under Florida Chapter 493, what curriculum and hours must an applicant complete to earn a Class D Security Officer License?',
      'licensure.security_guard.class_d',
      'Under Florida Statutes Chapter 493, applicants for the Class ''D'' Security Officer License must successfully complete a 40-hour training curriculum at a licensed security officer school. The training covers Florida law, security officer conduct, observation techniques, report writing, emergency procedures, terrorism awareness, and first aid. Once completed, the license is issued by the Florida Department of Agriculture and Consumer Services (FDACS) and is valid for two years.'
    union all select
      'What experience qualifications are required for the Florida Certified General Contractor (CGC) exam?',
      'What combination of education and four years of commercial construction experience is required by the Florida CILB?',
      'licensure.construction.general_contractor',
      'The Florida Construction Industry Licensing Board (CILB) requires applicants for the Certified General Contractor (CGC) license to demonstrate four years of proven commercial construction experience. Acceptable combinations include: 1) A 4-year accredited degree in construction or engineering plus 1 year of hands-on supervisory experience; 2) 3 years of accredited college credits plus 1 year of experience; or 3) 4 years of active field experience, with at least 1 year acting as a foreman or supervisor on commercial structures exceeding four stories.'
  ) loop
    -- Check if question already exists
    select id into v_q_id
      from public.community_questions
     where title = v_seed.title;

    if v_q_id is null then
      insert into public.community_questions (
        author_id, title, body_markdown, status, is_seeded,
        concept_id, view_count, upvote_count, answer_count
      ) values (
        v_author_id, v_seed.title, v_seed.body, 'published', true,
        v_seed.concept_id, 0, 0, 1
      ) returning id into v_q_id;

      insert into public.community_answers (
        question_id, author_id, body_markdown, is_ai_generated,
        is_accepted, status, upvote_count
      ) values (
        v_q_id, v_author_id, v_seed.answer_body, false,
        true, 'published', 0
      );

      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.seed_pilot_community_faqs(uuid) from public, anon;
grant execute on function public.seed_pilot_community_faqs(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. Safe Conditional Immediate Seeding (Preserves Clean-Slate CI)
-- -----------------------------------------------------------------------------
do $$
declare
  v_admin_id uuid;
  v_seeded_count integer;
begin
  select user_id into v_admin_id
    from public.moderation_roles
   where role = 'admin'
   limit 1;

  if v_admin_id is not null and exists (select 1 from auth.users where id = v_admin_id) then
    v_seeded_count := public.seed_pilot_community_faqs(v_admin_id);
    raise notice 'ECO-02: Successfully seeded % pilot FAQs with accepted answers.', v_seeded_count;
  else
    raise notice 'ECO-02: Skipping immediate FAQ seeding (no admin user found in auth.users). Seed via tool/seed_pilot_community_faqs.dart after user provisioning.';
  end if;
end;
$$;
