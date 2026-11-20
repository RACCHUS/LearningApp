-- Server grading for numeric_entry assessment items.
--
-- grade_assessment_items graded single_choice, multi_select,
-- ordered_response and matching; numeric_entry items (allowed by the
-- manifest schema and the assessment_items check constraint) came back as
-- unsupported_interaction_type. Imported open textbook lessons
-- (tool/import_open_textbook.py) use numeric_entry for exercises whose
-- answer key is a single number, so they need real grading.
--
-- This redefines the function from 20261108140000 unchanged except for the
-- new numeric_entry branch: same visibility and protected-item rules, same
-- "response required before any key is returned" rule, same grants.

create or replace function public.grade_assessment_items(p_responses jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_entry jsonb;
  v_item_id uuid;
  v_response jsonb;
  v_item public.assessment_items%rowtype;
  v_spec jsonb;
  v_correct_num numeric;
  v_user_num numeric;
  v_correct_set integer[];
  v_user_set integer[];
  v_mode text;
  v_items text[];
  v_order integer[];
  v_expected text[];
  v_user_order text[];
  v_pairs jsonb;
  v_user_pairs jsonb;
  v_matched integer;
  v_total integer;
  v_hit integer;
  v_miss integer;
  v_score numeric;
  v_is_correct boolean;
  v_is_partial boolean;
  v_supported boolean;
  v_results jsonb := '[]'::jsonb;
begin
  if p_responses is null or jsonb_typeof(p_responses) <> 'array' then
    raise exception 'p_responses must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_responses) > 250 then
    raise exception 'At most 250 responses can be graded per call'
      using errcode = '54000';
  end if;

  for v_entry in select value from jsonb_array_elements(p_responses)
  loop
    v_item_id := null;
    begin
      v_item_id := (v_entry->>'item_id')::uuid;
    exception when invalid_text_representation then
      v_item_id := null;
    end;
    v_response := v_entry->'response';

    if v_item_id is null then
      continue;
    end if;

    -- A response is required: keys are never revealed for unanswered items.
    if v_response is null or jsonb_typeof(v_response) = 'null' then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id, 'error', 'response_required'));
      continue;
    end if;

    select ai.* into v_item
    from public.assessment_items ai
    where ai.id = v_item_id
      and not public.exm03_has_protected_binding(ai.id)
      and not public.is_protected_simulation_item(ai.metadata)
      and (
        (v_uid is not null and ai.user_id = v_uid)
        or (ai.lesson_id is not null and public.is_lesson_visible(ai.lesson_id))
        or (ai.origin_target_version_id is not null and exists (
          select 1
          from public.target_versions tv
          join public.learning_targets lt on lt.id = tv.target_id
          where tv.id = ai.origin_target_version_id
            and (
              (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
              or (v_uid is not null and lt.created_by = v_uid)
              or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
            )
        ))
      );

    if not found then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id, 'error', 'not_available'));
      continue;
    end if;

    v_spec := coalesce(v_item.scoring_spec, '{}'::jsonb);
    v_is_correct := false;
    v_is_partial := false;
    v_score := 0;
    v_supported := true;

    case v_item.interaction_type
      when 'single_choice' then
        v_correct_num := case
          when jsonb_typeof(v_spec->'correct_index') = 'number' then (v_spec->>'correct_index')::numeric
          when jsonb_typeof(v_spec->'correct_answer') = 'number' then (v_spec->>'correct_answer')::numeric
        end;
        v_user_num := case
          when jsonb_typeof(v_response) = 'number' then (v_response#>>'{}')::numeric
          when jsonb_typeof(v_response) = 'string' and (v_response#>>'{}') ~ '^\s*-?\d+\s*$'
            then trim(v_response#>>'{}')::numeric
        end;
        v_is_correct := v_correct_num is not null and v_user_num is not null
          and trunc(v_user_num) = trunc(v_correct_num);
        v_score := case when v_is_correct then 1 else 0 end;

      when 'multi_select' then
        select coalesce(array_agg(distinct trunc(e::text::numeric)::integer), '{}')
          into v_correct_set
        from jsonb_array_elements(
          case when jsonb_typeof(v_spec->'correct_indices') = 'array'
            then v_spec->'correct_indices' else '[]'::jsonb end) e
        where jsonb_typeof(e) = 'number';

        select coalesce(array_agg(distinct trunc(e::text::numeric)::integer), '{}')
          into v_user_set
        from jsonb_array_elements(
          case when jsonb_typeof(v_response) = 'array'
            then v_response else jsonb_build_array(v_response) end) e
        where jsonb_typeof(e) = 'number';

        v_mode := coalesce(v_spec->>'scoring_method', v_spec->>'mode', 'all_or_nothing');
        v_total := coalesce(array_length(v_correct_set, 1), 0);

        if v_mode = 'partial_credit' and v_total > 0 then
          select count(*) filter (where u = any (v_correct_set)),
                 count(*) filter (where not (u = any (v_correct_set)))
            into v_hit, v_miss
          from unnest(v_user_set) u;
          v_score := greatest(0, least(1, (v_hit - v_miss)::numeric / v_total));
          v_is_correct := v_score >= 0.999;
          v_is_partial := v_score > 0 and not v_is_correct;
        else
          v_is_correct := v_total > 0
            and coalesce(array_length(v_user_set, 1), 0) = v_total
            and v_user_set <@ v_correct_set;
          v_score := case when v_is_correct then 1 else 0 end;
        end if;

      when 'ordered_response' then
        select coalesce(array_agg(
                 case when jsonb_typeof(e) = 'string' then e#>>'{}' else e::text end
                 order by ord), '{}')
          into v_items
        from jsonb_array_elements(
          case when jsonb_typeof(v_item.response_spec->'items') = 'array'
            then v_item.response_spec->'items' else '[]'::jsonb end)
          with ordinality as t(e, ord);

        select coalesce(array_agg(trunc(e::text::numeric)::integer order by ord), '{}')
          into v_order
        from jsonb_array_elements(
          case when jsonb_typeof(v_spec->'correct_order') = 'array'
            then v_spec->'correct_order' else '[]'::jsonb end)
          with ordinality as t(e, ord)
        where jsonb_typeof(e) = 'number';

        v_total := coalesce(array_length(v_items, 1), 0);
        if v_total > 0
           and coalesce(array_length(v_order, 1), 0) = v_total
           and not exists (select 1 from unnest(v_order) i where i < 0 or i >= v_total) then
          select array_agg(v_items[i + 1] order by ord) into v_expected
          from unnest(v_order) with ordinality as t(i, ord);

          select coalesce(array_agg(
                   case when jsonb_typeof(e) = 'string' then e#>>'{}' else e::text end
                   order by ord), '{}')
            into v_user_order
          from jsonb_array_elements(
            case when jsonb_typeof(v_response) = 'array' then v_response else '[]'::jsonb end)
            with ordinality as t(e, ord);

          v_is_correct := v_user_order = v_expected;
        end if;
        v_score := case when v_is_correct then 1 else 0 end;

      when 'matching' then
        v_pairs := case when jsonb_typeof(v_spec->'correct_pairs') = 'object'
          then v_spec->'correct_pairs' else '{}'::jsonb end;
        v_user_pairs := case when jsonb_typeof(v_response) = 'object'
          then v_response else '{}'::jsonb end;

        select count(*) into v_total from jsonb_object_keys(v_pairs);
        if v_total > 0 then
          select count(*) into v_matched
          from jsonb_each(v_pairs) c
          where exists (
            select 1 from jsonb_each(v_user_pairs) u
            where trim(u.key) = trim(c.key)
              and trim(case when jsonb_typeof(u.value) = 'string' then u.value#>>'{}' else u.value::text end)
                = trim(case when jsonb_typeof(c.value) = 'string' then c.value#>>'{}' else c.value::text end)
          );
          v_score := v_matched::numeric / v_total;
          v_is_correct := v_score >= 0.999;
          v_is_partial := v_score > 0 and not v_is_correct;
        end if;

      when 'numeric_entry' then
        -- A single number. Accepts a JSON number or a string holding a plain
        -- decimal or correctly grouped thousands ("1,200"); anything else,
        -- such as "0,6", is not a number and is graded incorrect, never
        -- reinterpreted. Correct within the item's tolerance (default 0).
        v_correct_num := case
          when jsonb_typeof(v_spec->'correct_value') = 'number' then (v_spec->>'correct_value')::numeric
        end;
        v_mode := replace(trim(coalesce(v_response#>>'{}', '')), chr(8722), '-');
        v_user_num := case
          when jsonb_typeof(v_response) = 'number' then (v_response#>>'{}')::numeric
          when jsonb_typeof(v_response) = 'string' and v_mode ~ '^[+-]?(\d+(\.\d+)?|\.\d+)$'
            then v_mode::numeric
          when jsonb_typeof(v_response) = 'string' and v_mode ~ '^[+-]?\d{1,3}(,\d{3})+(\.\d+)?$'
            then replace(v_mode, ',', '')::numeric
        end;
        v_is_correct := v_correct_num is not null and v_user_num is not null
          and abs(v_user_num - v_correct_num) <= greatest(coalesce(case
                when jsonb_typeof(v_spec->'tolerance') = 'number' then (v_spec->>'tolerance')::numeric
              end, 0), 0);
        v_score := case when v_is_correct then 1 else 0 end;

      else
        v_supported := false;
    end case;

    if not v_supported then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id, 'error', 'unsupported_interaction_type',
        'is_correct', false, 'is_partial', false, 'score', 0));
      continue;
    end if;

    v_results := v_results || jsonb_build_array(jsonb_build_object(
      'item_id', v_item_id,
      'is_correct', v_is_correct,
      'is_partial', v_is_partial,
      'score', round(v_score, 4),
      'scoring_spec', v_spec,
      'explanation', v_item.explanation
    ));
  end loop;

  return v_results;
end;
$$;

comment on function public.grade_assessment_items(jsonb) is
  'Grades [{item_id, response}] for visible, non-protected assessment items and returns the grade with scoring_spec and explanation only for answered items. Strictly blocks protected simulation items.';

revoke all on function public.grade_assessment_items(jsonb) from public;
grant execute on function public.grade_assessment_items(jsonb) to anon, authenticated, service_role;
