begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

select has_table('public', 'word_lists', 'word_lists exists');
select has_table('public', 'word_list_entries', 'word_list_entries exists');
select has_column('public', 'word_lists', 'user_id', 'list ownership is explicit');
select has_column('public', 'word_list_entries', 'form_key', 'stable form identity exists');
select has_column('public', 'word_lists', 'import_origin', 'retry-safe guest import provenance');
select has_column('public', 'word_list_entries', 'accepted_forms', 'explicit accepted variants supported');
select has_column('public', 'word_list_entries', 'meaning', 'private optional meaning is stored');
select has_column('public', 'review_items', 'metadata', 'review metadata serializer has a column');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.word_lists'::regclass),
  'lists have RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.word_list_entries'::regclass),
  'entries have RLS enabled'
);
select ok(
  (select count(*) > 0 from pg_policies
   where schemaname = 'public' and tablename = 'word_lists'
     and policyname = 'word_lists_owner_only'),
  'list owner policy exists'
);
select ok(
  (select count(*) > 0 from pg_policies
   where schemaname = 'public' and tablename = 'word_list_entries'
     and policyname = 'word_list_entries_owner_only'),
  'entry owner policy exists'
);

select * from finish();
rollback;
