-- pgTAP owner/guest isolation regression. The transaction is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

-- Synthetic accounts; Supabase anonymous sessions use role authenticated.
insert into auth.users (id, email) values
 ('8f7c1a10-0000-4000-8000-000000000001','word-owner@example.invalid'),
 ('8f7c1a10-0000-4000-8000-000000000002','word-other@example.invalid'),
 ('8f7c1a10-0000-4000-8000-000000000003',null)
on conflict (id) do nothing;

insert into public.word_lists(id,user_id,title,import_origin) values
 ('8f7c1a10-0000-4000-8000-000000000101',
  '8f7c1a10-0000-4000-8000-000000000001',
  'Private insurance words', 'guest-identity:a')
on conflict (id) do nothing;
insert into public.word_list_entries(id,list_id,word,form_key) values
 ('8f7c1a10-0000-4000-8000-000000000201',
  '8f7c1a10-0000-4000-8000-000000000101',
  'liability', 'v1:en-US:ordinary:ignore_case:bGlhYmlsaXR5')
on conflict (id) do nothing;
insert into public.review_items(
 user_id, content_id, content_type, lesson_id, title
) values (
 '8f7c1a10-0000-4000-8000-000000000001',
 'word:v1:en-US:ordinary:ignore_case:bGlhYmlsaXR5:spelling',
 'word_skill',null,'liability'
) on conflict (user_id,content_id) do nothing;

set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub',
    '8f7c1a10-0000-4000-8000-000000000001',true);
end $$;

select is((select count(*)::integer from public.word_lists
 where title='Private insurance words'),1,'Owner can read own list');
select is((select count(*)::integer from public.word_list_entries
 where word='liability'),1,'Owner can read own entries');

do $$ begin
  perform set_config('request.jwt.claim.sub',
    '8f7c1a10-0000-4000-8000-000000000002',true);
end $$;

select is((select count(*)::integer from public.word_lists
 where title='Private insurance words'),0,'Other account cannot read owner list');
select is((select count(*)::integer from public.word_list_entries
 where word='liability'),0,'Other account cannot read owner entry');
with deleted as (
 delete from public.word_lists
 where id='8f7c1a10-0000-4000-8000-000000000101'
 returning id
) select is((select count(*)::integer from deleted),0,
 'Other account cannot delete owner list');

-- Guest has a distinct auth UID but the same authenticated DB role.
do $$ begin
  perform set_config('request.jwt.claim.sub',
    '8f7c1a10-0000-4000-8000-000000000003',true);
  perform set_config('request.jwt.claims',
    '{"is_anonymous":true}',true);
end $$;

insert into public.word_lists (id,user_id,title) values
 ('8f7c1a10-0000-4000-8000-000000000103',
  '8f7c1a10-0000-4000-8000-000000000003',
  'Guest words');
select is((select count(*)::integer from public.word_lists
 where title='Guest words'),1,'Supabase authenticated guest can create list');
select is((select count(*)::integer from public.word_lists
 where title='Private insurance words'),0,'Guest cannot read other accounts');

do $$ begin
  perform set_config('request.jwt.claim.sub',
    '8f7c1a10-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims',
    '{"is_anonymous":false}',true);
end $$;

delete from public.word_lists
 where id='8f7c1a10-0000-4000-8000-000000000101';
select is((select count(*)::integer from public.word_lists
 where id='8f7c1a10-0000-4000-8000-000000000101'),0,
 'Owner can delete own list');
select is((select count(*)::integer from public.word_list_entries
 where id='8f7c1a10-0000-4000-8000-000000000201'),0,
 'List deletion cascades only its entries');
select is((select count(*)::integer from public.review_items
 where content_id='word:v1:en-US:ordinary:ignore_case:bGlhYmlsaXR5:spelling'),1,
 'Deleting list preserves shared spelling review history');

reset role;
select * from finish();
rollback;
