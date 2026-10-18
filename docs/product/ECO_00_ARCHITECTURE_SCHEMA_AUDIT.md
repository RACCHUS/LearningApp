# ECO-00: Community, Educator & Creator Platform — Architecture & Schema Audit

**Status:** Completed Audit & Baseline Specification  
**Epic:** ECO-00 (Phase 0 Prerequisite)  
**Date:** October 2026  
**Repository:** `RACCHUS/LearningApp`  
**Governing Documents:**  
- [COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md](COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md)  
- [LEARNING_ARCHITECTURE_V2.md](../../LEARNING_ARCHITECTURE_V2.md)  
- [UI_ARCHITECTURE_LOCKED.md](../../UI_ARCHITECTURE_LOCKED.md)  
- [LITERACY_ACCESSIBILITY_PLAN.md](../../LITERACY_ACCESSIBILITY_PLAN.md)  
- [CATALOG_GROWTH_AND_DEMAND_PLAN.md](../catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md)  
- [P2H_LEARNER_FACING_PATHWAY_PREPARATION.md](../catalog/P2H_LEARNER_FACING_PATHWAY_PREPARATION.md)  

---

## 1. Executive Summary & Objective

The **Community, Educator, Creator Economy & Adaptive Knowledge Roadmap** outlines an ambitious expansion of `LearningApp` from an individual study and foundational literacy client into an open, evidence-grounded educational ecosystem.

Before writing code or authoring database migrations for community interactions, educator identities, or content marketplaces, **ECO-00** mandates an exhaustive audit of:
1. Existing database tables, schemas, and RLS policies across 46 migrations.
2. Existing Flutter client models, state providers, and UI services.
3. Overlaps, naming conflicts, and potential failure modes (especially conflating psychometric testing items with social Q&A).
4. Safety, legal, minor-privacy (COPPA/FERPA), and cost/observability requirements.

This document establishes the official **Gap Matrix**, specifies the **Domain Separation Invariants**, and models the additive entities needed for subsequent epics (**ECO-00B** through **ECO-05**).

---

## 2. Current Architecture & Implemented State Inventory

### 2.1 Database & Schema Inventory (`supabase/migrations/`)

The database consists of 46 ordered, append-only migrations. Key subsystems include:

```mermaid
graph TD
    subgraph "Auth & Identity"
        U["public.users"]
        CR["public.curriculum_reviewers"]
    end

    subgraph "Catalog & Taxonomy (Phase 1-2)"
        C["catalog_clusters"]
        F["fields (CIP 2020)"]
        EC["external_classification_nodes (CIP/SOC)"]
        ON["occupation_nodes (O*NET 31.0)"]
        VD["catalog_verified_destinations (16 published)"]
        LP["catalog_license_pathway_versions (6 Florida)"]
        DR["catalog_destination_resources (15 links)"]
        GL["catalog_destination_goal_links"]
    end

    subgraph "Curriculum & Targets (v2 Architecture)"
        LT["learning_targets"]
        TV["target_versions"]
        CN["curriculum_nodes"]
        LC["learning_contexts"]
        UCR["user_curriculum_resources"]
    end

    subgraph "Knowledge & Psychometrics"
        KC["knowledge_concepts"]
        CRel["concept_relations"]
        CF["concept_fields"]
        UCS["user_concept_state"]
        RI["review_items (SM-2 / Spaced Repetition)"]
        UP["user_progress"]
    end

    subgraph "Content Primitives"
        L["lessons"]
        LB["lesson_blocks"]
        Q["questions (Psychometric MCQ / True-False)"]
        QC["question_concepts"]
        SS["study_sets"]
        FC["flashcards"]
    end

    U --> LT
    LT --> TV
    TV --> CN
    CN --> KC
    Q --> L
    Q --> QC
    QC --> KC
    RI --> UCS
    VD --> LP
    VD --> DR
    GL --> LT
    GL --> VD
```

#### Detailed Findings on Key Existing Tables:

1. **`public.questions` (Psychometric Assessment Items)**:
   - **Schema**: `id (uuid)`, `lesson_id (uuid FK to lessons)`, `question_text (text)`, `options (jsonb array)`, `correct_answer (int)`, `type (mcq|true_false|short_answer)`, `explanation (text)`, `user_id (uuid)`, `created_at`, `updated_at`.
   - **Role**: Serves exclusively as graded items for spaced repetition (`review_items` using the SuperMemo-2 / SM-2 algorithm via `SpacedRepetitionService`), diagnostic readiness (`AssessmentEngine`), and weighted concept evidence (`question_concepts` $\rightarrow$ `user_concept_state`).
   - **Critical Constraint**: `questions` has a single numeric `correct_answer` and strict scoring semantics. It is completely unsuitable for multi-perspective, threaded, or conversational community Q&A.

2. **`public.users` (User Identity)**:
   - **Schema**: `id (uuid PK default gen_random_uuid())`, `email (text unique not null)`, `display_name (text)`, `created_at (timestamptz default now())`.
   - **Live Schema Note**: The live hosted schema does not currently enforce a declared foreign key constraint from `public.users.id` to `auth.users.id`. Linking `public.users.id` directly to `auth.users.id` is an intended architecture and best practice for future identity migrations.
   - **Role**: Minimal identity record.
   - **Gaps**: Does not track user roles, age bracket/minor status, educator bio, verification state, social links, or public profile preferences.

3. **`public.learning_targets` & `catalog_destination_goal_links`**:
   - Distinguishes official regulator credentials from private user goals.
   - Enforces strict RLS: users can only link private, unreviewed draft goals to published catalog destinations in the matching jurisdiction.

4. **`public.curriculum_reviewers` (Target-Specific Governance)**:
   - **Schema**: 5 columns: `id (uuid PK)`, `target_id (uuid FK references learning_targets)`, `user_id (uuid)`, `role (text check in ('reviewer', 'editor', 'admin'))`, `created_at (timestamptz)`.
   - **Scope**: Strictly scoped to authoring, editing, and approving versioned curriculum trees for specific learning targets.
   - **Distinction**: Must **not** be automatically reused as a platform-wide community moderator table. Platform-wide moderation and trust & safety require a dedicated, distinct authorization role or table (`moderation_roles` / `trust_and_safety_actions`).

---

### 2.2 Client-Side Services & Models (`lib/`)

1. **Foundational Literacy Core (`lib/models/`, `lib/services/`)**:
   - 6 phases delivered and verified (51 passing automated tests).
   - `PreReaderAudioService`, tactile Zaner-Bloser stroke engine (`LetterStrokeData`), phonics catalog, decodable stories, and CVC word blending.
   - Practical survival domains: USCIS Civics oral mock, FLHSMV audio driver's exam, GED ABE reading bridge, OSHA pictograms, Currency recognition (18 U.S.C. § 504), Food Code.
   - `CaseworkerMode` and `PreReaderProfile`: All learner profiles and oral milestone progresses are currently kept **strictly local on-device** via `SharedPreferences`/Hive.

2. **Audio & Voice Interaction**:
   - `AudioLessonOrchestrator`, `VoiceInputService`, `VoiceCommandRouter`, `HandsFreeSettingsService`.
   - Client-side speech recognition and synthesis integration.

3. **AI Generation & Prompt Engine**:
   - `AiPromptService`: Phased blueprint and curriculum generation with terminology locking.
   - `ContentQualityService`: Client-side heuristic analysis for readability, structure, and accessibility.
   - **Security Gap**: Lacks input sanitization and prompt-injection filters for untrusted user inputs.

4. **License Pathway Preparation (P2h)**:
   - `PathwayTreeParser`, `PathwayReadinessService`, `PathwayPreparationSheet`, `PathwayPreparationGoalCard`.
   - Client-side interactive route selection (`op: 'any'`) and self-reported checklist tracking for 6 Florida licenses.
   - **Shared-Device Storage Finding**: `PathwayReadinessService` currently keys storage by destination/target ID (`pathway_readiness_{destinationId}_{goalId ?? "standalone"}`). On shared browser devices across family or caseworker profiles, standalone pathway state is device-wide rather than user-scoped. Hardening storage keys to user-scoped namespaces (e.g. `pathway_readiness_{userId ?? "local"}_{destinationId}_{goalId ?? "standalone"}`) and testing cross-session isolation across sign-in/out is flagged as an important operational enhancement.

---

## 3. Comprehensive Gap Matrix

The following matrix compares current capabilities against the strategic roadmap requirements:

| Architectural Domain | Existing Implementation | Roadmap Requirement (ECO) | Gap Classification | Architectural Strategy & Invariant |
| :--- | :--- | :--- | :--- | :--- |
| **1. Social Q&A vs. Psychometrics** | `public.questions` table is strictly psychometric (MCQ, 0-indexed answer, linked to `user_concept_state` mastery). | Conversational, threaded questions and answers scoped to lessons/concepts/targets with upvotes, citations, and revisions. | **Missing Subsystem** | **Invariant 1**: Complete domain isolation. Create `community_questions` and `community_answers`. Never mix social Q&A into psychometric `questions`. |
| **2. Educator & Creator Identity** | Minimal `public.users` (id, email, display_name). No public profile UI. | Educator channels, subject expertise, credential verification tags, followers, office hours. | **Missing Subsystem** | **Invariant 2**: Create additive `educator_profiles` and `educator_subjects`. Distinguish self-declared vs. verified credentials. |
| **3. Trust, Safety & Moderation** | Administrative SQL scripts & RLS. No user reporting UI or moderator inbox. | User flagging, moderation queue UI, audit log of actions, DMCA notices, automated profanity/spam filters. | **Missing Subsystem (P0 Prerequisite)** | **ECO-00B**: Build `moderation_reports`, `moderation_queue`, and admin moderation UI before enabling public UGC. |
| **4. Child Safety & Minor Protection** | Pre-reader profiles stored locally in offline Hive/SharedPreferences. | Strict minor protection operational design (age-assurance, guardian consent, retention/deletion rules). | **Critical Legal & Operational Gap** | **Invariant 3**: Minors default to private, guardian-managed accounts. Public posting restricted to verified adults ($\ge 18$). Operationalize consent and deletion procedures before claiming legal compliance. |
| **5. AI Transparency & Prompt Security** | `AiPromptService` generates lesson plans via rigid schemas. | In-context AI answer synthesis, uncertainty flags, robust defense-in-depth prompt-injection protection. | **Partial / Security Gap** | **Invariant 4**: Structural isolation of system instructions from user inputs, constrained model tool access, output schema validation, rate limits, and adversarial testing. Label AI answers clearly. |
| **6. Content Licensing & Provenance** | `content_provenance.dart` models source URL and checked dates for official catalog destinations. | Explicit creator licensing (CC-BY, CC-BY-SA, All Rights Reserved), derivative rights tracking. | **Missing Subsystem** | Add `resource_licenses` table and require explicit license selection upon publishing. |
| **7. Multi-Modal Audio Harmonization** | Rich local TTS/STT and oral literacy mocks. | Audio playback for community Q&A, voice question asking, accessible explanations. | **Integration Opportunity** | Re-use `PreReaderAudioService` and `AudioLessonOrchestrator` to vocalize community answers. |
| **8. Cost & Observability Monitoring** | Basic `supabase_health_service.dart`. | Real-time monitoring of AI tokens, TTS/STT API costs, media storage, and rate-limit violations. | **Missing Operational Tooling** | **ECO-00C**: Implement cost quotas, rate-limiting token buckets, and alert thresholds. |

---

## 4. Core Architectural Invariants

To maintain structural integrity, the following invariants are strictly binding for all future ECO epics:

### Invariant 1: Psychometric Assessment Isolation
- **Rule**: `public.questions` is reserved exclusively for validated assessment items that produce concept mastery evidence.
- **Enforcement**: Community knowledge discussions must reside in `public.community_questions` and `public.community_answers`.
- **Bridge**: A community answer can only become an assessment item through an explicit editorial review and transformation workflow that attaches options, distractors, and concept weights.

### Invariant 2: Trust Vocabulary Consistency
- **Rule**: All community content, educator profiles, and answers must reuse the platform's standardized trust vocabulary:
  - `Official` (issued by accredited body/state regulator)
  - `Catalog` (curated by platform curriculum team)
  - `Community (reviewed)` (peer-reviewed and approved by credentialed contributor)
  - `Community (pending)` (submitted, unreviewed community draft)
  - `Private` (learner's personal unshared draft)
- **Prohibition**: Never invent redundant labels (e.g., "Verified Answer", "Certified Expert") that blur regulatory vs. platform vs. self-reported distinctions.

### Invariant 3: Minor Safety & Privacy (Operational Design)
- **Policy Rule**: Public user-generated content (asking public questions, posting answers, creating public channels) is restricted to verified adult users ($\ge 18$).
- **Operational Requirements for ECO-00B**:
  - *Age Assurance*: Define non-intrusive, explicit age attestation/verification mechanisms during account onboarding.
  - *Guardian & Caseworker Controls*: Provide delegated account management for minors, enabling reading of approved educational FAQs and foundational literacy content while blocking public UGC broadcasts and disabling direct messaging from adult strangers.
  - *Data Retention & Deletion*: Establish strict data minimization, consent logging, and complete account/data deletion workflows ("Right to be Forgotten").
  - *Legal Scope Distinction*: Recognize that the 18+ policy is a conservative product control, but formal legal claims (COPPA, FERPA) require qualified legal review and documented operational procedures before asserting statutory compliance.

### Invariant 4: Defense-in-Depth Prompt-Injection Architecture
- **Principle**: Simple substring stripping (such as filtering `system:` or `ignore previous instructions`) is brittle, easily bypassed, and damages legitimate educational inquiries (e.g., questions about prompt engineering, system administration, or programming).
- **Defense-in-Depth Controls**:
  1. *Structural Separation*: Enforce strict message role boundaries (e.g., rigid OpenAI/Gemini system instructions vs. user content blocks) where system instructions cannot be overwritten by untrusted user payloads.
  2. *Tool Privilege Constraints*: AI agents/models generating or evaluating community explanations must run in an isolated sandbox with zero access to administrative database credentials or privileged RPC execution.
  3. *Strict Output Schema Validation*: Enforce deterministic JSON output schemas; parse and validate response types and structure before storing or rendering.
  4. *Rate Limits & Token Budgets*: Apply strict per-user request rate limits and context-window length caps (e.g., 1,000 characters per question) to eliminate prompt-stuffing vectors.
  5. *Adversarial Regression Testing*: Maintain an automated test suite of adversarial prompt injection attempts to continuously verify resilience without breaking educational edge cases.
  6. *Visual Transparency*: Explicitly mark all AI-synthesized responses with visual robot badges, confidence disclaimers, and links to official regulator sources.

### Invariant 5: Navigation Baseline & First-Run Help Integrity
- **Rule**: The core navigation destinations remain **Learn**, **Library**, and **Progress** per [UI_ARCHITECTURE_LOCKED.md](../../UI_ARCHITECTURE_LOCKED.md).
- **Placement**:
  - Community Q&A is contextual: embedded in lesson sheets, practice review dialogs, and library search.
  - Do NOT inject a top-level "Social" or "Forum" bottom-nav item.
  - Searchable Help (`?`) in the top-right chrome remains intact.

---

## 5. Target Entity Relationship Model (ECO Data Domains)

Below is the design target for the additive database entities required across Phase 0 through Phase 2. *(Design target only; do not execute as premature migrations).*

```mermaid
erDiagram
    users ||--o{ community_questions : "authors"
    users ||--o{ community_answers : "answers"
    users ||--o| educator_profiles : "has"
    users ||--o{ moderation_reports : "submits"
    
    educator_profiles ||--o{ educator_subjects : "specializes_in"
    educator_profiles ||--o{ educator_verifications : "holds"
    
    community_questions ||--o{ community_answers : "has"
    community_questions ||--o{ question_topic_links : "tagged_with"
    community_questions ||--o{ moderation_reports : "flagged_by"
    
    community_answers ||--o{ answer_revisions : "versioned_as"
    community_answers ||--o{ answer_feedback : "receives"
    community_answers ||--o{ moderation_reports : "flagged_by"
    
    knowledge_concepts ||--o{ question_topic_links : "grounds"
    learning_targets ||--o{ question_topic_links : "targets"
    lessons ||--o{ question_topic_links : "contextualizes"
    
    moderation_queue ||--|| moderation_reports : "evaluates"
    moderation_queue ||--o{ trust_and_safety_actions : "resolves_with"
```

### 5.1 Trust, Safety & Moderation Domain (`ECO-00B`)
- `moderation_reports`: `id`, `reporter_id`, `target_type` (`question|answer|comment|profile`), `target_id`, `reason` (`spam|harassment|misinformation|copyright|minor_safety`), `description`, `created_at`.
- `moderation_queue`: `id`, `report_id`, `status` (`pending|under_review|actioned|dismissed`), `priority`, `assigned_moderator_id`, `escalated_at`.
- `trust_and_safety_actions`: `id`, `moderator_id`, `target_type`, `target_id`, `action` (`warn|hide|delete|ban_user|rate_limit`), `justification`, `actioned_at`.
- `dmca_takedown_notices`: `id`, `claimant_name`, `claimant_email`, `infringing_url`, `original_work_description`, `sworn_statement_verified`, `received_at`, `status`.

### 5.2 Community Q&A Domain (`ECO-01`)
- `community_questions`: `id`, `author_id`, `title`, `body_markdown`, `status` (`published|under_review|archived`), `is_seeded` (boolean), `view_count`, `upvote_count`, `created_at`, `updated_at`.
- `community_answers`: `id`, `question_id`, `author_id`, `is_ai_generated` (boolean), `ai_model_name`, `body_markdown`, `status`, `is_accepted` (boolean), `upvote_count`, `created_at`, `updated_at`.
- `answer_revisions`: `id`, `answer_id`, `revision_number`, `body_markdown`, `editor_id`, `edit_reason`, `created_at`.
- `question_topic_links`: `id`, `question_id`, `concept_id` (optional FK), `target_id` (optional FK), `lesson_id` (optional FK), `cip_code` (optional).
- `answer_feedback`: `id`, `answer_id`, `user_id`, `is_helpful` (boolean), `feedback_tag`, `created_at`.

### 5.3 Educator Profiles Domain (`ECO-02`, `ECO-04`)
- `educator_profiles`: `id (uuid references auth.users)`, `bio`, `headline`, `avatar_url`, `website_url`, `hourly_rate_cents`, `is_accepting_students` (boolean), `created_at`, `updated_at`.
- `educator_subjects`: `id`, `educator_id`, `field_id` (FK to `fields`), `target_type`, `experience_years`, `self_declared_summary`.
- `educator_verifications`: `id`, `educator_id`, `credential_type` (`license|degree|certification`), `issuer_name`, `jurisdiction`, `verification_status` (`unverified|pending|verified|expired`), `verified_at`, `expires_at`.
- `follows`: `id`, `follower_id`, `educator_id`, `created_at`.

---

## 6. Execution Sequencing & Next Milestones

Based on this audit, work must proceed in strict dependency order:

```mermaid
graph TD
    ECO00["ECO-00: Architecture & Schema Audit\n(COMPLETE)"]
    ECO00B["ECO-00B: Trust, Safety, Legal & Moderation UI\n(P0 Prerequisite)"]
    ECO00C["ECO-00C: Cost & Observability Baselines\n(P0 Prerequisite)"]
    ECO01["ECO-01: Concept-Scoped Q&A & Cold-Start Seeding\n(P1 Delivery)"]
    ECO04["ECO-04: Educator Profiles & Subject Affiliations\n(P1 Delivery)"]

    ECO00 --> ECO00B
    ECO00 --> ECO00C
    ECO00B --> ECO01
    ECO00C --> ECO01
    ECO01 --> ECO04
```

### Action Items for Next Step:
1. **ECO-00B (Trust, Safety & Legal Infrastructure)**:
   - Draft repository Terms of Service and COPPA/FERPA-compliant Privacy Policy.
   - Establish DMCA agent registration and takedown policy.
   - Design additive `moderation_reports` and `moderation_queue` schema.
   - Build admin moderation queue UI.
2. **ECO-00C (Observability & Limits)**:
   - Implement rate limits and AI token budget controls in client/backend.
