# Catalog Population and Coverage Plan — Phase H

**Status:** Phase H0 in progress (source registry + read-only coverage CLI). Other phases are proposals, not deployed capabilities.  
**As of:** 2026-10-11  
**Owner:** LearningApp taxonomy/catalog  
**Authoritative references:** [Learning Architecture V2](../../LEARNING_ARCHITECTURE_V2.md), [Canonical Taxonomy Architecture](../../CANONICAL_TAXONOMY_ARCHITECTURE.md), [Official Taxonomy Data Ingestion](OFFICIAL_DATA_INGESTION.md), [Hosted Migration Rollout](../HOSTED_MIGRATION_ROLLOUT.md)

## 1. Product outcome and non-goals

A learner must be able to discover a real-world **destination** (career, degree/program, certification, exam, curriculum standard, or personal goal), see what is known and unknown about reaching it, compare **verified alternative pathways** where documented, and begin learning **even if no LearningApp course exists**.

This phase builds the discovery/reference-data layer **before** mass lesson generation. A classification, an educational program, a credential, a licensing requirement, a course, and a learning target are **different entities**, with source-backed relationships. No AI model, import script, or community editor may infer a legal requirement from a CIP–SOC crosswalk.

Non-goals: scrape prohibited material; invent missing requirements, prices, completion outcomes, or exam questions; treat all occupations as regulated; pretend curriculum completion establishes legal licensure; automatically publish newly discovered changes to existing reviewed requirements.

## 2. What is present today versus unverified

| Layer | Repository evidence | Release/production unknown |
| --- | --- | --- |
| US classifications | `tool/ingest_official_taxonomies.dart`; pinned NCES CIP 2020, BLS SOC 2018, O*NET 31.0; crosswalk validation | Whether full import ran against hosted Supabase; actual row coverage and completeness |
| Seed examples | `20260929000002_seed_canonical_taxonomy_full.sql`; `tool/seed_taxonomy.dart` | Not representative of national coverage |
| Formal targets | `learning_targets`, `target_versions`, `curriculum_nodes` and content provenance | Whether most careers have accurate prerequisites, credentials, requirements or any course |
| Catalog trust | Migration `20261009000005_learning_target_catalog_provenance.sql`; private drafts, moderation | Hosted migration status, official publication workflow, existing provider rights |
| Curriculum | Manifest pipeline and source citation contracts | A complete catalog of exam objectives, curricula or courses |
| Career pathways | CIP–SOC / O*NET links, career explorer UI | Verified geographic licensure rules and alternative route graph |

**Count rule:** Numbers in SQL seeds and mocked tests are *fixtures*, not hosted production counts. No live counts are asserted in this plan. Run `tool/taxonomy_coverage.dart` with authorized credentials before setting a baseline.

## 3. Source acquisition matrix (initial US-first scope)

The machine-readable inventory is [`data/taxonomy/source_registry.json`](../../data/taxonomy/source_registry.json). Status terms mean: `implemented_importer_execution_unverified` (code present, live execution not checked), `discovery_required`, `curation_required`, `blocked_agreement`, `blocked_rights_access`, or `future`.

| Priority | Source and content | Acquisition and update proposal | Rights / validation gate |
| --- | --- | --- | --- |
| P0 | [NCES CIP 2020](https://nces.ed.gov/ipeds/cipcode/) academic classification | Existing pinned download, checksum and idempotent importer; inspect yearly/new official editions | Version lineage; 48 active series and full validated code tree |
| P0 | [BLS SOC 2018](https://www.bls.gov/soc/2018/) occupations | Existing official import and precise per-level release counts; check for later editions | 23 major / 98 minor / 459 broad / 867 detailed; source edition matters |
| P0 | [O*NET 31.0](https://www.onetcenter.org/db_releases.html) occupation extensions, preparation and skills | Existing official importer; version each update independently | 1,016 occupation nodes in pinned 31.0; CC BY 4.0 attribution; career exploration tools have separate licenses |
| P1 | [CareerOneStop licensed occupations](https://www.careeronestop.org/Developers/WebAPI/web-api.aspx) | Request access; API/download discovery; regulator-backed review per state | Source is incomplete across states and may lag; **never** call coverage exhaustive without checking state board |
| P1 | Certification/exam issuers (e.g. [CompTIA](https://www.comptia.org/certifications), [NCSBN NCLEX](https://www.nclex.com/test-plans.page)) | Explicit provider adapters/curated metadata: credential edition, exams, prerequisites, term, blueprint, official links | No protected live exam items/question dumps; changes reviewed; jurisdiction validated separately |
| P1 | [US Dept. of Education College Scorecard](https://collegescorecard.ed.gov/data/api-documentation/) and [NCES IPEDS](https://nces.ed.gov/ipeds/use-the-data) | Official API/bulk imports for institutions and available program attributes; map institutional and CIP IDs | School/program listings are not proof of available seats, eligibility, accreditation or precise prerequisites |
| P2 | [Credential Engine Credential Registry](https://credentialengine.org/develop-solutions/apis/) | Obtain approved account and development agreement; ingest CTDL credentials/pathways only after permission | Participation is not exhaustive; terms/keys must be cleared before caching or commercial reuse |
| P2 | [1EdTech CASE](https://www.1edtech.org/standards/case) + state issuers | Use CASE 1.1 APIs for machine-readable standards where access/reuse is authorized | Specification interoperability **does not** grant rights to every jurisdiction's standards text |
| P3 | [UNESCO ISCED](https://uis.unesco.org/en/topic/international-standard-classification-education-isced) and [EU ESCO](https://esco.ec.europa.eu/en/use-esco/download) | Import as **separate** classification namespaces and languages; no direct overwrite of US codes | Legal permissions and translation/local recognition review; ESCO is not a US licensing rule |

Maintain **source-level owner, canonical URL, dataset/release, retrieval date, checksum, rights approval, official vs issuer/aggregator status, refresh schedule, contact and ingestion run ID**. Every importer must fail closed if its terms or structural checks fail.

The first launch scope is **US destinations**, with **Florida as a high-detail regulatory pilot**, not a hard-coded default everywhere. Expand to other states once templates and verification workflows pass; international data is a later independent release.

## 4. Reference graph, not merely a taxonomy dropdown

Distinct records (or typed nodes) required before broad imports:

- **Occupation** — stable source code, taxonomy edition and regional availability.
- **Program classification** — CIP/ISCED *category* (not an actual university program).
- **Provider / institution** — official identity and provenance; avoid duplicate brand/title keys.
- **Offered program or apprenticeship** — provider + location + modality + time range, verified offering URL, estimated costs where authorized, admissions rules.
- **Credential / certification** — issuer, award level, expiry/renewal status, version and issuing restrictions.
- **Exam** — administering body, edition, objective blueprint, eligibility and retake policy, tied to a credential only when corroborated.
- **Jurisdictional authorization / license** — country/state/regulator, effective date, scope, reciprocity caveats and renewal.
- **Requirements and transitions** — typed `requires`, `one_of`, `equivalent_to`, `qualifies_for`, `recommended_before`, `issued_by`, `offered_by`, `prepares_for`, `maps_to`; with **source evidence** and effective dates.
- **Learning target + target version** — learner-facing destination, connected to records above, without conflating these entities.
- **Learning content** — courses, lessons, concepts and practice assessment items; may be absent without removing a destination.

**Path alternatives:** use explicit AND/OR groups and directed conditions (residency, prior credential, hours, supervised experience). Validate acyclicity where appropriate and distinguish *required* from *recommended*. Keep qualifications and costs country/state-specific. Never convert a *statistical* CIP–SOC mapping into a guaranteed employment or licensing requirement.

**Proposed additive schema after design review:** `catalog_sources`, `catalog_source_snapshots`, `catalog_entities`, `catalog_entity_identifiers`, `catalog_relationships`, `catalog_requirement_groups`, `catalog_change_reviews`, and `catalog_ingestion_runs` or equivalents. Prefer existing provenance/release tables when semantics match. Do not alter old migrations. Finalize keys, indexes, RLS and tenant access *before* introducing the schema.

**Critical RLS/approval invariant:** imports are service-role controlled; public browse sees only approved/published authoritative or moderated items; personal drafts remain private; agent/community submissions cannot self-approve. Snapshot changes cannot silently mutate published `TargetVersion` requirements. Keep user evidence and progress separate from regulatory facts.

## 5. Pipeline contract

```
Register source + verify permitted uses
 -> Fetch immutable upstream snapshot (checksum, published date, retrieval date)
 -> Normalize identifiers, aliases, version and geography
 -> Stage import with validation + duplicate resolution (no public writes)
 -> Structural checks (counts, FK integrity, source mappings, jurisdiction)
 -> Diff against previous source release (add/update/remove, license changes)
 -> Human/issuer review for rights and consequential requirements
 -> Service-role publish to versioned reference graph
 -> Rebuild search index and invalidate affected caches
 -> Revalidate target-version requirements and notify impacted learners
 -> Audit, archive source evidence and provide rollback path
```

Publication rules: no provider's nonpublic data is scraped; no automatic approval of AI output; missing evidence becomes an explicit `unverified` or `unknown` UI state; failed fetch never deletes existing reviewed records. Deletions are marked discontinued and linked to the prior valid release.

## 6. Coverage measurement and operational targets

### Coverage report v0 (included in this PR)

Run:

```bash
dart run tool/taxonomy_coverage.dart --registry-only
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/taxonomy_coverage.dart --json
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/taxonomy_coverage.dart --strict
```

- Offline registry validation has **no network** and does not claim hosted data is populated.
- Live reporting queries real rows in Supabase and distinguishes the exact pinned CIP/SOC/O*NET release counts from raw target/category/content counts.
- `--strict` fails on mismatches in known published structural expectations.
- An anon key is RLS-scoped; use a service role only in a protected operator or CI environment. Never log keys or ship service-role secrets in the PWA.
- Unknown expected counts are shown as **baseline-only**, never replaced by speculative denominators.
- The older `tool/taxonomy_status.dart` is a **seed/hierarchy smoke test**, not the national coverage gate.

### Metrics to add in Phase H1/H2

| Metric | Denominator/definition | Initial gate |
| --- | --- | --- |
| Classification completeness | Per *pinned source release*, loaded codes / official expected count at each level | 100% for published pinned sources |
| Destination discoverability | Public approved/published targets / eligible, deduplicated scoped destinations | Establish independent denominator before target |
| Requirement coverage | Destinations with regulator/issuer-evidenced current requirement set / destinations for which requirements are relevant | Pilot >=90%; capture unknown explicitly |
| Pathway completeness | Destinations with at least one verified feasible step sequence / pilot destinations | Pilot >=80%; demonstrate alternatives |
| Jurisdiction coverage | Verified state-specific regulatory records / in-scope regulated occupation × state pairs | Florida pilot first; no fabricated nationwide estimate |
| Offering coverage | Verified current provider offerings / sampled provider offers in target scope | Baseline + stale-link checks |
| Curricular coverage | Destinations with a usable published curriculum / published destinations | Diagnostic metric, **not** catalog eligibility gate |
| Source freshness | Entries checked within approved TTL / entries requiring periodic review | >=95% current in pilot |
| Evidence coverage | Critical relationships with valid source/version/effective date / all critical relationships | 100% before trusted publication |

**Pilot acceptance example:** “Electrician — Florida” must show verified jurisdiction and responsible licensing authority; distinguish routes, provider offerings, exam and supervised-experience rules **only where supported**; never assert all electrician jobs require the same individual license. Tests also cover Registered Nurse, B.S. Computer Science, Security+, SAT and a user-created hobby goal. The absence of a course must not remove a destination from search.

## 7. Delivery milestones (entry and exit criteria)

| Phase | Deliverable | Completion gate |
| --- | --- | --- |
| **H0 — now** | This plan, source registry, safe baseline coverage CLI, architecture/README integration | Registry validates offline; code reviewed; CI green; no live coverage claims |
| **H1 — inventory** | Secure hosted baseline, source entitlement matrix, source refresh owner, sampled provider/credential gaps | Document production row counts and usage rights; approve P1 dataset list |
| **H2 — graph contract** | Additive schema + typed relationship semantics, jurisdiction, provenance, versioning and RLS/pgTAP tests | Idempotent migrations, no public forgery, no plan-regression; upstream diff test |
| **H3 — first expansion** | Florida licensure/admissions/credential pilot; issuer source adapters; search badges/unknown states | >=90% evidence-backed requirements in defined pilot subset; zero fabricated links |
| **H4 — national scale** | Permitted bulk imports, provider/course discovery, ingestion scheduler + change review queue | Idempotent backfills, alerting, update SLOs, review gates; missing sources visible |
| **H5 — cross-border & agents** | ISCED/ESCO/local regulator models; permissioned tool access for ChatGPT/Claude/Gemini | Separate country scopes; revocable OAuth grants; AI cannot publish official requirements |

**Priority:** verify existing releases and data rights -> build trustworthy relationship graph -> populate high-value career pathways -> add curricula where demand is demonstrated -> expand geography and AI coaching.

## 8. Tests and operational safeguards

- **Unit:** registry schema, duplicate source IDs, malformed provenance, missing classifications, orphan edges, cycles, version migration, conditional AND/OR paths.
- **Integration:** importer offline/dry-run; checksum mismatch; unauthorized publishing blocked; upgrade from a real hosted snapshot; source disappearance retains last reviewed state.
- **End-to-end:** a learner searches a destination absent curriculum, sees verified/unknown pathway steps and official sources, then starts personal study without an AI subscription.
- **Operations:** restricted ingestion identity, secret scanning, structured job logs with source IDs, incident rollback, licensing expiry and source staleness alarms.
- **Human review:** publisher rights and regulatory claims must be reviewed independently of the model that suggested them.

**Known Phase H0 limitations:** source-rights matrix is a decision queue, not legal clearance; no new dataset has been bulk-imported; no hosted Supabase audit was executed; there is no live relationship graph for the new categories yet; the current count CLI does not calculate evidence-backed career-to-license coverage until H2 tables exist.
