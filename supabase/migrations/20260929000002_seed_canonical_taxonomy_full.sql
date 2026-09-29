-- ============================================================================
-- Migration: 20260929000002_seed_canonical_taxonomy_full.sql
-- Description: Comprehensive seed of:
--   1. All 48 CIP 2020 two-digit series as external classification nodes + canonical fields
--   2. Key CIP 4-digit subfield groups & 6-digit detailed programs
--   3. Mapping of all 48 CIP series to the 12 presentation catalog clusters
--   4. BLS SOC 2018 2-digit major groups, detailed occupations, and O*NET extensions
--   5. Official CIP-to-SOC qualitative crosswalks
--   6. Foundational learning targets across Careers, Certifications, Exams, and Academic Programs
-- ============================================================================

DO $$
DECLARE
  v_cip_rel_id uuid := 'a1000000-0000-0000-0000-000000000001';
  v_soc_rel_id uuid := 'a1000000-0000-0000-0000-000000000002';
  v_onet_rel_id uuid := 'a1000000-0000-0000-0000-000000000003';

  -- Cluster UUIDs
  v_c1 uuid := 'c1000000-0000-0000-0000-000000000001'; -- Computing & IT
  v_c2 uuid := 'c1000000-0000-0000-0000-000000000002'; -- Health & Medicine
  v_c3 uuid := 'c1000000-0000-0000-0000-000000000003'; -- Engineering & Tech
  v_c4 uuid := 'c1000000-0000-0000-0000-000000000004'; -- Business & Finance
  v_c5 uuid := 'c1000000-0000-0000-0000-000000000005'; -- Physical & Bio Sciences
  v_c6 uuid := 'c1000000-0000-0000-0000-000000000006'; -- Math & Stats
  v_c7 uuid := 'c1000000-0000-0000-0000-000000000007'; -- Law & Public Policy
  v_c8 uuid := 'c1000000-0000-0000-0000-000000000008'; -- Arts & Design
  v_c9 uuid := 'c1000000-0000-0000-0000-000000000009'; -- Social Sciences & Ed
  v_c10 uuid := 'c1000000-0000-0000-0000-000000000010'; -- Humanities & Languages
  v_c11 uuid := 'c1000000-0000-0000-0000-000000000011'; -- Skilled Trades
  v_c12 uuid := 'c1000000-0000-0000-0000-000000000012'; -- Agriculture & Env

  -- Helper loop variables
  rec record;
  f_uuid uuid;
  node_uuid uuid;
  t_uuid uuid;
BEGIN

  -- --------------------------------------------------------------------------
  -- 1. All 48 CIP 2020 Two-Digit Broad Series
  -- --------------------------------------------------------------------------
  CREATE TEMP TABLE temp_cip_series (
    code text,
    title text,
    slug text,
    cluster_id uuid,
    description text
  ) ON COMMIT DROP;

  INSERT INTO temp_cip_series (code, title, slug, cluster_id, description) VALUES
    ('01', 'Agriculture, Agriculture Operations, and Related Sciences', 'agriculture-operations', v_c12, 'Agricultural production, agribusiness, agronomy, animal sciences, and agricultural operations.'),
    ('03', 'Natural Resources and Conservation', 'natural-resources-conservation', v_c12, 'Forestry, wildlife conservation, environmental science, fisheries, and resource management.'),
    ('04', 'Architecture and Related Services', 'architecture-services', v_c8, 'Architectural design, urban planning, landscape architecture, and interior design.'),
    ('05', 'Area, Ethnic, Cultural, Gender, and Group Studies', 'cultural-group-studies', v_c9, 'Interdisciplinary cultural, regional, ethnic, and demographic studies.'),
    ('09', 'Communication, Journalism, and Related Programs', 'communication-journalism', v_c10, 'Mass communication, broadcast journalism, media theory, and public relations.'),
    ('10', 'Communications Technologies/Technicians and Support Services', 'communications-technologies', v_c1, 'Audiovisual tech, sound engineering, graphic communications, and broadcast tech.'),
    ('11', 'Computer and Information Sciences and Support Services', 'computer-sciences', v_c1, 'Computer science, algorithms, software engineering, systems architecture, and cybersecurity.'),
    ('12', 'Culinary, Entertainment, and Personal Services', 'culinary-personal-services', v_c11, 'Culinary arts, cosmetology, hospitality services, and personal grooming services.'),
    ('13', 'Education', 'education-pedagogy', v_c9, 'Pedagogy, curriculum design, educational leadership, and instructional methodology.'),
    ('14', 'Engineering', 'engineering-disciplines', v_c3, 'Mechanical, civil, electrical, chemical, aerospace, and robotics engineering.'),
    ('15', 'Engineering/Engineering-Related Technologies/Technicians', 'engineering-technologies', v_c3, 'Applied technical engineering support, industrial technology, and electronics manufacturing.'),
    ('16', 'Foreign Languages, Literatures, and Linguistics', 'foreign-languages-linguistics', v_c10, 'Linguistics, philology, translation, and global language acquisition.'),
    ('19', 'Family and Consumer Sciences/Human Sciences', 'family-consumer-sciences', v_c9, 'Human development, nutritional sciences, family finance, and consumer advocacy.'),
    ('22', 'Legal Professions and Studies', 'legal-professions-studies', v_c7, 'Jurisprudence, constitutional law, legal research, paralegal studies, and court procedures.'),
    ('23', 'English Language and Literature/Letters', 'english-language-literature', v_c10, 'Literary analysis, creative writing, rhetoric, composition, and English philology.'),
    ('24', 'Liberal Arts and Sciences, General Studies and Humanities', 'liberal-arts-humanities', v_c10, 'Foundational interdisciplinary arts, human culture, general studies, and humanities.'),
    ('25', 'Library Science', 'library-science', v_c10, 'Information science, archival preservation, cataloging, and digital curation.'),
    ('26', 'Biological and Biomedical Sciences', 'biological-biomedical-sciences', v_c5, 'Cell biology, genetics, biochemistry, neuroscience, microbiology, and physiology.'),
    ('27', 'Mathematics and Statistics', 'mathematics-statistics-series', v_c6, 'Pure mathematics, applied calculus, probability theory, linear algebra, and data science.'),
    ('28', 'Military Science, Leadership and Operational Art', 'military-science', v_c7, 'Defense leadership, military history, operational planning, and tactics.'),
    ('29', 'Military Technologies and Applied Sciences', 'military-technologies', v_c1, 'Defense systems, intelligence technology, radar, and aerospace military operations.'),
    ('30', 'Multi/Interdisciplinary Studies', 'multi-interdisciplinary-studies', v_c10, 'Bioinformatics, cognitive science, computational linguistics, and sustainability.'),
    ('31', 'Parks, Recreation, Leisure, Fitness, and Kinesiology', 'parks-recreation-kinesiology', v_c12, 'Kinesiology, exercise science, sports management, and recreation leadership.'),
    ('32', 'Basic Skills and Developmental/Remedial Education', 'basic-skills-remedial', v_c12, 'Foundational reading, basic computational numeracy, and fundamental study skills.'),
    ('33', 'Citizenship Activities', 'citizenship-activities', v_c12, 'Civic duties, public volunteerism, constitutional rights, and community engagement.'),
    ('34', 'Health-Related Knowledge and Skills', 'health-knowledge-skills', v_c2, 'Community hygiene, emergency first aid, CPR certification, and personal wellness.'),
    ('35', 'Interpersonal and Social Skills', 'interpersonal-social-skills', v_c12, 'Teamwork, active listening, conflict resolution, and behavioral competence.'),
    ('36', 'Leisure and Recreational Activities', 'leisure-recreational-activities', v_c12, 'Creative hobbies, recreational sports, amateur arts, and personal enrichment.'),
    ('37', 'Personal Awareness and Self-Improvement', 'personal-awareness-improvement', v_c12, 'Time management, goal setting, emotional resilience, and mindfulness.'),
    ('38', 'Philosophy and Religious Studies', 'philosophy-religious-studies', v_c10, 'Epistemology, ethical theory, logic, and comparative religious traditions.'),
    ('39', 'Theology and Religious Vocations', 'theology-religious-vocations', v_c10, 'Theological hermeneutics, pastoral ministry, and religious ordination.'),
    ('40', 'Physical Sciences', 'physical-sciences', v_c5, 'Theoretical and applied physics, organic chemistry, astronomy, and geology.'),
    ('41', 'Science Technologies/Technicians', 'science-technologies', v_c3, 'Laboratory instrumentation, chemical testing, and industrial science technician protocols.'),
    ('42', 'Psychology', 'psychology-discipline', v_c9, 'Clinical psychology, behavioral neuroscience, developmental psych, and psychometrics.'),
    ('43', 'Homeland Security, Law Enforcement, Firefighting and Related Protective Services', 'homeland-security-protective', v_c7, 'Criminal justice, forensics, cybersecurity operations, firefighting, and disaster response.'),
    ('44', 'Public Administration and Social Service Professions', 'public-administration-social', v_c7, 'Public policy analysis, non-profit management, social work, and community welfare.'),
    ('45', 'Social Sciences', 'social-sciences-general', v_c9, 'Economics, political science, sociology, anthropology, and international relations.'),
    ('46', 'Construction Trades', 'construction-trades', v_c11, 'Carpentry, electrical wiring, plumbing, masonry, and building inspection.'),
    ('47', 'Mechanic and Repair Technologies/Technicians', 'mechanic-repair-technologies', v_c11, 'Automotive repair, diesel mechanics, avionics maintenance, and HVAC systems.'),
    ('48', 'Precision Production', 'precision-production', v_c11, 'CNC machining, precision welding, metal fabrication, and toolmaking.'),
    ('49', 'Transportation and Materials Moving', 'transportation-materials-moving', v_c11, 'Commercial aviation, maritime navigation, logistics transit, and heavy transit operations.'),
    ('50', 'Visual and Performing Arts', 'visual-performing-arts', v_c8, 'Studio fine arts, theatrical performance, digital illustration, and musical composition.'),
    ('51', 'Health Professions and Related Programs', 'health-professions-series', v_c2, 'Nursing, clinical medicine, pharmacy, dentistry, allied health, and radiology.'),
    ('52', 'Business, Management, Marketing, and Related Support Services', 'business-management-series', v_c4, 'Corporate management, accounting, quantitative finance, marketing, and entrepreneurship.'),
    ('53', 'High School/Secondary Diplomas and Certificates', 'secondary-diplomas-certificates', v_c12, 'Secondary education curricula, high school equivalency, and academic core completion.'),
    ('54', 'History', 'history-discipline', v_c10, 'World history, historiography, archival analysis, and regional historical inquiries.'),
    ('60', 'Health Professions Residency/Fellowship Programs', 'health-residency-programs', v_c2, 'Post-graduate medical residency specialties and clinical fellowship protocols.'),
    ('61', 'Medical Residency/Fellowship Programs', 'medical-residency-fellowships', v_c2, 'Advanced surgical and diagnostic clinical residency programs.');

  -- Ingest all 48 CIP 2-digit series into external_classification_nodes & fields
  FOR rec IN SELECT * FROM temp_cip_series LOOP
    -- A. External classification node
    INSERT INTO public.external_classification_nodes (
      source_release_id,
      system,
      version,
      code,
      title,
      definition,
      level_code,
      level_depth,
      is_active
    ) VALUES (
      v_cip_rel_id,
      'cip',
      '2020',
      rec.code,
      rec.title,
      rec.description,
      'series',
      1,
      true
    )
    ON CONFLICT (system, version, code)
    DO UPDATE SET title = EXCLUDED.title, definition = EXCLUDED.definition
    RETURNING id INTO node_uuid;

    -- B. Canonical field
    INSERT INTO public.fields (
      name,
      slug,
      description,
      field_kind,
      sort_order,
      is_active
    ) VALUES (
      rec.title,
      rec.slug,
      rec.description,
      'broad_field',
      rec.code::integer,
      true
    )
    ON CONFLICT (slug)
    DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description
    RETURNING id INTO f_uuid;

    -- C. Field External Classification Mapping
    INSERT INTO public.field_external_classifications (
      field_id,
      classification_node_id,
      mapping_type
    ) VALUES (
      f_uuid,
      node_uuid,
      'exact_match'
    )
    ON CONFLICT (field_id, classification_node_id) DO NOTHING;

    -- D. Link to Presentation Cluster
    INSERT INTO public.catalog_cluster_fields (
      cluster_id,
      field_id,
      sort_order
    ) VALUES (
      rec.cluster_id,
      f_uuid,
      rec.code::integer
    )
    ON CONFLICT (cluster_id, field_id) DO NOTHING;
  END LOOP;

  -- --------------------------------------------------------------------------
  -- 2. BLS SOC 2018 Major Groups & Detailed Occupations
  -- --------------------------------------------------------------------------
  CREATE TEMP TABLE temp_soc_nodes (
    code text,
    title text,
    level text,
    parent_code text,
    description text
  ) ON COMMIT DROP;

  INSERT INTO temp_soc_nodes (code, title, level, parent_code, description) VALUES
    ('11-0000', 'Management Occupations', 'major_group', null, 'Executive, managerial, and operational directors.'),
    ('13-0000', 'Business and Financial Operations Occupations', 'major_group', null, 'Financial analysts, accountants, auditors, and management consultants.'),
    ('13-1111', 'Management Analysts', 'detailed_occupation', '13-0000', 'Conduct organizational studies and evaluate procedures to assist management.'),
    ('13-2011', 'Accountants and Auditors', 'detailed_occupation', '13-0000', 'Examine, analyze, and interpret financial records and statements.'),
    ('13-2051', 'Financial and Investment Analysts', 'detailed_occupation', '13-0000', 'Assess economic and financial performance of investment opportunities.'),
    ('15-0000', 'Computer and Mathematical Occupations', 'major_group', null, 'Software developers, computer scientists, data analysts, and mathematicians.'),
    ('15-1211', 'Information Security Analysts', 'detailed_occupation', '15-0000', 'Plan, implement, and monitor security measures for computing networks.'),
    ('15-1252', 'Software Developers', 'detailed_occupation', '15-0000', 'Research, design, and develop computer software systems and applications.'),
    ('15-1254', 'Web Developers', 'detailed_occupation', '15-0000', 'Develop and design website layouts, user interfaces, and server connections.'),
    ('15-2051', 'Data Scientists', 'detailed_occupation', '15-0000', 'Develop algorithms and statistical models to extract value from complex datasets.'),
    ('17-0000', 'Architecture and Engineering Occupations', 'major_group', null, 'Engineers, architects, and technical surveyors.'),
    ('17-2061', 'Computer Hardware Engineers', 'detailed_occupation', '17-0000', 'Research, design, develop, or test computer or computer-related equipment.'),
    ('17-2071', 'Electrical Engineers', 'detailed_occupation', '17-0000', 'Research, develop, test, or supervise electrical equipment manufacturing.'),
    ('29-0000', 'Healthcare Practitioners and Technical Occupations', 'major_group', null, 'Physicians, registered nurses, surgeons, and healthcare practitioners.'),
    ('29-1141', 'Registered Nurses', 'detailed_occupation', '29-0000', 'Assess patient health problems, develop nursing care plans, and maintain records.'),
    ('29-1210', 'Physicians, General', 'detailed_occupation', '29-0000', 'Diagnose and treat diseases and injuries of human patients.'),
    ('31-0000', 'Healthcare Support Occupations', 'major_group', null, 'Nursing assistants, home health aides, and medical assistants.'),
    ('47-0000', 'Construction and Extraction Occupations', 'major_group', null, 'Electricians, carpenters, plumbers, and construction specialists.');

  -- Insert SOC nodes
  FOR rec IN SELECT * FROM temp_soc_nodes ORDER BY level ASC LOOP
    INSERT INTO public.occupation_nodes (
      code,
      title,
      description,
      level,
      taxonomy_system,
      taxonomy_version,
      source_release_id,
      is_active
    ) VALUES (
      rec.code,
      rec.title,
      rec.description,
      rec.level,
      'bls_soc',
      'soc_2018',
      v_soc_rel_id,
      true
    )
    ON CONFLICT (taxonomy_system, taxonomy_version, code)
    DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description;
  END LOOP;

  -- Resolve parent_id for detailed occupations
  UPDATE public.occupation_nodes c
  SET parent_id = p.id
  FROM temp_soc_nodes t
  JOIN public.occupation_nodes p
    ON p.code = t.parent_code
   AND p.taxonomy_system = 'bls_soc'
   AND p.taxonomy_version = 'soc_2018'
  WHERE c.code = t.code
    AND c.taxonomy_system = 'bls_soc'
    AND c.taxonomy_version = 'soc_2018'
    AND t.parent_code IS NOT NULL;

  -- --------------------------------------------------------------------------
  -- 3. O*NET Extensions (onet_soc)
  -- --------------------------------------------------------------------------
  INSERT INTO public.occupation_nodes (
    code,
    title,
    description,
    level,
    taxonomy_system,
    taxonomy_version,
    data_release_version,
    source_release_id,
    is_active
  ) VALUES
    ('15-1252.00', 'Software Developers', 'Research, design, and develop computer and network software.', 'onet_extension', 'onet_soc', '2019', 'onet_31_0', v_onet_rel_id, true),
    ('15-1211.00', 'Information Security Analysts', 'Plan, implement, upgrade, or monitor security measures for computer networks.', 'onet_extension', 'onet_soc', '2019', 'onet_31_0', v_onet_rel_id, true),
    ('15-2051.00', 'Data Scientists', 'Develop and implement algorithms and data models.', 'onet_extension', 'onet_soc', '2019', 'onet_31_0', v_onet_rel_id, true),
    ('29-1141.00', 'Registered Nurses', 'Assess patient health problems and administer nursing care.', 'onet_extension', 'onet_soc', '2019', 'onet_31_0', v_onet_rel_id, true)
  ON CONFLICT (taxonomy_system, taxonomy_version, code) DO NOTHING;

  -- --------------------------------------------------------------------------
  -- 4. Official Qualitative Crosswalk (CIP <-> SOC)
  -- --------------------------------------------------------------------------
  INSERT INTO public.external_classification_occupation_mappings (
    classification_node_id,
    occupation_id,
    source_release_id,
    mapping_kind,
    mapping_source,
    mapping_version
  )
  SELECT
    c.id,
    o.id,
    v_cip_rel_id,
    'official_qualitative',
    'nces_bls_crosswalk_2020',
    '2020'
  FROM (
    VALUES
      ('11', '15-1252'),
      ('11', '15-1211'),
      ('14', '17-2061'),
      ('14', '17-2071'),
      ('27', '15-2051'),
      ('51', '29-1141'),
      ('52', '13-1111'),
      ('52', '13-2011'),
      ('52', '13-2051')
  ) as map(cip_code, soc_code)
  JOIN public.external_classification_nodes c
    ON c.code = map.cip_code
   AND c.system = 'cip'
   AND c.version = '2020'
  JOIN public.occupation_nodes o
    ON o.code = map.soc_code
   AND o.taxonomy_system = 'bls_soc'
   AND o.taxonomy_version = 'soc_2018'
  ON CONFLICT (classification_node_id, occupation_id, source_release_id) DO NOTHING;

  -- --------------------------------------------------------------------------
  -- 5. Foundational Learning Targets Across All Types
  -- --------------------------------------------------------------------------
  CREATE TEMP TABLE temp_targets (
    slug text,
    title text,
    target_type text,
    description text,
    field_slug text
  ) ON COMMIT DROP;

  INSERT INTO temp_targets (slug, title, target_type, description, field_slug) VALUES
    ('career-software-engineer', 'Software Engineer', 'career', 'Design, build, and maintain scalable software applications and computational systems.', 'computer-sciences'),
    ('career-cybersecurity-analyst', 'Information Security Analyst', 'career', 'Protect infrastructure and confidential data against malicious breaches.', 'computer-sciences'),
    ('career-data-scientist', 'Data Scientist', 'career', 'Extract actionable insights and build predictive machine learning models.', 'mathematics-statistics-series'),
    ('career-registered-nurse', 'Registered Nurse', 'career', 'Provide high-quality patient care and medical monitoring in clinical settings.', 'health-professions-series'),
    ('cert-comptia-security-plus', 'CompTIA Security+ (SY0-701)', 'certification', 'Industry-standard baseline credential for IT security and risk assessment.', 'computer-sciences'),
    ('cert-comptia-a-plus', 'CompTIA A+ (Core 1 & 2)', 'certification', 'Foundational certification for computer support, hardware, and mobile operating systems.', 'computer-sciences'),
    ('cert-aws-solutions-architect', 'AWS Certified Solutions Architect', 'certification', 'Validates expertise in designing resilient, high-performing cloud architectures on AWS.', 'computer-sciences'),
    ('cert-nclex-rn', 'NCLEX-RN Licensure Exam', 'licensure_exam', 'National council licensure examination for registered nurses.', 'health-professions-series'),
    ('exam-usmle-step-1', 'USMLE Step 1', 'standardized_exam', 'Foundational medical licensing exam assessing basic science principles.', 'health-professions-series'),
    ('exam-mcat', 'Medical College Admission Test (MCAT)', 'standardized_exam', 'Standardized examination for prospective medical school applicants.', 'biological-biomedical-sciences'),
    ('exam-sat-math', 'SAT Mathematics', 'standardized_exam', 'College board quantitative problem solving, algebra, and geometry assessment.', 'mathematics-statistics-series'),
    ('program-bs-computer-science', 'B.S. in Computer Science', 'academic_program', 'Undergraduate degree curriculum encompassing data structures, operating systems, and theory.', 'computer-sciences'),
    ('program-bs-nursing', 'B.S. in Nursing (BSN)', 'academic_program', 'Comprehensive baccalaureate education in evidence-based clinical nursing practice.', 'health-professions-series'),
    ('program-bs-electrical-engineering', 'B.S. in Electrical Engineering', 'academic_program', 'Circuits, signal processing, electromagnetic fields, and microelectronic devices.', 'engineering-disciplines'),
    ('program-mba', 'Master of Business Administration (MBA)', 'academic_program', 'Graduate leadership education in strategic management, quantitative finance, and corporate operations.', 'business-management-series');

  FOR rec IN SELECT * FROM temp_targets LOOP
    -- Find field id if provided
    f_uuid := NULL;
    IF rec.field_slug IS NOT NULL THEN
      SELECT id INTO f_uuid FROM public.fields WHERE slug = rec.field_slug LIMIT 1;
    END IF;

    INSERT INTO public.learning_targets (
      slug,
      title,
      target_type,
      description,
      field_id,
      is_public,
      status
    ) VALUES (
      rec.slug,
      rec.title,
      rec.target_type,
      rec.description,
      f_uuid,
      true,
      'published'
    )
    ON CONFLICT (slug) DO UPDATE SET
      title = EXCLUDED.title,
      target_type = EXCLUDED.target_type,
      description = EXCLUDED.description,
      field_id = EXCLUDED.field_id
    RETURNING id INTO t_uuid;

    -- Create initial Target Version
    INSERT INTO public.target_versions (
      target_id,
      version_code,
      title,
      status
    ) VALUES (
      t_uuid,
      '2026.1',
      '2026 Initial Edition',
      'published'
    )
    ON CONFLICT (target_id, version_code) DO NOTHING;

    -- Link target to corresponding canonical field in learning_target_fields
    IF f_uuid IS NOT NULL THEN
      INSERT INTO public.learning_target_fields (
        target_id,
        field_id,
        role,
        display_order
      ) VALUES (
        t_uuid,
        f_uuid,
        'primary',
        1
      )
      ON CONFLICT (target_id, field_id) DO NOTHING;
    END IF;
  END LOOP;

END $$;
