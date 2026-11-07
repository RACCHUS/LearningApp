# Personal curriculum overlays

Status: revised design for review (2026-10-01)

## Purpose and invariant

A learner who creates a lesson from an official curriculum topic should find that lesson both in their Library and under the topic that prompted its creation. The published `TargetVersion`, its `curriculum_nodes`, and its official `curriculum_node_lessons` bindings remain unchanged. Personal material is supplemental, not a new official requirement.

The first release supports user-owned lessons attached to exact curriculum nodes. Study sets, notes, flashcards, uploads, and cross-version transfer are outside this release.

## Lesson visibility is independent of attachment

Add `public.lessons.visibility` as required text constrained to `private`, `unlisted`, or `public`. Migration backfills **every existing lesson** to `public`, preserving the currently anonymous-readable catalog, and gives future inserts a `private` default. Every new user-created lesson is private by default whether created from Library or a target topic. Bundled asset lessons stay public; future database/system lessons with no owner must be explicitly inserted as `public` and cannot remain private. The owner can see the current visibility and explicitly publish or return their lesson to private from its Library detail/actions UI; a failed update must leave the displayed state unchanged. The first release exposes private/public only. `unlisted` is reserved for a later sharing design and has private-equivalent read behavior for now, rather than accidentally becoming discoverable or link-accessible.

Replace the current unconditional lesson read policy with `visibility = 'public' OR user_id = auth.uid()`. Restrict visibility changes to the lesson owner; non-owners cannot publish another person's lesson. Apply the same effective parent-lesson read condition to `terms`, `questions`, legacy `concepts`, and `lesson_texts`. Also ensure `lesson_concepts`, `question_concepts`, `term_concepts`, and any public course/lesson junction cannot reveal private lesson content or IDs to nonowners through direct queries. A public course does not implicitly publish its private lessons; its owner still sees them. Rows without a readable parent must not become public merely because their parent ID is absent. Reading a public lesson and its content remains possible before sign-in.

Supabase anonymous-auth guests have an authenticated session and distinct `auth.uid()` values. A lesson created by one such guest is readable by that guest but not by a different guest or an unauthenticated caller. Lesson privacy does not depend on an overlay row existing or succeeding. Existing user-owned lessons remain public until their owners choose otherwise; a later privacy audit or bulk-change option is separate work, because existing sharing intent cannot be inferred.

## Data model and authorization

Add one forward migration for `public.user_curriculum_resources` with:

| Column | Rule |
| --- | --- |
| `id` | UUID primary key |
| `user_id` | Required FK to `auth.users(id)`, cascade on user deletion |
| `curriculum_node_id` | Required FK to `public.curriculum_nodes(id)`, cascade on node deletion |
| `lesson_id` | Required FK to `public.lessons(id)`, cascade on lesson deletion |
| `relationship` | Required text, initially constrained to `personal_study` |
| `sort_order` | Integer, default 0 |
| `created_at`, `updated_at` | Timestamps |

Enforce `UNIQUE(user_id, curriculum_node_id, lesson_id, relationship)` and index the owner/node lookup. Do not duplicate target or version IDs: the node already fixes both identities. A future target version has different nodes, so attachments never migrate silently. No column in this table makes a lesson required curriculum.

Enable RLS. The owner alone may read, insert, update, or remove an attachment. Writes must also verify that `lesson_id` belongs to that owner and that the node belongs to a readable, published official target version; the authenticated user's ID, not a client-supplied ID, is authoritative. Unauthenticated callers cannot see or write overlay rows; Supabase anonymous-auth guests may attach their own lessons to their own personal path. The official-target write policies stay restrictive. Database tests must verify these rules using client roles, not only by inspecting policy text.

## Creation, retry, and deletion

The official-topic action carries the exact `curriculum_node_id` into the existing private-lesson creation flow. A Supabase auth session is required, including a guest session. After the lesson is successfully created, the app attempts the owner-scoped, idempotent attachment and waits for its result.

- Success: report “Lesson created and added to this topic,” refresh the outline and active target scope, and keep the lesson in Library.
- Failure: preserve the created lesson, report “Lesson created, but we couldn't attach it to this topic,” and keep the creation result open with **Retry attachment** using that same lesson ID and node ID. Retry must not create another lesson or a duplicate overlay row. The first release does not queue failed attachments across app restarts; the lesson remains recoverable from Library.

Removing a lesson from a topic deletes only its overlay row; the private lesson remains in Library. Deleting the private lesson invokes the existing lesson-deletion flow and cascades away its overlay rows. The UI must name these as distinct actions. A failed unlink must not present success.

## Outline and navigation

Each topic shows **Official material** and **Your study material** separately, each with linked lesson titles. A topic with no official lessons says so and still offers **Create personal study lesson**. The action remains available when official lessons exist. Selecting a listed lesson opens that lesson directly; selecting a topic must not silently jump past its personal resources. The learner can open either material type within the existing direct-access interaction limit.

## Scope, recommendations, and progress

For the current user and exact target version, target scope loads personal links on the active node set (including the selected focus node and descendants). It retains a source distinction between official and personal teaching activities. Personal lessons are ordered deterministically within their nodes after official bindings and are visible in the target's personal study sequence and contextual Library search. Their own lesson content may enter scoped review/practice; attachment alone must not rewrite official concept mappings or required curriculum.

`NextAction` may surface a personal lesson, but incomplete official activities take precedence unless the learner explicitly resumes a personal lesson. Official structural completion and its denominator use official activities only; personal activities and counts remain separate. Completing or adding personal material must not change whether the official requirement set is complete. In particular, ten completed official lessons plus three unfinished personal lessons still means the ten official requirements are complete. Zero official lessons is an empty official curriculum, not a completed one, even if personal lessons exist.

Attaching, unlinking, and deleting invalidate the affected target scope/cache so outline, search, and recommendations refresh promptly. Existing offline caches may be shown while offline, but the next online resolution must reconcile overlays against RLS-visible rows.

## Verification and release boundary

Use test-first changes for service behavior, scope ordering and focus, NextAction completion separation, contextual search, creation failure/retry, and outline display. Database tests cover visibility backfill, private-by-default inserts from both creation paths, explicit owner publishing, public/system reads, private child and mapping reads, distinct guest identities, attachment ownership, duplicate retries, FK cascades, and unlink-versus-delete. Re-run Flutter analysis, the complete test suite, the release web build, and a clean local Supabase migration/reset/lint cycle. Do not push schema changes to the hosted database or deploy the web app as part of this implementation without a separate release decision.

The existing broader taxonomy import, authoritative curriculum provenance, and full catalog population remain separate work.
