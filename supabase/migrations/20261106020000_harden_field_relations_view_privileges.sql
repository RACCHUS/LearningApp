-- Harden the public taxonomy relation view without removing its intended read API.
-- The hosted project already has security_invoker=true from 20261019000000.
-- Reassert it here and make the view's API privileges explicitly read-only.

alter view public.v_field_relations_bidirectional
  set (security_invoker = true);

revoke all privileges on table public.v_field_relations_bidirectional
  from public, anon, authenticated, service_role;

-- Taxonomy relationships are intentionally public and are read by anonymous
-- and signed-in learners through TaxonomyCrosswalkService.
grant select on table public.v_field_relations_bidirectional
  to anon, authenticated, service_role;
