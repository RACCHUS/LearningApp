# Internal Taxonomy Completion Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to implement and review these tasks.

**Goal:** Continue the interrupted Antigravity taxonomy audit by completing the already specified CIP 2020 internal field hierarchy and making it browsable.

**Architecture:** Reuse the imported external CIP graph and existing exact field mappings. Add permanent internal UUIDs for unmapped groups and programs, with internal parent links. Keep cluster membership at broad roots and load children on demand.

**Tech Stack:** PostgreSQL/Supabase, Dart/Flutter/Riverpod, pgTAP.

**Spec:** CANONICAL_TAXONOMY_ARCHITECTURE.md sections 3.2 and 10.2 (Phase 2). The user's request to resume this work authorizes completing this existing design.

## Global constraints

- Migrations are append-only; preserve existing internal UUIDs and user content.
- Bootstrap CIP 2020 only. Future editions require explicit mapping review, never automatic duplication.
- No invented courses, credentials, legal requirements, demand, or source approval.
- Anonymous/authenticated clients cannot bootstrap; use an invoker function restricted to service_role.
- Preserve Learn/Library/Progress navigation and accessible Help.

## Tasks

- [x] Database: add a transactional, idempotent bootstrap function and append-only backfill migration. Validate parent hierarchy and ambiguous mappings. Reuse mapped UUIDs, never merge on title. Test idempotency, parentage, duplicate titles, source-edition isolation, preserved existing data and client denial. — `supabase/migrations/20261015000000_cip_internal_field_bootstrap.sql`, `supabase/tests/cip_internal_field_bootstrap_test.sql`.
- [x] Discovery: add parent-scoped canonical field fetching/provider and lazy hierarchy browsing in taxonomy explorer. Test broad -> subfield -> program traversal and bounded queries. — `getChildFields` (200-row pages + truncation flag), `childFieldsProvider`, `FieldHierarchyTile`; unscoped `getFields()` now returns roots only.
- [x] Operations: invoke bootstrap after official imports; report internal coverage separately with strict hierarchy checks; reconcile roadmap and provide a safe deployment/verification runbook.
- [ ] Verification: targeted Flutter tests, full `flutter analyze` and the pgTAP suite (30/30, run on embedded PostgreSQL 2026-10-15 with a schema replica and a hosted-scale 48/466/2,295 fixture) pass. Still required: `supabase db reset` + `supabase test db` on the real stack (local Docker was unavailable) and hosted deployment, which has **not** been done.

## Review focus

Repeated names must not merge unrelated fields; reruns must retain IDs; broken or ambiguous parents must fail closed; large trees must not become flat unbounded lists; external coverage alone must not imply internal or catalog completion.

## Scope still outstanding

Native literacy/life-skills ontology and concept links, ISCED-F, occupation/industry links, K-12 standards, broader credentials/providers and original learning content remain separate workstreams. This slice completes the CIP-backed hierarchy, not the entire taxonomy.
