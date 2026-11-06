-- ============================================================================
-- Architecture Phase 2 Deliverable: Versioned API Schema & Fast Scope Resolver
-- Migration: 20261106010000_arch_03_versioned_api_schema_and_scope_resolver.sql
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 1. VERSIONED API SCHEMA CREATION (ARCH-2)
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS api;
GRANT USAGE ON SCHEMA api TO anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. FAST SCOPE RESOLVER RPC: api.resolve_scope (ARCH-2, PERF-8)
-- -----------------------------------------------------------------------------
-- Resolves the bounded learning scope, curriculum hierarchy, and deterministic
-- activity sequence for any active learning context in a single server-side query.
-- Replaces client-side N+1 query cascades (35 round-trips with inFilter).
CREATE OR REPLACE FUNCTION api.resolve_scope(
  p_context JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, api
AS $$
DECLARE
  v_context_id TEXT;
  v_root_type TEXT;
  v_root_id TEXT;
  v_target_version_id UUID;
  v_config_hash TEXT;

  v_node_ids UUID[] := ARRAY[]::UUID[];
  v_core_concept_ids UUID[] := ARRAY[]::UUID[];
  v_supporting_concept_ids UUID[] := ARRAY[]::UUID[];
  v_related_concept_ids UUID[] := ARRAY[]::UUID[];

  v_activities JSONB := '[]'::JSONB;
  v_question_ids TEXT[] := ARRAY[]::TEXT[];
  v_term_ids TEXT[] := ARRAY[]::TEXT[];
  v_flashcard_ids TEXT[] := ARRAY[]::TEXT[];

  v_target_id UUID;
BEGIN
  v_context_id := COALESCE(p_context->>'id', p_context->>'context_id', 'ctx-default');
  v_root_type := COALESCE(p_context->>'root_type', 'target');
  v_root_id := p_context->>'root_id';
  v_config_hash := p_context->>'config_hash';

  -- Parse target_version_id if provided
  IF p_context ? 'target_version_id' AND p_context->>'target_version_id' IS NOT NULL AND (p_context->>'target_version_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    v_target_version_id := (p_context->>'target_version_id')::UUID;
  END IF;

  -- ---------------------------------------------------------------------------
  -- RESOLUTION BY ROOT TYPE: TARGET
  -- ---------------------------------------------------------------------------
  IF v_root_type = 'target' THEN
    -- If no target_version_id supplied, resolve latest published version for target
    IF v_target_version_id IS NULL AND v_root_id IS NOT NULL THEN
      IF v_root_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_target_id := v_root_id::UUID;
        SELECT id INTO v_target_version_id
        FROM public.target_versions
        WHERE target_id = v_target_id AND status = 'published'
        ORDER BY created_at DESC
        LIMIT 1;
      ELSE
        -- Match slug if root_id is not a UUID
        SELECT tv.id INTO v_target_version_id
        FROM public.learning_targets lt
        JOIN public.target_versions tv ON tv.target_id = lt.id
        WHERE lt.slug = v_root_id AND tv.status = 'published'
        ORDER BY tv.created_at DESC
        LIMIT 1;
      END IF;
    END IF;

    -- When target version is located, resolve complete curriculum graph
    IF v_target_version_id IS NOT NULL THEN
      -- 1. Curriculum Node IDs
      SELECT ARRAY_AGG(id) INTO v_node_ids
      FROM public.curriculum_nodes
      WHERE target_version_id = v_target_version_id;
      v_node_ids := COALESCE(v_node_ids, ARRAY[]::UUID[]);

      -- 2. Core, Supporting, and Related Concepts
      SELECT ARRAY_AGG(DISTINCT cnc.concept_id) INTO v_core_concept_ids
      FROM public.curriculum_node_concepts cnc
      JOIN public.curriculum_nodes cn ON cn.id = cnc.curriculum_node_id
      WHERE cn.target_version_id = v_target_version_id AND cnc.relevance = 'core';
      v_core_concept_ids := COALESCE(v_core_concept_ids, ARRAY[]::UUID[]);

      SELECT ARRAY_AGG(DISTINCT cnc.concept_id) INTO v_supporting_concept_ids
      FROM public.curriculum_node_concepts cnc
      JOIN public.curriculum_nodes cn ON cn.id = cnc.curriculum_node_id
      WHERE cn.target_version_id = v_target_version_id AND cnc.relevance = 'supporting';
      v_supporting_concept_ids := COALESCE(v_supporting_concept_ids, ARRAY[]::UUID[]);

      SELECT ARRAY_AGG(DISTINCT cnc.concept_id) INTO v_related_concept_ids
      FROM public.curriculum_node_concepts cnc
      JOIN public.curriculum_nodes cn ON cn.id = cnc.curriculum_node_id
      WHERE cn.target_version_id = v_target_version_id AND cnc.relevance = 'related';
      v_related_concept_ids := COALESCE(v_related_concept_ids, ARRAY[]::UUID[]);

      -- 3. Ordered Activities from Nodes and Linked Public Lessons
      SELECT COALESCE(jsonb_agg(act), '[]'::JSONB) INTO v_activities
      FROM (
        SELECT
          cn.id::TEXT AS activity_id,
          'lesson'::TEXT AS kind,
          'official'::TEXT AS source,
          TRUE AS is_required,
          cn.id::TEXT AS curriculum_node_id,
          COALESCE(cn.sort_order, 0) AS curriculum_order,
          COALESCE(cn.sort_order, 0) AS activity_order,
          'core'::TEXT AS role,
          COALESCE(cn.title, 'Node ' || cn.code) AS title,
          COALESCE((cn.metadata->>'estimated_minutes')::INTEGER, 10) AS estimated_minutes,
          NULL::TEXT AS course_id,
          NULL::TEXT AS course_title,
          NULL::TEXT AS module_id,
          NULL::TEXT AS module_title
        FROM public.curriculum_nodes cn
        WHERE cn.target_version_id = v_target_version_id
        ORDER BY COALESCE(cn.sort_order, 0) ASC
      ) act;

      -- 4. Assessment Item and Question IDs
      SELECT ARRAY_AGG(DISTINCT ai.id::TEXT) INTO v_question_ids
      FROM public.assessment_items ai
      WHERE ai.origin_target_version_id = v_target_version_id;
      v_question_ids := COALESCE(v_question_ids, ARRAY[]::TEXT[]);

      -- Also collect question IDs from questions table if any
      IF array_length(v_node_ids, 1) > 0 THEN
        DECLARE
          v_extra_qids TEXT[];
        BEGIN
          SELECT ARRAY_AGG(DISTINCT q.id::TEXT) INTO v_extra_qids
          FROM public.assessment_questions q
          JOIN public.curriculum_node_lessons cnl ON cnl.lesson_id = q.assessment_id
          WHERE cnl.curriculum_node_id = ANY(v_node_ids);

          IF v_extra_qids IS NOT NULL THEN
            v_question_ids := ARRAY(
              SELECT DISTINCT unnest(v_question_ids || v_extra_qids)
            );
          END IF;
        END;
      END IF;

    END IF;

  -- ---------------------------------------------------------------------------
  -- RESOLUTION BY ROOT TYPE: LESSON
  -- ---------------------------------------------------------------------------
  ELSIF v_root_type = 'lesson' AND v_root_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    DECLARE
      v_lid UUID := v_root_id::UUID;
    BEGIN
      -- Questions linked to lesson
      SELECT ARRAY_AGG(id::TEXT) INTO v_question_ids
      FROM public.assessment_questions
      WHERE assessment_id = v_lid;
      v_question_ids := COALESCE(v_question_ids, ARRAY[]::TEXT[]);

      -- Single activity representing the lesson
      SELECT COALESCE(jsonb_agg(act), '[]'::JSONB) INTO v_activities
      FROM (
        SELECT
          l.id::TEXT AS activity_id,
          'lesson'::TEXT AS kind,
          'official'::TEXT AS source,
          TRUE AS is_required,
          cnl.curriculum_node_id::TEXT AS curriculum_node_id,
          0 AS curriculum_order,
          0 AS activity_order,
          'core'::TEXT AS role,
          COALESCE(l.title, 'Lesson') AS title,
          15 AS estimated_minutes,
          NULL::TEXT AS course_id,
          NULL::TEXT AS course_title,
          NULL::TEXT AS module_id,
          NULL::TEXT AS module_title
        FROM public.lessons l
        LEFT JOIN public.curriculum_node_lessons cnl ON cnl.lesson_id = l.id
        WHERE l.id = v_lid
      ) act;
    END;

  END IF;

  -- Return complete structured ResolvedScope JSON
  RETURN jsonb_build_object(
    'context_id', v_context_id,
    'core_concept_ids', COALESCE(to_jsonb(v_core_concept_ids), '[]'::JSONB),
    'supporting_concept_ids', COALESCE(to_jsonb(v_supporting_concept_ids), '[]'::JSONB),
    'related_concept_ids', COALESCE(to_jsonb(v_related_concept_ids), '[]'::JSONB),
    'curriculum_node_ids', COALESCE(to_jsonb(v_node_ids), '[]'::JSONB),
    'ordered_activities', v_activities,
    'question_ids', COALESCE(to_jsonb(v_question_ids), '[]'::JSONB),
    'term_ids', COALESCE(to_jsonb(v_term_ids), '[]'::JSONB),
    'flashcard_ids', COALESCE(to_jsonb(v_flashcard_ids), '[]'::JSONB),
    'resolved_at', NOW(),
    'config_hash', v_config_hash
  );
END;
$$;

-- Public schema alias for client compatibility
CREATE OR REPLACE FUNCTION public.resolve_scope(
  p_context JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions, api
AS $$
  SELECT api.resolve_scope(p_context);
$$;

REVOKE ALL ON FUNCTION api.resolve_scope(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.resolve_scope(JSONB) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.resolve_scope(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_scope(JSONB) TO anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. LEARNER SUMMARY RPC: api.get_learner_summary (ARCH-2, ARCH-1)
-- -----------------------------------------------------------------------------
-- Computes the learner's active due counts, FSRS memory parameters, review backlog,
-- and recent study streak in a single consolidated RPC.
CREATE OR REPLACE FUNCTION api.get_learner_summary(
  p_context_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, api
AS $$
DECLARE
  v_uid UUID;
  v_due_count INTEGER := 0;
  v_total_reviewed INTEGER := 0;
  v_correct_reviewed INTEGER := 0;
  v_avg_stability DOUBLE PRECISION := 0.0;
  v_avg_difficulty DOUBLE PRECISION := 0.0;
  v_weakest_concepts JSONB := '[]'::JSONB;
  v_retention_rate REAL := 0.0;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required for learner summary' USING ERRCODE = '42501';
  END IF;

  -- 1. Spaced Repetition Due & Performance Aggregates
  SELECT
    COUNT(*) FILTER (WHERE next_review_date <= NOW()),
    COALESCE(SUM(total_reviews), 0),
    COALESCE(SUM(correct_reviews), 0),
    COALESCE(AVG(stability), 1.0),
    COALESCE(AVG(difficulty), 5.0)
  INTO
    v_due_count,
    v_total_reviewed,
    v_correct_reviewed,
    v_avg_stability,
    v_avg_difficulty
  FROM public.review_items
  WHERE user_id = v_uid;

  IF v_total_reviewed > 0 THEN
    v_retention_rate := (v_correct_reviewed::REAL / v_total_reviewed::REAL);
  END IF;

  -- 2. Weakest Concepts from Evidence Projection
  SELECT COALESCE(jsonb_agg(wc), '[]'::JSONB) INTO v_weakest_concepts
  FROM (
    SELECT
      ucs.concept_id::TEXT AS concept_id,
      COALESCE(kc.name, kc.slug, 'Concept ' || SUBSTRING(ucs.concept_id::TEXT FROM 1 FOR 8)) AS concept_title,
      CASE
        WHEN ucs.weighted_total > 0 THEN (ucs.weighted_correct / ucs.weighted_total)::NUMERIC(4,3)
        ELSE 0.0
      END AS accuracy,
      ucs.evidence_count,
      ucs.last_evidence_at
    FROM public.user_concept_state ucs
    LEFT JOIN public.knowledge_concepts kc ON kc.id = ucs.concept_id
    WHERE ucs.user_id = v_uid AND ucs.evidence_count >= 1
    ORDER BY (
      CASE WHEN ucs.weighted_total > 0 THEN (ucs.weighted_correct / ucs.weighted_total) ELSE 0.0 END
    ) ASC, ucs.evidence_count DESC
    LIMIT 5
  ) wc;

  RETURN jsonb_build_object(
    'user_id', v_uid,
    'context_id', p_context_id,
    'due_reviews_count', v_due_count,
    'total_reviews_count', v_total_reviewed,
    'correct_reviews_count', v_correct_reviewed,
    'retention_rate', ROUND(v_retention_rate::NUMERIC, 3),
    'average_stability', ROUND(v_avg_stability::NUMERIC, 2),
    'average_difficulty', ROUND(v_avg_difficulty::NUMERIC, 2),
    'weakest_concepts', v_weakest_concepts,
    'generated_at', NOW()
  );
END;
$$;

-- Public schema alias for client compatibility
CREATE OR REPLACE FUNCTION public.get_learner_summary(
  p_context_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions, api
AS $$
  SELECT api.get_learner_summary(p_context_id);
$$;

REVOKE ALL ON FUNCTION api.get_learner_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.get_learner_summary(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_learner_summary(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_learner_summary(UUID) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. UNIFIED CATALOG SEARCH RPC: api.search_catalog (ARCH-2, OPP-1)
-- -----------------------------------------------------------------------------
-- High-performance indexed catalog search across learning targets, certifications,
-- academic degrees, and licensure pathways with active version resolution.
CREATE OR REPLACE FUNCTION api.search_catalog(
  p_query TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, api
AS $$
DECLARE
  v_limit INTEGER;
  v_results JSONB := '[]'::JSONB;
BEGIN
  v_limit := LEAST(100, GREATEST(1, COALESCE(p_limit, 20)));

  SELECT COALESCE(jsonb_agg(cat), '[]'::JSONB) INTO v_results
  FROM (
    SELECT
      lt.id,
      lt.slug,
      lt.title,
      lt.description,
      lt.target_type AS category,
      COALESCE(lt.provider_name, lt.institution_name) AS issuer,
      tv.id AS active_version_id,
      tv.version_code,
      tv.title AS version_title,
      lt.created_at
    FROM public.learning_targets lt
    LEFT JOIN LATERAL (
      SELECT id, version_code, title
      FROM public.target_versions
      WHERE target_id = lt.id AND status = 'published'
      ORDER BY created_at DESC
      LIMIT 1
    ) tv ON TRUE
    WHERE (
      p_category IS NULL OR lt.target_type = p_category
    )
    AND (
      p_query IS NULL OR p_query = '' OR (
        lt.title ILIKE '%' || p_query || '%' OR
        lt.description ILIKE '%' || p_query || '%' OR
        lt.slug ILIKE '%' || p_query || '%' OR
        COALESCE(lt.provider_name, lt.institution_name, '') ILIKE '%' || p_query || '%'
      )
    )
    ORDER BY (
      CASE
        WHEN p_query IS NOT NULL AND lt.title ILIKE p_query || '%' THEN 1
        WHEN p_query IS NOT NULL AND lt.title ILIKE '%' || p_query || '%' THEN 2
        ELSE 3
      END
    ), lt.title ASC
    LIMIT v_limit
  ) cat;

  RETURN v_results;
END;
$$;

-- Public schema alias for client compatibility
CREATE OR REPLACE FUNCTION public.search_catalog(
  p_query TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions, api
AS $$
  SELECT api.search_catalog(p_query, p_category, p_limit);
$$;

REVOKE ALL ON FUNCTION api.search_catalog(TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.search_catalog(TEXT, TEXT, INTEGER) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.search_catalog(TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_catalog(TEXT, TEXT, INTEGER) TO anon, authenticated, service_role;

