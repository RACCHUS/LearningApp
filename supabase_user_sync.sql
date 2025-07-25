-- Trigger function to insert into public.users after signup in auth.users
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, created_at)
  values (new.id, new.email, new.created_at)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql;

-- Trigger on auth.users to call the function after insert
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
