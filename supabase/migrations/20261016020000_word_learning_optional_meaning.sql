-- W1: Optional learner-authored gloss; not a canonical dictionary sense.
-- Do not infer meaning mastery or vocabulary evidence from this private note.
alter table public.word_list_entries
  add column if not exists meaning text
    check (meaning is null or length(trim(meaning)) <= 2000);
