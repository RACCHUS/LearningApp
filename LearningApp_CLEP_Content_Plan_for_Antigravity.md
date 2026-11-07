# LearningApp CLEP Content Program
## Implementation Plan and Work Brief for Antigravity

**Status:** Proposed implementation plan  
**Prepared:** November 7, 2026  
**Project:** RACCHUS/LearningApp  
**Primary objective:** Build a repeatable, quality-controlled system for creating, validating, importing, teaching, and maintaining complete CLEP preparation courses inside LearningApp.

---

## 1. Mission and expected outcome

Create a high-quality CLEP preparation catalog within the existing LearningApp platform. The goal is not merely to upload study notes or generate question banks. Each exam course should teach the material, help learners retain it, diagnose weaknesses, provide realistic practice, and help learners judge when they are ready to sit the official exam.

CLEP should be implemented as an educational pathway using the existing LearningApp architecture wherever practical. Do not create a separate CLEP application, duplicate core learning functionality, or introduce a parallel content model without demonstrating that the existing model cannot support the requirement.

The work has two related outcomes:

1. **Content program:** A reliable pipeline and content standard that can produce all current CLEP courses and keep them aligned with the official exam specifications.
2. **Learning experience:** A consistent, effective course structure that supports diagnostic assessment, instruction, retrieval practice, mastery measurement, spaced review, and full-length practice.

The content pipeline should eventually be reusable for other standardized learning pathways, including professional licensing and trade exams. However, keep this implementation focused on CLEP and avoid expanding scope into unrelated exam programs.

## 2. Instructions to Antigravity before implementation

### 2.1 Inspect the actual repository first

Before changing code, database schema, migrations, or content:

- Inspect the current `main` branch and identify the current commit.
- Review the current course, subject, lesson, objective/skill, question, assessment, flashcard, progress, and content-ingestion models.
- Review existing content manifests, import scripts, authoring tools, generation workflows, and validation tests.
- Review the current assessment delivery and grading architecture. In particular, preserve server-side grading and answer-key protection.
- Review relevant Supabase migrations, Row Level Security (RLS) policies, storage usage, indexes, and existing content ownership rules.
- Review existing documentation and the current product/architecture proposals relevant to learning content and simulation.
- Identify what is already implemented, what is partially implemented, and what is only proposed.

Do not assume that a feature exists just because it appears in an older proposal or this plan. Do not rebuild existing functionality.

### 2.2 Produce an initial gap analysis

Before implementation, report:

- Existing reusable components and data models.
- Missing capabilities required for CLEP.
- Existing content formats and the recommended format for CLEP.
- Any schema changes genuinely required.
- Any security, storage, performance, or migration risks.
- A phased implementation proposal with files and systems likely to be affected.

Prefer extending existing models and workflows over creating CLEP-specific infrastructure. Do not begin broad refactoring as part of this task.

### 2.3 Work safely

- Work on a dedicated feature branch.
- Do not push directly to `main`.
- Do not merge without explicit authorization.
- Keep changes scoped, reviewable, and tested.
- Do not run destructive production operations.
- Do not add credentials, secrets, or private answer keys to client-accessible files.
- Do not introduce a paid third-party dependency or external AI service without documenting the need, cost, privacy implications, and alternatives.
- Keep content generation reproducible and reviewable; do not make runtime AI generation a prerequisite for a student to access published course content.

---

## 3. Curriculum authority and exam catalog

### 3.1 Use the official CLEP catalog as the source of truth

At implementation time, retrieve the current list of CLEP exams and the latest official exam descriptions, outlines, skill statements, and format information from the College Board.

For every exam, record:

- Official exam name and stable internal identifier.
- Official source URL(s).
- Source publication/update date or version, where available.
- Current exam format and time limit.
- Official content domains and their stated percentage ranges, if provided.
- Official skills and learning objectives.
- Any calculator, writing, listening, reading, or other exam-specific requirements.
- Date the course was last checked against the official specification.

Do not hard-code an assumed number of CLEP exams. The catalog must be reconciled against the official College Board catalog at the time of work.

### 3.2 Build an exam-to-objective coverage map

Each exam must have a traceable hierarchy:

`CLEP program → exam → domain → topic → learning objective → lesson/content → practice item`

Every official objective should map to one or more instructional units and assessment items. Where the official outline does not provide granular objectives, create clearly labeled instructional objectives derived from the official domain descriptions.

The coverage map must make it possible to answer:

- Which official objectives are covered?
- Where are they taught?
- How are they practiced?
- How is mastery measured?
- Which source supports the instruction?
- What has not yet been written or validated?

Do not represent a course as complete if important official objectives are missing.

### 3.3 Course priority

Build the system so the entire current catalog can be supported. Populate courses in waves rather than attempting to publish all exams at once.

Suggested initial pilot and first-wave candidates:

1. Introductory Psychology
2. Introductory Sociology
3. College Algebra
4. College Composition
5. American Government
6. Human Growth and Development
7. Principles of Macroeconomics
8. Principles of Microeconomics
9. History of the United States I
10. Biology

This is a proposed product-development sequence, not an assertion of official College Board exam-volume rankings. Before finalizing the production order, use the latest available official exam-volume data if it can be obtained, along with college-credit applicability and content-development effort. Record the rationale for the chosen sequence.

Start with one representative pilot course before scaling. Introductory Psychology is a reasonable pilot because it exercises terminology, conceptual explanation, theories, examples, and scenario-based questions. College Algebra should be an early second pilot to test mathematical notation, worked solutions, and problem-solving interactions.

---

## 4. Standard course structure

Use a consistent structure across exams, while allowing exam-specific teaching methods.

### 4.1 Course home

Each CLEP course should show:

- What the exam covers.
- Official exam format, time limit, and relevant requirements.
- A clear estimate of course scope and learner progress.
- A diagnostic assessment.
- Recommended learning sequence.
- Domain-level progress and strengths/weaknesses.
- Practice and simulated exam access.
- Source/specification review date.

Avoid presenting an unverified predicted pass probability. Readiness indicators must be based on actual assessment evidence and clearly explain their limitations.

### 4.2 Domain and topic structure

Each domain should contain coherent topics, and each topic should contain focused learning units. Avoid excessively long lessons and avoid splitting content into tiny fragments that destroy conceptual continuity.

Each learning unit should include, where appropriate:

1. Learning objectives written in measurable language.
2. Prerequisite knowledge.
3. A clear explanation of the concept.
4. Examples, applications, and worked reasoning.
5. Important vocabulary and distinctions.
6. Common misconceptions and likely distractors.
7. A short retrieval check.
8. Links to related topics.
9. References/source attribution.
10. A mastery check.

Do not force every subject into the same media format. For example:

- Mathematics needs worked examples, progressive problem difficulty, and step-by-step reasoning.
- History and government need chronology, cause/effect, institutions, comparisons, and source interpretation.
- Psychology and sociology need concept distinctions, theories, applications, and scenario analysis.
- Languages need listening, reading, vocabulary, grammar, and language production where supported.
- Composition needs writing and revision practice, not only multiple-choice questions.

### 4.3 Instructional sequence

The recommended learning loop is:

1. **Diagnose:** Identify prior knowledge and gaps.
2. **Plan:** Prioritize objectives based on the exam blueprint, prerequisites, and diagnostic evidence.
3. **Teach:** Explain the concept with examples and suitable media.
4. **Retrieve:** Ask learners to recall before revealing answers or explanations.
5. **Practice:** Provide varied, progressively challenging questions.
6. **Explain:** Give useful feedback that explains why an answer is right or wrong.
7. **Measure:** Track objective-level understanding, not just total points.
8. **Review:** Schedule retrieval and spaced practice.
9. **Adapt:** Re-teach or advance based on demonstrated learning.
10. **Prepare:** Provide domain reviews and timed exam simulations.

Preserve LearningApp's existing learning principles, including recall-before-reveal and meaningful mastery rather than engagement-only metrics.

---

## 5. Content production pipeline

Build a repeatable workflow that turns an official exam outline into publishable course content.

### Stage A — Source collection

For each objective, collect trustworthy material from sources appropriate to the subject. Preferred sources include:

- College Board exam descriptions and official specifications.
- Open educational resources with explicit reuse licenses.
- Public-domain primary sources and government publications where relevant.
- Reputable textbooks or reference works only where access and licensing permit.
- University and educational institution materials with clear terms of use.

Modern States and other free CLEP preparation resources may be useful research or learning references, but do not copy or redistribute their content unless the applicable license or written permission clearly permits it.

Record source title, publisher/author, URL, access date, applicable license/permission, and the objectives supported. A source being publicly viewable does not mean it is free to copy.

### Stage B — Objective research and content outline

For each objective:

- Summarize the knowledge and skills a learner must demonstrate.
- Identify prerequisite concepts.
- Identify common misconceptions.
- Identify the cognitive demand: recall, comprehension, application, analysis, or other relevant skill.
- Determine the best instructional approach.
- Map the objective to appropriate practice formats.

### Stage C — Original lesson authoring

Create original instructional material. It should be accurate, clear, accessible, and suitable for independent study.

Requirements:

- Explain ideas rather than paraphrasing a source sentence by sentence.
- Use original examples and scenarios.
- Define technical terms at first use.
- Distinguish facts, interpretations, and contested theories.
- Use accessible language without making the material academically shallow.
- Include equations, diagrams, timelines, tables, audio, or other formats when they genuinely help.
- Provide citations/references for factual claims and further reading.
- Avoid fabricated quotations, studies, statistics, or citations.

### Stage D — Practice item authoring

Create original questions aligned to the official exam domains and objectives.

Each item should include, as appropriate:

- Stable item ID.
- Exam, domain, topic, and objective mapping.
- Question type and difficulty.
- Question stem and answer choices, if applicable.
- Correct answer and explanation.
- Explanation of why distractors are wrong, where useful.
- Skill/cognitive-demand classification.
- Source or rationale supporting the keyed answer.
- Authoring and review status.
- Version and change history.

Questions should test understanding and application, not merely repeat lesson wording. Use varied scenarios and avoid predictable answer patterns.

Do not scrape, reproduce, or claim access to secure/live CLEP questions. Do not imply that generated questions are official College Board questions. Label them as original LearningApp practice questions.

### Stage E — Review and validation

Every course must pass content review before publication.

Minimum review checks:

- Accuracy and factual consistency.
- Alignment with official exam objectives.
- Coverage completeness.
- Correct answer and explanation verification.
- Ambiguity and multiple-defensible-answer checks.
- Distractor quality.
- Appropriate difficulty and cognitive demand.
- Accessibility and readability.
- Citation and licensing review.
- Duplication and near-duplication checks.
- Mathematical calculation and notation checks where applicable.
- Grammar and formatting checks.

Use automated checks where possible, but do not treat AI self-review as sufficient independent validation. High-impact factual claims, answer keys, and difficult questions should receive human review. If human review is not available, mark the content as awaiting review rather than silently presenting it as fully verified.

### Stage F — Import, publish, and maintain

- Convert approved content into the existing LearningApp content format.
- Validate manifests and references before import.
- Make imports idempotent so re-running an import does not duplicate content.
- Keep drafts separate from published content.
- Support updates without losing learner progress.
- Record content versions and publication status.
- Retain source and review metadata.
- Provide a way to identify content affected by a changed College Board specification.

---

## 6. Content quality and status model

Use the existing status/version system if one exists. Otherwise, propose the smallest compatible extension.

Suggested lifecycle:

`planned → sourced → drafted → reviewed → approved → published → needs_update → archived`

A course should not be marked complete merely because it has a title, a few lessons, or a question bank.

Suggested publication gates:

- Every official domain is represented.
- Every objective is mapped.
- Every objective has meaningful instruction or a documented reason why instruction is not needed.
- Every objective has appropriate practice.
- Questions have verified keys and explanations.
- Sources and licensing are recorded.
- Required reviews are complete.
- Import and student-facing flows pass tests.

Show learners when material is being updated if a meaningful specification change affects their course.

---

## 7. Assessment and exam simulation

Use the existing secure assessment architecture wherever possible. Do not weaken server-side grading, answer-key withholding, assessment immutability, or RLS protections to make content authoring easier.

Provide three distinct assessment modes:

### 7.1 Learning checks

- Short, untimed checks after lessons or topics.
- Immediate feedback and explanations.
- Focus on learning, not high-stakes scoring.
- Allow retries and targeted remediation.

### 7.2 Domain practice

- Questions sampled by objective and difficulty.
- Configurable practice sessions.
- Clear explanations and review of missed concepts.
- Objective-level performance tracking.
- Avoid repeatedly serving the same items when enough alternatives exist.

### 7.3 Full-length CLEP-style simulations

- Match the current official exam's documented structure, timing, and question-format mix as closely as the public specifications allow.
- Use original LearningApp questions only.
- Keep simulation questions and answer keys protected using existing assessment security controls.
- Provide a realistic timed experience, with accessibility options that do not undermine the intended simulation.
- After submission, provide a detailed report by domain and objective.
- Clearly state that a LearningApp simulation score is not an official CLEP score and is not a guaranteed prediction of exam performance.

Do not invent official scoring conversions or pass thresholds. If College Board does not publish enough information to support a conversion, report raw performance and LearningApp readiness indicators without pretending they are equivalent to the official scaled score.

---

## 8. Personalization and mastery

Use the platform's existing progress and learning models. The course should adapt to evidence of learning rather than merely track completion.

Desired capabilities:

- Diagnostic placement by domain/objective.
- Objective-level mastery estimates based on sufficient evidence.
- Remediation recommendations for weak objectives.
- More challenging application questions after foundational mastery.
- Spaced review based on recall performance and time.
- Revisit of previously weak concepts.
- Recognition of prior knowledge so learners do not have to repeat mastered material unnecessarily.
- Clear separation between exposure, practice success, and durable retention.

Do not overstate mastery from a single correct answer. Track the evidence behind mastery and use confidence/insufficient-evidence states where appropriate.

---

## 9. Accessibility and device support

CLEP courses must work within LearningApp's existing responsive application experience across phones, tablets, laptops, and desktops. Review larger-screen and keyboard/controller possibilities without making unsupported promises about gaming-console compatibility.

Requirements:

- Responsive layouts and readable typography.
- Keyboard navigation and visible focus.
- Screen-reader labels and semantic structure.
- Sufficient contrast and non-color-only status indicators.
- Captions or transcripts for audio/video where applicable.
- Mathematical notation that remains usable on small screens.
- No essential instruction available only through hover.
- Save and resume behavior for longer lessons and assessments.
- Efficient media delivery and sensible caching.
- Avoid downloading large media files unless needed.

Do not create a separate media or asset system if existing storage and delivery patterns can meet these requirements.

---

## 10. Data, storage, performance, and security constraints

CLEP will introduce a substantial amount of content. Design for efficient storage and delivery.

- Reuse shared concepts and assets when appropriate, but do not create confusing cross-course coupling.
- Avoid storing duplicate copies of identical lesson text or media.
- Avoid oversized JSON blobs if the existing model supports more efficient structured records.
- Keep large media in suitable object storage rather than database rows.
- Avoid unnecessary storage of generated intermediate drafts and duplicate exports.
- Define retention and cleanup rules for temporary generation artifacts.
- Add indexes only for demonstrated query patterns.
- Paginate large content and question collections.
- Avoid loading every exam's entire content catalog on course startup.
- Preserve RLS and per-user isolation for progress and assessment data.
- Keep answer keys and protected assessment data inaccessible to unauthorized clients.
- Do not store secrets in content manifests or client bundles.
- Ensure content imports are auditable and safe to retry.

Before adding migrations, estimate row counts and storage implications for the full catalog and explain any meaningful tradeoffs.

---

## 11. Authoring and automation tools

Prefer a maintainable workflow that lets content creators produce and review courses without hand-editing database rows.

Evaluate existing tools first. If the current repository lacks a suitable authoring workflow, propose a lightweight extension that supports:

- Exam and objective outline import.
- Structured lesson and question authoring.
- Source/reference tracking.
- Draft and review status.
- Schema and coverage validation.
- Duplicate detection.
- Preview in the student experience.
- Idempotent import and publication.
- Export or backup of source-authored content.

AI can assist with research organization, first drafts, alternative explanations, question generation, and quality checks. AI-generated material must remain reviewable, versioned, and unpublished until it passes the defined gates.

Do not build a large custom content management system unless the repository audit demonstrates that a smaller solution is inadequate.

---

## 12. Testing and acceptance criteria

### 12.1 Engineering tests

At minimum:

- Content schema and manifest validation tests.
- Import idempotency tests.
- Missing/invalid objective mapping tests.
- Course, lesson, and question retrieval tests.
- Assessment security and answer-key withholding tests.
- Server-side grading tests.
- RLS and cross-user isolation tests.
- Progress preservation across content updates.
- Responsive layout and accessibility checks.
- Performance tests for course startup and large question sets.
- Storage and duplicate-content checks.

Run the repository's relevant CI suites and report exact results. Do not claim a test passed unless it was actually run.

### 12.2 Pilot course acceptance

The pilot course is acceptable when:

1. Its exam outline is current and sourced from College Board.
2. All official domains and objectives are mapped.
3. Each objective has suitable instruction and practice.
4. Lessons are coherent, accessible, and fact-checked.
5. Practice questions have validated answers and explanations.
6. The diagnostic, learning, domain practice, and simulation flows work.
7. Learner progress and objective-level feedback work.
8. Content imports are repeatable without duplication.
9. Assessment security remains intact.
10. The course works on supported screen sizes and input methods.
11. The course's review and publication status is visible to administrators/content maintainers.
12. Known limitations are documented.

### 12.3 Catalog acceptance

The catalog implementation is acceptable when:

- Every currently offered CLEP exam has a catalog record.
- Every exam has official source/specification metadata.
- The catalog clearly distinguishes planned, in-development, reviewed, and published courses.
- The pilot production workflow can be repeated for another exam without bespoke engineering.
- A second, materially different exam (such as College Algebra) validates that the framework supports subject-specific teaching needs.

A catalog record does not mean a complete course is available. Never advertise an exam as fully prepared until its course meets the publication gates.

---

## 13. Phased delivery plan

### Phase 0 — Repository and architecture audit

**Deliverables:**

- Current-branch and commit identification.
- Architecture map for existing learning/content systems.
- CLEP-specific gap analysis.
- Proposed reuse-versus-extension decisions.
- Risks and phased implementation plan.

**Gate:** Review findings before making broad architectural changes.

### Phase 1 — CLEP catalog and curriculum framework

**Deliverables:**

- Current official exam catalog.
- Exam/domain/objective data model or reuse mapping.
- Source and specification version tracking.
- Coverage map and validation rules.
- Course status lifecycle.

**Gate:** Demonstrate one exam's official outline mapped to the proposed framework.

### Phase 2 — Content production workflow

**Deliverables:**

- Source collection and attribution standard.
- Lesson and question authoring templates.
- Review/approval workflow.
- Manifest validation and idempotent import.
- Draft preview and publication process, reusing existing tools.

**Gate:** Import a small, reviewed sample without duplicate records or unsafe exposure.

### Phase 3 — Pilot course: Introductory Psychology

**Deliverables:**

- Complete domain/objective map.
- Lessons for the full pilot scope.
- Original practice questions and explanations.
- Diagnostic and domain practice.
- Spaced-review integration.
- At least one full-length simulation aligned with public specifications.
- Quality and source review report.

**Gate:** Meet all pilot acceptance criteria.

### Phase 4 — Second pilot: College Algebra

**Deliverables:**

- Complete objective map and course.
- Mathematical lesson and worked-example support.
- Problem-solving question types and validation.
- Appropriate timed practice and simulation.
- Evidence that the framework supports a different subject type without major redesign.

**Gate:** Confirm the content pipeline is reusable.

### Phase 5 — First-wave catalog expansion

Develop the remaining initial priority courses using the same workflow. Reassess ordering using current exam demand, credit applicability, development effort, and learner feedback.

**Gate:** Each course independently passes the publication checklist.

### Phase 6 — Full catalog and ongoing maintenance

- Add all remaining current CLEP exams.
- Monitor College Board specification changes.
- Review content quality and learner performance.
- Retire or revise outdated content.
- Improve lessons and questions based on measured learning outcomes.

---

## 14. Required progress reporting

At the end of each phase, report:

1. What was inspected or changed.
2. What existing functionality was reused.
3. Files and database objects changed.
4. Migrations added, if any, and why they were necessary.
5. Content produced and its review status.
6. Source and licensing status.
7. Tests run and exact pass/fail counts.
8. Security, performance, storage, and accessibility implications.
9. Known gaps and risks.
10. Recommended next phase.

Keep implementation work on the feature branch and provide reviewable commits/PRs. Stop at phase gates when a decision or approval is required rather than silently expanding scope.

---

## 15. Explicit non-goals and prohibited shortcuts

Do not:

- Build a separate CLEP app or duplicate the existing learning engine.
- Treat a list of topics or a large AI-generated question bank as a complete course.
- Copy College Board test questions, secure exam material, or third-party course content without permission.
- Claim practice questions are official CLEP questions.
- Claim a simulated score is an official CLEP score.
- Publish unreviewed AI-generated answers as verified facts.
- Mark courses complete when official objectives are unmapped.
- expose answer keys or protected assessment content to the client.
- weaken RLS, server-side grading, or existing assessment protections.
- introduce unnecessary schema, storage, or dependency complexity.
- make all courses use identical instructional formats when the subject requires different approaches.
- merge to `main` without explicit authorization.

---

## 16. First task to execute

**Begin with Phase 0 only.**

Inspect the current LearningApp repository and produce a concise but evidence-based CLEP readiness report. Identify the actual existing systems for courses, lessons, skills/objectives, questions, assessments, progress, content manifests/import, and any AI content generation. Map this plan to the real implementation and identify the smallest set of changes needed.

Do not start building all CLEP content before this audit. Once the audit is complete, propose the Phase 1 implementation and identify any decisions that require approval.

**Definition of success:** LearningApp gains a repeatable, source-grounded, quality-controlled way to deliver genuinely effective CLEP preparation courses using its existing learning platform—not merely a collection of AI-generated study materials.
