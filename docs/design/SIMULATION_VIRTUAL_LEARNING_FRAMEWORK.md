# LearningApp Simulation & Virtual Learning Framework

**Architecture and Product Proposal, v0.11 (draft for review)**

Status: discussion draft, not an approved technical specification. Date: November 7, 2026. Supersedes v0.1 through v0.10 of the same date. Repository basis: `RACCHUS/LearningApp` `main` at commit `baa26c0`, read-only review of documents and key source files. No build or test run was performed.

## 1. What changed from v0.1

v0.1 proposed an engine-independent simulation framework and recommended repository discovery before any commitment. This version completes the first pass of that discovery and revises the proposal accordingly.

1. Added a **Phase 0 gap analysis** (section 3) grounded in the repository.
2. Added a **native Flutter runtime tier** below Phaser. Several existing in-app simulators already prove this tier works and inherit the app's audio, voice and contrast work.
3. Replaced the bespoke manifest with a **thin extension of the existing task taxonomy** (`LearningTaskProfile`, `AssessmentPolicy`) instead of a parallel metadata system.
4. Made **server-recomputed scoring** the evidence model, with explicit evidence tiers, instead of generic "validate events when possible."
5. Added **platform changes the draft did not know about**: CSP and frame headers, a database CHECK constraint on lesson block types, caching behavior, and the locked UI baseline.
6. Reordered the proof-of-concept plan and added exit gates.
7. Made accessibility a **manifest requirement** rather than "where feasible."

Unchanged from v0.1: simulations are learning activities, not games; modular engines; lazy loading; core-app independence; template-first AI authoring; Roblox as an optional external adapter only.

### Changes in v0.3 (from design review)

1. **Isolation is a hypothesis to test, not a settled architecture.** The sandboxed same-origin iframe is the preferred option to evaluate; the spike must compare it with alternatives and define the security boundary (section 4.3).
2. **Three scoring classes** replace one scoring technique: deterministic, structured and free-form (section 5.1).
3. **The shared contract is deliberately small.** Lifecycle, result and evidence only; interaction models stay engine-specific (section 4.2).
4. **Readiness reconciliation is done at design level.** Evidence tiers describe an attempt, not content eligibility, and feed the existing concept-evidence path; they do not create a second readiness system (section 5.1).
5. **MVP boundary and Phase 0 deliverables are explicit** (sections 8 and 9). No framework code, schema change or security-header change is merged until the Phase 0 design note is reviewed.

### Changes in v0.4 (from second design review)

1. **Practice telemetry is separated from mastery and scheduling evidence.** The `record_events` hardening gates only the second. The Phase 0 note decides whether unverified events can safely use the existing pipeline (section 5.2).
2. **No credentials or learner identifiers in simulation runtimes by default.** Network access is mediated by the host (sections 4.2 and 5.5).
3. **Action traces are treated as sensitive**, with required limits defined before any attempt table exists (section 5.5).
4. **"Verified" is scoped to what was validated**, never to learner competence (section 5.1).
5. **Phase 0 has a stop condition** of six questions (section 9).
6. **The first simulation is narrowly educational**, and the first success criterion is measurable learning (section 8).

### Changes in v0.5

The four owner decisions in section 10 are adopted at their recommended defaults: networking first (HVAC second), nothing from unverified evidence counts toward mastery, anonymous learners can practice without evidence persistence, and WCAG 2.2 AA is the accessibility target for native simulations. The owner can reverse any of them.

### Changes in v0.6

1. **Anonymous practice leaves no server-side trail**, including analytics, event-outbox records and traces with identifiable session data (section 5.5).
2. **"One contract across tiers" means one lifecycle contract**, not identical capabilities. Adapters declare unsupported capabilities and handle them predictably (section 4.2).
3. **The learning measurement is defined to avoid practice effects**: baseline, equivalent post items, delayed retention where practical, and a comparison or alternative-explanation analysis (section 8).

### Changes in v0.7

1. **The anonymous-practice promise is defined precisely** and audited across every path; it does not claim that infrastructure retains no connection logs (section 5.5).
2. **Completion telemetry is separated from scored evidence.** Client-asserted scores, ratings and scheduler state never go through an RPC that accepts them unvalidated (section 5.2).
3. **Completion submissions carry version identity and idempotency** (section 5.2).
4. **The full-screen route has explicit Help, exit and failure behavior** for the locked-UI amendment (section 4.4).
5. **The learning experiment has a realistic scope**: a small pilot finds usability and measurement problems and makes no causal claims (section 8).

### Changes in v0.8

1. **Same-origin iframe is not described as a security boundary** until a specific sandbox configuration and threat model are demonstrated, and the opaque-origin message validation is explained (section 4.3).
2. **Terminology is fixed:** exploratory, completion telemetry, unverified result, verified result. Phase 1 records completion telemetry and personal study progress only, never mastery evidence (sections 5.1, 5.2, 8 and 9).
3. **Attempt identity is server-controlled**, with a database uniqueness constraint, a defined scope and retries that return the original result (section 5.2).
4. **Server-canonical concept projection is a Phase 2 acceptance criterion**, not only a design consideration (section 9).
5. **The accessibility decision is reconciled** between sections 7 and 10.
6. **"Completion is not learning" is a formal principle** of the evidence model (section 5.1).

### Changes in v0.9

1. **Two separate database constraints** for attempt identity and idempotency, with server rejection of mismatched versions (section 5.2).
2. **Authenticated and anonymous telemetry are separated explicitly**, including accidental capture by analytics, crash reporting and the outbox (section 5.5).
3. **The iframe threat model is broader than message validation** (section 4.3). T1 and T2 stay out of Phase 1.
4. **PoC A's server-scoring check is a test-only prototype**, not production evidence processing (section 8).
5. **Phase 1 has a minimal event vocabulary**, and a missing completion event is never a failed assessment (section 5.2).
6. **A permanent architectural rule:** simulation attempts are a source of learning evidence, not a separate learning system (section 5).

### Changes in v0.10

1. **Repository update.** Newer commits on main add migration `arch_04`, which changes the picture on idempotency and on who writes concept state. The doc now records what it fixes and what it does not (section 3, row 15, and section 9).
2. **Idempotency uses independent rules** (attempt identity, one accepted completion per attempt, request-level idempotency) and explicit acceptance tests (section 5.2).
3. **The Phase 1 write path has required properties** and prefers a dedicated completion-only path over changing the general event pipeline (section 5.2).
4. **Anonymous local progress** is ephemeral or device-local and is never synchronized or migrated to an account (section 5.5).
5. **The iframe threat model is turned into acceptance tests**, a Phase 3 concern (section 4.3).
6. **Accessibility alternatives must be equivalent**, and basic requirements apply to all tiers (section 7).
7. **The test-only scoring prototype has hard boundaries** (section 8).
8. **The Phase 2 gate is restated** as server-computed evidence values and server-validated concept mapping (section 9).

### Changes in v0.11

1. **The `ConceptEvidenceService` conflict with arch\_04 is a priority Phase 0 investigation**, with call-site findings so far and five questions to answer (section 9).
2. **The attempt lifecycle is specified**, not only its constraints (section 5.2).
3. **The Phase 1 completion event contract is exact**: source, repeatability, ordering, offline behavior, and what each event does not mean (section 5.2).
4. **Anonymous progress is ephemeral by default**, with testable storage rules if device-local progress is ever added (section 5.5).
5. **Phase 0 stop conditions are a table of seven areas**, including evidence architecture and attempt handling (section 9).
6. **Outdated `record_events` hardening wording is corrected** in sections 3, 5, 9, 11 and 12. arch\_04 is a necessary foundation, not a sufficient condition.

## 2. Summary and principles

LearningApp should treat interactive simulation as a first-class learning modality alongside lessons, flashcards, assessments and tutoring. The framework integrates existing engines and tools behind one activity contract and does not build a game engine.

Principles (retained from v0.1, condensed):

1. Learning outcomes first; complexity must be justified by educational value.
2. Modular engines behind one contract; no lock-in.
3. Lazy loading; ordinary lessons pay nothing for simulation code.
4. Progressive capability: native, then 2D/3D in isolation, then heavy or external.
5. Core-app independence; a failed simulation never breaks a lesson.
6. Accessibility by design, including pre-reader and audio-first access.
7. Cross-device awareness; do not assume modern GPUs or fast networks.
8. Safe practice; simulated permission is not real-world authorization.
9. Evidence-based assessment with minimal, privacy-conscious telemetry.
10. Scenario definitions separate from engine implementation where practical.
11. AI-assisted, not AI-trusted.
12. Cost-aware operation.

A simulation is chosen because it improves learning, not because it is impressive.

## 3. Phase 0 gap analysis (repository findings)

Findings marked **verified** were read in the repository. Items marked **to confirm** need a follow-up check before implementation.

**Repository update.** Rows 1 to 14 were written against commit `baa26c0`. Three newer commits on main (through `dd3f899`) add migration `20261107050000_arch_04_learning_events_strict_rules.sql`. Row 15 records its effects and supersedes rows 7, 8 and 14 where they differ.

| # | Area | Finding | Implication |
| --- | --- | --- | --- |
| 1 | Existing simulators | Four Flutter widgets (DMV exam, USCIS civics, currency/ATM, Rx and first aid), about 3,100 lines total, are mounted directly on the life-domains and life-milestones screens. No references to `LearningEvent` or the event outbox were found in them. **Verified.** | They are working native-tier simulations that produce no progress or evidence. Wiring them is the cheapest first proof of the framework. |
| 2 | Task taxonomy | `docs/learning_science/02_LEARNING_TASK_TAXONOMY.md` already defines `procedural_execution`, `perceptual_diagnostic`, `reference_navigation`, response channel `ordered_checklist`, `reference_policy`, and `AssessmentPolicy`. **Verified.** | A simulation activity should carry these profiles. Do not invent a competing metadata model. |
| 3 | Lesson blocks | `LessonBlockType` has eight values. `fromString` defaults unknown strings to `markdown`. The renderer is an exhaustive switch. `block_type` has a database CHECK constraint (migration `20261004000000_content_primitives_v2.sql`, and again in `deploy/self-host/init-scripts/01-full-schema.sql`). **Verified.** | A new block type needs an append-only migration, enum and serializer changes, and an explicit unsupported-client fallback. Without a fallback, older clients would render a new block as markdown. How the self-host schema file is regenerated is **to confirm**. |
| 4 | Lazy loading | `router_provider.dart` uses Dart `deferred as` for about nine screens. No `HtmlElementView`, iframe or JS engine interop exists in `lib/`. **Verified.** | Dart-side lazy loading is a proven pattern. Loading a JS engine is new ground and needs its own spike. |
| 5 | Security headers | Both `web/_headers` and `firebase.json` set `default-src 'self'`, `script-src 'self' 'unsafe-eval' 'unsafe-inline' https://www.gstatic.com`, `connect-src` limited to self and Supabase, no `worker-src`, no `frame-src`, and `X-Frame-Options: DENY` on all paths. **Verified.** | CDN-hosted engines are blocked. Blob workers (used by some 3D decoders) are blocked. Any iframe, including same-origin, is blocked by `DENY` and the default `frame-src`. External platforms such as Roblox cannot be framed. Both config files must be changed together. Which host is authoritative for production is **to confirm** (README says to verify). |
| 6 | Caching | `/assets/*` is cached for one hour with `must-revalidate` and no content hash. **Verified.** | Engine bundles and scenes need hashed filenames and their own cache and offline strategy. |
| 7 | Event pipeline | `learning_events` is append-only with `response`, `metadata`, `hints_used`, `latency_ms`, `confidence` columns. `record_events` accepts client-supplied `score` (clamped to 0 to 1), `rating`, `scheduler_state_after` and event `id`, and performs no validation of `item_type` or `event_type`. **Verified.** | A `simulation` item type works without a table change, but the RPC cannot satisfy "do not trust client score claims." Superseded in part by row 15: arch\_04 added idempotency and a server-side projection boundary, but client-asserted scores and concept IDs remain. |
| 8 | Server scoring precedent | The EXM work (`20261101130000` through `20261101180000` migrations) implements assigned practice, authenticated submission and protected-item scoring on the server. **Verified by file names; function bodies not reviewed.** | Reuse the pattern: client submits an action trace, server scores against a versioned rubric. |
| 9 | xAPI and cmi5 | `lib/services/interop/` converts events to xAPI 1.0.3 statements and builds cmi5 manifests and launch statements. No callers outside that folder were found. **Verified.** | A capability exists but is not wired into the app. Designing simulation events to map to xAPI is cheap and keeps export options open. |
| 10 | Locked UI | `UI_ARCHITECTURE_LOCKED.md` v1.6 fixes three destinations (Learn, Library, Progress), required Help chrome, and a Learn screen limit of five interactive elements in the default state. **Verified.** | Simulations must not add a destination. Any new route needs an explicit amendment in that document. |
| 11 | Accessibility baseline | A literacy and accessibility plan, text-to-speech, voice input, and a contrast audit test exist. **Verified.** | Native-tier simulations inherit these. Canvas and WebGL content does not, and needs an operable alternative. |
| 12 | Platform target | Documentation and deployment describe a Flutter PWA. Native packages are present but nothing indicates a shipped native app. **Verified for docs; shipping status to confirm.** | Scope Phase 1 to the PWA. |
| 13 | Offline | Local persistence uses Hive and SharedPreferences, and the event outbox is account-scoped. Service-worker behavior was not reviewed. | Offline simulation support is **to confirm** and should stay out of Phase 1. |
| 14 | Readiness and concept evidence | 07 defines six provenance properties, item-level readiness eligibility and four evidence layers. ConceptEvidenceService propagates a normalized evidence value (0 to 1) to mapped concepts in user\_concept\_state and is called from the client. Verified for the specification and client service; the server-side projection was not reviewed. | Simulation evidence must use this path. Tier is not a readiness input. Server-canonical projection should land before simulations feed it. |
| 15 | Event pipeline update (arch\_04) | On main at dd3f899, record\_events requires an idempotency key with UNIQUE (user\_id, idempotency\_key), detects payload mismatches with a SHA-256 digest, takes advisory locks, enforces per-session sequence uniqueness, and stores a client-supplied attempt\_id. Direct client writes to user\_concept\_state are revoked, so projections are written server-side. It still accepts client-supplied score, rating and scheduler state; derives concept evidence from that score and a client-supplied concept ID without validating the ID against item-concept mappings; and leaves event\_type and item\_type as unvalidated text. ConceptEvidenceService still upserts user\_concept\_state from the client on main, which the revoke should now block (to confirm). Verified by reading the migration; not executed. | Idempotency and the projection write boundary are largely addressed; authoritative evidence values are not. Mirror the idempotency pattern for simulation submissions. The Phase 2 gate narrows to server-computed evidence values and server-validated concept mapping. |

## 4. Revised architecture

### 4.1 Runtime tiers

| Tier | Runtime | Use for | Notes |
| --- | --- | --- | --- |
| T0 | Native Flutter (widgets, `CustomPaint`, drag-and-drop) | Checklists, diagrams, procedure ordering, network or schematic wiring, calculators, scenario branching | No new dependency. Inherits audio, TTS, voice, semantics, contrast. Default choice. |
| T1 | Isolated JS runtime, 2D (Phaser or plain canvas) | Richer 2D that T0 cannot do cleanly | Loaded only on launch, with the isolation approach chosen in section 4.3. |
| T2 | Isolated JS runtime, 3D (Babylon.js or Three.js) | Equipment exploration, spatial tasks | Same isolation. Gated by performance and accessibility spikes. |
| T3 | External or heavy (Godot, Unity, Roblox) | Specialized cases only | Research spikes. Needs header, identity and verification decisions. |

Rule: use the lowest tier that serves the learning objective. Phaser is a candidate, not a default; v0.1's engine shortlist is unchanged but sits behind T0.

### 4.2 Activity contract

Every simulation, at any tier, implements one contract:

- Receives a validated **activity configuration** (scenario definition, difficulty, seed).
- Emits **structured events** through one interface and reports completion with an action trace.
- Receives **no authentication token, Supabase credential or learner identifier** by default. If a network capability is required, the host mediates it through a narrowly scoped interface. Direct credentials are prohibited unless a security review explicitly approves the exception.
- Supports start, pause, resume, exit, and release of resources.
- Declares its tier, version, input modes, accessibility alternative, and safety classification.

The manifest from v0.1 section 4.4 is reduced to what the taxonomy does not already hold: simulation ID and version, tier and runtime compatibility, entry point, asset references with hashes and sizes, minimum device profile, input modes, accessibility alternative reference, save/resume support, safety classification, provenance and review status, and hosting origin (internal, third-party, external). Learning objectives, skill and concept links, task profile, and assessment policy come from the existing canonical models.

**Contract scope.** The shared contract covers only: identity and version, start, pause, resume and exit, completion, a structured result, error reporting, and an evidence declaration (scoring class and requested tier). Interaction model, scene description, physics and internal state belong to the simulation or its tier adapter and are not part of the contract. A networking simulator, a virtual chemistry lab and an external Roblox experience should differ almost entirely behind this boundary. A field needed by only one tier goes in that tier's adapter.

**Capabilities.** One contract means one lifecycle, not identical capabilities. Native Flutter, browser 3D and external platforms will not all support the same pause and resume, save and resume, offline use, evidence tier or input modes. Each adapter declares which optional capabilities it supports and handles unsupported ones predictably: the host disables the control or falls back, and never fails silently.

**Provenance.** Content provenance and review status use the six existing properties from `07_READINESS_AND_VALIDATION.md` (origin, visibility, rights status, review status, source authority, version validity) rather than new fields.

### 4.3 Isolation for T1 and T2 (hypothesis to test)

Proposed (to be proven in the spike): serve each JS-engine simulation as a **same-origin static page** under a dedicated path, embedded in a sandboxed iframe, communicating with the app only through `postMessage`.

- Crash and memory isolation: removing the iframe releases the runtime.
- Lazy by construction: nothing loads until launch.
- Engine bundles self-hosted, so the existing `script-src 'self'` still applies.

Required header work: a path-scoped rule so the simulation path can be framed (`X-Frame-Options: SAMEORIGIN` or `frame-ancestors 'self'`) while `DENY` remains elsewhere; `frame-src 'self'`; `worker-src` and `wasm` allowances as the chosen engine needs; verification that `unsafe-eval` and the new rules behave in both hosting configurations.

The spike must decide the iframe `sandbox` flags (with and without `allow-same-origin`) and how Flutter embeds the frame, since there is no existing platform-view code.

The iframe approach adds Flutter embedding, sandbox configuration, a message protocol, accessibility bridging and header changes. It is the preferred option to test, not a commitment. The spike compares at least these options and records the result in a written decision:

| Option | Isolation | Main costs |
| --- | --- | --- |
| Sandboxed same-origin iframe | Separate document and DOM; shared origin unless sandboxed without same-origin | Flutter platform-view work, `postMessage` protocol, path-scoped framing headers |
| Separate-origin static host | Strongest boundary | Second deployment, CORS, session and token handling, offline and caching complexity |
| In-page lazy-loaded module (no frame) | None beyond code review | Simplest; acceptable only for reviewed first-party content, never third-party |
| Web Worker with OffscreenCanvas | Compute isolation only | Limited DOM and accessibility access; browser support varies |

Decision criteria: what a compromised simulation can reach (tokens, storage, DOM), crash and memory release, accessibility bridging, mobile behavior, CSP delta, offline fit, and implementation cost. Third-party or unreviewed content requires isolation regardless of option. T0 needs none of this.

**Sandbox configuration and threat model.** A same-origin iframe that has both `allow-scripts` and `allow-same-origin` can remove its own sandbox attribute or reach the parent's storage, DOM and credentials, so it is not a security boundary. The design note must evaluate each configuration explicitly:

- Sandboxed same-origin iframe without `allow-same-origin` (opaque origin).
- Sandboxed same-origin iframe with `allow-same-origin`, including its security limitations.
- Separate-origin hosting.
- In-page modules, limited to reviewed first-party content.

It must also explain how the parent validates messages when the iframe has an opaque origin. The origin string is then `null` and cannot identify the sender, so validation would rely on the frame's window reference, a per-attempt channel such as a `MessageChannel` port, a nonce, and strict message schemas. Until an exact sandbox configuration and threat model are demonstrated, no same-origin iframe is described as a strong security boundary.

**Further threat-model review items.** Message validation is only part of the boundary. The design note also reviews:

- Network requests and possible data exfiltration.
- Access to authenticated same-origin endpoints.
- Cookies, local storage, IndexedDB and service-worker interactions.
- Navigation, popups, downloads and form submission.
- Referrer leakage.
- Content Security Policy restrictions on network destinations.
- Runtime termination and resource cleanup.

A `null` origin must never be treated as sufficient validation. T1 and T2 stay out of Phase 1, and no implementation time is spent on this threat model until the native framework has demonstrated value.

The design note turns the review list above into concrete acceptance tests:

| Test | Expected behavior |
| --- | --- |
| Simulation attempts to access the parent DOM | Blocked |
| Simulation attempts to read parent storage | Blocked |
| Simulation attempts unauthorized API requests | Blocked |
| Simulation attempts navigation or a popup | Blocked unless explicitly permitted |
| Simulation sends malformed messages | Rejected |
| Simulation sends oversized messages | Rejected |
| Simulation is terminated | Resources released |
| Simulation attempts to leak referrer information | Restricted |
| Simulation attempts to impersonate another frame | Rejected |

The review also covers cookies, service-worker scope, form submission, downloads, permissions and network egress. This is a Phase 3 concern, not a Phase 1 requirement.

Message protocol (all messages schema-validated, origin-checked, size-capped and rate-limited):

| Direction | Message | Purpose |
| --- | --- | --- |
| host to sim | `sim:init` | Configuration, seed, device profile (no credentials or learner identifiers) |
| sim to host | `sim:ready` | Runtime loaded and interactive |
| sim to host | `sim:action` | One learner action, minimal fields |
| sim to host | `sim:hint` | Hint requested or shown |
| sim to host | `sim:complete` | Completion and compact action trace |
| sim to host | `sim:error` | Recoverable or fatal failure |
| host to sim | `sim:pause`, `sim:resume`, `sim:exit` | Lifecycle |

The host treats every sim message as untrusted input.

### 4.4 Integration with lessons and navigation

- Add a `simulation` lesson block type that references a simulation ID and version, so simulations appear inside lessons and practice steps.
- Launch as a **full-screen route from Learn or a lesson**, not a fourth destination. Record this in `UI_ARCHITECTURE_LOCKED.md` as an explicit amendment, including how Help remains reachable.
- Every simulation has a **non-simulation fallback block** that older clients and failed loads render.

**Full-screen route requirements** (to be written into the locked-UI amendment; they matter most for accessibility and safety-sensitive simulations):

- Help remains accessible throughout, including during a simulation.
- Exit is always explicit and handles unsaved or incomplete attempts (save, discard or resume, depending on the adapter's declared capabilities).
- Pause and resume are capability-aware, as in section 4.2.
- A failed or timed-out simulation returns the learner to the lesson without losing lesson state, and the fallback block renders.
- No simulation can trap the learner: system back, keyboard escape and an on-screen exit always work, and the host can terminate the runtime.

## 5. Evidence and trust

**Permanent architectural rule.** Simulation attempts are a source of learning evidence, not a separate learning system. The existing concept, skill, task-profile, provenance and readiness architecture remains authoritative. The simulation framework must never introduce a simulation mastery score, a simulation-specific readiness score, a separate learning progression system, a second scheduler, or a parallel evidence database that gradually becomes authoritative. In professional subjects such as HVAC, construction, insurance and healthcare, a simulation result must never be mistaken for actual professional competency.

### 5.1 Scoring classes and evidence tiers

| Scoring class | What the server can do | Highest evidence tier |
| --- | --- | --- |
| Deterministic scenario (rule-based, such as networking or procedure ordering) | Replay the action trace against the versioned scenario model and recompute the score | `verified` |
| Structured scenario (milestones and rules) | Validate required milestones, ordering rules and bounds; it does not reconstruct every interaction | `verified` for the validated milestones only; the rest `unverified` |
| Free-form simulation (3D manipulation, physics, open exploration) | No defensible recomputation | `unverified`, unless a reviewed mechanism is defined later |
| Viewed only, no scored action | None | `exploratory` |

Four terms are used consistently:

- `exploratory`: the learner opened or viewed the simulation.
- **Completion telemetry**: the client reported that the learner completed or exited the simulation. It carries no score.
- `unverified` result: the client reported an outcome, such as a score or rubric result, that the server has not validated.
- `verified` result: the server recomputed or validated the outcome under a versioned scenario and rubric.

Completion telemetry is a record of activity, not evidence of learning. Each simulation declares its scoring class in its manifest, and a simulation cannot claim a higher class than its scenario definition supports.

**What "verified" does and does not mean.** A verified scenario result does not mean the learner is verified as competent. A verified milestone is only evidence that the server validated that milestone under a specific scenario and rubric version. Readiness, mastery, certification and competency remain governed by their existing rules. This matters most for HVAC, healthcare, construction and other professional subjects.

**Principle: completion is not learning.** A learner can complete a simulation without demonstrating learning.

- Opening a simulation is not progress toward mastery of its subject.
- Completing a simulation is not proof of understanding.
- A correctly completed, validated task may become evidence only after server verification under a versioned rubric, and only through the existing evidence path.
- Retention and transfer require separate assessment.

Completion and engagement figures may be reported as usage metrics, never as learning progress.

**Reconciliation with the existing readiness model.** Based on `07_READINESS_AND_VALIDATION.md` and the evidence propagation contract cited in `ConceptEvidenceService`. Proposed rules:

- Evidence tier describes an attempt; readiness eligibility is a property of the content. A simulation carries the same six provenance properties as other items and is official-readiness-eligible only under the existing rule (reviewed against an active official blueprint, authoritative source, active version, blueprint-weighted). A `verified` tier never substitutes for that.
- A `verified` result enters the existing path: a normalized evidence value between 0 and 1, propagated to the mapped concepts in `user_concept_state`, using the activity's task-profile facets (for example `procedural_execution`). There is no parallel mastery score.
- Completion telemetry, `unverified` and `exploratory` results, and any result from content that is not readiness-eligible, appear only in personal study progress, as 07 specifies for unreviewed and AI-generated items.
- Simulations are never item-psychometrically calibrated: at most `observed_uncalibrated`, with no Elo or IRT treatment.
- A simulation does not count as execution under actual exam conditions for exam readiness.
- AI-authored simulations (`origin = ai_generated`) default to private and personal-progress-only until reviewed.

Open items: how partial milestone scores normalize into one evidence value; whether one attempt maps to one or several concepts; how concept state treats non-eligible content today; and whether the client-invoked `ConceptEvidenceService` still works, and what replaces it, after arch\_04. The last item is a priority Phase 0 investigation (section 9).

**Update (v0.10).** On main, direct client writes to `user_concept_state` are revoked and the projection is written only server-side. The evidence value and concept ID are still client-asserted, and the client service still upserts directly (to confirm whether it now fails). See section 3, row 15.

### 5.2 Scoring path

1. Simulation emits actions during play; the host keeps a compact trace in memory.
2. On completion the host submits the trace to a **simulation-specific server function** (new append-only migration), not directly through `record_events`.
3. The server validates the trace against the scenario definition and rubric version, computes the score, and writes a summary event to `learning_events` (`item_type = 'simulation'`) with score, hints, latency and the evidence tier in `metadata`.
4. The full or compact trace is stored in a separate simulation-attempt table with size caps and retention rules, not in `learning_events`.

This follows the EXM server-scoring precedent. The key distinction is **completion telemetry** versus **scored evidence**, not only verified versus unverified. A client can claim that a simulation was completed; that claim is not a validated score.

- **Completion telemetry** (launched, completed, terminated, failed) may be recorded in Phase 1 only for authenticated learners and only if its write path is proven safe. It carries no score and is not mastery evidence: Phase 1 records completion telemetry and personal study progress only.
- **Client-asserted scores, ratings or scheduler state** are never sent through an RPC that accepts them without validating their meaning. `record_events` currently accepts such fields, so it is not used for simulation scores.
- **Scored evidence**, and anything that influences mastery, scheduling, readiness, credentials or official progress, requires server-authoritative validation (Phase 2).

Phase 1 uses a minimal event vocabulary:

| Event | Meaning |
| --- | --- |
| `launched` | The simulation was opened. |
| `completed` | The client reported completion. |
| `terminated` | The learner exited or the runtime ended. |
| `failed` | The runtime encountered a failure. |

These events are not learning outcomes. A completion event is never required: if the learner loses connectivity or closes the browser, no event may arrive. A missing completion event must never be interpreted as a failed assessment.

**Phase 1 write path requirements.** The Phase 0 note must show how the authenticated completion write avoids unintended side effects. It requires:

- Server-derived learner identity.
- Allowlisted simulation event types.
- No client-supplied score, rating or scheduler state.
- No change to mastery, readiness or scheduling.
- Server-controlled timestamps where appropriate.
- Database authorization and ownership checks.
- No accidental outbox replay and no duplicate completion records.

On main, `record_events` accepts free-text event and item types and client-asserted score, rating and scheduler state, so a dedicated completion-only RPC is the likely path (to confirm). If the existing RPC cannot enforce these conditions, Phase 1 uses a dedicated completion-only RPC or local-only progress. The general event pipeline is not modified to accommodate simulations; the smallest safe path is used.

**Completion event contract.** For each event the Phase 0 note defines the required fields and allowed metadata (an allowlist, no free text), who generates it, whether it can repeat, how out-of-order arrival is handled, and what happens offline.

| Event | Generated by | Constraints and meaning | Repeatable |
| --- | --- | --- | --- |
| `launched` | Host | Opened with a server-issued attempt ID | No; once per attempt |
| `completed` | Reported by the runtime, submitted by the host | The client reported completion. It does not mean the learner passed | No; at most one accepted per attempt |
| `terminated` | Host | Records whether the learner exited or the host or runtime ended it, as distinct values | No; once per attempt |
| `failed` | Host | A runtime or infrastructure failure, never a failed assessment; carries a coarse failure category | Bounded number per attempt |

Rules:

- Events arriving after the attempt is closed are ignored or recorded as late, and never change the attempt's state.
- Offline behavior is defined per event as persisted, discarded or kept locally. Default for authenticated learners: kept locally and retried with the same idempotency key for a bounded time, then discarded. Anonymous events are never persisted server-side.
- A missing `completed` event is an unknown outcome, never an inferred failure.
- If Phase 0 finds a safe way to use `record_events`, it must prove that these events cannot populate score, rating, scheduler state, concept evidence or readiness. Otherwise the dedicated completion-only RPC is used.

The Phase 0 note determines whether completion telemetry can use the existing pipeline in isolation from mastery and scheduling. If it cannot, PoC 0 uses local-only progress or a separate safe server write. Server-authoritative scoring and concept mapping, not the arch\_04 idempotency and projection controls that have already landed, are the blocker for scored evidence and scheduling (Phase 2). They are not a blocker for Phase 1 completion telemetry.

Which scoring class applies is declared per simulation and reviewed with the scenario definition. Free-form activities remain `unverified` until a defensible scoring mechanism exists; the framework does not depend on any single scoring technique.

**Submission identity.** Attempt identity is server-controlled; the client is never solely responsible for uniqueness.

A unique attempt ID alone does not stop a client from obtaining a second attempt and submitting the same work again, and adding the attempt ID to an idempotency key is redundant because it is already unique. The design therefore uses independent rules, mirroring the pattern `record_events` already uses on main (a unique learner and idempotency key, plus a payload digest). The database enforces all three:

| Rule | Purpose | Enforced by |
| --- | --- | --- |
| Attempt identity | One server-issued attempt ID identifies exactly one attempt | Primary key on the attempt ID |
| One accepted completion per attempt | An attempt accepts at most one completion submission | Unique constraint on the attempt ID in the completion record, or an attempt-state rule |
| Request-level idempotency | Retrying the same request returns the original result | `UNIQUE (learner_id, idempotency_key)`, with a payload digest that detects a reused key carrying different content |

If the system permits several submission operations within one attempt, request-level keys and completion uniqueness need separate semantics, which the Phase 0 note defines.

Required behavior, written as explicit Phase 0 acceptance tests:

- Same attempt and same idempotency key: return the original result.
- Same attempt and a different key after completion: reject, or return the original completed result.
- New attempt: the server issues a new server-controlled attempt ID.
- Different learner: cannot retrieve or overwrite another learner's attempt.
- Mismatched simulation, scenario, rubric or contract version: reject.

**Attempt lifecycle.** The sequence is:

1. The host requests a new attempt.
2. The server authenticates the learner and creates the attempt, assigning its ID and pinning the simulation, scenario, rubric and contract versions.
3. The host launches the simulation using that attempt configuration.
4. The host submits the completion with the attempt ID and a request idempotency key.
5. The server validates the attempt and atomically accepts at most one completion.
6. A retry with the same key and the same payload returns the original result. Reusing the key with a different payload is rejected. A different key after completion cannot create a second accepted completion.

Database enforcement: a primary key on the server-issued attempt ID; a unique constraint on the completion record's attempt ID; a unique request-idempotency constraint scoped to the learner and operation; a stored payload digest for detecting key reuse with different content; and transactional handling of completion state and result creation. The Phase 0 note decides whether attempt creation is a separate operation or happens atomically with another request. In every case the client cannot invent an attempt identity or turn retries into additional accepted attempts.

- For authenticated attempts, the server generates or authoritatively issues the attempt ID.
- A retry returns the original result and never creates another attempt.
- The server rejects a submission whose simulation, scenario, rubric or contract version does not match the versions recorded on the attempt.
- Simulation, scenario, rubric and contract versions are immutable for the lifetime of an attempt and are recorded on it.
- Each completion submission carries the simulation ID and immutable version, scenario version, rubric version where one applies, attempt ID, idempotency key, and contract or schema version. These are set by the host or server and are not part of the runtime's interaction contract.

The existing events table takes a client-supplied identifier as its primary key. The Phase 0 note must confirm how that interacts with this rule, including that one learner's identifier cannot collide with or shadow another's.

### 5.3 Event vocabulary and xAPI

Define simulation events so each maps to an xAPI verb using the existing interop code: launched, initialized, interacted, completed, passed or failed, terminated. This keeps LRS export and cmi5 packaging possible without committing to them. Wiring xAPI emission into the app is out of scope for this proposal.

### 5.4 Data minimization

Collect only what an objective needs: objective attempted, key decisions, procedure order where it matters, hint usage, safety-critical errors, completion, rubric result. No raw input streams. No learner identifiers in third-party runtimes.

### 5.5 Credentials and action traces

**Credentials.** The simulation runtime receives no authentication token, Supabase credential or learner identifier by default. If a network capability is required, the host mediates it through a narrowly scoped interface. Direct credentials are prohibited unless a security review explicitly approves the exception. This keeps a simulation runtime from becoming a credential-exfiltration path.

**Action traces are potentially sensitive.** Before any attempt table exists, the design note defines:

- Maximum trace size and action count.
- Retention and deletion policy.
- Whether a trace may contain free text (default: no).
- Whether a trace can be replayed or used to identify a learner.
- Access permissions for teachers and institutions.
- Version pinning for scenario, engine and rubric.

For the first native PoC, traces contain minimal structured actions only: no raw input and no free-form learner text.

**Anonymous practice.** Anonymous simulation practice must not create LearningApp evidence, analytics events, outbox records or simulation-attempt records. The implementation must verify that no simulation-specific data is queued for later synchronization. This requirement does not claim that infrastructure or network providers retain no connection logs. The Phase 0 note audits every path: authentication activity, analytics and crash-reporting SDKs, the event outbox and automatic sync, host-generated telemetry, and session or device identifiers. The implementation plan carries this as a test: an anonymous session produces no LearningApp server-side simulation writes.

**Authenticated and anonymous telemetry are separate paths.**

| Context | What is allowed |
| --- | --- |
| Anonymous | Local-only practice progress. No server writes and no delayed synchronization. |
| Authenticated | Completion telemetry may be persisted through an approved, isolated write path. |
| Verified scoring | Phase 2 only. |

The design note must also verify that existing analytics, crash reporting and automatic event-outbox functionality cannot accidentally capture simulation activity in either context.

**Anonymous local progress.** Local-only has two possible meanings: ephemeral progress that disappears when the session ends, or device-local progress that stays on the device. Either is acceptable. Anonymous simulation progress may be kept locally on the device, but it must never be queued for synchronization, associated with a later authenticated account, or converted into server-side evidence without a separately approved design and an explicit learner action. Account switching on a shared device must neither leak nor migrate it.

**Ephemeral by default.** Ephemeral progress is the default for anonymous practice. If persistent device-local progress is added later, it must live in a separate anonymous storage namespace; never enter the authenticated event outbox; never be attached to an account after sign-in; never be visible to another signed-in learner; and have a clear reset or expiration behavior. These rules are tested at the storage boundary, not only in the UI, including account switching on a shared device.

## 6. Platform changes required

| Change | Detail |
| --- | --- |
| Security headers | Path-scoped framing rule, `frame-src`, `worker-src`, wasm allowance as needed; update `web/_headers` and `firebase.json` together; confirm the production host |
| Cache strategy | Content-hashed filenames for engine bundles and scenes; defined cache and offline policy outside Flutter's asset manifest |
| Lesson block | Append-only migration widening the `block_type` CHECK; confirm self-host schema handling; enum, serializer and renderer changes; explicit unsupported-block fallback |
| Database | New tables for simulation catalog metadata and attempts; RLS consistent with existing patterns; deployed only through the guarded migration workflow |
| UI baseline | Amendment to `UI_ARCHITECTURE_LOCKED.md` for the full-screen route |
| Tests | Flutter widget tests for the contract and fallback; pgTAP tests for scoring and authorization; browser matrix for T1 and T2 |

## 7. Accessibility requirements

The following are manifest requirements, not goals:

- Every simulation declares an **operable alternative** for learners who cannot use it as built (for T1 and T2, a semantic, non-canvas action list or equivalent).
- Audio narration hooks use the existing text-to-speech and pre-reader services; no simulation is the only path to a critical concept.
- Keyboard and touch operation, reduced motion, color-independent cues and adjustable pace are checked against the existing contrast audit approach.
- T1 and T2 canvases are opaque to assistive technology by default; the alternative is what makes them acceptable.
- T0 native simulations target WCAG 2.2 AA (decided, section 10). T1 and T2 require an operable alternative. All tiers must preserve access to critical learning content.

**Equivalent alternatives.** An operable alternative must let the learner demonstrate the same underlying learning objective, not merely read about it. A learner who cannot use a 3D HVAC simulator should still be able to identify the relevant component, diagnose the problem, select the appropriate action and demonstrate the required procedural sequence. A text description of the simulation is not necessarily an equivalent learning experience. Keyboard, touch, reduced-motion and accessible-feedback requirements apply to all tiers where applicable, not only T0.

Safety-sensitive domains (trades, healthcare, chemistry, construction) keep v0.1's rules: simulation is distinguished from real-world instruction, procedures are validated by qualified sources, and a simulation never certifies real-world competence.

## 8. Revised proof-of-concept plan

| PoC | Tier | Goal | Exit gate |
| --- | --- | --- | --- |
| 0 | T0 | Connect one existing simulator (for example the currency/ATM or Rx widget) to the activity contract: launch from a lesson block, emit events, and record completion telemetry with no score | Shows the contract, fallback block and event path work with no new engine |
| A | T0 | Networking: connect devices, diagnose a broken network, hints, rubric | Works with keyboard, touch and audio narration; a test-only scoring prototype can replay and score a trace, writing no mastery evidence and updating no concept state |
| B | T2 | Isolated Babylon.js HVAC exploration in a sandboxed iframe | Header changes proven in both host configs; measured payload size, load time and mobile frame rate recorded; accessible alternative demonstrated; unload releases memory |
| C | T0 or T1 | Virtual lab with reusable scenario state and rubric representation | Defined reusable scenario schema; safety review process exercised once |
| D | T3 | Roblox launch-and-return research spike (optional) | Written findings on framing, identity, verifiable results, child privacy; no production dependency |

PoC B proceeds only if PoC 0 and A pass. Performance targets are set after PoC B baselines, as in v0.1.

**MVP boundary (Phase 1).**

In scope:

1. Integration of existing Flutter simulators with the activity contract.
2. One native networking simulation.
3. One consistent activity contract.
4. Completion telemetry and personal study progress only; no mastery evidence.

Out of scope: any 3D engine, iframe or header changes, verified scoring, AI-generated simulations, Roblox, offline support, and any new top-level destination.

**Test-only scoring prototype.** PoC A may include a prototype showing that the server can replay and score an action trace. It is not production evidence processing. It must not:

- Write to `learning_events`.
- Write to `user_concept_state`.
- Update readiness.
- Affect mastery or scheduling.
- Be callable by production clients as an evidence endpoint.

It runs against test fixtures and returns a result for evaluation only. Production server-authoritative scoring is Phase 2.

**First simulation: narrow and educational.** PoC A is a plain schematic with clickable components, state transitions, hints and a deterministic rubric. It tests whether a learner can connect devices correctly, diagnose a deliberately broken connection, identify the failed component, apply a repair, and explain why the network works afterward. The explanation is captured as a structured choice (select the correct reason or order the reasoning steps), not free text, consistent with the minimal-trace rule in section 5.5. Visual ambition is deliberately low.

**First success criterion: measurable learning.** Success is a measurable improvement in learning, not graphics, engine flexibility or the number of simulations. The Phase 0 note defines the measurement so that it does not merely reflect familiarity with the same questions:

- A baseline assessment before the simulation.
- A post-assessment with equivalent, not necessarily identical, items.
- A delayed retention check if practical.
- A comparison group, or an alternative-explanation analysis (practice effects, the lesson alone) if feasible.

Without these, apparent improvement could simply be a practice effect.

**Realistic scope for the early experiment.** Define the target learning outcome before building anything. Then:

- Use equivalent items that are independently validated, not written only by the simulation's author.
- Separate procedural transfer from recall if both matter.
- Record prior familiarity and whether the learner received the lesson before the simulation.
- Report uncertainty and sample size rather than treating a small pilot as proof.

A randomized comparison group may be impractical for an early PoC. A small pilot can establish usability and expose measurement problems, but it does not support claims of causal effectiveness.

## 9. Revised roadmap

**Phase 0: discovery and design (read-only; approve this first).** Close the "to confirm" items in section 3. Deliverables: a repository-grounded design note; an explicit list of unresolved questions; a draft activity contract and event flow from launch to evidence; a dependency map showing what must land first (the remaining server-authoritative evidence requirements, the `ConceptEvidenceService` investigation, readiness reconciliation, the locked-UI amendment, the header and CSP review, and the block-type migration); and a small, testable Phase 1 plan. Exit: owner review. No framework code, database schema or security-header change is merged during Phase 0.

**Phase 0 stop condition.** Phase 0 ends when the design note reaches a conclusion in each of these areas:

| Area | Required conclusion |
| --- | --- |
| Existing simulator integration | Which simulator can be integrated with minimal changes, and without changing core navigation? |
| Completion telemetry | Is there a safe, isolated Phase 1 write path? |
| Activity contract | What is the smallest contract and lifecycle? |
| Lesson integration | What are the block, fallback and navigation strategies? |
| Evidence architecture | What is the actual server-side projection path, and do existing `ConceptEvidenceService` callers still work after arch\_04? |
| Attempt handling | How are attempts created, version-pinned, completed and made idempotent? |
| Native PoC | Can networking be built without new engine infrastructure? |

Anything else becomes a follow-up decision or a Phase 1 task.

**Priority Phase 0 investigation: `ConceptEvidenceService` after arch\_04.** This is potentially broader than simulations, because existing assessments and learning activities may rely on the client-side upsert that arch\_04 revokes.

Findings so far (from reading code on main at `dd3f899`; nothing was run):

- Callers include `SpacedRepetitionService` (the review flow), `DiagnosticAssessmentService`, `TargetReadinessService`, the target-readiness provider and the progress screen.
- The service resolves concept mappings and weights client-side, computes retrieval band and confidence, and upserts `user_concept_state` directly. arch\_04 revokes that privilege for authenticated clients.
- The server projection in `record_events` updates evidence counts and weighted totals, but as read it does not compute retrieval band or confidence and does not apply per-concept weights.
- The service tests found use fake clients, so they do not exercise the real database permissions (to confirm for all tests).

The investigation establishes:

1. Which production app flows still invoke the client-side upsert.
2. Whether those writes now fail under the actual authenticated client role, and whether the failure is silent.
3. Whether the server-side projection replaces the old behavior, including band, confidence and weights.
4. Whether existing assessment and learning-progress tests cover the new write boundary.
5. Whether any user-facing progress or readiness behavior has regressed.

Simulation evidence is not built on a projection path that is assumed to work. If existing functionality is broken, it gets its own corrective work and is not hidden inside the simulation project.

**Phase 1: contract and native proof (behind a feature flag).** Activity contract, PoC 0 and PoC A. Records completion telemetry and personal study progress only; it produces no mastery evidence. Any schema change (a `simulation` lesson block type, a catalog table) is proposed in the Phase 0 note and merged only after review; if it is not approved, PoC 0 launches without a new block type. Deliverable: one native simulation integrated into a lesson or practice step.

**Phase 2: server-authoritative evidence.** Simulation scoring function, attempt table, and evidence tiers wired to the readiness rules. Acceptance criteria:

1. The server validates and scores the attempt, and rejects mismatched versions.
2. The server computes the evidence value itself and validates the concept mapping against the activity's registered concepts. It never accepts a client-asserted score or concept as evidence.
3. The server controls the authoritative update to concept evidence and readiness-related state, through the existing evidence architecture rather than a simulation-specific one.
4. Attempt identity and idempotency are enforced in the database.
5. The shared evidence pipeline no longer accepts client-asserted evidence values for scored activity types.

The intended flow is: the learner completes the simulation; the server validates the attempt and versions; the server recomputes the score; the server applies the existing evidence rules; the authoritative concept and readiness projection is updated. On main, direct client writes to `user_concept_state` are now revoked and `record_events` enforces idempotency, but the evidence value and concept ID are still client-asserted, so the projection is written server-side without authoritative scoring. No simulation result can affect mastery, scheduling or readiness until that gap is closed. The closing work should be the authoritative version of the existing evidence architecture, usable by assessments and other learning activities, not a simulation-specific system. Before building it, the Phase 0 note checks the broader architecture roadmap so that nothing is duplicated. Deliverable: one server-verified simulation.

**Phase 3: isolated engine spike.** Header changes, PoC B, accessibility and performance gates, engine decision for T2. Deliverable: go or no-go on browser 3D with measurements.

**Phase 4: authoring and templates.** Reusable templates, scenario configuration, review and versioning workflow, controlled AI-assisted population of validated templates.

**Phase 5: external and heavy experiences.** Roblox, Godot or Unity only where a documented need exceeds earlier tiers.

## 10. Open questions and proposed defaults

Items marked **Decided** adopt the recommended default as of v0.5 and can be reversed by the owner. The rest are proposed defaults.

| # | Question | Default or decision |
| --- | --- | --- |
| 1 | Embedded or full screen? | Full-screen route launched from a lesson or Learn, with a locked-UI amendment |
| 2 | PWA only or native too? | PWA only through Phase 3 |
| 3 | Offline in Phase 1? | No; revisit after caching strategy exists |
| 4 | First subject (**Decided**) | Networking for PoC A (cleanest native fit); HVAC for PoC B, with expert review before any publication (item 13) |
| 5 | Learner-created simulations? | Not before Phase 4 template work |
| 6 | Roblox role? | Later optional integration; PoC D is research only |
| 7 | How much progress counts toward mastery? (**Decided**) | Nothing from `unverified` or `exploratory` counts toward mastery. A `verified` milestone counts only through the existing evidence-value path and only for readiness-eligible content; weighting is set with the readiness rules. |
| 8 | Which results must be server-verified? | Anything affecting mastery, readiness or credentials |
| 9 | Anonymous learners? (**Decided**) | Anonymous learners may practice, with no server-side persistence of evidence or telemetry; evidence requires sign-in |
| 10 | Accessibility standard (**Decided**) | WCAG 2.2 AA for T0, plus the operable alternative for T1 and T2 (a manifest requirement) |
| 11 | Download and load targets | Set after PoC B measurements |
| 12 | 3D asset sourcing | Licensed or internally authored; AI-generated only after validation process exists |
| 13 | Which simulations need expert review? | All safety-sensitive domains before publication |
| 14 | Institutional private simulations? | Out of scope until Phase 4 |

## 11. Proposed decisions (checklist)

- [ ] Simulation framework is modular, with one lifecycle contract across tiers; adapters declare unsupported capabilities and handle them predictably.
- [ ] Native Flutter (T0) is the default and first implementation target.
- [ ] JS engines are lazy-loaded and self-hosted; the isolation approach is chosen after the spike.
- [ ] Browser 3D proceeds only after the PoC B gates pass.
- [ ] No simulation result affects mastery, scheduling or readiness until the server computes the evidence value, validates the concept mapping, and applies the result through the authoritative existing evidence architecture. arch\_04 idempotency and server-side projection controls are necessary foundations, not sufficient conditions.
- [ ] Simulation events map to xAPI verbs.
- [ ] A `simulation` lesson block with an explicit fallback; no new top-level destination.
- [ ] Accessibility alternative required in every manifest.
- [ ] AI authoring starts with validated templates.
- [ ] Roblox remains an optional external spike.

Added in v0.3:

- [ ] Scoring class (deterministic, structured, free-form) is declared per simulation and caps its evidence tier.
- [ ] Simulation evidence flows only through the existing evidence-value propagation and provenance rules; no parallel readiness system.
- [ ] The shared contract stays small; interaction models are engine-specific.
- [ ] Phase 0 is approved as design work only; no framework, schema or header change merges before review.

Added in v0.4:

- [ ] Practice telemetry is separated from mastery and scheduling evidence; the Phase 0 note decides whether unverified events can use the existing pipeline.
- [ ] Simulation runtimes receive no credentials or learner identifiers by default; the host mediates network access.
- [ ] Action traces have size, retention, free-text, identifiability, access and version-pinning rules before any attempt table exists.
- [ ] "Verified" never implies learner competence.
- [ ] Phase 0 ends when the design note reaches a conclusion in each of the seven stop-condition areas.
- [ ] The first success criterion is measurable learning, not graphics or engine count.

Added in v0.6:

- [ ] An anonymous practice session produces no server-side writes, analytics or outbox records.
- [ ] The contract is one lifecycle; capabilities vary by adapter and are declared.
- [ ] The learning measurement includes a baseline, equivalent post items, and a practice-effect check.

Added in v0.7:

- [ ] The anonymous-practice promise covers LearningApp-generated records only, and every path is audited.
- [ ] Completion telemetry is separate from scored evidence; no client-asserted score, rating or scheduler state goes through an unvalidating RPC.
- [ ] Every completion submission carries version identity, an attempt ID and an idempotency key.
- [ ] The full-screen route guarantees Help, an explicit exit and a lesson-preserving failure path.
- [ ] The learning experiment defines its outcome first and makes no causal claim from a small pilot.

Added in v0.8:

- [ ] No same-origin iframe is called a security boundary until a sandbox configuration and threat model are demonstrated.
- [ ] Phase 1 records completion telemetry and personal study progress only.
- [ ] Attempt IDs are server-issued, with database-enforced idempotency and defined uniqueness scope.
- [ ] Phase 2 requires a server-canonical concept projection before any simulation result affects mastery.
- [ ] Completion is not learning: only validated, verified tasks can become evidence.

Added in v0.9:

- [ ] Attempt identity and idempotency are two separate database constraints, and mismatched versions are rejected.
- [ ] Anonymous practice is local-only; authenticated completion telemetry uses an approved isolated write path.
- [ ] The iframe threat model covers exfiltration, same-origin endpoints, storage, navigation, referrer leakage, CSP and cleanup; a `null` origin is never sufficient validation.
- [ ] PoC A's scoring prototype writes no mastery evidence and updates no concept state.
- [ ] A missing completion event is never read as a failed assessment.
- [ ] Simulation attempts are a source of learning evidence, not a separate learning system.

Added in v0.10:

- [ ] Idempotency uses independent rules (attempt identity, one completion per attempt, request-level key) with the five acceptance tests.
- [ ] The Phase 1 write path meets the listed requirements, or Phase 1 uses a dedicated completion-only RPC or local-only progress.
- [ ] Anonymous simulation progress is never synchronized, tied to a later account, or converted to evidence without a separate design and explicit learner action.
- [ ] The iframe acceptance tests are written before any T1 or T2 work (Phase 3).
- [ ] Accessibility alternatives let learners demonstrate the same objective.
- [ ] The test-only scoring prototype cannot write evidence or be called by production clients.
- [ ] Phase 2 requires server-computed evidence values and server-validated concept mapping.

Added in v0.11:

- [ ] The `ConceptEvidenceService` investigation (five questions) is complete before any simulation evidence is designed on the projection path.
- [ ] The attempt lifecycle is specified: server-created, version-pinned, one accepted completion, idempotent retries.
- [ ] Each Phase 1 completion event has a defined source, allowed metadata, repeatability, ordering and offline behavior.
- [ ] Anonymous practice is ephemeral by default; any persistent local progress is namespaced, never synchronized, never attached to an account and tested at the storage boundary.

## 12. Risks (updated)

| Risk | Mitigation |
| --- | --- |
| Overengineering a game engine | Lowest-tier rule; integrate engines only when T0 cannot serve the objective |
| Header changes weaken app security | Path-scoped rules; sandboxed iframe; message validation; review in both host configs |
| Unverifiable free-form results | Evidence tiers; keep free-form activities `unverified` until validation exists |
| New block type breaks older clients | Explicit fallback block and migration sequencing |
| Competing with higher-priority work | Phase 0 verifies the effects of arch\_04; Phase 2 evidence work proceeds only after the remaining server-authoritative scoring and concept-mapping requirements are satisfied |
| Accessibility gap on canvas content | Required operable alternative; gate on demonstration in PoC B |
| Unsafe professional procedures | Qualified review, safety classification, no certification claims |
| AI-generated inaccuracy | Template-based generation, review and automated scenario tests |
| Scope explosion | Prove PoC 0 and A before any engine work |
| Cost growth | Track hosting, asset delivery, development and support per simulation |
| A second readiness system is created by accident | Evidence propagates only through the existing evidence-value path; provenance and eligibility rules unchanged; reviewed in Phase 0 |
| Isolation approach adds more complexity than it removes | Treat the iframe as a hypothesis; compare options in the spike; no isolation needed for T0 |
| A simulation runtime or action trace leaks credentials or learner data | No credentials or identifiers by default; host-mediated network access; trace limits and minimal structured actions defined before any attempt table |
| A same-origin iframe is mistaken for a security boundary | Evaluate each sandbox configuration and a threat model in the spike; treat a same-origin iframe with scripts and same-origin access as no boundary; validate messages without relying on origin |
| A hardened event pipeline is mistaken for authoritative scoring | Treat idempotency and the projection boundary as solved; require server-computed evidence values and validated concept mapping before any simulation result affects mastery |

## 13. Verification notes

Reviewed: root and architecture documents, `docs/learning_science/02` and `07` and related files, README and AGENTS guidance, security header and hosting configs, `lib/models/lesson_block.dart` and the block renderer, router deferred imports, event outbox and learning event model, the `learning_events` and `record_events` migration, EXM migration file names, interop services, `ConceptEvidenceService`, and the four literacy simulator widgets (structure and event references only).

Updated in v0.10: also reviewed `20261107050000_arch_04_learning_events_strict_rules.sql` on main at `dd3f899`, three commits after the original basis `baa26c0`. The migration was read, not executed.

Not reviewed or not run: build, tests, CI results, EXM function bodies, service-worker and offline behavior, production hosting configuration, any unmerged branches, and the server-side projection into `user_concept_state` (only the client service and the readiness specification were read).
