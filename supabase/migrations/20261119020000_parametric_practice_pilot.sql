-- Parametric practice pilot (master plan v2.6 §6.6, C09, A19, §15.0
-- `content.parametric_practice`): zero-AI practice items made from
-- reviewed templates, generated and scored on the server.
--
-- * New gate `content.parametric_practice`, default OFF, not release-ready.
-- * Families live in `private` (no client access): an allowlisted template,
--   reviewed variable ranges and constraints, and a prompt pattern. No
--   arbitrary formula or model-authored code is ever executed.
-- * parametric_next_item() picks variables within the constraints, computes
--   the answer in SQL and returns ONLY an instance id and the prompt. The
--   answer stays server-side until the learner has answered (key isolation).
-- * Exposure: an unanswered item is returned again rather than a new one;
--   variables are not repeated within a learner's last 20 items of a
--   family; at most 100 new items per learner per day.
-- * parametric_submit() parses strictly and compares exactly (after the
--   family's rounding). The first answer is final for the record. It is
--   practice only: no mastery, readiness or completion is written.
-- * Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.parametric_practice', 'Parametric practice (new numbers)', 'Content', 'release', false, 'experimental', false,
  'Server-generated, server-scored practice from reviewed templates; answers never sent before answering')
ON CONFLICT (feature_key) DO NOTHING;

create table if not exists private.parametric_families (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9-]{1,63}$'),
  concept_id text not null check (concept_id ~ '^[a-z0-9][a-z0-9-]{1,63}$'),
  title text not null check (char_length(title) between 3 and 120),
  template text not null
    check (template in ('percent_change', 'fraction_to_decimal')),
  -- Per variable: {"choices":[...]} or {"min":a,"max":b,"step":s}.
  variables jsonb not null,
  -- Optional: {"integer_result":true,"max_abs_result":n,"distinct":["a","b"],
  --            "less_than":["numerator","denominator"]}
  constraints jsonb not null default '{}'::jsonb,
  round_to integer check (round_to is null or round_to between 0 and 6),
  prompt text not null check (char_length(prompt) between 10 and 400),
  accepts_percent_sign boolean not null default false,
  version integer not null default 1,
  active boolean not null default false,
  reviewed_note text
);

create table if not exists private.parametric_instances (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references private.parametric_families(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  variables jsonb not null,
  answer numeric not null,
  created_at timestamptz not null default now(),
  answered_at timestamptz,
  first_correct boolean
);

create index if not exists parametric_instances_user_family
  on private.parametric_instances (user_id, family_id, created_at desc);

revoke all on table private.parametric_families from public, anon, authenticated;
revoke all on table private.parametric_instances from public, anon, authenticated;

-- Seed: two reviewed families tied to the Bridge concepts. Both give exact
-- (terminating) results, so no rounding is needed.
insert into private.parametric_families
  (id, concept_id, title, template, variables, constraints, round_to, prompt,
   accepts_percent_sign, version, active, reviewed_note)
values
 ('pc-whole-percent', 'percent-change', 'Percent change with whole-number answers',
  'percent_change',
  '{"original":{"min":20,"max":400,"step":10},"new":{"min":10,"max":600,"step":5}}',
  '{"integer_result":true,"max_abs_result":200,"distinct":["original","new"]}',
  null,
  'A price changed from ${original} to ${new}. What is the percent change? Use a minus sign for a decrease.',
  true, 1, true,
  'Answer = (new - original) / original * 100, computed in SQL; whole-number results only.'),
 ('fd-terminating', 'fraction-decimal-percent', 'Fractions to decimals (exact)',
  'fraction_to_decimal',
  '{"numerator":{"min":1,"max":24,"step":1},"denominator":{"choices":[2,4,5,8,10,16,20,25,40,50]}}',
  '{"less_than":["numerator","denominator"]}',
  null,
  'Write {numerator}/{denominator} as a decimal.',
  false, 1, true,
  'Denominators have only 2 and 5 as prime factors, so every answer terminates.')
on conflict (id) do nothing;

-- Picks one value for a variable spec.
create or replace function private.parametric_pick(p_spec jsonb)
returns numeric
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_n integer;
begin
  if p_spec ? 'choices' then
    v_n := jsonb_array_length(p_spec->'choices');
    return (p_spec->'choices'->>(floor(random() * v_n))::integer)::numeric;
  end if;
  return (p_spec->>'min')::numeric
       + (p_spec->>'step')::numeric
       * floor(random() * (floor(((p_spec->>'max')::numeric - (p_spec->>'min')::numeric)
                                 / (p_spec->>'step')::numeric) + 1));
end;
$$;

-- The allowlisted templates. Returns null when the inputs are invalid.
create or replace function private.parametric_compute(
  p_template text,
  p_vars jsonb,
  p_round_to integer
)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v numeric;
begin
  if p_template = 'percent_change' then
    if (p_vars->>'original')::numeric = 0 then return null; end if;
    v := ((p_vars->>'new')::numeric - (p_vars->>'original')::numeric)
         / (p_vars->>'original')::numeric * 100;
  elsif p_template = 'fraction_to_decimal' then
    if (p_vars->>'denominator')::numeric = 0 then return null; end if;
    v := (p_vars->>'numerator')::numeric / (p_vars->>'denominator')::numeric;
  else
    return null;
  end if;
  return case when p_round_to is null then trim_scale(v) else round(v, p_round_to) end;
end;
$$;

-- Strict learner input: digits with optional sign, decimal point, proper
-- thousands grouping and (when allowed) a trailing %. Null when unreadable.
create or replace function private.parametric_parse(p_input text, p_percent boolean)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  s text := btrim(replace(coalesce(p_input, ''), '−', '-'));
begin
  if p_percent and right(s, 1) = '%' then s := btrim(left(s, -1)); end if;
  if left(s, 1) = '+' then s := substr(s, 2); end if;
  if position(',' in s) > 0 then
    if s !~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$' then return null; end if;
    s := replace(s, ',', '');
  end if;
  if s !~ '^-?[0-9]+(\.[0-9]+)?$' or char_length(s) > 30 then return null; end if;
  return s::numeric;
end;
$$;

revoke all on function private.parametric_pick(jsonb) from public, anon, authenticated;
revoke all on function private.parametric_compute(text, jsonb, integer) from public, anon, authenticated;
revoke all on function private.parametric_parse(text, boolean) from public, anon, authenticated;

-- Active families for a concept (titles only).
create or replace function public.parametric_families_for(p_concept_id text)
returns table (id text, title text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.parametric_practice') then
    return;
  end if;
  return query
    select f.id, f.title from private.parametric_families f
     where f.active and f.concept_id = p_concept_id
     order by f.id;
end;
$$;

revoke all on function public.parametric_families_for(text) from public, anon;
grant execute on function public.parametric_families_for(text) to authenticated;

-- Returns the caller's pending item for the family, or a new one. Never
-- returns the answer.
create or replace function public.parametric_next_item(p_family_id text)
returns table (instance_id uuid, prompt text, accepts_percent_sign boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  f private.parametric_families%rowtype;
  v_pending private.parametric_instances%rowtype;
  v_vars jsonb;
  v_answer numeric;
  v_key text;
  v_ok boolean;
  v_today integer;
  v_try integer := 0;
  v_text text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.parametric_practice') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into f from private.parametric_families where id = p_family_id and active;
  if not found then
    raise exception 'family_not_found' using errcode = 'P0002';
  end if;

  select * into v_pending from private.parametric_instances
   where user_id = v_uid and family_id = f.id and answered_at is null
   order by created_at desc limit 1;
  if found then
    v_vars := v_pending.variables;
  else
    select count(*) into v_today from private.parametric_instances
     where user_id = v_uid and created_at > now() - interval '24 hours';
    if v_today >= 100 then
      raise exception 'rate_limited' using errcode = '54000';
    end if;
    loop
      v_try := v_try + 1;
      if v_try > 200 then
        raise exception 'no_variant_available' using errcode = 'P0002';
      end if;
      select jsonb_object_agg(k, private.parametric_pick(f.variables->k))
        into v_vars from jsonb_object_keys(f.variables) k;
      v_answer := private.parametric_compute(f.template, v_vars, f.round_to);
      v_ok := v_answer is not null;
      if v_ok and coalesce((f.constraints->>'integer_result')::boolean, false) then
        v_ok := v_answer = trunc(v_answer);
      end if;
      if v_ok and f.constraints ? 'max_abs_result' then
        v_ok := abs(v_answer) <= (f.constraints->>'max_abs_result')::numeric;
      end if;
      if v_ok and f.constraints ? 'distinct' then
        v_ok := (v_vars->>(f.constraints->'distinct'->>0))::numeric
             <> (v_vars->>(f.constraints->'distinct'->>1))::numeric;
      end if;
      if v_ok and f.constraints ? 'less_than' then
        v_ok := (v_vars->>(f.constraints->'less_than'->>0))::numeric
              < (v_vars->>(f.constraints->'less_than'->>1))::numeric;
      end if;
      -- Exposure: no repeat within the learner's last 20 items here.
      if v_ok then
        v_ok := not exists (
          select 1 from (
            select i.variables from private.parametric_instances i
             where i.user_id = v_uid and i.family_id = f.id
             order by i.created_at desc limit 20
          ) recent where recent.variables = v_vars
        );
      end if;
      exit when v_ok;
    end loop;
    insert into private.parametric_instances (family_id, user_id, variables, answer)
    values (f.id, v_uid, v_vars, v_answer)
    returning * into v_pending;
  end if;

  v_text := f.prompt;
  for v_key in select jsonb_object_keys(v_vars) loop
    v_text := replace(v_text, '{' || v_key || '}',
                      trim_scale((v_vars->>v_key)::numeric)::text);
  end loop;
  return query select v_pending.id, v_text, f.accepts_percent_sign;
end;
$$;

revoke all on function public.parametric_next_item(text) from public, anon;
grant execute on function public.parametric_next_item(text) to authenticated;

-- Scores the caller's answer. The answer is revealed only now. The first
-- answer is recorded; later answers are checked but change nothing.
create or replace function public.parametric_submit(p_instance_id uuid, p_answer text)
returns table (readable boolean, correct boolean, answer text, first_attempt boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  i private.parametric_instances%rowtype;
  f private.parametric_families%rowtype;
  v_given numeric;
  v_correct boolean;
  v_first boolean;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.parametric_practice') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into i from private.parametric_instances
   where id = p_instance_id and user_id = v_uid for update;
  if not found then
    raise exception 'item_not_found' using errcode = 'P0002';
  end if;
  select * into f from private.parametric_families where id = i.family_id;
  v_given := private.parametric_parse(p_answer, f.accepts_percent_sign);
  if v_given is null then
    -- Unreadable input reveals nothing and is not an attempt.
    return query select false, null::boolean, null::text, i.answered_at is null;
    return;
  end if;
  v_correct := v_given = i.answer;
  v_first := i.answered_at is null;
  if v_first then
    update private.parametric_instances
       set answered_at = now(), first_correct = v_correct
     where id = i.id;
  end if;
  return query select true, v_correct, trim_scale(i.answer)::text, v_first;
end;
$$;

revoke all on function public.parametric_submit(uuid, text) from public, anon;
grant execute on function public.parametric_submit(uuid, text) to authenticated;
