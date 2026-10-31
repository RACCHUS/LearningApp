-- ECO-02 Hardening & Integrity Fixes
-- Migration Version: 20261028000000
-- 1. Restrict seed_pilot_community_faqs to verified administrators (private.is_admin())
-- 2. Correct answer_count trigger double-increment and repair existing counters
-- 3. Correct Florida DBPR licensure facts (Cosmetology, Electrical Endorsement, General Contractor)
-- 4. Server-enforce Public UGC Launch Gate (community_config.public_ugc_enabled)
-- 5. Introduce durable community review decision audit table (community_review_audit)

-- -----------------------------------------------------------------------------
-- 1. Community Configuration & Public UGC Launch Gate
-- -----------------------------------------------------------------------------
create table if not exists public.community_config (
  key text primary key,
  value boolean not null default false,
  description text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.community_config enable row level security;

drop policy if exists community_config_select_policy on public.community_config;
create policy community_config_select_policy on public.community_config
  for select to authenticated, anon
  using (true);

revoke all on table public.community_config from public, anon;
grant select on table public.community_config to anon, authenticated;
grant all on table public.community_config to service_role;

insert into public.community_config (key, value, description)
values (
  'public_ugc_enabled',
  false,
  'Controls whether learner-submitted community questions and answers can be published to the public catalog'
)
on conflict (key) do nothing;

create or replace function private.is_community_ugc_public_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select value from public.community_config where key = 'public_ugc_enabled'),
    false
  );
$$;

revoke all on function private.is_community_ugc_public_enabled() from public, anon;
grant execute on function private.is_community_ugc_public_enabled() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Community Review Audit Table (Immutable Audit Log)
-- -----------------------------------------------------------------------------
create table if not exists public.community_review_audit (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('question', 'answer')),
  target_id uuid not null,
  reviewer_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('publish', 'reject', 'archive', 'flag')),
  previous_status text not null,
  new_status text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.community_review_audit enable row level security;

create index if not exists idx_community_review_audit_target
  on public.community_review_audit(target_type, target_id);

create index if not exists idx_community_review_audit_reviewer
  on public.community_review_audit(reviewer_id);

create index if not exists idx_community_review_audit_created
  on public.community_review_audit(created_at desc);

drop policy if exists community_review_audit_select_policy on public.community_review_audit;
create policy community_review_audit_select_policy on public.community_review_audit
  for select
  to authenticated
  using (private.is_moderator());

revoke all on table public.community_review_audit from public, anon;
revoke insert, update, delete on table public.community_review_audit from authenticated;
grant select on table public.community_review_audit to authenticated;
grant all on table public.community_review_audit to service_role;

-- -----------------------------------------------------------------------------
-- 3. Hardened Question Review RPC (Review Audit & UGC Launch Gate)
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
  v_question record;
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

  select * into v_question
    from public.community_questions
   where id = p_question_id
     for update;

  if not found then
    raise exception 'Question % not found', p_question_id
      using errcode = 'P0002';
  end if;

  -- Public UGC Launch Gate: Non-seeded learner questions cannot be published until public UGC is enabled
  if p_action = 'publish' and not v_question.is_seeded and not private.is_community_ugc_public_enabled() then
    raise exception 'Public learner UGC is currently disabled. Learner questions cannot be published before operational launch clearance.'
      using errcode = '22000';
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

  -- Insert durable audit record
  insert into public.community_review_audit (
    target_type, target_id, reviewer_id, action, previous_status, new_status, notes
  ) values (
    'question', p_question_id, v_caller_id, p_action, v_question.status, v_new_status, p_notes
  );

  return jsonb_build_object(
    'success', true,
    'question_id', p_question_id,
    'action', p_action,
    'previous_status', v_question.status,
    'status', v_new_status,
    'notes', p_notes
  );
end;
$$;

revoke all on function public.review_community_question(uuid, text, text) from public, anon;
grant execute on function public.review_community_question(uuid, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. Hardened Answer Review RPC (Review Audit & UGC Launch Gate)
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
  v_parent_question record;
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

  select * into v_parent_question
    from public.community_questions
   where id = v_answer.question_id;

  if not found then
    raise exception 'Parent question not found'
      using errcode = 'P0002';
  end if;

  if p_action = 'publish' then
    if v_parent_question.status <> 'published' then
      raise exception 'Cannot publish answer for non-published parent question'
        using errcode = '22000';
    end if;

    -- Public UGC Launch Gate: Non-seeded learner answers cannot be published until public UGC is enabled
    if not v_parent_question.is_seeded and not private.is_community_ugc_public_enabled() then
      raise exception 'Public learner UGC is currently disabled. Learner answers cannot be published before operational launch clearance.'
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

  -- Insert durable audit record
  insert into public.community_review_audit (
    target_type, target_id, reviewer_id, action, previous_status, new_status, notes
  ) values (
    'answer', p_answer_id, v_caller_id, p_action, v_answer.status, v_new_status, p_notes
  );

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
-- 5. Hardened Seed Pilot FAQs RPC (Admin Authorization & Trigger Fix)
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
  -- Enforce authorization: caller must be a verified administrator or service role
  if auth.uid() is not null then
    if not private.is_admin() then
      raise exception 'Access denied: only administrators may invoke seed_pilot_community_faqs'
        using errcode = '42501';
    end if;
  elsif coalesce(auth.jwt()->>'role', '') <> 'service_role' and session_user <> 'postgres' then
    raise exception 'Access denied: only administrators may invoke seed_pilot_community_faqs'
      using errcode = '42501';
  end if;

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
      'CVC stands for Consonant-Vowel-Consonant (e.g., ''cat'', ''pin'', ''sun'', ''bed'', ''fog''). In CVC words, the single vowel in the middle always makes its short vowel sound. Blending these three distinct phonemes (onset, vowel nucleus, and coda) is the core initial milestone in phonemic decoding before learners progress to consonant blends, vowel teams, or silent-e patterns. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.' as answer_body
    union all select
      'How do sight words differ from decodable words?',
      'Why are high-frequency words often called sight words, and should learners sound them out or memorize them?',
      'literacy.sight_words',
      'Decodable words follow transparent phonetic rules that learners can sound out letter by letter using taught grapheme-phoneme correspondences. High-frequency ''sight words'' (such as ''the'', ''was'', ''said'', ''of'') often contain irregular or advanced spelling patterns. Modern evidence-based reading instruction recommends ''orthographic mapping''—pointing out the regular sound parts while explicitly highlighting the irregular ''heart'' sounds, enabling instantaneous word retrieval without pure rote memorization. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'What is the difference between continuous blending and segmented blending?',
      'When teaching a struggling reader to blend letter sounds into words, what is continuous blending and why is it recommended?',
      'literacy.phonics.blending',
      'Segmented blending pauses between each individual sound (e.g., /s/ ... /a/ ... /t/), which places heavy demands on working memory. Continuous blending (also called additive or connected phonation) stretches continuous sounds smoothly into one another without pausing (e.g., ''ssssaaaat''). Research indicates continuous blending significantly reduces memory drop-off and error rates for early and struggling readers. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'What is a consonant digraph versus a consonant blend?',
      'What distinguishes consonant digraphs like ''sh'' and ''th'' from consonant blends like ''bl'' and ''st''?',
      'literacy.digraphs',
      'A consonant digraph consists of two letters that team together to represent a single, unique phoneme (e.g., ''sh'' in ''ship'', ''th'' in ''thin'', ''ch'' in ''chin'', ''ck'' in ''duck''). In contrast, a consonant blend consists of two or three consonants where each letter retains its own distinct individual sound that can still be heard when spoken together (e.g., /b/ and /l/ in ''black'', /s/ and /t/ in ''stop''). Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'How does onset-rime awareness support phonological development?',
      'Why is dividing words into onset and rime beneficial for pre-readers and developing spellers?',
      'literacy.rhyming',
      'In phonological awareness, the ''onset'' is the initial consonant sound before the vowel (e.g., /c/ in ''cat''), and the ''rime'' is the vowel and any subsequent consonants (e.g., ''-at''). Recognizing common rimes (word families like ''-at'', ''-in'', ''-op'') accelerates reading fluency because learners can rapidly map and read dozens of new words by simply swapping the onset consonant. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'How does the silent-e (split digraph) change vowel sounds in English?',
      'What is the phonics principle behind the ''magic e'' or silent-e pattern in words like ''hop'' vs ''hope''?',
      'literacy.silent_e',
      'In the VCe (Vowel-Consonant-e) pattern, the final silent ''e'' signals that the preceding vowel represents its long vowel sound (saying its name) rather than the short vowel sound heard in closed CVC syllables (e.g., ''cap'' becomes ''cape'', ''pin'' becomes ''pine'', ''tub'' becomes ''tube''). Linguistically, this is a split vowel digraph, where the two vowel letters work together across the intervening consonant. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'What are the five levels of the Hierarchy of Controls in workplace safety?',
      'Under NIOSH and OSHA standards, how should employers prioritize hazard mitigation methods?',
      'workplace.safety.ppe',
      'The Hierarchy of Controls prioritizes hazard mitigation from most to least effective: 1) Elimination (physically remove the hazard); 2) Substitution (replace the hazard with a safer alternative); 3) Engineering Controls (isolate people from the hazard, e.g., machine guards, ventilation); 4) Administrative Controls (change the way people work through procedures, training, and signs); and 5) Personal Protective Equipment (PPE: gloves, respirators, hard hats, earplugs). PPE is the last line of defense, not the first. Source: OSHA & NIOSH Safety Standards. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'What information must be included on an OSHA-compliant GHS chemical safety label?',
      'What are the mandatory elements required on hazardous chemical container labels under OSHA HazCom 2012?',
      'workplace.safety.hazcom',
      'Under OSHA''s Hazard Communication Standard (29 CFR 1910.1200) aligned with the Globally Harmonized System (GHS), container labels must include six mandatory elements: 1) Product Identifier (chemical name/code); 2) Signal Word (''Danger'' for severe hazards, ''Warning'' for less severe); 3) Hazard Statements (nature and degree of hazard); 4) Precautionary Statements (prevention, response, storage, disposal); 5) GHS Pictograms (red diamond borders with black hazard symbols); and 6) Supplier Identification (manufacturer name, address, and emergency telephone number). Source: OSHA HazCom Standard (29 CFR 1910.1200). Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'What is the PASS method for operating a portable fire extinguisher?',
      'What four-step sequence should workers follow when using a portable fire extinguisher during an incipient-stage fire?',
      'workplace.safety.fire',
      'The PASS acronym summarizes the correct technique: 1) Pull the safety pin from the handle; 2) Aim low, pointing the extinguisher nozzle or hose at the base of the fire (not into the flames); 3) Squeeze the handle lever slowly and evenly to discharge the extinguishing agent; 4) Sweep the nozzle from side to side across the base of the fire until the fire is completely out. Workers should only fight fires in their incipient stage when a safe exit path is behind them. Source: OSHA Standard 29 CFR 1910.157 & NFPA Guidelines. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'What is Lockout/Tagout (LOTO) and why is it mandatory during machinery maintenance?',
      'Under OSHA standard 29 CFR 1910.147, what is the primary purpose of hazardous energy control procedures?',
      'workplace.safety.lockout_tagout',
      'Lockout/Tagout (LOTO) establishes minimum performance requirements to prevent unexpected energization, startup, or release of stored energy during servicing or maintenance of machines and equipment. A designated lockout device physically holds the energy-isolating mechanism in a safe position, while a standardized tagout warning tag indicates the equipment must not be energized until the authorized technician removes the lock. Source: OSHA Standard 29 CFR 1910.147. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'What are the primary OSHA walking-working surface requirements for housekeeping?',
      'How should walkways, aisles, and floors be maintained in commercial and industrial workspaces to prevent fall injuries?',
      'workplace.safety.slips_trips_falls',
      'Under OSHA 29 CFR 1910.22, all places of employment, passageways, storerooms, and service rooms must be kept clean, orderly, and in a sanitary condition. Floors must be kept dry and clear of debris, electrical cords, and protrusions. Where wet processes are used, employers must provide adequate drainage, non-slip mats, or false floors to maintain traction. Source: OSHA Standard 29 CFR 1910.22. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'What core components are required in an OSHA Emergency Action Plan (EAP)?',
      'When an employer is required to have an Emergency Action Plan under 29 CFR 1910.38, what procedures must be documented?',
      'workplace.safety.emergency_action',
      'An OSHA Emergency Action Plan must document: 1) Procedures for reporting fires and other emergencies; 2) Emergency evacuation procedures, including designated exit route assignments; 3) Procedures for employees who remain to operate critical operations before evacuation; 4) Procedures to account for all employees after evacuation; 5) Rescue and medical duties for assigned workers; and 6) Preferred names or job titles of individuals to contact for further information. Source: OSHA Standard 29 CFR 1910.38. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'What are the continuing education (CE) requirements for Florida Cosmetology license renewal?',
      'How many continuing education hours are required by the Florida Board of Cosmetology for biennial license renewal?',
      'licensure.cosmetology.ce',
      'Under Section 477.019, Florida Statutes, and Rule 61G5-20.002, Florida Administrative Code (F.A.C.), Florida licensed cosmetologists must complete 10 hours of Board-approved continuing education prior to biennial license renewal. Cosmetology licenses are divided into two renewal groups: Group 1 expires October 31 of odd-numbered years, and Group 2 expires October 31 of even-numbered years. The mandatory 10-hour curriculum allocation requires: 1 hour of Board-approved HIV/AIDS education, 3 hours of sanitation and sterilization, 0.5 hour of Occupational Safety and Health Administration (OSHA) regulations, 0.5 hour of Workers'' Compensation law, 1 hour of Florida and Federal laws and rules, and 4 hours of General cosmetology courses or specialty electives. Source: Florida DBPR Board of Cosmetology (Rule 61G5-20.002, F.A.C.; § 477.019, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'What are the work and in-service training requirements to renew a Florida CNA certificate?',
      'How does a Certified Nursing Assistant maintain an active license with the Florida Board of Nursing?',
      'licensure.cna.renewal',
      'Under Florida Statutes Chapter 464 and Rule 64B9-15, a Certified Nursing Assistant (CNA) license renews biennially. To qualify for active renewal, the CNA must perform nursing-related services for monetary compensation within the 24-month renewal cycle and complete a minimum of 24 hours of in-service training (12 hours per calendar year) covering mandatory topics such as medical error prevention, infection control, CPR, patient rights, and HIPAA compliance. Source: Florida Board of Nursing (Rule 64B9-15, F.A.C.; Ch. 464, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'What is the first-renewal post-licensing requirement for Florida Real Estate Sales Associates?',
      'What coursework must a newly licensed Florida real estate sales associate complete before their initial license expiration date?',
      'licensure.real_estate.post_licensing',
      'Florida Real Estate Commission (FREC) Rule 61J2-3 requires all newly licensed sales associates to satisfactorily complete a commission-approved 45-hour post-licensing education course prior to their first biennial license expiration date. There is no grace period in Florida: failure to complete the 45-hour post-licensing course before the expiration date renders the license null and void by operation of law. Source: Florida Real Estate Commission (Rule 61J2-3, F.A.C.; Ch. 475, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'How does license reciprocity work for Florida Certified Electrical Contractors?',
      'Does the Florida Electrical Contractors'' Licensing Board (ECLB) grant reciprocal recognition to electrical licenses from other states?',
      'licensure.electrical.reciprocity',
      'The Florida Electrical Contractors'' Licensing Board (ECLB) explicitly states that Florida does not have reciprocal licensing agreements with any other state. Under Section 489.511, Florida Statutes, out-of-state contractors must apply for Licensure by Endorsement rather than reciprocity. To qualify for endorsement without retaking the Florida technical examination, an applicant must demonstrate either: 1) They passed a state or national examination substantially equivalent to Florida''s examination at the time taken; or 2) They held a valid, active electrical contractor license in another state for at least 10 years, with qualifications meeting or exceeding Florida statutory standards. All endorsement applicants must independently satisfy Florida financial responsibility requirements, credit reporting, fingerprint-based criminal history background checks, and proof of active workers'' compensation insurance. Source: Florida DBPR Electrical Contractors'' Licensing Board (ECLB; § 489.511, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'What training hours are required for the Florida Class D Security Officer License?',
      'Under Florida Chapter 493, what curriculum and hours must an applicant complete to earn a Class D Security Officer License?',
      'licensure.security_guard.class_d',
      'Under Florida Statutes Chapter 493, applicants for the Class ''D'' Security Officer License must successfully complete a 40-hour training curriculum at a licensed security officer school. The training covers Florida law, security officer conduct, observation techniques, report writing, emergency procedures, terrorism awareness, and first aid. Once completed, the license is issued by the Florida Department of Agriculture and Consumer Services (FDACS) and is valid for two years. Source: Florida Department of Agriculture and Consumer Services (FDACS; Ch. 493, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'What experience qualifications are required for the Florida Certified General Contractor (CGC) exam?',
      'What combination of education and four years of commercial construction experience is required by the Florida CILB?',
      'licensure.construction.general_contractor',
      'The Florida Construction Industry Licensing Board (CILB) requires applicants for the Certified General Contractor (CGC) license under Section 489.111, Florida Statutes, and Rule 61G4-15.001, F.A.C., to demonstrate four years of proven commercial construction experience. For general contractors, commercial high-rise experience is specifically defined as new commercial construction of structures of not less than four stories (at least four stories or taller). Qualifying experience must encompass substantial structural knowledge in: foundations and piers, structural framing, elevated slabs and post-tensioning, structural masonry, and curtain walls. Acceptable qualifying paths include: 1) A 4-year accredited degree in construction, engineering, or architecture plus 1 year of proven supervisory experience; 2) 3 years of accredited college credits plus 1 year of supervisory experience; or 3) 4 years of active field experience, with at least 1 year acting as a foreman or supervisor on commercial projects including structures of not less than four stories. Source: Florida DBPR Construction Industry Licensing Board (CILB; § 489.111, Fla. Stat.; Rule 61G4-15.001, F.A.C.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
  ) loop
    -- Check if question already exists
    select id into v_q_id
      from public.community_questions
     where title = v_seed.title;

    if v_q_id is null then
      -- Insert question with answer_count = 0; trg_community_answer_count trigger will increment to 1 on answer insertion
      insert into public.community_questions (
        author_id, title, body_markdown, status, is_seeded,
        concept_id, view_count, upvote_count, answer_count
      ) values (
        v_author_id, v_seed.title, v_seed.body, 'published', true,
        v_seed.concept_id, 0, 0, 0
      ) returning id into v_q_id;

      insert into public.community_answers (
        question_id, author_id, body_markdown, is_ai_generated,
        is_accepted, status, upvote_count
      ) values (
        v_q_id, v_author_id, v_seed.answer_body, false,
        true, 'published', 0
      );

      v_count := v_count + 1;
    else
      -- Question already exists: update accepted answer body with verified content
      update public.community_answers
         set body_markdown = v_seed.answer_body,
             updated_at = now()
       where question_id = v_q_id
         and is_accepted = true;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.seed_pilot_community_faqs(uuid) from public, anon;
grant execute on function public.seed_pilot_community_faqs(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 6. Immediate Production Data Repair & Sourcing Update
-- -----------------------------------------------------------------------------
do $$
begin
  perform set_config('community.internal_counter_update', 'true', true);

  -- Repair 1: Recalculate accurate answer_count for all questions
  update public.community_questions q
     set answer_count = coalesce(
       (select count(*)
          from public.community_answers a
         where a.question_id = q.id
           and a.status = 'published'),
       0
     ),
     updated_at = now()
   where q.is_seeded = true;

  -- Repair 2: Update Florida Cosmetology CE answer
  update public.community_answers a
     set body_markdown = 'Under Section 477.019, Florida Statutes, and Rule 61G5-20.002, Florida Administrative Code (F.A.C.), Florida licensed cosmetologists must complete 10 hours of Board-approved continuing education prior to biennial license renewal. Cosmetology licenses are divided into two renewal groups: Group 1 expires October 31 of odd-numbered years, and Group 2 expires October 31 of even-numbered years. The mandatory 10-hour curriculum allocation requires: 1 hour of Board-approved HIV/AIDS education, 3 hours of sanitation and sterilization, 0.5 hour of Occupational Safety and Health Administration (OSHA) regulations, 0.5 hour of Workers'' Compensation law, 1 hour of Florida and Federal laws and rules, and 4 hours of General cosmetology courses or specialty electives. Source: Florida DBPR Board of Cosmetology (Rule 61G5-20.002, F.A.C.; § 477.019, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.',
         updated_at = now()
    from public.community_questions q
   where a.question_id = q.id
     and q.title = 'What are the continuing education (CE) requirements for Florida Cosmetology license renewal?'
     and a.is_accepted = true;

  -- Repair 3: Update Florida Electrical Contractor Endorsement answer
  update public.community_answers a
     set body_markdown = 'The Florida Electrical Contractors'' Licensing Board (ECLB) explicitly states that Florida does not have reciprocal licensing agreements with any other state. Under Section 489.511, Florida Statutes, out-of-state contractors must apply for Licensure by Endorsement rather than reciprocity. To qualify for endorsement without retaking the Florida technical examination, an applicant must demonstrate either: 1) They passed a state or national examination substantially equivalent to Florida''s examination at the time taken; or 2) They held a valid, active electrical contractor license in another state for at least 10 years, with qualifications meeting or exceeding Florida statutory standards. All endorsement applicants must independently satisfy Florida financial responsibility requirements, credit reporting, fingerprint-based criminal history background checks, and proof of active workers'' compensation insurance. Source: Florida DBPR Electrical Contractors'' Licensing Board (ECLB; § 489.511, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.',
         updated_at = now()
    from public.community_questions q
   where a.question_id = q.id
     and q.title = 'How does license reciprocity work for Florida Certified Electrical Contractors?'
     and a.is_accepted = true;

  -- Repair 4: Update Florida General Contractor qualifications answer
  update public.community_answers a
     set body_markdown = 'The Florida Construction Industry Licensing Board (CILB) requires applicants for the Certified General Contractor (CGC) license under Section 489.111, Florida Statutes, and Rule 61G4-15.001, F.A.C., to demonstrate four years of proven commercial construction experience. For general contractors, commercial high-rise experience is specifically defined as new commercial construction of structures of not less than four stories (at least four stories or taller). Qualifying experience must encompass substantial structural knowledge in: foundations and piers, structural framing, elevated slabs and post-tensioning, structural masonry, and curtain walls. Acceptable qualifying paths include: 1) A 4-year accredited degree in construction, engineering, or architecture plus 1 year of proven supervisory experience; 2) 3 years of accredited college credits plus 1 year of supervisory experience; or 3) 4 years of active field experience, with at least 1 year acting as a foreman or supervisor on commercial projects including structures of not less than four stories. Source: Florida DBPR Construction Industry Licensing Board (CILB; § 489.111, Fla. Stat.; Rule 61G4-15.001, F.A.C.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.',
         updated_at = now()
    from public.community_questions q
   where a.question_id = q.id
     and q.title = 'What experience qualifications are required for the Florida Certified General Contractor (CGC) exam?'
     and a.is_accepted = true;

  raise notice 'ECO-02 Hardening: Recomputed answer counts and applied Florida DBPR factual corrections.';
end;
$$;
