-- =============================================================================
-- Migration 61: ECO-02 Hardening — Seed Pilot FAQ Matching Integrity
-- Description:
--   Restricts fallback title matching in public.seed_pilot_community_faqs to
--   already-seeded questions (is_seeded = true). This prevents unseeded learner
--   drafts or user questions with identical titles from being inadvertently
--   matched or converted into platform-seeded FAQs during future seeding runs.
-- =============================================================================

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
      'seed-faq-001' as seed_key,
      'What is the CVC pattern in phonics and how is it taught?' as title,
      'What does the CVC acronym stand for, and why is it considered the foundational pattern in early phonics instruction?' as body,
      'literacy.cvc.basics' as concept_id,
      'CVC stands for Consonant-Vowel-Consonant (e.g., ''cat'', ''pin'', ''sun'', ''bed'', ''fog''). In CVC words, the single vowel in the middle always makes its short vowel sound. Blending these three distinct phonemes (onset, vowel nucleus, and coda) is the core initial milestone in phonemic decoding before learners progress to consonant blends, vowel teams, or silent-e patterns. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.' as answer_body
    union all select
      'seed-faq-002',
      'How do sight words differ from decodable words?',
      'Why are high-frequency words often called sight words, and should learners sound them out or memorize them?',
      'literacy.sight_words',
      'Decodable words follow transparent phonetic rules that learners can sound out letter by letter using taught grapheme-phoneme correspondences. High-frequency ''sight words'' (such as ''the'', ''was'', ''said'', ''of'') often contain irregular or advanced spelling patterns. Modern evidence-based reading instruction recommends ''orthographic mapping''—pointing out the regular sound parts while explicitly highlighting the irregular ''heart'' sounds, enabling instantaneous word retrieval without pure rote memorization. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'seed-faq-003',
      'What is the difference between continuous blending and segmented blending?',
      'When teaching a struggling reader to blend letter sounds into words, what is continuous blending and why is it recommended?',
      'literacy.phonics.blending',
      'Segmented blending pauses between each individual sound (e.g., /s/ ... /a/ ... /t/), which places heavy demands on working memory. Continuous blending (also called additive or connected phonation) stretches continuous sounds smoothly into one another without pausing (e.g., ''ssssaaaat''). Research indicates continuous blending significantly reduces memory drop-off and error rates for early and struggling readers. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'seed-faq-004',
      'What is a consonant digraph versus a consonant blend?',
      'What distinguishes consonant digraphs like ''sh'' and ''th'' from consonant blends like ''bl'' and ''st''?',
      'literacy.digraphs',
      'A consonant digraph consists of two letters that team together to represent a single, unique phoneme (e.g., ''sh'' in ''ship'', ''th'' in ''thin'', ''ch'' in ''chin'', ''ck'' in ''duck''). In contrast, a consonant blend consists of two or three consonants where each letter retains its own distinct individual sound that can still be heard when spoken together (e.g., /b/ and /l/ in ''black'', /s/ and /t/ in ''stop''). Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'seed-faq-005',
      'How does onset-rime awareness support phonological development?',
      'Why is dividing words into onset and rime beneficial for pre-readers and developing spellers?',
      'literacy.rhyming',
      'In phonological awareness, the ''onset'' is the initial consonant sound before the vowel (e.g., /c/ in ''cat''), and the ''rime'' is the vowel and any subsequent consonants (e.g., ''-at''). Recognizing common rimes (word families like ''-at'', ''-in'', ''-op'') accelerates reading fluency because learners can rapidly map and read dozens of new words by simply swapping the onset consonant. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'seed-faq-006',
      'How does the silent-e (split digraph) change vowel sounds in English?',
      'What is the phonics principle behind the ''magic e'' or silent-e pattern in words like ''hop'' vs ''hope''?',
      'literacy.silent_e',
      'In the VCe (Vowel-Consonant-e) pattern, the final silent ''e'' signals that the preceding vowel represents its long vowel sound (saying its name) rather than the short vowel sound heard in closed CVC syllables (e.g., ''cap'' becomes ''cape'', ''pin'' becomes ''pine'', ''tub'' becomes ''tube''). Linguistically, this is a split vowel digraph, where the two vowel letters work together across the intervening consonant. Source: National Reading Panel & Evidence-Based Reading Research. Verified October 2026. Note: Platform-curated educational reference.'
    union all select
      'seed-faq-007',
      'What are the five levels of the Hierarchy of Controls in workplace safety?',
      'Under NIOSH and OSHA standards, how should employers prioritize hazard mitigation methods?',
      'workplace.safety.ppe',
      'The Hierarchy of Controls prioritizes hazard mitigation from most to least effective: 1) Elimination (physically remove the hazard); 2) Substitution (replace the hazard with a safer alternative); 3) Engineering Controls (isolate people from the hazard, e.g., machine guards, ventilation); 4) Administrative Controls (change the way people work through procedures, training, and signs); and 5) Personal Protective Equipment (PPE: gloves, respirators, hard hats, earplugs). PPE is the last line of defense, not the first. Source: OSHA & NIOSH Safety Standards. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'seed-faq-008',
      'What information must be included on an OSHA-compliant GHS chemical safety label?',
      'What are the mandatory elements required on hazardous chemical container labels under OSHA HazCom 2012?',
      'workplace.safety.hazcom',
      'Under OSHA''s Hazard Communication Standard (29 CFR 1910.1200) aligned with the Globally Harmonized System (GHS), container labels must include six mandatory elements: 1) Product Identifier (chemical name/code); 2) Signal Word (''Danger'' for severe hazards, ''Warning'' for less severe); 3) Hazard Statements (nature and degree of hazard); 4) Precautionary Statements (prevention, response, storage, disposal); 5) GHS Pictograms (red diamond borders with black hazard symbols); and 6) Supplier Identification (manufacturer name, address, and emergency telephone number). Source: OSHA HazCom Standard (29 CFR 1910.1200). Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'seed-faq-009',
      'What is the PASS method for operating a portable fire extinguisher?',
      'What four-step sequence should workers follow when using a portable fire extinguisher during an incipient-stage fire?',
      'workplace.safety.fire',
      'The PASS acronym summarizes the correct technique: 1) Pull the safety pin from the handle; 2) Aim low, pointing the extinguisher nozzle or hose at the base of the fire (not into the flames); 3) Squeeze the handle lever slowly and evenly to discharge the extinguishing agent; 4) Sweep the nozzle from side to side across the base of the fire until the fire is completely out. Workers should only fight fires in their incipient stage when a safe exit path is behind them. Source: OSHA Standard 29 CFR 1910.157 & NFPA Guidelines. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'seed-faq-010',
      'What is Lockout/Tagout (LOTO) and why is it mandatory during machinery maintenance?',
      'Under OSHA standard 29 CFR 1910.147, what is the primary purpose of hazardous energy control procedures?',
      'workplace.safety.lockout_tagout',
      'Lockout/Tagout (LOTO) establishes minimum performance requirements to prevent unexpected energization, startup, or release of stored energy during servicing or maintenance of machines and equipment. A designated lockout device physically holds the energy-isolating mechanism in a safe position, while a standardized tagout warning tag indicates the equipment must not be energized until the authorized technician removes the lock. Source: OSHA Standard 29 CFR 1910.147. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'seed-faq-011',
      'What are the primary OSHA walking-working surface requirements for housekeeping?',
      'How should walkways, aisles, and floors be maintained in commercial and industrial workspaces to prevent fall injuries?',
      'workplace.safety.slips_trips_falls',
      'Under OSHA 29 CFR 1910.22, all places of employment, passageways, storerooms, and service rooms must be kept clean, orderly, and in a sanitary condition. Floors must be kept dry and clear of debris, electrical cords, and protrusions. Where wet processes are used, employers must provide adequate drainage, non-slip mats, or false floors to maintain traction. Source: OSHA Standard 29 CFR 1910.22. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'seed-faq-012',
      'What core components are required in an OSHA Emergency Action Plan (EAP)?',
      'When an employer is required to have an Emergency Action Plan under 29 CFR 1910.38, what procedures must be documented?',
      'workplace.safety.emergency_action',
      'An OSHA Emergency Action Plan must document: 1) Procedures for reporting fires and other emergencies; 2) Emergency evacuation procedures, including designated exit route assignments; 3) Procedures for employees who remain to operate critical operations before evacuation; 4) Procedures to account for all employees after evacuation; 5) Rescue and medical duties for assigned workers; and 6) Preferred names or job titles of individuals to contact for further information. Source: OSHA Standard 29 CFR 1910.38. Verified October 2026. Note: Platform-curated educational reference; does not replace employer site safety training.'
    union all select
      'seed-faq-013',
      'What continuing education is required to renew a Florida Cosmetology license?',
      'Under Florida DBPR regulations, how many CE hours are required biennially and what specific subject areas must be covered?',
      'licensure.cosmetology.ce',
      'Under Section 477.019, Florida Statutes, and Rule 61G5-20.002, Florida Administrative Code (F.A.C.), Florida licensed cosmetologists must complete 10 hours of Board-approved continuing education prior to biennial license renewal. Cosmetology licenses are divided into two renewal groups: Group 1 expires October 31 of odd-numbered years, and Group 2 expires October 31 of even-numbered years. The mandatory 10-hour curriculum allocation requires: 1 hour of Board-approved HIV/AIDS education, 3 hours of sanitation and sterilization, 0.5 hour of Occupational Safety and Health Administration (OSHA) regulations, 0.5 hour of Workers'' Compensation law, 1 hour of Florida and Federal laws and rules, and 4 hours of General cosmetology courses or specialty electives. Source: Florida DBPR Board of Cosmetology (Rule 61G5-20.002, F.A.C.; § 477.019, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'seed-faq-014',
      'What are the mandatory renewal requirements for a Florida Certified Nursing Assistant (CNA)?',
      'Under the Florida Board of Nursing, how many in-service hours and paid employment hours are required to maintain active CNA certification?',
      'licensure.cna.renewal',
      'Under Florida Statutes Chapter 464 and Rule 64B9-15, a Certified Nursing Assistant (CNA) license renews biennially. To qualify for active renewal, the CNA must perform nursing-related services for monetary compensation within the 24-month renewal cycle and complete a minimum of 24 hours of in-service training (12 hours per calendar year) covering mandatory topics such as medical error prevention, infection control, CPR, patient rights, and HIPAA compliance. Source: Florida Board of Nursing (Rule 64B9-15, F.A.C.; Ch. 464, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'seed-faq-015',
      'What is the post-licensing education requirement for Florida Real Estate Sales Associates?',
      'Before the first renewal of a Florida Real Estate Sales Associate license, what coursework is mandatory and what is the consequence of non-compliance?',
      'licensure.real_estate.post_licensing',
      'Florida Real Estate Commission (FREC) Rule 61J2-3 requires all newly licensed sales associates to satisfactorily complete a commission-approved 45-hour post-licensing education course prior to their first biennial license expiration date. There is no grace period in Florida: failure to complete the 45-hour post-licensing course before the expiration date renders the license null and void by operation of law. Source: Florida Real Estate Commission (Rule 61J2-3, F.A.C.; Ch. 475, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'seed-faq-016',
      'How does license reciprocity work for Florida Certified Electrical Contractors?',
      'Does the Florida Electrical Contractors'' Licensing Board (ECLB) grant reciprocal recognition to electrical licenses from other states?',
      'licensure.electrical.reciprocity',
      'The Florida Electrical Contractors'' Licensing Board (ECLB) explicitly states that Florida does not have reciprocal licensing agreements with any other state. Under Section 489.511, Florida Statutes, out-of-state contractors must apply for Licensure by Endorsement rather than reciprocity. To qualify for endorsement without retaking the Florida technical examination, an applicant must demonstrate either: 1) They passed a state or national examination substantially equivalent to Florida''s examination at the time taken; or 2) They held a valid, active electrical contractor license in another state for at least 10 years, with qualifications meeting or exceeding Florida statutory standards. All endorsement applicants must independently satisfy Florida financial responsibility requirements, credit reporting, fingerprint-based criminal history background checks, and proof of active workers'' compensation insurance. Source: Florida DBPR Electrical Contractors'' Licensing Board (ECLB; § 489.511, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'seed-faq-017',
      'What training hours are required for the Florida Class D Security Officer License?',
      'Under Florida Chapter 493, what curriculum and hours must an applicant complete to earn a Class D Security Officer License?',
      'licensure.security_guard.class_d',
      'Under Florida Statutes Chapter 493, applicants for the Class ''D'' Security Officer License must successfully complete a 40-hour training curriculum at a licensed security officer school. The training covers Florida law, security officer conduct, observation techniques, report writing, emergency procedures, terrorism awareness, and first aid. Once completed, the license is issued by the Florida Department of Agriculture and Consumer Services (FDACS) and is valid for two years. Source: Florida Department of Agriculture and Consumer Services (FDACS; Ch. 493, Fla. Stat.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
    union all select
      'seed-faq-018',
      'What experience qualifications are required for the Florida Certified General Contractor (CGC) exam?',
      'What combination of education and four years of commercial construction experience is required by the Florida CILB?',
      'licensure.construction.general_contractor',
      'The Florida Construction Industry Licensing Board (CILB) requires applicants for the Certified General Contractor (CGC) license under Section 489.111, Florida Statutes, and Rule 61G4-15.001, F.A.C., to demonstrate four years of proven commercial construction experience. For general contractors, commercial high-rise experience is specifically defined as new commercial construction of structures of not less than four stories (at least four stories or taller). Qualifying experience must encompass substantial structural knowledge in: foundations and piers, structural framing, elevated slabs and post-tensioning, structural masonry, and curtain walls. Acceptable qualifying paths include: 1) A 4-year accredited degree in construction, engineering, or architecture plus 1 year of proven supervisory experience; 2) 3 years of accredited college credits plus 1 year of supervisory experience; or 3) 4 years of active field experience, with at least 1 year acting as a foreman or supervisor on commercial projects including structures of not less than four stories. Source: Florida DBPR Construction Industry Licensing Board (CILB; § 489.111, Fla. Stat.; Rule 61G4-15.001, F.A.C.). Verified October 2026. Note: Platform-curated educational reference; does not constitute legal counsel or regulatory endorsement.'
  ) loop
    -- Robust match: check seed_key first, then concept_id for seeded questions, then title strictly for seeded questions
    select id into v_q_id
      from public.community_questions
     where seed_key = v_seed.seed_key
        or (is_seeded = true and concept_id = v_seed.concept_id)
        or (is_seeded = true and title = v_seed.title)
     order by (seed_key = v_seed.seed_key) desc,
              (is_seeded = true and concept_id = v_seed.concept_id) desc
     limit 1;

    if v_q_id is null then
      insert into public.community_questions (
        author_id, title, body_markdown, status, is_seeded, seed_key,
        concept_id, view_count, upvote_count, answer_count
      ) values (
        v_author_id, v_seed.title, v_seed.body, 'published', true, v_seed.seed_key,
        v_seed.concept_id, 0, 0, 0
      ) returning id into v_q_id;

      insert into public.community_answers (
        question_id, author_id, body_markdown, is_ai_generated,
        is_accepted, status, is_seeded, seed_key, upvote_count
      ) values (
        v_q_id, v_author_id, v_seed.answer_body, false,
        true, 'published', true, v_seed.seed_key, 0
      );

      v_count := v_count + 1;
    else
      -- Existing question: update in-place with latest title, body, concept_id, seed_key, is_seeded
      update public.community_questions
         set title = v_seed.title,
             body_markdown = v_seed.body,
             concept_id = v_seed.concept_id,
             seed_key = v_seed.seed_key,
             is_seeded = true,
             updated_at = now()
       where id = v_q_id;

      -- Update accepted answer with verified source attribution, is_seeded, seed_key
      if exists (select 1 from public.community_answers where question_id = v_q_id and is_accepted = true) then
        update public.community_answers
           set body_markdown = v_seed.answer_body,
               is_seeded = true,
               seed_key = v_seed.seed_key,
               updated_at = now()
         where question_id = v_q_id
           and is_accepted = true;
      else
        insert into public.community_answers (
          question_id, author_id, body_markdown, is_ai_generated,
          is_accepted, status, is_seeded, seed_key, upvote_count
        ) values (
          v_q_id, v_author_id, v_seed.answer_body, false,
          true, 'published', true, v_seed.seed_key, 0
        );
      end if;
    end if;
  end loop;

  return v_count;
end;
$$;
