# LearningApp — Platform Vision, Trust Architecture & Full-Scope Execution Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Branch:** `feature/arch-review-phase-0` (PR `#136`, tracked separately)
**Related Plan:** [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md) · **Status:** Reconciled Platform Strategy (v2.1)

---

## 1. Strategic Position: Keep the Broad Platform Vision, Enforce Honest Validation Boundaries

1. **The Product Vision Remains Broad and Reusable**
   - LearningApp is a multi-domain learning and exam-readiness platform built on reusable primitives: **Learning Architecture V2** (global concepts + scoped curricula), **Canonical Taxonomy v2.4**, **Curriculum Manifests**, **Literacy & Audio-First Accessibility**, **EXM-00..03** (open-book reference navigation and server-validated assessment), and **ECO-00..04** (community Q&A, moderation, and educator verification).
   - We do **not** dismantle or artificially narrow these foundations.

2. **Distinguish Built Foundations from Validated Claims**
   - Some subsystems on `main` (`e538585`) are implemented and pgTAP/widget-tested (`EXM-01..03`, `ECO-00..04`, taxonomy crosswalks, manifest ingestion), while others are heuristic baselines (`spaced_repetition.dart`, `ConceptEvidenceService`) or architectural specifications awaiting empirical validation.
   - **Core Rule**: Only claims that have actually been validated with appropriate data may be presented to learners as proven.

3. **Task-Aware Engine Over One-Size-Fits-All or Rigid Modalities**
   - As specified in [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md), the learning engine uses **Multidimensional Learning Task Profiles (`LearningTaskProfile`)** with composable instructional strategies rather than mutually exclusive concept modalities.

---

## 2. Two Independent Quality Systems: Content Trust vs. Measurement Quality

Content provenance and statistical measurement are orthogonal: an official statute is authoritative at $N=0$ attempts, while a popular unverified quiz can have $N=5,000$ attempts and still be wrong. And neither is the same as whether the *learner* has mastered the material.

We therefore enforce four independent state dimensions across the platform:

### A. Content Trust & Provenance (`content_trust_level`)
1. **`personal_import`** — Private to the user (`is_public = false`), source recorded, unverified. Fully usable for personal study and spaced review; **never counted toward authoritative exam readiness**.
2. **`automated_checked`** — Passed deterministic schema, citation, option-structure, and consistency checks.
3. **`editorially_reviewed`** — Reviewed by a verified educator/moderator (`ECO-02` / `ECO-04`) for factual accuracy and instructional quality.
4. **`authoritatively_verified`** — Verified against the primary official source and effective `TargetVersion` release window (`content_provenance`).

### B. Measurement Quality (`measurement_quality_level`)
1. **`unobserved`** — No learner response data ($N = 0$).
2. **`research_informed_prior`** — Initial cognitive/content complexity profile established from deterministic task features.
3. **`observed`** — Learner responses available, below statistical calibration threshold.
4. **`calibrated`** — Sufficient representative responses and validated statistical item estimates ($b_i, a_i$) with bounded uncertainty.
5. **`validated_for_intended_use`** — Demonstrated measurement and predictive validity in the relevant candidate population and exam context.

### C. Blueprint Alignment (`blueprint_alignment_state`)
- Recorded independently (`unmapped` | `concept_mapped` | `blueprint_weighted` against an official `TargetVersion` exam outline).

### D. Learner Mastery & Readiness Evidence
- Evaluated across four distinct capabilities: **(1) Comprehension during instruction, (2) Delayed spaced retrieval, (3) Transfer to unfamiliar held-out problems, and (4) Execution under actual examination conditions (timing + reference rules).**

---

## 3. Keeping the Platform Free, High-Quality, and Sustainable

Every subsystem operates under explicit **feature maturity levels (`experimental` | `beta` | `stable`)**, free-tier cost boundaries, and kill switches:

- **Optional External & On-Device AI (`BYOK` / `MCP` / Browser)**:
  - Users can connect their own API keys (including Gemini's public YouTube URL support within its daily free-tier allowance, OpenRouter, OpenAI, or Anthropic) or connect via **MCP**. Server-side quotas (`ECO-00C`) protect any platform-sponsored actions.
- **Embed Rather Than Host Video**:
  - Video instruction uses privacy-safe embeds (`youtube-nocookie`, Vimeo, PeerTube) paired with timestamped retrieval checkpoints mapped to canonical concepts.
- **Private Imports by Default**:
  - Imported decks (Anki, CSV, PDF, YouTube, AI) enter as `personal_import`. Promotion to public catalog tiers requires passing automated checks and editorial review (`ECO-02`/`ECO-04`).
- **Domain-Appropriate Proving Grounds**:
  - The Florida contractor pilot in `EXM-00` serves as an end-to-end proving ground for open-book licensing readiness without restricting the rest of the platform; adult literacy, oral production, and procedural calculation tracks each have their own domain-appropriate validation protocols (`docs/learning_science/07_READINESS_AND_VALIDATION.md`).

---

## 4. Stream Separation: `main` Learning Science vs. Antigravity Engineering (`PR #136`)

1. **`main` Track — Learning Science & Instructional Optimization**:
   - Governed by [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md) and `/docs/learning_science/01..08`.
   - Focuses on the peer-reviewed evidence register, multidimensional `LearningTaskProfile` taxonomy, adaptive instructional delivery rules, content/import alignment, and reconciling the unified evidence contract with existing `review_items`, `ConceptEvidenceService`, `user_concept_state`, `EXM-02B`, and `EXM-03`.
2. **Antigravity Track — Architecture & Engineering Hardening (`feature/arch-review-phase-0` / PR `#136`)**:
   - Continues independently on security fixes (`FIX-1..14`), schema contract verification, lints, RLS performance, and web delivery optimizations.
3. **Integration**:
   - Both tracks merge into `main` through clean, independent pull requests verified by the 3 required GitHub Actions CI checks (`Verify`, `Database migrations (clean slate)`, `Database migrations (incremental)`).
