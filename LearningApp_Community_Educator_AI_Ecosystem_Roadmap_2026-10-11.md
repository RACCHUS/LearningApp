# LearningApp — Community, Educators, Creator Economy & Adaptive Knowledge Roadmap

**Status:** Proposed product roadmap; not an implementation claim.  
**Prepared:** October 11, 2026  
**Project:** `RACCHUS/LearningApp`  
**Suggested repository location:** `docs/product/COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md`  
**Priority:** Strategic, multi-phase expansion; coexist with the active catalog-growth plan.

## 0. Mission and non-negotiable intent

**Mission:** Make effective education easier to discover, afford, create, teach, understand, and complete. Help people gain actual knowledge, academic progress, qualifications, and economic opportunity—not merely consume content.

The product has **two distinct returns**:
1. **Enduring family/personal utility**, regardless of commercial success: school support for children, accessible foundational literacy for adults, CLEP and college preparation, insurance/real-estate/HVAC/contractor credentials, and eventually practical trade skills. Build for long-term use and diverse literacy, age, and ability levels.
2. **Potential financial return** from a scalable public educational ecosystem: paid creator resources, instruction, tutoring, subscriptions, marketplace transactions, and optional services. Do not sacrifice family educational utility merely to maximize revenue.

**Core thesis:** Build more than a course library. Build a platform where learners ask questions, teachers teach without needing to author courses, creators publish and earn, AI helps both sides, and credible evidence about educational effectiveness makes the platform better over time.

**North-star question:** Is the platform helping people demonstrably *learn, retain, apply knowledge, and reach independently verified goals* more effectively, affordably, and accessibly?

## 1. What exists and must be reused

Repository review (as described in the current `README.md`, `LEARNING_ARCHITECTURE_V2.md`, `UI_ARCHITECTURE_LOCKED.md`, and `docs/catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md`):

- Flutter/Dart PWA; Riverpod + GoRouter; Supabase PostgreSQL/Auth/Storage/RLS; Hive/local sync.
- Existing primary destinations **Learn / Library / Progress**; collapsible desktop rail, searchable Help; no forced first-run onboarding. The locked UI baseline governs new navigation work unless explicitly amended.
- Learning contexts, learning targets and published versions, curriculum nodes, autonomous `knowledge_concepts`, courses, lessons, assessment `questions`, study sets, flashcards, user progress, review scheduling, and diagnostic pathways.
- Voice input, text-to-speech, AI-assisted educational creation (where configured), and offline-capable study elements.
- Catalog trust/provenance distinguishes official, reviewed community, unreviewed, and personal goals.
- Official CIP/SOC/O*NET classification ingestion is completed according to the active catalog plan. Credential/license/provider catalog expansion remains a **separate ongoing plan**: `docs/catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md`. Do not revive the superseded taxonomy roadmap.

**Implementation note:** Documentation is not proof that every feature is production-ready. Before any phase, inspect actual Flutter UI, Supabase migrations, APIs, access rules, tests, and hosted schema; record what exists vs. incomplete vs. missing. Avoid duplicating models or resetting production data.

## 2. Product model: destinations, knowledge, people and contributions

Maintain **distinct but linked entities**:

- **Learning destination / goal:** e.g., Florida real estate licensing exam, CLEP College Algebra, grade-level mathematics, practical reading, HVAC/EPA credential, contractor trade knowledge. It represents *what a learner hopes to accomplish*; it is not itself a course.
- **Formal requirements and versioned curriculum:** regulator/issuer rules and competencies, with jurisdiction, dates, authoritative citations, and known/unknown status. Education that is officially mandated or accredited must be labeled accordingly; ordinary exam prep is not a substitute.
- **Canonical knowledge concept:** share concept-level evidence across compatible contexts while keeping each learning context scoped; reuse existing v2 architecture.
- **Learning resource:** lesson, video, audio, text, diagram, flashcard, original practice item, exercise, simulator, workshop, external link or collection. May be platform-owned, creator-owned, reviewed community, or private. Course creation remains optional.
- **Community question and answer:** public or scoped knowledge exchange; separate from assessment questions. Link to destination/concept/resource where useful but allow general standalone questions.
- **Person / contribution identity:** learner, teacher/tutor, creator, subject-matter contributor, credentialed reviewer, moderator. Roles overlap; teaching does not require owning a course.
- **Evidence / provenance:** source, author, editorial review, AI involvement, freshness, reliability, moderation, rights and outcome evidence. Display what is verified vs. self-reported vs. estimated.

**Architectural invariant:** A course, teacher, community question, and knowledge concept must not be collapsed into one row or rigid parent-child chain. Many-to-many mappings and clear provenance are essential.

## 3. Core experience and workstreams

### W1 — Question-and-answer community (Quora-like, learning-connected)

**User needs:** Ask a genuine question; get human or AI explanations; discover prior answers; debate or correct outdated information; follow helpful contributors; turn a useful answer into deeper learning.

**Functional scope:**
- Ask publicly or within a community/topic; optionally relate question to an existing learning goal, concept, lesson, or qualification. Do not force selection of a formal goal for ordinary Q&A.
- Search and deduplicate near-identical questions; meaningful tags; follow/bookmark; edit history and context; clear author identity and timestamps.
- Human answers, comments/clarifications, citations, attachments where safe, useful/needs-correction feedback, reporting, and moderation.
- Optional instant **AI answer**, visibly labeled AI-generated, with uncertainty and sources where available. Allow users to request simpler, step-by-step, audio, visual or advanced explanations. An AI answer is **not** the authoritative accepted answer by default.
- Answer revision history; mark stale, contested or verified information; flag where regulation or exam syllabus may have changed.
- Link excellent answers to lessons and relevant practice *only after rights/permission and review*; do not silently appropriate creators' work.
- Account for discussions with multiple defensible perspectives, not only questions with one numeric answer.

**Critical separation:** Existing `questions` are assessment items used for learning/scoring. Add a distinct community Q&A domain (e.g., `community_questions`, `community_answers`) and bridge to assessment items only through explicit reviewed conversion.

**First release target:** authenticated adult users can ask, answer, search, report, and link questions to concepts; moderators can intervene; anonymous visitors can read approved public Q&A.

### W2 — Teach a topic without creating a course

**User needs:** A knowledgeable person can sign up to teach a subject/skill, answer questions, tutor, host sessions, or review content. Creating a course is optional.

**Functional scope:**
- Educator profile/channel, bio, areas of expertise, languages, availability, teaching formats and optional price.
- Apply to teach a destination, concept, subject, or skill; maintain multiple subject associations.
- Labels distinguishing self-declared expertise, evidence reviewed by platform, and independently verified licenses/credentials; re-verification and expiration as needed.
- Offer free office hours, live classes, group teaching, recorded explanations, paid tutoring or premium Q&A over time.
- Learners can follow teachers and compare teaching styles without requiring a single teacher to own an entire curriculum.
- Reputation weighted toward evidence-backed helpfulness and outcomes rather than answer volume or follower count.
- Jurisdiction-specific checks for representations about regulated instruction, continuing-education credit, and exam-approval status.

**First release target:** educator opt-in, profile, subject association, questions answered, follower/bookmark function; do not require payments or real-time video in the initial release.

### W3 — Creator channels and a content marketplace

**User needs:** Create original educational work manually or with AI; own and edit it; build an audience; publish free or paid material; earn income with clear terms.

**Functional scope:**
- Creator/channel profile, followers, collections, author identity, content ownership and explicit content license.
- Upload or author individual resources, practice items, courses, study guides, audio and video. Courses are *one format*, not the default obligation.
- AI-assisted outlines, transcripts, translation, diagrams, quizzes and lesson drafts with editing and review. Preserve provenance: human-authored, AI-assisted, or substantially AI-generated.
- Publishing workflow: private draft → submitted → reviewed (when needed) → published → updated/archived. New versions preserve learner history and rights.
- Free, one-time purchase, optional subscription, group seats, tip or tutoring transactions; exact pricing/revenue share deferred until financial and compliance modeling.
- Payment ledger, refunds, entitlements, payout/identity verification, fraud controls, disputes and tax treatment before charging users.
- Prevent low-quality mass-produced AI spam, misattributed content, stolen exam questions, and misleading official affiliations.

**First release target:** free creator publishing with moderation and attribution; test utility and supply before adding real-money transactions.

### W4 — Multi-modal and accessible personal learning

**User needs:** Reading, listening, speaking, asking questions and practicing should be available through the same educational context. Particularly important for adults with limited literacy, children, and learners with accessibility needs.

**Functional scope:**
- Read-aloud and voice interaction; adjustable speed, captions/transcripts, accessible controls, keyboard/screen-reader support and text alternatives.
- Explanations at user-selected reading levels without condescending tone; stepwise scaffolding; visual examples; multilingual support where quality can be verified.
- Adaptive hints, misconception diagnosis, retrieval practice, spaced review and teach-back, using existing study architecture.
- Young learners get age-appropriate experiences and access controls; adults with limited literacy can navigate by audio and visual cues with minimal required reading.
- Clearly distinguish personalized practice from official exam format; don't imply AI-generated items mirror confidential exam questions.
- Local/offline capabilities where feasible; voice and cloud AI may depend on connectivity and usage budgets.

**First release target:** audit and improve existing voice/TTS/STT, accessible Q&A reading/listening, and one adult-literacy or credential learning path tested end-to-end.

### W5 — Measurable learning outcomes and credible recommendations

**User needs:** Learn which resources and teachers are genuinely effective for *people like me*, not simply most liked.

**Measures (keep separate):**
- **Engagement:** visits, completions, saves, helpful votes.
- **Learning:** performance change from diagnostic to comparable validated assessment; concept-level retrieval over time; retained knowledge vs. content completion.
- **Outcome:** independently verified exam passes/credentials when voluntarily supplied and appropriately validated; distinguish self-reported from confirmed.
- **Quality:** expert accuracy review, content age, source freshness, accessibility, student feedback, costs.
- **Fairness/confidence:** sample size, selection bias, learner baseline, subgroup accessibility, repeated attempts, possible gaming; do not claim causal superiority from raw pass rates.

**Rules:** Never manufacture pass rates or grade a course as superior based only on approval scores. Publish minimum sample-size policy and uncertainty where reasonable; offer “insufficient evidence” where unknown. Ranking should balance relevance, instructional suitability, trusted quality, freshness and price rather than rewarding the largest publisher. Maintain a meaningful appeals process.

**First release target:** baseline diagnostic and aligned post-assessment for selected pilot goals, clear outcomes dashboard and feedback collection; later add adjusted comparative ranking once evidence quality warrants it.

### W6 — Platform feedback loop: continuous improvement, not unchecked self-editing

- Aggregate recurring learner questions, misconceptions, invalid practice items, dropout points, outdated cited regulations and accessibility complaints.
- Generate **proposals** to fix instructional gaps, create better explanations, refresh obsolete content and improve learning-path recommendations.
- Assign proposal owners; preserve sources, before/after diffs and change history; reviewer or creator approves changes before they affect published regulated content.
- Re-measure after updates. For experiment-based comparisons, document user consent/eligibility, adequate sample size, guardrails and when results are inconclusive.
- Never silently overwrite creator content or automatically treat AI-generated answers as facts. Official rules require direct authority checking and versioned evidence.

### W7 — Discovery, community and social graph

- Learn / Library / Progress remain the three primary destinations unless a separately reviewed IA change is approved. Discovery of teachers, Q&A and resources can begin through **Library**, goal pages and contextual links.
- Search across trusted destinations, courses, resources, public questions, concepts and teacher profiles, with type filters and freshness/verification labels.
- Follow educators and subjects, save good answers, use opt-in updates. Prevent manipulative gamification, noisy default notifications and popularity-only ranking.
- Maintain source and trust distinction for official/reviewed/unreviewed/personal goals already established in the catalog architecture.

### W8 — Integrations and extensibility

- Design a permissioned integration boundary for voice, AI model adapters, source verification, external video/call services, credential issuer updates and creator tools.
- Provider-agnostic interfaces, model budgets, retry/fallback, observability, rate limits and revocable user consent.
- Keep server secrets server-side. Do not let third-party integrations write directly into authoritative credential requirements, grades or payment records without authorization and auditability.
- Developer integrations/API/third-party extensions are longer-term opportunities, not prerequisites for Q&A or teacher onboarding.

## 4. Launch approach and pilot audience

**Family-first pilots without family-only product design:**

1. **Adult literacy**: voice-guided, low-reading-burden navigation and basic reading tasks, tracked by practical skill demonstrations.
2. **K–12**: age-appropriate reading/math support; minors need appropriate guardian consent and strict restrictions on public posting and direct contact.
3. **Credential/college exams**: CLEP, Florida real estate, insurance, HVAC/EPA or contractor prep; select one or two supported targets whose official requirements and legal constraints are verified.
4. **Contributor/teacher**: a knowledgeable adult joins an existing topic, answers questions, and gains followers without making a course.
5. **Independent market signal**: test with unrelated learners to avoid assuming family willingness to use the app proves public adoption.

Pilot participation should be voluntary; avoid recording sensitive learner details or sharing relatives' education results without consent.

## 5. Suggested data domains (design targets—not migrations to execute)

Map the proposed logical entities to existing tables first; use new tables only where needed:

| Domain | Candidate logical tables / entities | Key notes |
|---|---|---|
| Community Q&A | `community_questions`, `community_answers`, `answer_revisions`, `question_topic_links`, `question_reports`, `answer_feedback` | Separate from existing assessment `questions`; moderation and stable concept/target links |
| Educators | `educator_profiles`, `educator_subjects`, `educator_verifications`, `follows`, `teaching_offerings` | Claims vs. verification; a teacher doesn't own the subject |
| Creator content | `creator_channels`, `resource_versions`, `resource_authorship`, `resource_licenses`, `publication_reviews` | Extend existing courses/lessons rather than duplicating them |
| Learning quality | `assessment_evidence`, `outcome_attestations`, `content_quality_reviews`, `learning_feedback` | Distinguish diagnostic, retention, self-report, official evidence |
| Improvement | `content_issue_signals`, `content_update_proposals`, `source_check_runs` | Reviewable and versioned, with traceability |
| Marketplace (later) | `marketplace_offers`, `orders`, `entitlements`, `payout_ledger`, `refunds` | Transaction compliance, provider segregation, server-side enforcement |
| AI/integrations | `ai_generation_provenance`, `provider_usage`, `integration_permissions` | Model and source transparency, consent, costs and secrets |

**Database guardrails:** additive Supabase migrations only; RLS by role/resource; server-side authorization; protect user content and progress; avoid public leakage of minors' data; no production reset; backup/restore verification before material user-data changes. Keep source-of-truth for official licensing rules restricted to reviewed and versioned records.

## 6. Prioritized roadmap and delivery gates

### Phase 0 — Repository inventory, product boundaries and baseline safety (first)

**Tasks**
- [ ] Audit actual implemented features, migrations, existing assessment `questions`, Q&A-like components (if any), author/content ownership, voice capability and current catalog/data state. Produce a gap matrix, not guesses.
- [ ] Map this plan to `LEARNING_ARCHITECTURE_V2.md`, `UI_ARCHITECTURE_LOCKED.md` and active catalog-growth roadmap; document conflicts and change-control proposals.
- [ ] Define learning destination vs. community question vs. assessment item vs. learning resource vs. teacher/creator identity.
- [ ] Define moderation, AI disclosure, rights, minor-safety, regulated-course claims, source freshness, minimum access controls and instrumentation.
- [ ] Establish baseline hosting/AI/TTS/media cost dashboards and conservative feature budgets.

**Exit:** accepted domain model and issue backlog with owners, dependencies, data risk assessment, test plan and no duplicate implementations.

### Phase 1 — Community Q&A minimum useful product

**Tasks**
- [ ] Public approved question/answer detail pages and topic/category search; support standalone and concept-linked questions.
- [ ] Logged-in ask/answer/edit/report flows, answer history, spam/rate limits, moderation queue.
- [ ] Optionally generate labeled AI explanations; avoid pretending AI is a verified human expert.
- [ ] Contextual links from lessons/goal pages to related Q&A; new feature discoverable within existing navigation.
- [ ] Automated unit, database-policy, accessibility and browser E2E tests.

**Exit:** a new user can find an existing answer, ask an original question, receive or add a human answer, listen to it where supported, and report incorrect/harmful information; published content respects moderation rules.

### Phase 2 — Teacher identities and lightweight contribution

**Tasks**
- [ ] Opt-in educator profile and subject/concept/goal affiliation; independent of course ownership.
- [ ] Clear expertise/verifications; teacher-answer attribution, searchable teacher profile, follows.
- [ ] Easy “Teach this topic” pathway; creator can contribute an explanation or original lesson without building a full course.
- [ ] Begin quality and helpfulness feedback with anti-abuse measures.

**Exit:** an adult can register as an educator for an existing topic and build a public body of useful contributions without creating a course; verification claims are accurately labeled.

### Phase 3 — Content creation, accessibility and family pilot

**Tasks**
- [ ] Resource authoring/publishing with creator ownership, source references, AI-assisted drafts, content review and revisions.
- [ ] Improve voice, read-aloud, simpler explanations and assessment context reuse.
- [ ] Run opt-in adult literacy + credential-prep pilots; test age-appropriate study functionality separately with proper safeguards.
- [ ] Add comparable before/after assessments and feedback on confusion, time, cost and usefulness.

**Exit:** at least one credible end-to-end learning experience improves a specific learner skill or preparation outcome; contributors can publish a reviewed standalone learning resource.

### Phase 4 — Evidence-based discovery and content improvements

**Tasks**
- [ ] Build educational-quality scoring framework with evidence quality, uncertainty and protection against cherry-picking.
- [ ] Propose content fixes from outdated sources, repeated misconceptions and study outcome patterns; review before publication.
- [ ] Pilot personalized recommendations and matching between learner needs, questions, resources and teachers.
- [ ] Track effects without conflating engagement, pass rates and genuine educational gains.

**Exit:** learner can find resources relevant to their needs with transparent reasoning; source-linked corrections can be safely proposed, reviewed, published and measured.

### Phase 5 — Marketplace, sessions and extensibility

**Tasks**
- [ ] Model creator ownership/terms and choose monetization based on demonstrated user demand; prototype free or simulated purchase first.
- [ ] Add compliant payments, sales entitlements, refunds and payouts only after legal/accounting/security readiness.
- [ ] Optional booking, live/group instruction, subject expert offerings and premium Q&A.
- [ ] Evaluate provider integrations or external developer APIs once core user journeys are reliable and abuse controls mature.

**Exit:** at least one paid workflow is compliant, comprehensible to users, economically viable after creator share and variable costs, and reliably reconciled.

## 7. Epics suitable for project tracking

| ID | Epic | Priority | Dependencies |
|---|---|---|---|
| ECO-00 | Architecture audit & gaps | P0 | Existing repo docs, schema and migrations |
| ECO-01 | Community Q&A core | P0 | ECO-00, moderation |
| ECO-02 | Question-topic/lesson/goal linking | P0 | ECO-01, existing concept model |
| ECO-03 | AI answer disclosure and safety | P1 | ECO-01, AI integration boundary |
| ECO-04 | Educator identities & subject affiliation | P1 | ECO-00, identity, trust |
| ECO-05 | Educator contribution and discovery | P1 | ECO-01, ECO-04 |
| ECO-06 | Creator channels and original resource publishing | P1 | ECO-00, moderation, copyright rules |
| ECO-07 | Accessible voice-first learning | P1 | Existing TTS/STT, ECO-01 |
| ECO-08 | Family pilot evaluation and verified readiness | P1 | Existing assessments, ECO-07 |
| ECO-09 | Learning outcome analytics and quality measures | P2 | ECO-08, vetted assessments |
| ECO-10 | Automated content issue detection + human review | P2 | ECO-06, ECO-09, authoritative sources |
| ECO-11 | Personalized discovery and teacher/resource matching | P2 | ECO-02, ECO-05, ECO-09 |
| ECO-12 | Creator monetization and tutoring marketplace | P3 | ECO-06, economics, compliance, payouts |
| ECO-13 | External integrations/API ecosystem | P3 | Security, mature usage evidence |

*P0 = urgent prerequisite; P1 = near-term; P2 = medium-term; P3 = longer-term. These are relative priorities, **not delivery-date promises**.*

## 8. Metrics and decision rules

Track at least the following, with appropriate consent, privacy controls and definitions:

- Learner usefulness: percentage able to complete a desired task; relevant learning outcomes, not only session length.
- Retrieval/retention: concept-level recall over appropriately spaced, comparable assessments; separately report content completion.
- Credibility: percentage of sampled published answers/resources passing editorial factual checks; unresolved error and freshness backlog.
- Q&A health: time to first useful human answer, proportion of unanswered questions, reports per exposure, repeat-question rate.
- Creator health: meaningful contributions per active educator, repeat learners, revenue **after** costs when monetization exists, unfair-report appeals.
- Economics: AI cost per resolved question, TTS/STT cost per learning session, media storage, moderation burden, payment processing and refunds.
- Equity/accessibility: voice-use reliability, reading-level accessibility, mobile performance and offline coverage where supported.

**Interpretation:** use segmented cohorts and credible denominators. Self-reported “I passed” is not equivalent to official verified result. Educational gain is not identical to a course completion or high rating. Do not invent numerical targets before baseline data exists.

## 9. Trust, rights, safety and compliance gates

1. **Accuracy:** publisher/regulator/official-source priority for credential requirements; timestamps, jurisdiction/version IDs, review status and correction flow. Content that is outdated can be deprecated without erasing educational history.
2. **AI:** label generated content; store provenance; protect prompts and submitted personal data; human/expert review for high-stakes published content; no false claims of accreditation, pass guarantees or official examination materials.
3. **Copyright & attribution:** creators retain rights according to agreed licenses; handle takedowns; do not ingest copyrighted paid courses or live exam questions without permission; reuse an answer for a course only with appropriate rights.
4. **Minors:** age-appropriate experiences; guardian permissions where required; default restrict public profiles, messaging, live interactions and visibility; abuse reporting and moderation. Seek legal review for applicable children's privacy requirements.
5. **Regulated education:** distinguish study preparation from state-approved prelicensing/continuing education or officially approved instruction. Verify state, program, age and credential claims.
6. **Security:** least-privilege RLS; rate limits; audit logs; service credentials only on servers; transactional integrity for money; regular restore-tested backups including off-site encrypted backup.
7. **Fairness and manipulation:** anti-spam, verified reviewer procedures, appeals, confidence labels, and resistance to fake pass rates or AI answer flooding.

## 10. Specific UX commitments

- Preserve direct access to learning and the existing Learn/Library/Progress navigation unless change control approves otherwise.
- Make ordinary Q&A discoverable via Library/search and contextual links, not a mandatory onboarding step.
- “Ask a question,” “Teach this,” and “Create material” can coexist, but appear only in relevant places and avoid overloading first-run screens.
- A user can ask a general question without selecting a course or official goal; linking to knowledge concepts should be optional/assisted.
- AI help is available but not required. A teacher can teach without publishing a course. A learner can study without engaging the public community.
- Keep private family/child learning distinct from public social feeds.

## 11. Agent handoff and progress-tracking instructions

**Intake prompt for any coding agent or planning assistant working in `RACCHUS/LearningApp`:**

> Treat this file as a strategic product roadmap, not permission to implement everything immediately. First review current `README.md`, `AGENTS.md`, `LEARNING_ARCHITECTURE_V2.md`, `UI_ARCHITECTURE_LOCKED.md` and `docs/catalog/CATALOG_GROWTH_AND_DEMAND_PLAN.md`, plus the latest code and Supabase migrations. Identify existing, partial and missing functionality. Retain the completed official taxonomy work and active catalog-growth plan. Convert each epic above into a trackable issue/task with acceptance criteria, dependencies, status, risks and verification steps. Do not duplicate existing models, rewrite merged migrations, reset live data, weaken RLS, claim unverified credentials, or modify locked navigation without change control. Implement only an explicitly selected and scoped phase via feature branch and PR, with tests and a rollback/backup plan. Keep the roadmap updated as issues complete; record actual evidence rather than treating planned features as shipped.

**Suggested issue fields:** `Epic ID`, `Feature`, `Goal / user story`, `Priority`, `Status (proposed / scoped / in progress / blocked / tested / shipped)`, `Dependencies`, `Acceptance criteria`, `Data changes`, `Privacy/legal risks`, `Evidence links`, `Owner`, `Last reviewed`.

**Suggested initial action:** Save the plan in the repo and create/organize tracking issues. Then begin **ECO-00** (gap audit). Do **not** build the full feature set in one implementation pass.

## 12. Decisions explicitly left open

- Whether the public Q&A brand is one named area under Library or eventually merits dedicated navigation (requires UX evidence and baseline change control).
- Exact creator revenue share, subscriptions, tutoring fees, or ad model (test unit economics before committing).
- Formal verification standard for teacher credentials and user-submitted exam pass results.
- Moderation staffing/model, global languages, geographic rollout, age eligibility for community posting, and minors' interaction restrictions.
- Third-party AI and video providers, model portability, API monetization and streaming architecture.

**Decision principle:** Make reversible choices early; protect the long-term separation between goals, content, people, questions, and evidence. Prioritize educational value and trust over raw content volume.
