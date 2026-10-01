-- ============================================================================
-- Migration: 20260929000005_v2_immutability_and_curriculum_seed.sql
-- Description:
-- 1. Complete Published TargetVersion & CurriculumNode Immutability RLS.
--    - Target versions update/delete disallowed once published (cannot revert status).
--    - Curriculum nodes write disallowed for published target versions.
-- 2. Add trigger to prevent circular prerequisite cycles in concept_relations.
-- 3. Seed curriculum node structures for primary targets:
--    - CompTIA Security+ (5 domains)
--    - GRE (5 domains)
--    - Software Engineer (5 domains)
--    - Data Scientist (4 domains)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Published TargetVersion & CurriculumNode Immutability RLS
-- ----------------------------------------------------------------------------

-- A. target_versions write policies (insert, update, delete)
alter table public.target_versions enable row level security;
drop policy if exists "versions_write" on public.target_versions;
drop policy if exists "versions_insert" on public.target_versions;
drop policy if exists "versions_update" on public.target_versions;
drop policy if exists "versions_delete" on public.target_versions;

create policy "versions_insert" on public.target_versions
  for insert with check (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

create policy "versions_update" on public.target_versions
  for update using (
    target_versions.status <> 'published'
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

create policy "versions_delete" on public.target_versions
  for delete using (
    target_versions.status <> 'published'
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

-- B. curriculum_nodes write policy with parent version immutability check
alter table public.curriculum_nodes enable row level security;
drop policy if exists "nodes_write" on public.curriculum_nodes;
create policy "nodes_write" on public.curriculum_nodes
  for all using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  )
  with check (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Prerequisite Cycle Prevention Trigger
-- ----------------------------------------------------------------------------
create or replace function public.check_concept_relation_cycle()
returns trigger as $$
declare
  v_cycle_found boolean;
begin
  if new.relation_type = 'prerequisite' then
    if new.from_concept_id = new.to_concept_id then
      raise exception 'Prerequisite cycle detected: concept cannot be prerequisite of itself';
    end if;

    with recursive prereq_path as (
      select to_concept_id as reachable_id
      from public.concept_relations
      where from_concept_id = new.to_concept_id
        and relation_type = 'prerequisite'
      union
      select cr.to_concept_id
      from public.concept_relations cr
      join prereq_path p on p.reachable_id = cr.from_concept_id
      where cr.relation_type = 'prerequisite'
    )
    select exists (
      select 1 from prereq_path where reachable_id = new.from_concept_id
    ) into v_cycle_found;

    if v_cycle_found then
      raise exception 'Prerequisite cycle detected: adding relation from % to % forms a directed cycle', new.from_concept_id, new.to_concept_id;
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_prevent_concept_relation_cycle on public.concept_relations;
create trigger trg_prevent_concept_relation_cycle
  before insert or update on public.concept_relations
  for each row execute function public.check_concept_relation_cycle();

-- ----------------------------------------------------------------------------
-- 3. Seed Curriculum Nodes for Primary Targets
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_target_id uuid;
  v_ver_id uuid;
BEGIN
  -- A. CompTIA Security+ (SY0-701)
  SELECT id INTO v_target_id FROM public.learning_targets WHERE slug = 'cert-comptia-security-plus' LIMIT 1;
  IF v_target_id IS NOT NULL THEN
    SELECT id INTO v_ver_id FROM public.target_versions WHERE target_id = v_target_id ORDER BY created_at DESC LIMIT 1;
    IF v_ver_id IS NOT NULL THEN
      INSERT INTO public.curriculum_nodes (target_version_id, title, description, code, node_type, sort_order, weight) VALUES
        (v_ver_id, 'General Security Concepts', 'Foundational security principles, confidentiality, integrity, availability, authentication, and access control models.', 'SEC-1.0', 'domain', 1, 1.0),
        (v_ver_id, 'Threats, Vulnerabilities, and Mitigations', 'Common threat actors, vectors, social engineering, malware types, vulnerabilities, and hardening mitigations.', 'SEC-2.0', 'domain', 2, 1.0),
        (v_ver_id, 'Security Architecture', 'Network architectures, zero trust principles, cloud security models, data protection, and resilience.', 'SEC-3.0', 'domain', 3, 1.0),
        (v_ver_id, 'Security Operations', 'Monitoring, incident response, digital forensics, vulnerability scanning, and cryptographic management.', 'SEC-4.0', 'domain', 4, 1.0),
        (v_ver_id, 'Security Program Management and Oversight', 'Governance, risk management strategies, regulatory compliance, audits, and third-party assessments.', 'SEC-5.0', 'domain', 5, 1.0)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- B. GRE General Test
  SELECT id INTO v_target_id FROM public.learning_targets WHERE slug = 'exam-gre' LIMIT 1;
  IF v_target_id IS NOT NULL THEN
    SELECT id INTO v_ver_id FROM public.target_versions WHERE target_id = v_target_id ORDER BY created_at DESC LIMIT 1;
    IF v_ver_id IS NOT NULL THEN
      INSERT INTO public.curriculum_nodes (target_version_id, title, description, code, node_type, sort_order, weight) VALUES
        (v_ver_id, 'Quantitative Reasoning: Arithmetic & Algebra', 'Number properties, exponents, operations, algebraic equations, inequalities, and functions.', 'GRE-Q1', 'domain', 1, 1.0),
        (v_ver_id, 'Quantitative Reasoning: Geometry & Data Analysis', 'Coordinate geometry, polygons, circles, descriptive statistics, probability, and data interpretation.', 'GRE-Q2', 'domain', 2, 1.0),
        (v_ver_id, 'Verbal Reasoning: Reading Comprehension', 'Critical passage analysis, rhetoric, evaluating arguments, and synthesizing multi-paragraph texts.', 'GRE-V1', 'domain', 3, 1.0),
        (v_ver_id, 'Verbal Reasoning: Text Completion & Sentence Equivalence', 'Advanced contextual vocabulary, tone, semantic consistency, and sentence completion structures.', 'GRE-V2', 'domain', 4, 1.0),
        (v_ver_id, 'Analytical Writing', 'Constructing coherent, persuasive critiques of arguments and analyzing complex issues clearly.', 'GRE-AW', 'domain', 5, 1.0)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- C. Software Engineer Career
  SELECT id INTO v_target_id FROM public.learning_targets WHERE slug = 'career-software-engineer' LIMIT 1;
  IF v_target_id IS NOT NULL THEN
    SELECT id INTO v_ver_id FROM public.target_versions WHERE target_id = v_target_id ORDER BY created_at DESC LIMIT 1;
    IF v_ver_id IS NOT NULL THEN
      INSERT INTO public.curriculum_nodes (target_version_id, title, description, code, node_type, sort_order, weight) VALUES
        (v_ver_id, 'Data Structures & Algorithms', 'Arrays, lists, trees, graphs, sorting, searching, time complexity, and dynamic programming.', 'SWE-1', 'domain', 1, 1.0),
        (v_ver_id, 'System Design & Architecture', 'Scalability, microservices, load balancers, caching strategies, asynchronous messaging, and resilience patterns.', 'SWE-2', 'domain', 2, 1.0),
        (v_ver_id, 'Web & API Engineering', 'HTTP protocols, REST, GraphQL, authentication protocols, state management, and API design.', 'SWE-3', 'domain', 3, 1.0),
        (v_ver_id, 'Database & Storage Systems', 'Relational modeling, indexing, ACID transactions, NoSQL paradigms, and distributed data stores.', 'SWE-4', 'domain', 4, 1.0),
        (v_ver_id, 'Testing, CI/CD & DevOps', 'Unit testing, integration testing, automated deployment pipelines, containerization, and telemetry.', 'SWE-5', 'domain', 5, 1.0)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- D. Data Scientist Career
  SELECT id INTO v_target_id FROM public.learning_targets WHERE slug = 'career-data-scientist' LIMIT 1;
  IF v_target_id IS NOT NULL THEN
    SELECT id INTO v_ver_id FROM public.target_versions WHERE target_id = v_target_id ORDER BY created_at DESC LIMIT 1;
    IF v_ver_id IS NOT NULL THEN
      INSERT INTO public.curriculum_nodes (target_version_id, title, description, code, node_type, sort_order, weight) VALUES
        (v_ver_id, 'Exploratory Data Analysis & Statistics', 'Hypothesis testing, probability distributions, statistical significance, and data cleansing.', 'DS-1', 'domain', 1, 1.0),
        (v_ver_id, 'Machine Learning Algorithms', 'Regression, classification, decision trees, ensemble methods, clustering, and model validation.', 'DS-2', 'domain', 2, 1.0),
        (v_ver_id, 'Deep Learning & Neural Architectures', 'Feedforward networks, CNNs, sequence models, transformers, and transfer learning.', 'DS-3', 'domain', 3, 1.0),
        (v_ver_id, 'Data Engineering & MLOps', 'Feature stores, model deployment, monitoring drift, pipeline orchestration, and reproducibility.', 'DS-4', 'domain', 4, 1.0)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;
