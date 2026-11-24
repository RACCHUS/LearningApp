# LearningApp — Demand-Driven Content Ingestion & Educational Optimization

**Implementation plan v1.1 — owner review draft**
**Date:** 2026-11-23 (US Eastern)
**Status:** Proposed. Review before implementation.
**Scope:** Path B of [Content Intelligence v2.6](LEARNINGAPP_CONTENT_INTELLIGENCE_AND_GAP_RESCUE_MASTER_PLAN_V2_6_2026-11-11.md) (§8), with interfaces to Path A (AI-assisted generation, §5) and Path C (external-resource companionship, §9).
**Authority:** The product owner approves priorities, rights exceptions, budget changes and production publication. This document authorizes no code change, migration, scraping, source-rights approval, deployment or spending.
**Precedence (v1.1):** This plan refines v2.6 §8; it does not replace it. Where they conflict, the binding v2.6 decisions (D1–D89), `AGENTS.md` and `UI_ARCHITECTURE_LOCKED.md` win until the owner accepts a specific change from §18 below. No decision in this plan is binding until the owner accepts it.
**Repository:** RACCHUS/LearningApp. Baseline: read-only inspection of `main` at `6033de6` (2026-11-23). No hosted audit, production query or test run was done for this draft.

---

## 0. What changed in v1.1 (repository review)

v1.0 was checked against `main` at `6033de6`. Most of its repository claims hold. Corrections and additions are folded into the sections below and marked **(v1.1)**.

### 0.1 Claims verified

| v1.0 claim | Evidence on `main` | Result |
|---|---|---|
| Source registry has 16 records, 14 approved, 2 candidates, six uses | `data/content_sources.json`; `USES` in `tool/ci/verify_content_sources.py` | Confirmed |
| Open index has 204 sections from registered OpenStax sources | `assets/open_content/index.json` (`sections`: 204) | Confirmed |
| Importer handles OpenStax archive, math, reading, terms, numeric practice; omits images; drops sections with no auto-gradable answer | `tool/import_open_textbook.py`; runbook "From the book / Becomes" table | Confirmed. Dropped sections stay reachable as open-textbook links |
| Reuse Gate uses lexical overlap at 60% | `lib/services/content_generation/reuse_gate.dart` (`coverage = 0.6`, word overlap, never blocks) | Confirmed |
| Popularity weights 35/25/20/20 | `docs/catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md` line 59 | Confirmed |
| BLS and IPEDS parsers | `tool/catalog_official_demand.py` (`parse_bls`, `parse_ipeds`) with tests | Both built. BLS 2025–2035 read (831 rows). **IPEDS import is blocked** until the official C2025_A ZIP is obtained (`P1_OFFICIAL_DEMAND_RUNBOOK.md`) |
| Manifest citations default to `reference` | `verify_content_sources.py` line ~170: `metadata.use` defaults to `"reference"` | Confirmed |
| Known rights discrepancies are warnings | Same file, "open issue: owner decision pending" path | Confirmed |
| Coverage Matrix, fill list, companion plans, champion/challenger, prompt cart are built | `/admin/coverage`, `/admin/freshness`; PRs #359–#371 | Confirmed (built; not all switched on) |

### 0.2 Corrections

1. **The "production-status conflict" is mostly a scoping difference (§2).** The runbook's "none has been ingested" (line 173) refers to the **seven authored curriculum manifests**: adult literacy, BS Computer Science, CLEP College Algebra, CLEP Introductory Psychology, Excel, Security+ and Software Engineer career. The **two open-textbook manifests** (`open_openstax_college_algebra_1e.yaml`, `open_openstax_prealgebra_1e.yaml`) were published 2026-11-20, and R2 replaced R1. Hosted state still has to be re-verified in IN-0, but the documents do not contradict each other. The runbook should say which set each statement covers.
2. **The Psychology fix is narrower than v1.0 implied (§2, §6).** The registry already has `openstax-psychology-1e` (CC BY 4.0, `adapt` and `ai_transform` approved by the owner on 2026-11-20) and `openstax-psychology-2e` (CC BY-NC-SA 4.0, link and reference only). The mismatch is in `content/clep_introductory_psychology.yaml`, `docs/catalog/CLEP_PROGRAM_GUIDE.md` (line 112) and `docs/catalog/CLEP_LESSON_AND_ITEM_SPECIFICATION.md` (line 27). All three still say 2e is CC BY 4.0. The owner chooses between re-pointing to 1e (already approved) and keeping 2e as link and reference only.
3. **Authored manifests have unverified source pins and free-text licenses (new, §6, IN-0).** Several `source_release.sha256` values look like placeholders, not real hashes. `adult_literacy_foundations.yaml` has `a1b2c3d4e5f6…`. The Psychology and Security+ manifests share an identical 50-character run (`e95632b85d38f8cf2e4389ab9213bc54784a621e25e9d3d3a77a94…`). `bs_computer_science.yaml` starts with the MD5 of "hello". License fields hold free text ("Authoritative Reading Research Synthesis", "Public Educational Research") instead of registry license IDs. Under this plan's own rule, "a pinned source hash proves identity", these pins prove nothing. Before any of these manifests is ingested, every pin must be recomputed from a lawfully retrieved copy or set to null with a reason, and every license must map to a registry entry. The adult-literacy source is registered as `ky-reading-research`, license `unknown`, link and reference only.
4. **The demand store is narrower than the plan's observation record (§4.1).** `public.catalog_official_demand_observations` (migration `20261012000001`) allows only two metrics: IPEDS awards and BLS openings in thousands. It has fixed units and periods and no fields for directness, cohort, suppression or confidence. The richer record therefore needs either a reviewed additive migration through the guarded path or, as proposed, version-controlled research files first.
5. **Source status vocabulary (§5.2).** The CI verifier accepts `approved`, `proposed`, `candidate` and `restricted` for source policy. Discovery states (researching, deferred and so on) belong in the discovery inventory, not in the approved runtime registry.
6. **Adapt vs redistribute is a live question, not a hypothetical one (§6, §18).** The importer requires `adapt`. Its reading blocks carry close to verbatim section text with math conversion. The three CC BY 1e sources are approved for `adapt` but not `redistribute`. CC BY 4.0 allows both, so this is a registry-policy decision, not a license barrier. It is now owner decision D-7.
7. **Two pilot candidates already have manifests (§10).** `content/excel_fundamentals.yaml` and `content/adult_literacy_foundations.yaml` exist, pass the dry run, and are not ingested. Reuse before acquisition means the first step in those lanes is to evaluate and repair the existing manifests (see item 3), not to acquire new sources. The runbook already lists "Excel and CLEP Algebra first" for production ingestion.
8. **The importer already fetches per page (§13).** `fetch_book` requests book metadata, then one archive JSON per selected page, with a 60-second timeout per request. It does not download whole books. "Source sections per batch" is therefore the natural limit. The byte cap applies to summed response sizes.
9. **Feature controls are now named (§13, new §13.1).** `AGENTS.md` (FLAG-010/016) requires a stable key, a default-OFF seed and `tool/verify_feature_registry.py` parity for substantial new runtime features. CLI and CI tooling is gated by workflow approval, not by a runtime key.
10. **Defined units:** capacity is in operator minutes per review cycle (§3.2). Learner-validation work follows the existing consent and age rules and needs a privacy review before any assignment experiment (§16.3).

---

## 1. Executive decision

LearningApp should not try to ingest all educational content. Its advantage should be helping learners reach worthwhile outcomes more efficiently, reliably and affordably than they could by navigating existing resources alone.

> **Broad discovery; selective acquisition; deep educational optimization; evidence-led expansion.**

- Research the educational landscape broadly enough to understand demand, underserved learners, existing alternatives and where suitable content can be obtained later.
- Prioritize high-demand areas with meaningful unmet needs, socially important underserved areas, and reusable foundational competencies. Popularity is not the sole objective. Absence of data is not absence of need.
- Acquire only the portions that advance a selected learner outcome and whose intended use is permitted. Prefer existing LearningApp content, including **existing unpublished manifests (v1.1)**, and suitable openly licensed material over unnecessary generation.
- Do not confuse an imported book, a completed lesson, or a correct answer to a memorized question with mastery or with exam or job readiness.
- Use assessment, instructional design, learner-controlled adaptation and remediation to reduce unnecessary work and support sustained motivation.
- Use external resources when linking is better, when copying is not permitted, or when an existing provider already teaches the material well. Preserve the foundation for the third product objective without making deep third-party integration the current critical path.

The current work should improve supply and its quality, not maximize content counts. A candidate catalog entry is not an acquisition commitment. An acquisition is not a publication commitment. Publication is not proof of effectiveness.

### 1.1 Constraints that remain binding

- Zero operator-paid AI inference, and no mandatory paid human-review program. No new paid data API, subscription, storage tier or worker without explicit owner approval. Existing hosting and CI have finite free quotas, so cost controls must be real, not merely aspirational.
- No removal of existing or planned functionality to simplify this initiative. Preserve personal import, manual AI, Bridges, companions, contribution and feature controls. BYOK stays behind the existing disabled release latch. This plan activates no new AI provider. `ai.managed` remains a separate owner decision.
- All provenance, licensing, privacy, assessment isolation, moderation and controlled-deployment requirements in the existing plans remain in force. Nothing here relaxes them.
- Build once on the existing curriculum, concept, coverage and evidence contracts. Avoid a second taxonomy, demand engine, lesson database, moderation system or parallel learner-progress ledger.
- Design for a small team and bounded maintainer attention. Automate repetitive checks, not legal judgment or unsupported claims of accuracy.
- Avoid addictive design and engagement optimization at the expense of learning. Motivation should follow meaningful progress, achievable challenge and autonomy.
- **(v1.1)** Migrations are append-only and are deployed only through `tool/guarded_supabase_deploy.dart` (or `.ps1`). Never repair versions to pass a check. If a feature owner moves, update `docs/engineering/CODEBASE_MAP.md` in the same PR.

---

## 2. Current foundation and actual gaps

This section is based on repository evidence. It does not claim that every feature is live or educationally validated.

| Area | Current repository evidence | Required extension |
|---|---|---|
| Demand | [Catalog Growth and Demand Plan](docs/catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md); `catalog_candidate_intake` and `catalog_official_demand_observations` (migrations `20261012000000/1`); BLS parser and data built; IPEDS parser built but its import is blocked on the official ZIP | Reuse verified data. Connect demand to learning objectives, supply gaps and acquisition decisions. Extend the observation shape (see §4.1). Verify current hosted status |
| Rights | `data/content_sources.json`: 16 records (14 approved, 2 candidates); six uses; CI checker `tool/ci/verify_content_sources.py` | Granular edition and asset rights, an explicit use on every publishable artifact, source approval and takedown traceability. Replace free-text manifest licenses with registry IDs **(v1.1)** |
| External content search | `assets/open_content/index.json`: 204 sections, generated from registered OpenStax sources | Broader metadata-first source inventory, selected-source objective mapping, better candidate relevance |
| Extraction | `tool/import_open_textbook.py`: OpenStax archive import (per-page fetch), math, reading blocks, terms, numeric practice | Reusable adapter boundary, partial imports, broader formats as justified, loss reporting |
| Publication | `tool/ingest_curriculum.dart`, manifest schema and linter, `controlled-curriculum-ingestion.yml` | Staged acquisition records and evidence gates that reuse the existing importer and publication RPCs |
| Coverage | Coverage Matrix at `/admin/coverage`, objective roles, fill list, "Your draft" state, coverage priority (`20261123030000`), Wanted Board, Reuse Gate | Distinguish candidate, link, teachable, practiced and independently assessed coverage. Map source evidence to explicit objective depth |
| Reuse | Reuse Gate: word overlap with `coverage = 0.6`, never blocks, offers open sections before AI; catalog near-duplicate detection (#366) | Improve concept and skill matching and verify actual coverage. Do not treat lexical overlap as equivalence at mastery level |
| Learning | Canonical concepts, diagnostic assessments, learning contexts, Bridges (math and programming), TEL modes, practice, evidence and progress | Ensure imported content has pedagogical structure, prerequisites, meaningful practice and appropriate independent checks |
| Lifecycle | Freshness queue (`/admin/freshness`, daily workflow), source pins, champion/challenger with decision screen (#362, #371), replacement lineage and learner continuity (#345) | Extend to source assets, rights changes, partial changes and objective-level impact. Validate identity migration |
| Contributions | Community review, refresh proposals, disputes, Wanted Board (switched on) | Permit rights-cleared source nominations, corrections and reusable improvements through existing moderation |
| Companions | Link, focus note, checkpoint, Bridge and multi-step companion plans: built (#238, #367) | Share source and objective identity. Keep access and evidence boundaries honest |

**Hosted status (v1.1).** The runbook records a 2026-11-20 production pilot of the two **open-textbook** manifests: College Algebra chapter 1 (4 lessons, 27 graded questions; 1.4 Polynomials and 1.5 Factoring left out) and Prealgebra chapter 6 (5 lessons, 49 graded questions), with R2 replacing R1. Its "none ingested" line refers to the seven **authored** manifests. Neither statement replaces a fresh hosted check in IN-0.

**Known limits.** The importer leaves out sections without automatically gradable answers, does not copy images, and supports CC BY OpenStax material only; it is not a general document intake engine. Psychology: see §0.2 item 2. Authored-manifest pins and licenses: see §0.2 item 3. Existing lawful material must not be deleted automatically because current terms change.

The actual `main` SHA, migration inventory (158 files at `6033de6`), flags, deployed content and automated test status must be recorded afresh when implementation starts. This plan claims no new implementation.

---

## 3. Scope and expansion policy

### 3.1 Three distinct inventories

| Inventory | Breadth | Payload | Default state |
|---|---|---|---|
| Learning opportunity inventory | Broad across domains, outcomes and populations | Target IDs, demand evidence, supply gaps, source leads | Private research. No popularity claim without evidence |
| Source discovery inventory | Broad across relevant repositories, publishers and resources | Permitted metadata, URLs, edition, known license evidence, format, topic and access | Candidate; metadata only |
| Acquisition inventory | Narrow, limited to approved objectives and batches | Approved source artifacts, extracted blocks, mapping, assessment and release evidence | Private staged draft |

A source can be indexed or documented without acquiring its educational payload. Even metadata must comply with the source's terms. No blanket crawl of the internet, entire textbook repositories or proprietary services. Do not download files merely because they may be useful later. Discovery records may be deferred indefinitely, refreshed on a bounded schedule, or revisited when needs arise.

### 3.2 Portfolio lanes and coverage expansion

Allocate new acquisition work by **capacity**, not by number of files or estimated page count. **(v1.1)** Capacity is measured in operator minutes per review cycle: estimated when the work is planned, actual when it is done. Both are recorded so the estimates can be calibrated.

Proposed initial allocation: **55%** high-demand unmet needs, **25%** underserved or high-impact learners, **20%** reusable foundations and high-leverage gaps shared by several goals. Classify each work item in one primary lane. Note secondary value without double-counting capacity. These are owner-tunable planning defaults, not measured optimal weights. Unused capacity may move to another lane with a recorded reason, but the underserved lane is never permanently eliminated.

- **High-demand:** evidence of large learner interest or participation, and an opportunity to improve affordability, efficiency, reliability or outcomes.
- **Underserved or high impact:** credible barriers, or an important life or educational opportunity, even where search volume or market data are sparse. Low literacy, disability access, geographic exclusion and unaffordable resources can be considered with appropriate evidence. Never infer sensitive attributes about individuals.
- **Reusable foundations:** prerequisite or shared skill nodes with demonstrated fan-in to several prioritized outcomes, such as fractions or spreadsheet reasoning. Do not build every theoretical prerequisite before delivering a useful pathway.

**Expansion order:** improve weak objectives in chosen tracks → cover adjacent objectives and shared prerequisites → add new high-value tracks → broaden into long-tail domains when demand, gaps and operating capacity justify it. Release a useful, coherent slice rather than a vast incomplete catalog. There is no absolute coverage target for the whole world and no quota for textbooks imported.

### 3.3 Decide whether to build at all

For each opportunity, choose one or more actions: reuse an existing lesson; **repair and ingest an existing unpublished manifest (v1.1)**; improve an existing lesson; adapt a permitted resource; author original material; link to an excellent resource; create an independent companion or check; request a licensed contribution; research further; defer. A high-quality free external resource may make full ingestion unnecessary. A weak external ecosystem may justify deeper acquisition even if traffic is lower. Never downgrade a learner's free option just because a referral or sponsor is available.

---

## 4. Demand and opportunity research

### 4.1 Extend the existing demand infrastructure

The Catalog Growth and Demand Plan already defines comparable cohorts, observed signals and private intake. Its popularity score (labor 35%, participation and completions 25%, search 20%, community 20%) is a provisional existing policy, not a new cross-domain fact. Keep its authority for destination-level popularity, and improve its inputs and confidence where necessary. Acquisition priority is a separate decision. It combines measured demand with need, outcome value and supply; it does not replace the popularity ranking.

Use the most specific unit that can be supported: destination or credential → target version → objective → canonical concept → missing role. Where an occupation is the only observed unit, label labor demand as an indirect signal for the learning opportunity. An occupation opening is not a certification candidate. An IPEDS completion is not an enrollment. A search index is not an absolute count of learners.

| Evidence class | Candidate sources and methods | Interpretation |
|---|---|---|
| Official participation | Issuer exam reports, state regulator statistics, school and adult-education reporting | Direct participation where definitions and period match. Not every issuer publishes counts |
| Education | NCES IPEDS, enrollment datasets, national and local education statistics | Distinguish enrollment, completions, tests and credentials |
| Labor | BLS projections, O*NET, permitted workforce datasets and job postings | Opportunity and skills context, kept separate from whether a credential is necessary |
| Public interest | Permitted search-trend datasets, course and community interest, structured surveys | Relative interest. Control geography, window, season and source bias |
| Internal demand | Aggregate library searches, no-result searches, goal creation, Wanted Board, content-gap requests | Initially sparse and selection-biased. Never expose sensitive raw searches or identities |
| Unmet need | Audits of free and paid alternatives, access costs, current coverage, barriers, educator and community reports | Measure barriers, not just the quantity of resources |
| Outcome value | Official pathway costs, credit-equivalence policies, competency and job requirements, relevant research | Document potential benefits and limits. No guarantee of employment, credit or qualification |

An observation stores metric, value, unit, geography, population, period, source locator, publisher, release, date checked, allowed use, data quality, method, comparability cohort and directness. Preserve original counts. Normalize only within compatible cohorts. Deduplicate syndicated or correlated evidence. Suppressed, missing, not applicable and zero are different states. Search trends cannot be summed across unrelated topics; use shared anchors or matched cohorts when feasible.

**Storage (v1.1).** `catalog_official_demand_observations` constrains `metric` to the IPEDS and BLS pair and lacks directness, cohort, suppression and confidence fields. Proposed sequence:

1. Keep official BLS and IPEDS observations in the existing table and uploader. Do not fork them.
2. Record the other evidence classes as version-controlled research files, proposed under `data/research/opportunities/`. Validate them with a Python checker in `tool/` (tests in `tool/tests/`) and run it in CI.
3. Only after the shape has been stable for at least one review cycle, propose an additive migration through the guarded deploy path, if a database copy is actually needed (for admin views or RLS-protected access).

Research files must contain aggregate, public, non-personal data only.

**Demand status:** `unmeasured`, `research_in_progress`, `measured_limited`, `measured_comparable`, `stale`. Keep editorial priority visible as editorial, separate from measured popularity. A measured ranking requires the existing roadmap's minimum: two independent signal categories and two comparable observations per cohort. Unknown fields stay unknown. Confidence covers age, directness, independence, completeness and limitations. Never fabricate demand, test participation or job numbers. Review high-priority signals at least quarterly, and more often for volatile data. Defer expensive refreshes on long-tail candidates.

### 4.2 Opportunity brief and alternative analysis

For each shortlisted target, produce a compact, evidence-linked brief:

- Intended learner, locale and language, target version, exact outcome, eligibility prerequisites, and how success can be measured.
- Observed demand and its confidence; unmet needs; current alternatives; costs (dated and region-specific); access barriers; expected marginal improvement.
- Current LearningApp coverage by role (from `/admin/coverage`), **existing unpublished manifests and their blocking issues (v1.1)**, source leads and their legal-use state, content volatility (V0–V4), domain risk, estimated acquisition, review and maintenance effort, and dependencies.
- Recommended action (acquire, adapt, link, create, improve, defer) and the smallest useful pilot, with rationale and stop conditions.

Review representative free and paid alternatives, not just the easiest open textbook. Sample their actual scope, instructional fit, accessibility, practice, independent assessments, currency and outcome alignment. An editorial evaluation is not proof of poor educational outcomes; mark uncertainty and research gaps.

### 4.3 Acquisition priority (proposed initial policy)

**Hard gates come before scoring:** a permitted operation, a minimum source-trust level for its role, a defined outcome and objective, safety requirements, capacity, and feasible validation. A source with unknown rights may enter discovery or a lawful link lane. It cannot enter adaptation, download or publication merely because its opportunity score is high.

| Factor | Weight | Measurement anchor |
|---|---|---|
| Demand | 25 | Existing comparable demand evidence; do not rescore from unsupported impressions |
| Underserved need | 20 | Evidence of cost, access, coverage or quality barriers and the affected population |
| Outcome value | 20 | Documented meaningful benefit, relevance and a credible success measure |
| Cross-goal reuse | 15 | Fan-in from the existing concept graph to prioritized objectives, not duplicate topic labels |
| Permitted reliable source feasibility | 10 | Source readiness, coverage and validation feasibility for the chosen operation |
| Improvement potential | 10 | A specific hypothesis for reduced time, stronger retention or transfer, or better access |

Rate each factor 0–5 using written anchors: 0 = documented absent, 1 = weak, 3 = moderate, 5 = strong, with 2 and 4 as intermediates. **Unknown is null, not zero.** Each value stores its evidence and the reviewer or algorithm version.

- `known_weight` = sum of weights for factors with observed scores.
- `provisional_score` = 100 × Σ(weight × score / 5) / `known_weight`.
- Also report the bounds of the full score, assuming each missing factor could range from 0 to 5. A high score from one known factor is not comparable to complete evidence.

Proposed minimum: **70% of the weight known**, plus lane-specific evidence, before a numeric priority is used in allocation. The high-demand lane requires measured demand. The underserved lane may be selected editorially on documented need when demand is missing. **(v1.1)** Without demand, at most 75% of the weight can be known, so the underserved lane can still reach the threshold, but its bounds will be wide and must be shown. The owner can approve a bounded discovery experiment instead of inventing a score.

Compare scores within similar work lanes. Show separately an effort estimate (S/M/L, with the reason and estimated operator minutes), safety risk and dependency order. Select the most useful portfolio within capacity, not a blind sort by score. The existing v2.6 §6.5 reuse-value priority (now stored by the coverage-priority migration) continues to rank content-level gaps inside selected objectives. Do not double-weight Wanted Board and reuse signals at both levels without recording the effect. Owner overrides need a reason and date, cannot override rights or quality gates, and can expire. Test sensitivity to reasonable weight changes and to missing evidence. No public popularity label comes from this editorial score.

---

## 5. Source discovery intelligence

### 5.1 Build a map of where to obtain content later

Maintain a source directory at two levels: publisher or repository, and resource or edition. Record a candidate source before acquiring any of its material. Discovery must answer:

- Which publisher has relevant resources?
- How could a future importer access them lawfully?
- What format and structure exist?
- Which subjects are represented?
- Which rights need verification?
- How much value might the material add?

| Source family | Candidate leads (not blanket reuse approvals) | Potential use |
|---|---|---|
| Open textbooks | OpenStax exact editions, Open Textbook Library, LibreTexts, institutional open presses | Explanations, worked examples, glossary, exercises |
| OER discovery | OER Commons, Mason OER Metafinder, MERLOT | Finding resource leads and publisher pages; verify each item's rights |
| Public agencies | BLS, NCES, Census, selected federal education and training pages | Official facts, datasets, public-domain works where applicable; check for third-party exclusions |
| Exam issuers and regulators | College Board, GED Testing Service, state boards, CompTIA, other issuers | Official scope, eligibility and blueprint alignment; normally link or reference unless explicitly permitted |
| Open courseware | MIT OCW, university open courses, SkillsCommons | Source discovery and companion pathways; review each asset's license and terms |
| Software documentation | Microsoft Learn and Support, Python documentation, other project docs | Link or reference; adapt only exactly licensed material under permitted terms |
| Educators and community | Authorized donations, original educator lessons, public-domain archives | Rights-cleared content and feedback under an explicit contributor license |
| Media, simulations, datasets | Wikimedia Commons, institutional datasets, open simulations | Per-asset licenses, accessibility and independent quality checks |

Research resources such as the Oregon State OER directory, the University of Florida OER guide and the Virginia Tech open textbook guide are discovery leads, not permission to reproduce the material they link to. Check the exact current publisher terms and acquisition method for each candidate family when it is selected. This plan does not claim that any of these services offers a free API, bulk access or commercial adaptation rights.

### 5.2 Discovery records and acquisition feasibility

Reuse `data/content_sources.json` for approved source policy and CI. Never copy all candidates automatically into the approved runtime registry. **(v1.1)** The registry's status vocabulary is the one the verifier enforces: `approved`, `proposed`, `candidate`, `restricted`. A source enters the registry, as `proposed` with link and reference only, at the point it is selected for a pilot, not when it is discovered.

Start with a version-controlled metadata research artifact, proposed as `data/research/sources/`, validated in CI. Alternatively, extend the existing private intake where that fits semantically. Choose one authoritative owner for each field. The logical record below is not a new database mandate:

```text
source_candidate_id, publisher_id, resource_id, edition_or_release,
canonical_url, discovery_url, locale, subject_ids, outcome_refs,
metadata_checked_at, observed_access, metadata_permission,
license_claim, license_evidence_locator, rights_review_state,
permitted_actions, exclusions, format, acquisition_method,
structure_hint, estimated_effort, authority_role, review_evidence,
known_gaps, last_link_check, volatility, recommendation, decision_reason,
registry_source_id   # (v1.1) set only once registered in content_sources.json
```

Source-specific adapter descriptors record the permissible API, feed or download endpoints, format, supported content types, limits, provenance locators, expected update behavior and fixture location. Do not fetch restricted payloads to test feasibility; inspect public metadata or a permitted sample. A provider with unknown rights defaults to discovery, link or reference, subject to its access terms, and never to AI transformation. Unverified claims from aggregators never override primary license evidence.

Use the canonical URL and publisher, resource and edition identifiers. Distinguish mirrored duplicates, translations and revised editions. Each indexed resource may link to many objectives. Discover section-level metadata only where it is useful and permitted. Never expose unfinished research as validated public content.

Record defer reasons (`low_current_priority`, `rights_unknown`, `strong_external_alternative`, `no_reliable_source`, `high_maintenance`, `adapter_not_ready`) together with a revisit trigger. The discovery inventory can grow independently of ingestion volume. **(v1.1)** External links in research files are checked by the existing `external-link-check.yml` and `tool/check_external_links.py` only if they are added to its scope; decide this in IN-2 so the check does not fail on research-only URLs.

---

## 6. Rights, provenance and source trust

Preserve the six current use types: `link`, `reference`, `quote`, `adapt`, `redistribute`, `ai_transform`. Permission is specific to each operation. Open access, an academic publisher, public visibility or private storage do not, on their own, establish copying rights. Owner approval cannot override an actual license restriction.

- **Validate the exact release.** Check the edition, source release, license version, evidence URL, checked date, attribution, commercial-use condition, share-alike, change notices and item exclusions. Keep content licensing separate from trademarks, API and access contracts, personal data and AI-provider terms.
- **Record provenance per item.** For each block, item or asset, record the source locator (section, page, exercise or stable anchor), source release ID, acquisition time, source hash where lawfully stored, adapter version, transformation and review evidence. Inherit rights only where the source explicitly covers the item. Images, tables and third-party excerpts may carry separate rights.
- **(v1.1) Pins must be real.** A `sha256` in a manifest must be computed from the retrieved artifact, or be absent with a recorded reason such as "not lawfully storable" or "web page, no stable artifact". `clep_college_algebra.yaml` already does this with `metadata.checksum_status: unverified_remote_document`. CI should reject obvious placeholders (repeated hex patterns, all-same characters, or hashes shared across different sources) and free-text licenses that do not map to a registry license ID. Existing manifests with such values are fixed before ingestion, not silently accepted (see §0.2 item 3).
- **Declare the operation explicitly.** Manifests and assets must state their use. The current CI treats manifest citations as `reference` unless declared otherwise; a reference citation must not hide an adaptation. CI should fail closed on missing or mismatched rights for **new** public adaptations. **(v1.1) Mechanism:** freeze the current list of known discrepancies as an explicit allowlist, with each entry tied to an open owner decision, so that new discrepancies fail. Do not break legacy material silently; quarantine and review affected releases through the existing lifecycle rules.
- **Separate adaptation from verbatim redistribution.** A permissive license may allow both, while the owner registry authorizes only one. **(v1.1)** This applies today. The OpenStax importer's reading blocks are close to verbatim and are authorized under `adapt` only. Resolve it through decision D-7 before increasing import volume beyond the pilot chapters. Never infer source-wide redistribution approval.
- **Non-commercial and share-alike.** Non-commercial sources stay link and reference only under current policy, pending a substantiated owner or legal decision that is compatible with sponsorships, donations and other monetization. Share-alike adaptations require license support at the asset level before use (content files have no license field yet). Historical lawful copies need historical license evidence; new versions need fresh verification.
- **Private learner imports** stay separate and private by default, subject to rights and terms. No automatic public indexing, training, community submission or acquisition from them. Never send restricted source material or learner data to a third-party AI.
- **Treat source material as untrusted input.** Sanitize markup. Never execute embedded scripts, instructions, macros, links or prompt injections. Any future network fetcher uses allowlists, HTTPS, redirect and SSRF defenses, size, time and rate caps, and restricted credentials. Do not bypass paywalls, access controls, robots rules, terms or CAPTCHAs.
- **Trust depends on purpose.** Regulators and issuers are authoritative for current requirements. Strong academic sources are authoritative for factual instruction. Educational research and evidence inform teaching design. Cross-check contentious, volatile and safety-critical facts. Source authority does not imply teaching quality. Use the separate origin, rights, authority, review and validity statuses already defined in the learning-science docs. If review capacity is not enough for a high-risk release, keep a link or a lower-trust private draft instead of manufacturing verification.

---

## 7. Acquisition and ingestion workflow

### 7.1 One workflow with explicit decisions

```text
Broad research → shortlist opportunity → choose outcome and objective slice
  → compare existing LearningApp (incl. unpublished manifests) + external resources
  → select operation → approve exact source/use + capacity → acquire bounded artifact(s)
  → normalize to staging + fidelity report → map concepts and roles
  → optimize instruction and develop assessments → validate independently
  → stage review → publish through existing controlled pathway
  → measure, correct, replace, retain or retire
```

If any required gate fails, keep a reasoned blocked or deferred record. A failed assessment adapter does not invalidate teachable material: publish it as teaching-only if its own teaching and rights gates pass. Never claim that an objective has independent check coverage when it does not.

Proposed logical states: `discovered`, `researching`, `shortlisted`, `rights_pending`, `approved_for_acquisition`, `acquiring`, `staged`, `validation_failed`, `review_ready`, `approved_for_publication`, `published`, `refresh_due`, `restricted`, `retired`, `deferred`. Implement only the minimal states not already owned by catalog intake, target versions, content contribution or freshness. Moving an intake record never publishes anything on its own; the existing authorized publication transitions stay authoritative (`ingest_curriculum.dart` stages: dry-run, draft, review-ready, published). A rights restriction blocks further use and triggers a downstream impact review. Distinguish retryable operational failures from permanent validation failures.

### 7.2 Batch contract and reproducibility

Each selected batch records:

- objective IDs and roles;
- source and edition IDs, and the allowed actions;
- size and effort limits, and the owner's authorization;
- adapter and version, and pinned artifact hashes where permitted;
- output manifest IDs, warnings and checks;
- skipped material, with the reason and fallback;
- unresolved gaps and the publication result.

Use a stable idempotency key built from the selected source release, scope, adapter revision and transformation config. Repeat runs must not create duplicate published lessons or reset review decisions. (The importer's `IMPORT_REVISION` and the `OPENSTAX-<book>-R<n>` version code are the existing form of this.) Persist only the source material needed, within storage and rights limits. A pinned source hash proves identity, not correctness or licensing.

Stage writes in isolation. The existing manifest tooling must remain the final normalized authoring contract. No parallel public content stores and no arbitrary client writes. Publish a coherent release atomically, and never partially publish a failed batch. Keep batches small and resumable, retrying only recoverable failures, with checkpoints and a clear cancel path. The retention and purge policy must respect rights, privacy, rollback needs and free-tier limits. Store metadata and diagnostics instead of the raw source payload when retention is unnecessary or restricted.

### 7.3 Format adapters, in demand-driven order

| Adapter family | Initial plan | Trigger for implementation |
|---|---|---|
| Existing OpenStax XML/HTML (archive JSON) | First. Refactor behind an explicit adapter contract; preserve outputs and regression fixtures | Existing verified pilot and a selected opportunity |
| Existing YAML/JSON manifests and supported lesson dialects (v2.6 §5.6 five dialects) | Reuse and improve validation; no replacement schema | Existing routes; always maintain compatibility |
| Structured HTML/Markdown | Candidate next | An approved high-priority resource with stable structure and permitted acquisition |
| Born-digital PDF/EPUB | Candidate next, if justified | A chosen source actually needs it, and reading order, tables, math and extraction fixtures pass |
| Licensed CSV/question banks, QTI, H5P, course packages | Targeted | An approved source and a needed task type; review existing interop support first |
| DOCX/slides, media/transcripts, OCR, interactive packages | Deferred until justified | A documented high-priority unmet need, with rights, accessibility, fidelity and cost feasibility |

Do not build every adapter speculatively. First implement a thin adapter interface that can:

- discover permitted metadata;
- fetch an approved slice;
- parse it into normalized staging objects, preserving source locations;
- emit explicit loss reports and warnings;
- produce fixtures.

Adapter output must distinguish a successful parse from a faithful one. Optional AI may propose mappings or adaptations only where permitted, with no operator-paid inference. Its structured outputs are validated and treated as untrusted. Deterministic extraction and transforms are the default.

### 7.4 Immediate importer improvements

- **Separate the roles.** Judge teaching, worked examples, practice and independent-assessment eligibility separately. Keep valid teaching sections with a visible assessment gap instead of dropping them. This directly addresses the College Algebra 1.4 Polynomials and 1.5 Factoring omissions.
- **Math fidelity.** Distinguish unsupported mathematical markup from correctly rendered content. Unknown conversions must not silently become authoritative equations. Build fixtures for fractions, radicals, powers, inequalities, graphs, tables and multipart questions (extending `test/content/open_textbook_math_test.dart`).
- **Answer alignment.** Align answers by stable exercise identifier, not by answer order alone. Keep missing or ambiguous keys, units, domain assumptions and inconsistent variants out of scored use. Recompute where deterministic verification is possible.
- **Source images.** Handle them explicitly: keep appropriately licensed assets only after item-level review; create original or licensed replacement diagrams where needed; or link to the original with a clear description. Mark visual-dependent tasks incomplete if the visual is essential. Alt text and captions must be accurate, never fabricated.
- **Rights at output time.** Check the source license and the actual intended operation before output, not just the publisher identifier. The importer already stops when the archive's license differs from the registry; extend this to the operation (see D-7). Produce a transformation and change log, and attribution at the relevant granularity.
- **Partial imports.** Import selected sections and roles independently, not only whole chapters. Preserve stable objective and lesson identity across revisions. Guard against accidentally duplicating or replacing unrelated material. Continuity currently moves progress to the lesson with the same title in the new version, so renamed sections need an explicit mapping.

---

## 8. Canonical objective mapping and educational optimization

### 8.1 The outcome contract comes before lesson design

Every prioritized target needs a success definition and a versioned scope: the official blueprint where one exists, required knowledge and skills, prerequisite and eligibility boundaries, expected depth, task type, acceptable performance evidence, and exclusions.

- A career goal needs a realistic path and evidence of competence, not a promise of employment.
- Where no official blueprint exists, write a transparent editorial scope with references and stated uncertainty.
- For licensing, distinguish preparation from legally mandated education, hours, application steps and examination eligibility. The existing regulator-pathway documents in `docs/catalog/P2*` already do this.
- For CLEP, distinguish exam readiness from institution-specific credit acceptance.

Map source sections to canonical concepts using existing IDs, objective placement, task profiles and prerequisite relations. Never merge concepts on title alone. A candidate mapping records its match type (`exact`, `partial`, `prerequisite`, `supplementary`, `unrelated`), depth, role, source locator, confidence and review state. Lexical retrieval generates candidates; it does not prove that content is sufficient. Add exact identifiers, aliases and synonyms, and concept and skill matches before considering costly semantic infrastructure. Check for ambiguity and for multi-language mappings. Require reviewed mappings for high-stakes use.

### 8.2 Objective-role coverage

Extend the existing Coverage Matrix as a derived view, not a second catalog. The roles remain Teach, Example, Practice, Check, Bridge and Access. For each objective and role, show one state with its evidence and applicability reason: `missing`, `external_candidate`, `external_available`, `internal_draft`, `internal_usable`, `independently_verified` or `not_applicable`. Reconcile these with the states the matrix already shows, including "Your draft", instead of duplicating columns.

Keep these distinctions: available content, a link, technical validation, human review, and evidence of mastery. A reading-only lesson can be useful without checks, but it cannot mark the whole outcome ready. Track depth, prerequisites and task profile, not just the number of blocks. A published source may fill several objectives or only part of one.

Coverage calculations use weighted required objectives and roles with explicit denominators, including uncovered objectives. An exam blueprint's weights are not automatically valid for other goals. Never count a planned question, an unavailable link, a repeated item or an unreviewed generated claim as independently verified coverage. Show coverage uncertainty where mappings are incomplete. Learners keep the ability to override suggested learning routes.

### 8.3 Turn content into learning experiences

- Separate reusable concept-level teaching assets from target-specific placements. Keep source order where it matters; reorder only when prerequisites, coherence and intended depth justify it. Keep the context around equations, examples and safety warnings.
- Use diagnostic evidence to choose a pathway. Avoid forced pretesting or mandatory prerequisites when the learner's evidence already supports moving on. Offer a clear route for beginners and an efficient route for experienced learners.
- Prefer concise, objective-sized units with worked examples, gradual removal of scaffolding, retrieval practice, spaced review, appropriate feedback and transfer tasks. Use the existing TEL modes as alternative depth and pacing, not as three inconsistent factual curricula.
- For complex concepts, combine text with useful diagrams or worked examples. Do not delete essential information to meet an arbitrary lesson length. Show estimated duration as a range or an observed measure, and keep estimates distinct from actuals.
- Connect previously learned concepts to new objectives. Use relevant, varied examples, misconception checks and Bridges for recovering from difficulties. Keep exact return anchors and avoid infinite prerequisite loops (the existing depth and cycle limits apply).
- Keep the learning sequence separate from the assessment blueprint and independent items. A good teaching example may be deliberately easy; readiness checks must sample the intended difficulty, breadth and transfer.
- Offer equivalent or complementary alternatives when justified, with a clear recommended route and the choice to switch. Reuse strong external explanations instead of creating redundant versions merely to keep learners in the app.

**Research basis for the initial instructional choices:** IES/What Works Clearinghouse, *Organizing Instruction and Study to Improve Student Learning*, and MIT Teaching + Learning Lab, *Help Students Retain, Organize and Integrate Knowledge*. Apply these methods conditionally by task and learner. Validate their effects on LearningApp's intended users instead of assuming published research guarantees local outcomes.

### 8.4 Motivation and inclusion are content acceptance criteria

For each coherent learning slice, specify:

- a purpose;
- an actionable next step;
- a manageable entry difficulty;
- useful feedback;
- a way to recover when stuck;
- a meaningful milestone;
- alternative support, where available.

For long or challenging material, provide an estimated workload, learner-controlled pacing, and a visible distinction between progress through content and demonstrated competence. Do not penalize rest or use manipulative streak loss. Optional reminders should support the learner's chosen goals, not enforce usage.

Support low-bandwidth and mobile use, plain language where appropriate, accessible reading order, keyboard access, screen-reader labels, sufficient contrast, and captions or transcripts where allowed. Do not assume reading age, language ability or disability; make supports available without intrusive profiling. Translation or plain-language adaptation requires rights and semantic validation. Never mark automatically translated high-stakes terminology as reviewed. Validate with representative learners and educators where they volunteer.

Measure whether learners return after difficulty, complete the meaningful milestones they chose, improve on delayed performance, and report that the path is manageable. A learner who finishes efficiently and leaves is a success, not an engagement failure.

---

## 9. Quality and reliability gates

Do not collapse quality into one score. Record independent gate outcomes (`pass`, `fail`, `needs_review`, `not_applicable`) with the scope, method, source and version, date, responsible actor and limitations. Never claim human review for AI or automatic checks. Quality status is specific to purpose: lower-risk teaching may be publishable while a scored item or an exam claim is blocked.

| Gate | Evidence required | Failure action |
|---|---|---|
| G1 Rights and provenance | Approved intended operation, exact release and asset locators, **real source pins or a recorded null (v1.1)**, visible attribution, exclusions checked | Block use; link only if appropriate |
| G2 Structural integrity | Manifest and schema, IDs, references, no unsafe markup, reproducible adapter fixtures | Quarantine and repair |
| G3 Extraction fidelity | Source-to-output comparison; expected blocks and questions; list of unsupported features and losses; math, table and rendering checks | Block the affected block; essential omissions block the slice |
| G4 Factual integrity | Source-grounded claims, terminology, numbers and units; independent corroboration or review as risk warrants | Mark unresolved; no trusted publication of affected claims |
| G5 Mapping and instructional fit | Correct objective and depth, prerequisites, coherent sequence, learner-access and motivation checks | Repair, remap or reduce scope |
| G6 Assessment integrity | Valid keys, independent recomputation where possible, fair handling of equivalent answers, no answer leakage, task fit | Remove from scoring and readiness; keep the teaching if safe |
| G7 Publication safety | Existing RLS; separation of authoring, presentation and scoring; moderation; versioning; feature readiness; rollback | Block release |
| G8 Outcome evidence | Delayed retention, unseen transfer, appropriate real outcome data, transparent uncertainty | No claim of validated effectiveness or readiness; investigate or revise |

G8 is a post-pilot gate for claims and scaling. It is not a prerequisite for all initial low-risk pilot content. The pre-publication gates must distinguish a pilot release with honest limitations from a trusted or high-stakes release. Every published artifact must pass all applicable safety, rights and integrity gates; no weighted quality average can override a failure.

For deterministic checks, validate semantic results, not just valid syntax. Sample extraction across representative source layouts, and record the sampling method and what was not checked. For higher-risk claims, use authoritative references and qualified review where needed. If no qualified volunteer capacity exists, limit that release's role and keep the rest of the product available.

### 9.1 Assessment integrity and independent evidence

Use the existing protected scoring infrastructure for assessments that count toward readiness. Verify the latest non-EXM and EXM implementation instead of relying on historical specs. Never ship protected scoring keys in public asset bundles, DTOs, debug logs, downloadable curricula or accessible database columns. Practice feedback and answer-reveal exercises remain explicitly formative. Keep source-derived practice separate from held-out assessments, with versioned exposure and similarity checks (the parametric-practice exposure limits are the existing pattern). Do not grade recalled answer keys as transfer.

- **Numeric questions:** specify units, tolerance or precision, and domain.
- **Algebra:** first evaluate a bounded, safe symbolic parser with domain restrictions, equivalence tests, limits on expression complexity and time, and adversarial cases. No arbitrary code evaluation. Numeric sampling of expressions alone is not proof of equivalence. If robust grading is unavailable, provide a self-check with the solution and mark it unscored, as the importer already does for expression answers.
- **Psychology:** use source-supported scenarios with justified answers and defensible distractors.
- **Excel:** verify the actual task output with the existing deterministic simulation and rubric capabilities. Never award competence for a video-completion tick.
- **Literacy:** use appropriately accessible unseen items, and distinguish assisted from independent performance.

---

## 10. Pilot selection and scope

The following are research candidates, not a validated popularity ranking. Start with existing infrastructure to minimize new engineering, while basing selection on current demand and supply evidence. A candidate may be replaced before acquisition if research reveals a better opportunity.

| Candidate | Reason to investigate | Possible first scope | Source leads and constraints |
|---|---|---|---|
| Foundational numeracy + CLEP College Algebra | Reused across math, Excel and credentials; textbook import already exists; algebra Bridges exist for 1.1–1.3 and 1.6 | Restore the 1.4 and 1.5 teaching sections as teaching-only; add prerequisite Bridges (negative numbers, linear equations; see the supply map) and independent practice for selected objectives | Approved exact OpenStax first editions; College Board outline as reference only. The authored `clep_college_algebra.yaml` is a separate, un-ingested manifest; reconcile it with the open-textbook lessons before ingesting either again |
| CLEP Introductory Psychology | Validates a non-math, factual and conceptual subject; curriculum already exists | Resolve the edition decision (D-5); re-pin the manifest's sources with real hashes; then a selected scenario-based objective slice | 1e approved for `adapt`; 2e link and reference only; issuer outline as reference only |
| Excel fundamentals | Practical workplace outcome; simulation capability exists; **manifest exists (one lesson) and passes the dry run (v1.1)** | Ingest the existing lesson after the gate check; then cell references, AVERAGE/COUNT, filtering, or a budget or percent skill with a task-based check | Microsoft as link and reference; original explanations; rights-cleared sample workbooks |
| Adult literacy and numeracy | Underserved-lane candidate; accessibility and self-paced recovery; **manifest exists (v1.1)** | First repair the manifest: the source license is `unknown` and the pin is a placeholder. Then a small coherent reading or numeracy progression with accessible feedback | `ky-reading-research` is link and reference only. Write original text; research adult-education sources and verify their exact rights |
| GED, English language learning, programming, IT credentials, trades, healthcare | Potential high-value expansion. Programming Bridges and Security+, BS CS and Software Engineer manifests exist | Discovery and evidence briefs at first; acquire only the next selected slice | Official outlines, OER repositories, original content or permitted assets; high-stakes boundaries. Fix pins in the existing manifests before ingesting them |

**Recommended first engineering pilot:** one small numeracy or algebra slice. It exercises the existing adapter, gap recovery, rights and mathematical assessment. Run research for the other lanes in parallel, without downloading courses. Follow with one non-math or practical slice selected from the evidence, so the architecture does not overfit algebra. **(v1.1)** Excel is the cheapest second slice, because its manifest, simulation and Bridges already exist. Include one underserved opportunity in the first portfolio review. If no usable source is cleared, document the link, original or rights-cleared contribution alternative instead of ignoring the need.

A complete pilot means a learner can find the target, understand the expected outcome, study a coherent objective slice, get appropriate practice, recover from a gap, show independent progress, and resume later. It does not mean that the whole exam curriculum, job qualification or every available book has been imported.

---

## 11. Operator workflow and learner-facing experience

### 11.1 Admin surfaces

Start with reproducible CLI reports and versioned research files. Extend existing private admin screens only once the workflow has stabilized. Suggested views, reusing existing routing and governance (existing admin routes: `/admin/coverage`, `/admin/freshness`, `/admin/features`, `/admin/prompt-signals`, `/admin/analytics`):

| View | Purpose |
|---|---|
| Opportunity queue | Demand confidence, gaps, lane, rank, effort, selected or deferred, and reasons. CLI report first |
| Source discovery | Resource and edition metadata, acquisition method, rights evidence, linked objectives, candidate status. CLI report first |
| Acquisition jobs | Batch scope, stage, resource use, extraction losses, retries, blockers. GitHub workflow run summary first |
| Existing `/admin/coverage` | Source and role coverage, evidence, gaps and fill list |
| Existing moderation and refresh queues | Source nominations, corrections, disputes, review decisions, takedowns |
| Existing `/admin/freshness` | Changed sources, rights changes, affected releases, replacement decisions (champion/challenger screen) |
| Quality and outcome reporting | Gate status, confidence of learner signals, missing assessments, pilot comparisons |

Do not build a second admin application. Private intake is never exposed to ordinary users. Role checks are enforced server-side. Bulk operations are allowed only on validated records, with a preview, bounded selection, authorization and an audit trail. High-risk bulk publication stays behind the current controlled workflow. Keep the approval load low by grouping compatible source releases, but never grant implicit permission to new editions or asset classes.

### 11.2 Learner experience

Keep the Learn / Library / Progress navigation and the always-available Help (`?`) control. Within selected goals, distinguish official requirements, LearningApp teaching, external resources, community drafts, and review and validation labels. Show where a resource helps, what it costs if known, whether sign-in is needed, what remains uncovered, and the next meaningful action. Offer choices without burying the recommended route. A missing item should offer eligible alternatives, Ask for it, or a private creation path (the existing Need cards); it must never pretend coverage exists. External-only material stays useful even when AI is unavailable.

---

## 12. Path A and Path C interfaces

**Path A.** The Reuse Gate checks existing content and permitted sources before generation. The selected missing objective-role slots feed the existing prompt cart (#369) and slot wizard. Give AI only source locators and permitted excerpts (only sources with `ai_transform` approved). Require structured validation, attribution and an explicit AI-origin status. Do not pay for operator inference, enable BYOK, or call unapproved providers. Generation fills the unresolved role; it does not recreate a whole chapter.

**Path C.** Keep shared resource IDs, edition, access, objective-role mapping and stable links, so that a learning route can mix local and external assets. Keep the existing five levels, from a plain link up to a guided external path (companion plans, #367). Provide independent checkpoints and return anchors. No external completion tick counts as canonical mastery or readiness. Future provider integrations must use approved APIs, embeds or agreements, and keep consent, terms, access costs and evidence authority separate. Do not make provider integration a blocker for the ingestion pilot, and do not remove the third objective.

---

## 13. Free-first operations and security

Use repository jobs and CLI tools, local deterministic processing, existing free-tier hosting, compact metadata, incremental changes and caching where the terms allow it. Do not download every discovered resource or store every version unnecessarily. Run one acquisition batch at a time.

**Configurable limits.** Proposed pilot defaults:

- 20 source sections (pages) per batch;
- 25 MiB downloaded per batch, summed over all responses;
- a 10-minute network job timeout, on top of the importer's existing 60-second per-request timeout;
- 2 retry attempts.

Tailor these per adapter and approve any increases. **(v1.1)** The OpenStax importer already fetches page by page, so these limits do not require a redesign; add a byte counter and a section cap to `fetch`.

Track actual requests, bytes transferred, bytes stored, execution minutes, review minutes and any operator-paid spend separately. Handle large documents as approved exceptions or in smaller slices; never silently truncate essential content. Stop or degrade before exceeding provider or CI quotas, since free tiers do not guarantee unlimited service. The manual workflow stays available when automation is paused.

**Security.** Treat metadata indexing and content extraction as separate trust boundaries. Use least privilege and restricted secrets: no database admin credentials in Flutter, source parsing, AI chat or public logs. Validate MIME types, cap archive expansion, sandbox parsers, strip active content and external resource loads, and protect against prompt injection and path traversal. RLS restricts research drafts. Test unauthorized reads, writes and publication attempts. Disabling a feature must preserve data, existing functionality and the path to re-enable it. Never reset production or change existing user permissions. Use additive migrations only where required. Backup and restore and the controlled deploy rules remain mandatory.

### 13.1 Feature controls (v1.1)

Per `AGENTS.md` (FLAG-010/016), each new runtime feature gets a stable key in `lib/models/governance/site_feature_keys.dart`, a reviewed additive default-OFF seed in `private.site_feature_controls` through the guarded migration path, and parity checked by `python3 tool/verify_feature_registry.py`. Wire real server gates at the read, write and side-effect boundaries, and test bypass attempts. Proposed keys, named only when the corresponding package is built:

| Proposed key | Covers | Default |
|---|---|---|
| `content.acquisition_admin` | Admin views for the opportunity queue, source discovery and acquisition jobs, if they move beyond CLI reports (IN-7) | OFF |
| `content.teaching_only_sections` | Learner-visible teaching-only imported sections with a visible assessment gap (IN-5/IN-6), if this changes learner-facing behavior beyond the existing lesson renderer | OFF |
| `analytics.pilot_outcomes` | Any new consented pilot-outcome instrumentation (IN-8), on top of the existing analytics consent | OFF |

CLI tools, research files and CI checks are not runtime features. They are controlled by code review and by approvals in the `supabase-production-deployment` environment for any production run. Ingesting content through the existing controlled workflow needs no new key.

---

## 14. Delivery work packages and acceptance

| Package | Deliverables | Exit criteria and dependencies |
|---|---|---|
| IN-0 Baseline and contracts | Reverify `main` and hosted status (which manifests and versions are published); existing source and demand schema; manifest rights; feature controls; current tests. Reconcile stale docs: runbook scope, Psychology license in the three files, runbook "proposed" vs registry "candidate". **(v1.1) Audit every manifest's `sha256` and license fields and list the placeholders** | Inventory of reuse and extension decisions and known blockers. No production mutation |
| IN-1 Demand and portfolio | Opportunity research files and validator, lane allocation, scoring tests, initial candidate briefs | Existing demand engine and table reused; no unsupported rankings; owner selects the first slice |
| IN-2 Source discovery | Metadata directory (research files), separation of candidates from source policy, source feasibility and rights workflow | At least two relevant source alternatives investigated for each pilot where available; an absent alternative is documented; no bulk payload intake |
| IN-3 Staging and adapter contract | Bounded acquisition jobs (section and byte caps), deterministic adapter fixtures, loss reports, normalized manifest preview | Existing OpenStax and personal routes preserved; repeated runs are idempotent; unsupported content is reported explicitly; `CODEBASE_MAP.md` updated if owners move |
| IN-4 Rights and quality gates | Explicit operation metadata, frozen discrepancy allowlist, pin and license-ID checks, fidelity and assessment gates, release and takedown tests | Missing or disallowed rights, placeholder pins and incorrect answers fail closed for applicable publication; no silent deletion of legacy material |
| IN-5 Objective mapping and optimization | Coverage Matrix extended, concept matching, prerequisite and role mapping, coherent learning units | Teaching-only and check coverage kept separate; reuse before generation; accessibility and motivation criteria recorded |
| IN-6 Pilot content and assessment | Selected math or numeracy slice; second task-family slice (Excel proposed) once approved; Bridges and independent checks | Both slices pass the applicable gates; learners can study without AI; no claim of complete credential readiness |
| IN-7 Operator integration | Extend existing admin reports, queues, rights and freshness, review actions and quota flags | Unauthorized users denied; workflow restart, cancel and recovery tested; replacement continuity tested |
| IN-8 Learner validation | Consented pilot, outcome and learning-efficiency metrics, comparison plan, evidence report, **privacy review (v1.1)** | Observed limitations reported; no claims of scale or efficacy from inadequate data |
| IN-9 Selective expansion | New opportunity review, choice of next sources and adapter, maintenance and refresh | Owner approves based on demand, unmet need, capacity, quality and pilot evidence |

IN-1 and IN-2 can run at the same time once the IN-0 baseline is done. IN-3 and IN-4 should share fixtures and proceed in small changes. Do not wait for a comprehensive source directory or admin UI before improving the existing importer. Rights remediation (Psychology, manifest pins, D-7) is independent of acquisition expansion and can start earlier. If the selected opportunity does not need an adapter, defer it without removing it from the roadmap.

**Suggested PR slices** (adjust to actual repository dependencies; no implementation is authorized yet):

1. Audit and docs only. Includes the runbook scope fix and the Psychology doc reconciliation once D-5 is decided.
2. Manifest pin and license audit, plus the CI placeholder check (warnings first, then fail closed for new manifests).
3. Demand research files, validator and decision tests.
4. Source inventory and metadata validation.
5. Rights operation and legacy migration strategy, with the frozen discrepancy allowlist.
6. Importer interface and fidelity fixtures.
7. Separation of teaching-only and assessment content (College Algebra 1.4 and 1.5).
8. Objective mapping and coverage.
9. First selected content slice, with provenance.
10. Gated operator integration.
11. Learner-validation instrumentation and pilot review.

---

## 15. Test matrix and release controls

- **Demand:** normalization within the same unit, period and geography; missing vs zero vs suppressed; duplicate syndicated observations; stale input; low-confidence scores; lane allocation; override audit; no fabricated rank; unknown source feasibility cannot pass the acquisition gate; the research-file validator rejects personal data fields.
- **Rights:** exact edition mismatch; wrong use; unknown license; NC or SA restriction; separately licensed image; redistribution vs adaptation; stale or revoked permission; untrusted candidate; historical release evidence; enforcement of explicit operations in manifests; takedown scope; **placeholder or shared `sha256`; free-text license with no registry ID (v1.1)**.
- **Acquisition:** partial download; wrong MIME type; malformed XML, HTML or PDF; oversized or zip-bomb payload; redirect to a private address; script, macro or prompt injection; network failure; timeout; quota; idempotent replay; cancel and resume; stable IDs; no partial publication; section and byte caps enforced.
- **Fidelity:** source-locator round trip; expected heading and exercise counts; tables; mathematical meaning; missing visual dependencies; skipped material; unsupported tags; lost answers; multipart alignment; representative renderer screenshots and manual accessibility checks as appropriate.
- **Learning:** correct concept and depth; duplicate vs distinct concept; prerequisite cycles; route override; reading-only status; fallback for unsupported scoring; separation of independent assessment; remediation return anchor; resume on mobile and offline; learner choice and honest progress.
- **Security and deployment:** clean and incremental migration tests if the schema changes; pgTAP and Flutter tests; linter and dry run; role denial; isolation of protected keys; wrong-project guard; backup and rollback; feature disable and re-enable; compatibility of existing legacy routes; hosted smoke checks after owner-authorized deployment.
- **Lifecycle:** source version change; rights complaint; replacement with stable objective IDs; renamed, split or merged lessons; no duplicate progress; stale independent evidence; retired history retained. Never transfer mastery solely because titles match. Distinguish navigation continuity from evidence validity, and preserve source lineage.

Before publication, capture the actual commit SHA, the exact manifest hash, source versions, applicable gate outcomes, test results, and the authorized reviewer's or owner's decision. No high-stakes validation claim without the appropriate evidence. New pilot content may be labeled clearly as source-attributed, automatically checked and unreviewed where allowed. Never invent a reviewer or imply an official endorsement.

---

## 16. Measurement and continuous improvement

### 16.1 Supply and reliability metrics

| Metric | Definition and guardrail |
|---|---|
| Objective-role coverage | Weighted coverage of eligible objectives and roles over a defined target scope; internal and external, draft and independent checks shown separately |
| Acquisition precision | Useful source-role mappings selected ÷ source-role candidates reviewed; includes rejected and unknown cases |
| Source-to-publish yield | Eligible published slices ÷ approved acquired slices; blocked rights, gaps and failures shown separately |
| Rights and provenance completeness | Required operation, edition, locator, attribution **and a real pin or recorded null (v1.1)** complete; target 100% on applicable public releases |
| Extraction defects | Known material discrepancies per audited unit, reported with the sample denominator and severity |
| Scoring defects | Invalid keys, unfair grading or leaked protected answers; critical defects block the affected scored use |
| Maintenance effort | Operator minutes, plus storage, requests and CI use, per useful slice; stale-source backlog |
| Reuse and avoided generation | Objectives served by existing assets or lawful external resources before new generation; measured by the role actually resolved, not by link clicks |

### 16.2 Learner outcome and motivation metrics

Record baseline ability where appropriate, the task and target version, the chosen route, exposure, time on task, independent accuracy, transfer and later retention, using the existing consent and event ledger. No personal learner data in source research or public rankings. Distinguish:

- a proxy for active study from total time;
- estimated from actual;
- assisted from independent attempts;
- absence of evidence from failure.

Repeated practice alone is not mastery.

**Proposed primary metrics:**

- delayed independent performance (for example, follow-ups at 7 and 30 days where suitable);
- performance on unseen transfer or authentic tasks;
- the study effort needed to reach a defined competence threshold.

**Secondary metrics:** recovery after difficulty, attainment of meaningful milestones, perceived clarity and agency, optional return behavior, and accessibility barriers.

Real exam, credit or job outcomes are optional and consented. Self-reports and verified results are kept distinct, with their selection bias and uncertainty stated. Never imply causal impact from observational data alone.

### 16.3 Pilot evaluation protocol

Define the target-specific competency threshold and the comparison before analyzing results. Compare a faithful source-based route with an optimized route that has the same objective scope and held-out assessments. Where feasible, randomize among volunteers or use a documented matched comparison. Do not withhold needed support or require participants to use a paid resource.

Measure both learning gain and effort. Account for baseline differences, attrition and accessibility. Report sample sizes, confidence intervals and missingness. An initial small pilot is evidence of feasibility, not proof of effectiveness. Choose the sample size and the threshold for a meaningful improvement before drawing causal conclusions, based on the task, its variability and what is feasible. If the sample is too small, report descriptive evidence only. Never publish data about individuals or small sensitive groups (the existing suppression of groups under 5 accounts applies). Honor the existing analytics opt-in, retention and deletion rules.

**(v1.1)** Any route assignment or comparison is new data processing. Before it starts, it needs a written protocol and a privacy review in the form of `docs/privacy/PROMPT_QUALITY_PRIVACY_REVIEW.md`, its own opt-in on top of base analytics consent, the existing age rules (no assignment experiments for accounts under the applicable age threshold), and the owner's approval.

**Scaling criteria:**

- no unresolved critical rights, security, scoring or accuracy issues;
- coherent pilot coverage with honest gaps;
- maintenance and free-tier budget are manageable;
- evidence that learners can complete the learning and assessments;
- no material observed harm or accessibility regressions.

Stronger claims of educational effectiveness require enough comparative evidence and independent outcome validation. While evidence remains weak, extend to another bounded pilot instead of mass ingestion.

---

## 17. Maintenance, correction and expansion governance

Reuse the existing volatility classes V0–V4 and the `/admin/freshness` policy. Track source changes at a meaningful resource or section level, using permitted checksums and metadata, and avoid bulk re-downloads.

- **Source updates.** An update opens a change proposal; it never publishes automatically. Determine the affected assets, objective mappings, assessment versions and learner evidence. Verify a replacement against source facts, usability, quality and outcome evidence. Apply the champion/challenger and patch-first policies.
- **Retirement.** The current owner gate requires a recorded reason for retiring a version; respect it (the database refuses to retire an official version without one).
- **Learning history.** Preserve it. Invalidate or discount evidence only where content, scoring or the competency changed, under the existing rules.
- **Corrections and disputes.** Correct misinformation promptly. Quarantine disputed unsafe content while it is evaluated.
- **Rights restrictions.** Distinguish future acquisition from previously lawful use, and follow a documented takedown and appeal workflow.

Review the portfolio at a regular cadence the owner sets: proposed monthly for active work and quarterly for demand evidence. This draft creates no automatic recurring jobs. Each review compares opportunity rank, capacity, learner outcomes, missing roles, source freshness, maintenance cost and newly discovered alternatives, then promotes, defers, improves, links, retires or expands each item with a reason. Expansion is never automatic just because an importer can process more pages. Lower-demand opportunities stay discoverable in the research inventory and become candidates when evidence, strategic reuse or public value warrants it.

---

## 18. Owner review decisions and definition of done

### Decisions requested before implementation

| # | Decision | Proposed default |
|---|---|---|
| D-1 | Acquisition portfolio | 55% high-demand unmet need / 25% underserved / 20% reusable foundations, measured in operator minutes per cycle; adjustable |
| D-2 | First research scope | US exam, education and workforce evidence plus broader open-source discovery; record language and geography explicitly; expand internationally based on need |
| D-3 | First engineering pilot | The existing math and numeracy adapter on a selected objective slice (College Algebra 1.4 and 1.5 teaching-only, plus algebra Bridges). Second task family: Excel, unless the evidence picks another |
| D-4 | Rights posture | Keep NC and SA adaptations blocked until a compatible policy and implementation exist; no blanket source approval |
| D-5 **(v1.1)** | CLEP Psychology edition | Re-point `clep_introductory_psychology.yaml` and the two CLEP docs to **Psychology 1st edition** (CC BY, already approved for `adapt`); keep 2e as a link-only companion |
| D-6 **(v1.1)** | Manifest source pins and licenses | Recompute every `sha256` from a lawfully retrieved copy, or drop it and use the convention `clep_college_algebra.yaml` already follows (`checksum_status: unverified_remote_document` plus a note); map license text to registry IDs; CI warns on placeholders now and fails for new or changed manifests after IN-0 |
| D-7 **(v1.1)** | Close-to-verbatim OpenStax import | Either (a) approve `redistribute` for the three CC BY 1e sources (CC BY 4.0 permits it), or (b) keep `adapt` only and require the importer's change log to show real changes. **Proposed: (a)**, recorded in the registry with `decided_by`. Until decided, do not import beyond the pilot chapters |
| D-8 | Operator economics | No new paid inference, reviewers, data feeds or hosting; enforce bounded jobs |
| D-9 | Publication policy | Existing owner-controlled workflow, honest review labels, no automatic public promotion |
| D-10 | Prioritization model | Existing demand ranking plus a separate provisional acquisition priority with confidence; revisit after the pilot |
| D-11 **(v1.1)** | Demand evidence storage | Version-controlled research files first; a database migration only once the shape is stable and a database copy is needed |
| D-12 | Scope boundary | No comprehensive web crawl, speculative all-format engine, full-textbook import requirement or parallel content platform |

### Definition of done for this initiative

This covers the initiative, not every educational domain. The initiative is done when a reproducible workflow from research to publication can:

- find meaningful opportunities and source leads without indiscriminate ingestion;
- prioritize using auditable evidence and an equity lane;
- acquire only permitted, selected resources, with real source pins;
- normalize them faithfully;
- integrate them into the existing curriculum and learning architecture;
- produce independent assessment where appropriate;
- keep rights and quality labels honest;
- enable motivated, efficient learner progress;
- measure and improve real outcomes;
- remain operable within the current free-first constraints;
- support at least two materially different learning task families;
- expand only through deliberate portfolio decisions.

All existing product features and third-party integration goals remain intact.

---

## 19. Repository references and research leads

### Existing implementation and contracts (verified at `6033de6`)

- [Content Intelligence v2.6 master plan](LEARNINGAPP_CONTENT_INTELLIGENCE_AND_GAP_RESCUE_MASTER_PLAN_V2_6_2026-11-11.md): §§4, 5.6, 6, 7, 8, 9, and the implementation status (updated 2026-11-21, with 2026-11-23 notes)
- [Catalog Growth and Demand Plan](docs/catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md); [P1 Official Demand Runbook](docs/catalog/P1_OFFICIAL_DEMAND_RUNBOOK.md); `tool/catalog_official_demand.py`, `tool/catalog_intake.py` and their tests in `tool/tests/`
- [Content Ingestion Runbook](docs/content_intelligence/CONTENT_INGESTION_RUNBOOK.md); [Content Supply and Reuse Map](docs/content_intelligence/CONTENT_SUPPLY_AND_REUSE_MAP.md); [Baseline and Compatibility Audit](docs/content_intelligence/00_BASELINE_AND_COMPATIBILITY_AUDIT.md)
- Source registry `data/content_sources.json`; CI verifier `tool/ci/verify_content_sources.py`; open index `assets/open_content/index.json`
- Open textbook importer `tool/import_open_textbook.py`; `tool/ingest_curriculum.dart`; `.github/workflows/controlled-curriculum-ingestion.yml`; `curriculum-freshness.yml`; `external-link-check.yml`
- Reuse Gate `lib/services/content_generation/reuse_gate.dart`; open-content index service `lib/services/content_generation/open_content_index.dart`
- Feature registry `lib/models/governance/site_feature_keys.dart`; `tool/verify_feature_registry.py`
- Curriculum manifests in `content/` (nine: seven authored and two open-textbook)
- [Codebase map](docs/engineering/CODEBASE_MAP.md); [Learning Architecture V2](LEARNING_ARCHITECTURE_V2.md); [UI Architecture (locked)](UI_ARCHITECTURE_LOCKED.md); [CLEP Program Guide](docs/catalog/CLEP_PROGRAM_GUIDE.md)

### Public research starting points (not acquisition approvals)

- NCES IPEDS, BLS Employment Projections, O*NET Resource Center: verify the relevant release, definitions, access terms and observation period when collecting data.
- Oregon State OER directory, University of Florida OER guide, Virginia Tech open textbook guide: for source discovery only; each publisher and edition needs its own rights decision.
- IES WWC practice guide on organizing instruction and study, and MIT Teaching + Learning Lab: starting points for task-appropriate instructional design, not proof of LearningApp efficacy.

*End of review draft v1.1.*
