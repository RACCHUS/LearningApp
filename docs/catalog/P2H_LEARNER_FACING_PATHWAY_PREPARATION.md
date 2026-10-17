# P2h — Learner-Facing License Pathway Route Selection and Preparation Tracking

**Date:** October 2026. **Scope:** Interactive route selection, administrative milestone checklist tracking, and private learning goal integration for verified professional license pathways.

---

## 1. Product Distinctions & Governance Boundaries

With the successful publication of six Florida professional licensing pathways (Nursing RN/LPN, Insurance 2-20/2-15, and General/Building Construction CGC/CBC), the catalog offers verified regulator-sourced step hierarchies. P2h transforms these static hierarchies into active learner-facing planning tools under strict governance invariants:

1. **Self-Reported Preparation Only**:
   - Marking a step as complete is strictly a self-reported study planning action.
   - It **does not** submit paperwork or fees to any state agency or regulator.
   - It **does not** constitute official legal eligibility determination, authorization to test (ATT), or license issuance.
   - All interactive UI surfaces display prominent disclaimers reminding the learner that only the statutory board/department can verify eligibility.
2. **Alternative Route Exploration**:
   - Regulatory pathways often define alternative qualifying methods (e.g., Florida Construction 4-year field experience vs 3-year experience + 1-year accredited college vs military training; Florida Nursing BSN vs ADN vs diploma programs).
   - Learners can interactively select their intended qualification route (`op: 'any'`).
   - The checklist automatically adapts, focusing on mandatory universal requirements plus the selected branch milestones while filtering out alternate paths.
3. **Strict Separation of Knowledge vs Administrative Readiness**:
   - Administrative and statutory milestones (submitting fingerprint cards, filing electronic applications, passing background checks) are strictly partitioned from conceptual learning mastery (quiz scores, flashcard reviews, mastery levels).
   - Knowledge readiness and administrative milestone completion are never conflated into a single misleading progress metric.

---

## 2. Technical Implementation & Architecture

### Zero-Migration Database Invariant
P2h was architected without introducing new database tables or schema migrations:
- **Catalog Definitions**: Read from existing published records in `catalog_license_pathway_versions` via the existing `verifiedDestinationsProvider`.
- **Private Goal Connections**: When associated with a learner's target, links resolve through the existing `catalog_destination_goal_links` table and `learning_targets`.
- **Local Persistence**: Route choices and step completion states are stored securely and responsively on-device via `SharedPreferences` (`PathwayReadinessService`), enabling both standalone catalog exploration and offline-first private goal tracking.

### Core Components

1. **Domain Models & Tree Parsing** ([`lib/models/license_pathway_readiness.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/lib/models/license_pathway_readiness.dart)):
   - `PathwayStep`: Flat representation of a pathway action containing id, label, stage, optional condition, and source URL.
   - `PathwayRouteOption`: Represents a distinct route alternative extracted from `op: 'any'` branches.
   - `PathwayReadinessState`: Immutable state containing selected route label, checked step IDs, and optional linked goal ID.
   - `PathwayTreeParser`: Pure algorithmic helper providing:
     - `extractRoutes(dynamic tree)`: Discovers alternative qualifying branches.
     - `extractApplicableSteps(dynamic tree, String? selectedRouteLabel)`: Flattens the hierarchy into applicable linear milestones.
     - `computeReadiness(...)`: Computes checked count, total count, completion percentage, and full completion status.

2. **Persistence & State Management** ([`lib/services/pathway_readiness_service.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/lib/services/pathway_readiness_service.dart), [`lib/providers/pathway_readiness_provider.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/lib/providers/pathway_readiness_provider.dart)):
   - `PathwayReadinessService`: Manages local storage keys with namespaces `pathway_readiness_{destinationId}_{goalId ?? "standalone"}`.
   - `pathwayReadinessProvider`: Riverpod `StateNotifierProvider.family` reacting to destination and goal identity parameters.

3. **Learner Experience Surfaces**:
   - **Preparation Modal Sheet** ([`lib/widgets/taxonomy/pathway_preparation_sheet.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/lib/widgets/taxonomy/pathway_preparation_sheet.dart)):
     - Launched from the Taxonomy Explorer when viewing any published license destination.
     - Displays regulator header, official website outbound link, alternative route selector, interactive checklist, progress indicator, and clear legal disclaimers.
     - Offers a direct action to save the preparation plan into a private `learning_targets` draft.
   - **Target Detail Embedded Card** ([`lib/widgets/targets/pathway_preparation_goal_card.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/lib/widgets/targets/pathway_preparation_goal_card.dart)):
     - Embedded inside `TargetDetailScreen` whenever viewing an owned learning target linked to a licensed destination.
     - Seamlessly displays route info, milestone progress percentage, and checklist items directly alongside the learner's target study objectives.

---

## 3. Verification & Test Coverage

Comprehensive unit, service, and widget test suites validate the implementation:

| Test Suite | File | Tests | Coverage |
| :--- | :--- | :--- | :--- |
| **Parser & Models** | [`test/models/license_pathway_readiness_test.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/test/models/license_pathway_readiness_test.dart) | 7 | Route extraction, step filtering, progress calculation, immutability, JSON roundtrip. |
| **Storage & Provider** | [`test/services/pathway_readiness_service_test.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/test/services/pathway_readiness_service_test.dart) | 6 | Route persistence, step toggling, goal linking, state resets, Riverpod reactive binding. |
| **Preparation Sheet Widget** | [`test/widgets/pathway_preparation_sheet_test.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/test/widgets/pathway_preparation_sheet_test.dart) | 3 | Route radios rendering, checklist item clicks, progress meter updates, disclaimers. |
| **Goal Card Widget** | [`test/widgets/pathway_preparation_goal_card_test.dart`](file:///c:/Users/richa/Documents/Code/LearningApp/test/widgets/pathway_preparation_goal_card_test.dart) | 2 | Target detail card display, milestone completion toggle, reactive count update. |

---

## 4. Next Opportunities

1. **State License Scope Expansion**: Expand from the initial 6 Florida licenses to additional state jurisdictions (e.g. Texas, California, New York) across nursing, insurance, and contractor boards.
2. **Offline Document Attachment Checklist**: Allow learners to note private document reference dates (e.g. date fingerprint submitted or background check cleared) stored strictly on-device.
3. **Renewals & Continuing Education (CE)**: Model post-licensure statutory renewal cycles and continuing education unit (CEU) milestone tracking.
