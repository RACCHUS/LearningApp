begin;
select plan(3);

select has_index(
  'public', 'learning_targets', 'learning_targets_title_trgm_idx',
  'Learning target substring search has a trigram index'
);
select has_index(
  'public', 'knowledge_concepts', 'knowledge_concepts_name_trgm_idx',
  'Knowledge concept substring search has a trigram index'
);
select has_index(
  'public', 'courses', 'courses_title_trgm_idx',
  'Course substring search has a trigram index'
);

select * from finish();
rollback;
