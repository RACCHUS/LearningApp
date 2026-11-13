-- Columns present in production must exist in a migration-built database.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

select has_column('public', 'terms', 'order_index', 'terms.order_index exists');
select col_type_is('public', 'terms', 'order_index', 'integer', 'terms.order_index is integer');
select has_column('public', 'concepts', 'order_index', 'concepts.order_index exists');
select col_type_is('public', 'concepts', 'order_index', 'integer', 'concepts.order_index is integer');
select has_column('public', 'questions', 'order_index', 'questions.order_index exists');
select col_default_is('public', 'questions', 'order_index', '0', 'questions.order_index defaults to 0');
select has_column('public', 'lessons', 'content', 'lessons.content exists');
select col_type_is('public', 'lessons', 'content', 'jsonb', 'lessons.content is jsonb');

select * from finish();
rollback;
