-- ============================================================================
-- Learning Architecture v2 — Sample Target & Knowledge Graph Seed
-- Migration: 20260928000000_v2_sample_data.sql
-- ============================================================================

DO $$
DECLARE
  v_field_id uuid := 'f1000000-0000-0000-0000-000000000001';
  v_target_id uuid := 'e1000000-0000-0000-0000-000000000001';
  v_version_id uuid := 'd1000000-0000-0000-0000-000000000001';
  
  v_node1_id uuid := 'c1000000-0000-0000-0000-000000000001';
  v_node2_id uuid := 'c1000000-0000-0000-0000-000000000002';
  v_node3_id uuid := 'c1000000-0000-0000-0000-000000000003';
  
  v_concept1_id uuid := 'b1000000-0000-0000-0000-000000000001';
  v_concept2_id uuid := 'b1000000-0000-0000-0000-000000000002';
  v_concept3_id uuid := 'b1000000-0000-0000-0000-000000000003';
  v_concept4_id uuid := 'b1000000-0000-0000-0000-000000000004';
  v_concept5_id uuid := 'b1000000-0000-0000-0000-000000000005';
  v_concept6_id uuid := 'b1000000-0000-0000-0000-000000000006';
BEGIN
  -- 1. Insert Field
  INSERT INTO public.fields (id, name, slug, description, icon, is_active)
  VALUES (
    v_field_id,
    'Computer Science & Software',
    'computer-science',
    'Foundations of computing, software engineering, and systems.',
    'computer',
    true
  ) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

  -- 2. Insert Learning Target
  INSERT INTO public.learning_targets (
    id, target_type, field_id, title, slug, description,
    provider_name, institution_name, emoji, is_public, is_official, status
  ) VALUES (
    v_target_id,
    'certification',
    v_field_id,
    'Programming Fundamentals',
    'programming-fundamentals',
    'Master core computational logic, structured algorithms, and object-oriented architecture.',
    'Code Learning Institute',
    'Global Standards',
    '💻',
    true,
    true,
    'published'
  ) ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;

  -- 3. Insert Target Version
  INSERT INTO public.target_versions (
    id, target_id, version_code, title, description, status
  ) VALUES (
    v_version_id,
    v_target_id,
    '2026.1',
    'Programming Fundamentals (2026 Core Curriculum)',
    'Comprehensive 3-unit progression through variables, control flow, functions, and OOP.',
    'published'
  ) ON CONFLICT (id) DO UPDATE SET status = 'published';

  -- 4. Insert Curriculum Nodes
  INSERT INTO public.curriculum_nodes (
    id, target_version_id, parent_id, node_type, title, description, code, sort_order, importance
  ) VALUES
  (
    v_node1_id, v_version_id, null, 'unit',
    'Unit 1: Syntax & Control Flow',
    'Variables, primitive types, conditional branches, and iterative loops.',
    'UNIT-01', 1, 'core'
  ),
  (
    v_node2_id, v_version_id, null, 'unit',
    'Unit 2: Functions & Data Structures',
    'Reusable procedures, parameter passing, lists, maps, and memory collections.',
    'UNIT-02', 2, 'core'
  ),
  (
    v_node3_id, v_version_id, null, 'unit',
    'Unit 3: Advanced Paradigms & OOP',
    'Classes, encapsulation, inheritance, polymorphism, and recursive problem solving.',
    'UNIT-03', 3, 'core'
  )
  ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;

  -- 5. Bind Existing Lessons to Curriculum Nodes
  -- Node 1: Variables & Control Flow
  INSERT INTO public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order, is_required)
  SELECT v_node1_id, id, 1, true FROM public.lessons WHERE id = '8c73e33b-825f-45f3-a7e5-3c498350df60'
  ON CONFLICT (curriculum_node_id, lesson_id) DO NOTHING;

  INSERT INTO public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order, is_required)
  SELECT v_node1_id, id, 2, true FROM public.lessons WHERE id = '5e8ae4ec-d37c-41a1-acd7-ededdd97c0d1'
  ON CONFLICT (curriculum_node_id, lesson_id) DO NOTHING;

  -- Node 2: Functions & Data Structures
  INSERT INTO public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order, is_required)
  SELECT v_node2_id, id, 1, true FROM public.lessons WHERE id = 'a0db6b00-04b7-4c3b-a797-c1a4bb25d613'
  ON CONFLICT (curriculum_node_id, lesson_id) DO NOTHING;

  INSERT INTO public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order, is_required)
  SELECT v_node2_id, id, 2, true FROM public.lessons WHERE id = 'ec1def6e-a9c3-4760-9d63-89a5cfeb5796'
  ON CONFLICT (curriculum_node_id, lesson_id) DO NOTHING;

  -- Node 3: OOP & Recursion
  INSERT INTO public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order, is_required)
  SELECT v_node3_id, id, 1, true FROM public.lessons WHERE id = '604ec6e2-9acd-4aec-aed3-71f9bd768c19'
  ON CONFLICT (curriculum_node_id, lesson_id) DO NOTHING;

  INSERT INTO public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order, is_required)
  SELECT v_node3_id, id, 2, true FROM public.lessons WHERE id = 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20'
  ON CONFLICT (curriculum_node_id, lesson_id) DO NOTHING;

  -- 6. Insert Knowledge Concepts
  INSERT INTO public.knowledge_concepts (id, field_id, name, slug, description, emoji, status)
  VALUES
  (v_concept1_id, v_field_id, 'Variables & Types', 'variables-and-types', 'Memory allocation, data types, and identifier scope.', '🔢', 'active'),
  (v_concept2_id, v_field_id, 'Control Flow', 'control-flow', 'Boolean branching, if-else trees, and loop execution.', '🔀', 'active'),
  (v_concept3_id, v_field_id, 'Functions & Scope', 'functions-and-scope', 'Modularity, pure routines, argument passing, and stack frames.', '⚡', 'active'),
  (v_concept4_id, v_field_id, 'Collections & Data Structures', 'collections-data-structures', 'Contiguous arrays, dynamic lists, hash maps, and key-value indexing.', '📦', 'active'),
  (v_concept5_id, v_field_id, 'Object-Oriented Design', 'object-oriented-design', 'Encapsulation, class instantiations, methods, and inheritance.', '🏛️', 'active'),
  (v_concept6_id, v_field_id, 'Recursive Algorithms', 'recursive-algorithms', 'Base cases, divide-and-conquer, and recursive call stacks.', '🔄', 'active')
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

  -- 7. Bind Concepts to Curriculum Nodes
  INSERT INTO public.curriculum_node_concepts (curriculum_node_id, concept_id, relevance, weight)
  VALUES
  (v_node1_id, v_concept1_id, 'core', 1.0),
  (v_node1_id, v_concept2_id, 'core', 1.0),
  (v_node2_id, v_concept3_id, 'core', 1.0),
  (v_node2_id, v_concept4_id, 'core', 1.0),
  (v_node3_id, v_concept5_id, 'core', 1.0),
  (v_node3_id, v_concept6_id, 'core', 1.0)
  ON CONFLICT (curriculum_node_id, concept_id) DO NOTHING;

  -- 8. Bind Concepts to Lessons
  INSERT INTO public.lesson_concepts (lesson_id, concept_id, role, weight)
  SELECT '8c73e33b-825f-45f3-a7e5-3c498350df60', v_concept1_id, 'primary', 1.0
  ON CONFLICT (lesson_id, concept_id) DO NOTHING;

  INSERT INTO public.lesson_concepts (lesson_id, concept_id, role, weight)
  SELECT '5e8ae4ec-d37c-41a1-acd7-ededdd97c0d1', v_concept2_id, 'primary', 1.0
  ON CONFLICT (lesson_id, concept_id) DO NOTHING;

  INSERT INTO public.lesson_concepts (lesson_id, concept_id, role, weight)
  SELECT 'a0db6b00-04b7-4c3b-a797-c1a4bb25d613', v_concept3_id, 'primary', 1.0
  ON CONFLICT (lesson_id, concept_id) DO NOTHING;

  INSERT INTO public.lesson_concepts (lesson_id, concept_id, role, weight)
  SELECT 'ec1def6e-a9c3-4760-9d63-89a5cfeb5796', v_concept4_id, 'primary', 1.0
  ON CONFLICT (lesson_id, concept_id) DO NOTHING;

  INSERT INTO public.lesson_concepts (lesson_id, concept_id, role, weight)
  SELECT '604ec6e2-9acd-4aec-aed3-71f9bd768c19', v_concept5_id, 'primary', 1.0
  ON CONFLICT (lesson_id, concept_id) DO NOTHING;

  INSERT INTO public.lesson_concepts (lesson_id, concept_id, role, weight)
  SELECT 'a7f3c2e1-9b4d-4e6a-8c12-3f5d7e9a1b20', v_concept6_id, 'primary', 1.0
  ON CONFLICT (lesson_id, concept_id) DO NOTHING;

END $$;
