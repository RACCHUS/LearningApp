# Companion outcome report

Companion plan v1.0, §10, package EX-10. Function: `public.get_companion_outcome_report(target_version_id)` (migration `20261126010000`). Admins and moderators only. Tests: `supabase/tests/companion_outcome_report_test.sql`.

## What it is

A descriptive count, for one goal, of how learners who study outside LearningApp use the companion. It follows the learner-signal report (`20261125010000`): opted-in learners only, small groups withheld, no comparison and no causal claim.

**Nothing new is collected.** The report reads rows the server already holds for signed-in learners and counts them. No product event is recorded for it.

## Who is counted

Only accounts with an active product-analytics opt-in (`analytics.product_consents`). On 2026-11-26 production had no opted-in account and no outside resource stored in any account, so every figure is withheld until both exist. Since 2026-11-26 the in-app notice names this counting (see [The opt-in notice](#the-opt-in-notice)).

Guests are never counted: their outside resources stay on the device.

## What it returns

| Field | Meaning |
|---|---|
| `goal_learners` | Opted-in learners with study progress on the goal's lessons or an outside resource on the goal |
| `with_outside_resource`, `outside_resource_share` | How many of them added an outside resource to this goal |
| `mapping` | The furthest each of those learners got: `listed_only`, `ticked_objectives`, `outline_word_match`, `outline_own_ai` |
| `studied_then_checked.studied_pairs` | (learner, objective) pairs the learner marked studied, for objectives LearningApp has independent checks for |
| `studied_then_checked.checked_within_7_days`, `checked_share` | How many of those pairs were followed by at least one independent check within 7 days of the mark |
| `studied_then_checked.mean_check_score` | The mean score of those checks |
| `not_measured` | The plan's measures this report cannot give yet, each with the reason |

"Marked studied" is the learner's own note. The report only counts how often a real check followed it. It feeds no readiness, coverage or mastery calculation, and the database tests assert that no such function reads the outside-resource tables or this report.

## What it never returns

- The name, link, kind or outline of anything a learner studies.
- A per-learner row or any account identifier.
- Anything about pages visited or time spent watching. Those are never collected.

## Small groups

- Any count resting on fewer than 5 accounts is withheld (`small_cohort_suppressed`), with every rate built on it.
- A figure is also withheld when showing it would let a withheld one be worked out by subtraction. A share is shown only when the group left over is empty or at least 5. The mapping breakdown is shown only when every rung is empty or holds at least 5 learners. The same rule applies to checked against not checked.

## Not measured

| Measure in the plan | Why not |
|---|---|
| Gap offers opened, and whether the objective later reaches "strong" | Needs a product event that is not collected |
| Return after a break | Needs a session definition and events that are not collected |
| Readiness with and without outside resources | Not defined yet; if added it stays descriptive, side by side, with no causal claim |
| Dead links | LearningApp never fetches a learner's link, so there is nothing to count. Catalog links have their own weekly check |

## The opt-in notice

**Adopted 2026-11-26** (the owner asked the AI to choose the wording). The in-app opt-in dialog and the privacy screen now say, as `outsideStudyCountsNotice` in `lib/screens/settings/product_analytics_privacy_screen.dart`:

> If you opt in, we may also count, in groups of five or more people only, whether learners use the outside-study companion and whether they take a LearningApp check after marking something studied. We never record the names or links of what you study outside LearningApp.

The opt-in card adds that it never records "the names or links of what you study outside LearningApp", and `docs/legal/PRIVACY_POLICY.md` §2.4 has the same sentence. Migration `20261126050000` approves the notice as policy version `basic-2026-11-26`; the existing trigger withdraws consent given under the old version, so nobody is counted under wording they did not see. Production had no opted-in account when it was written.

## Reading it

Admins open it from the cost and telemetry screen (the book icon, "Outside study outcomes") or at `/#/admin/companion-outcomes`: pick a goal, and each group is shown or marked as withheld, with the list of what is not measured. Screen: `lib/screens/governance/companion_outcome_screen.dart`. The function stays callable through the API for admins and moderators.
