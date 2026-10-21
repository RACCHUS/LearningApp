begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(33);
select has_function('public','exam_reference_drill_export_inventory',
 array[]::text[],'Owner all-edition inventory RPC exists');
select has_function('public','exam_reference_drill_export_page',
 array['integer','timestamptz','uuid'],'Keyset export-page RPC exists');
select ok(not has_function_privilege('anon',
 'public.exam_reference_drill_export_inventory()','EXECUTE'),
 'No unsigned export inventory');
select ok(not has_function_privilege('anon',
 'public.exam_reference_drill_export_page(integer,timestamptz,uuid)','EXECUTE'),
 'No unsigned export pages');
select ok(has_function_privilege('authenticated',
 'public.exam_reference_drill_export_inventory()','EXECUTE'),
 'Authenticated owner can request exact inventory');
select is((select prosecdef from pg_proc where oid=
 'public.exam_reference_drill_export_page(integer,timestamptz,uuid)'::regprocedure),
 false,'Page function is SECURITY INVOKER');
select is((select prosecdef from pg_proc where oid=
 'public.exam_reference_drill_export_inventory()'::regprocedure),
 false,'Inventory is SECURITY INVOKER');
select ok(not has_table_privilege('authenticated',
 'public.exam_reference_drill_scoring_keys','SELECT'),
 'No private rubric read permission gained');
insert into auth.users (id,email) values
 ('b3000000-0000-4000-8000-000000000001','exm03-a@example.invalid'),
 ('b3000000-0000-4000-8000-000000000002','exm03-b@example.invalid'),
 ('b3000000-0000-4000-8000-000000000003',null)
on conflict(id) do nothing;

insert into public.learning_targets
  (id,target_type,title,slug,status,is_public,is_official)
values ('b3000000-0000-4000-8000-000000000011','licensure_exam',
  'EXM02B Scoring Synthetic','exm02b-scoring-private-fixture',
  'published',true,false);
insert into public.target_versions
 (id,target_id,version_code,status,metadata)
values ('b3000000-0000-4000-8000-000000000012',
 'b3000000-0000-4000-8000-000000000011','fictional-v1','published',
 '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Fake PM","curriculum_root_node_id":"b3000000-0000-4000-8000-000000000013"}]}}'::jsonb);
insert into public.curriculum_nodes
 (id,target_version_id,node_type,title,sort_order)
values ('b3000000-0000-4000-8000-000000000013',
 'b3000000-0000-4000-8000-000000000012','domain','Fake chapter',1);
insert into public.content_source_releases
 (id,publisher,title,version,source_url)
values
 ('b3000000-0000-4000-8000-000000000014','Fictional','Fake list',
  'fictional-2027','https://example.gov/scoring-fixture-list.pdf'),
 ('b3000000-0000-4000-8000-000000000015','Fictional','Fake book',
  '2027-book','https://example.org/scoring-fixture-book.pdf');

insert into public.exam_reference_manifest_revisions(
 id,target_version_id,exam_part_key,revision,effective_from,effective_until,
 source_release_id,official_source_url,source_checked_at,author_ref,
 reviewer_ref,reviewed_at,review_status,publication_status,reference_entries
) values (
 'b3000000-0000-4000-8000-000000000016',
 'b3000000-0000-4000-8000-000000000012','project_management',1,
 '2027-01-01','2027-12-31',
 'b3000000-0000-4000-8000-000000000014',
 'https://example.gov/scoring-fixture-list.pdf',now()-interval '2 days',
 'fictional-author','fictional-reviewer',now()-interval '1 day',
 'approved','published',
 '[{"key":"example_book","edition":"2027-book","source_page":"2"}]'::jsonb
);
insert into public.assessment_items(
 id,origin_target_version_id,interaction_type,prompt,response_spec,scoring_spec
) values (
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000012',
 'single_choice','Fictional independent review item',
 '{"options":["A","B"]}'::jsonb,'{"correct_index":0}'::jsonb
);
insert into public.assessment_item_reference_validity(
 id,assessment_item_id,manifest_revision_id,
 item_content_revision,item_content_sha256,answer_location_revision,
 reference_edition_key,reference_edition,source_release_id,
 expected_locations,author_ref,ai_drafted,reviewer_ref,
 reviewer_qualification_evidence,reviewer_edition_access_evidence,
 rights_review_status,review_status,reviewed_at,review_minutes,
 publication_status
) values (
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000016',
 1,public.exam_reference_item_fingerprint('b3000000-0000-4000-8000-000000000017'),1,
 'example_book','2027-book','b3000000-0000-4000-8000-000000000015',
 '[{"section":"1.1","source_page":"11"}]'::jsonb,
 'fixture-author',true,'independent-qualified-human',
 'fictional qualified reviewer','fictional 2027 book in hand',
 'approved','approved',now(),12,'published'
);

-- An editorial rubric is a second independently approved entity.
insert into public.exam_reference_drill_scoring_keys (
 id,approved_binding_id,scoring_version,step_tokens,author_ref,
 ai_drafted,publication_status
) values (
 'b3000000-0000-4000-8000-000000000019',
 'b3000000-0000-4000-8000-000000000018',1,
 '{"resource_choice":["example_book"],"section_location":["1.1"],"interpretation":["yes"],"application":["b"]}'::jsonb,
 'fixture-author',true,'draft'
);
select throws_ok($q$
 update public.exam_reference_drill_scoring_keys
 set publication_status='published'
 where id='b3000000-0000-4000-8000-000000000019'
$q$, 'P0001',null,
 'Cannot publish scoring answer keys without independent reviewer signoff');
select lives_ok($q$
 update public.exam_reference_drill_scoring_keys set
  reviewer_ref='independent-score-reviewer',
  reviewer_qualification_evidence='fictional subject reviewer',
  reviewer_edition_access_evidence='fictional 2027 book in hand',
  rights_review_status='approved',review_status='approved',
  reviewed_at=now(),review_minutes=9,
  publication_status='published'
 where id='b3000000-0000-4000-8000-000000000019'
$q$, 'Independently approved scoring rubric can be published');
select throws_ok($q$
 update public.exam_reference_drill_scoring_keys
 set step_tokens='{"resource_choice":["wrong"],"section_location":["1.1"],"interpretation":["yes"],"application":["b"]}'::jsonb
 where id='b3000000-0000-4000-8000-000000000019'
$q$, 'P0001',null,'Published scoring answer keys cannot be changed');









set local role authenticated;
do $jwt$ begin
 perform set_config('request.jwt.claim.sub','b3000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;
select is((public.exam_reference_drill_export_inventory()->>'record_count')::int,0,
 'Owner empty inventory is exact');
select is((public.exam_reference_drill_export_page()->>'row_count')::int,0,
 'Owner empty export page is exact');
select throws_ok($q$select public.exam_reference_drill_export_page(251)$q$,
 '22023',null,'Page over 250 rejected');
select throws_ok($q$select public.exam_reference_drill_export_page(0)$q$,
 '22023',null,'Page size zero rejected');
select throws_ok($q$select public.exam_reference_drill_export_page(
 25,now(),null)$q$,'22023',null,'Partial cursor cannot be supplied');

-- Two large sets of 2,501 events test the actual >5,000 boundary.
insert into public.exam_reference_drill_events(
 id,client_attempt_id,assessment_item_id,approved_binding_id,
 manifest_revision_id,exam_part_key,administration_date,
 item_content_revision,answer_location_revision,drill_step,responded,
 app_elapsed_ms,started_at,completed_at
)
select
 ('e0000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('f0000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'b3000000-0000-4000-8000-000000000017'::uuid,
 'b3000000-0000-4000-8000-000000000018'::uuid,
 'b3000000-0000-4000-8000-000000000016'::uuid,
 'project_management','2027-07-01'::date,1,1,'resource_choice',true,
 900,now()-interval '2 seconds',now()
from generate_series(1,5001) n;
select is((public.exam_reference_drill_export_inventory()->>'record_count')::int,
 5001,'Owner can now export past the previous 5000-step bound');
select is((public.exam_reference_drill_export_page(250)->>'row_count')::int,
 250,'Page returns no more than the requested 250');
select is(jsonb_array_length(public.exam_reference_drill_export_page(250)->'rows'),
 250,'JSON projection has exact bounded page count');
select ok(not (public.exam_reference_drill_export_page(1)->'rows'->0 ?
 'scoring_spec'),'No answer key in page payload');
select ok(not (public.exam_reference_drill_export_page(1)->'rows'->0 ?
 'step_tokens'),'No protected reviewer tokens in page payload');
select ok(not (public.exam_reference_drill_export_page(1)->'rows'->0 ?
 'reviewer_ref'),'No reviewer identity exposed');

create temp table exm_first_page on commit drop as
 select public.exam_reference_drill_export_page(250) as payload;
create temp table exm_first_last on commit drop as
 select (payload->'rows'->249->>'recorded_at')::timestamptz as at,
        (payload->'rows'->249->>'event_id')::uuid as event_id
 from exm_first_page;
select is((
 select (public.exam_reference_drill_export_page(
  250,(select at from exm_first_last),
  (select event_id from exm_first_last))->>'row_count')::int
 ),250,'Second keyset page follows first cursor exactly');
select is((
 select count(*)::int from
   jsonb_array_elements((select payload->'rows' from exm_first_page)) j
 where j->>'event_id'=(
  select jsonb_array_elements(
   public.exam_reference_drill_export_page(
    250,(select at from exm_first_last),
    (select event_id from exm_first_last))->'rows'
  )->>'event_id'
  limit 1
  )
 ),0,'Different pages never repeat their boundary event');
create temp table exm_inventory_pre on commit drop as
 select public.exam_reference_drill_export_inventory() as body;
select is(public.exam_reference_drill_export_inventory()->>'record_fingerprint',
 (select body->>'record_fingerprint' from exm_inventory_pre),
 'Unmodified inventory digest remains stable across calls');
select is((select is_correct from public.score_exam_reference_drill_step(
 'e0000000-0000-4000-8000-000000000001','example_book')),true,
 'Private grade can be computed after the first inventory');
select isnt(public.exam_reference_drill_export_inventory()->>'record_fingerprint',
 (select body->>'record_fingerprint' from exm_inventory_pre),
 'New immutable grade receipt changes postflight digest');
select is((public.exam_reference_drill_export_inventory()->>'record_count')::int,
 5001,'Grading changed fingerprint without changing step count');

-- Retired editions are still privately exportable.
reset role;
update public.exam_reference_manifest_revisions
 set publication_status='retired'
 where id='b3000000-0000-4000-8000-000000000016';
set local role authenticated;
select is((public.exam_reference_drill_export_inventory()->>'record_count')::int,
 5001,'Retired manifest events remain in historical inventory');
do $jwt$ begin
 perform set_config('request.jwt.claim.sub','b3000000-0000-4000-8000-000000000002',true);
end $jwt$;
select is((public.exam_reference_drill_export_inventory()->>'record_count')::int,
 0,'Other account sees no owner inventory');
select is((public.exam_reference_drill_export_page(250)->>'row_count')::int,0,
 'Other account reads zero page rows');
do $jwt$ begin
 perform set_config('request.jwt.claim.sub','b3000000-0000-4000-8000-000000000003',true);
 perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
end $jwt$;
select throws_ok($q$select public.exam_reference_drill_export_inventory()$q$,
 '42501',null,'Authenticated-role anonymous guest denied inventory');
select throws_ok($q$select public.exam_reference_drill_export_page()$q$,
 '42501',null,'Authenticated-role anonymous guest denied pages');
reset role;
select * from finish();
rollback;
