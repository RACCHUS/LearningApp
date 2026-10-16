# Personal Curriculum Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every newly created user lesson private by default and allow a learner to attach one to an exact official curriculum topic without changing published curriculum or official completion.

**Architecture:** A forward migration owns lesson visibility and parent-scoped read policies; a second migration owns typed, owner-only `user_curriculum_resources` rows. Flutter keeps lesson creation, attachment, outline display, scope resolution, and recommendation/completion as separate units. Attachment is idempotent and recoverable after a successful lesson save.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase/Postgres RLS, pgTAP, Hive, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-10-01-personal-curriculum-overlay-design.md`

## Global Constraints

- Preserve the existing dirty stabilization changes on `main`; never reset, stash, overwrite, or stage unrelated work implicitly. A fresh worktree from `HEAD` omits these changes. Task 0 requires separate user approval to commit that existing work as a reproducible baseline; if declined, stop and agree on another safe isolation method before implementation. Inspect staged hunks before every commit.
- Published `TargetVersion`, `curriculum_nodes`, and `curriculum_node_lessons` remain immutable for personal attachments. The existing draft-target authoring flow may still use its official binding path.
- Existing lesson rows retain public visibility; newly inserted user lessons default to private; ownerless system rows must be public. `unlisted` is schema-valid but owner-only until a later sharing design.
- A Supabase anonymous-auth guest has an authenticated `auth.uid()` and owns private lessons/attachments just like a full account. The unauthenticated `anon` role owns none.
- Use exact failure copy from the spec and retry attachment with the saved lesson ID, never a second lesson insert.
- Do not push, alter hosted Supabase, or deploy Firebase under this implementation plan. A release requires a separate decision.

## Review Focus

- An authenticated guest changes to another account in the same browser: cached private catalog, lesson, and target scope from the old identity must not display (Tasks 2 and 7).
- A private lesson is linked from a public course or a draft curriculum binding: a nonowner must not obtain its title, content, or lesson ID from junction queries (Task 1).
- An overlay insert races with a duplicate retry or points to another user's lesson/unpublished node: exactly one valid row remains and invalid rows are denied (Task 3).
- The lesson save succeeds but attachment times out, then the user retries: the saved lesson remains private, only one overlay is created, and no second lesson is inserted (Tasks 4 and 5).
- Ten required official lessons are complete while three personal lessons are unfinished: official completion is true, but a personal lesson may still be recommended (Task 8).

---

### Task 0: Preserve the existing stabilization baseline (approval required)

**Files:** The already modified/untracked stabilization files shown by `git status` before execution; exclude this plan and all later feature files.

**Interfaces:** Produces a reproducible local baseline containing the current target/scope stabilization work. Does not push or deploy.

- [x] **Step 1: Record** `git status --short`, `git diff --stat`, untracked file names, and current `HEAD`; compare against the prior stabilization review so no unrelated file enters the baseline.
- [x] **Step 2: Run** `flutter analyze`, the complete `flutter test --reporter compact --no-color`, and `supabase db reset --local`/`supabase db lint --local`; expect the previously observed clean baseline. Investigate any regression before committing.
- [x] **Step 3: With the user's explicit baseline-commit approval, stage only those existing stabilization paths** and inspect `git diff --cached --stat` and `git diff --cached --check`; separate line-ending warnings from semantic changes.
- [x] **Step 4: Commit** the reviewed stabilization baseline locally with a message describing that work. Do not push.

---

### Task 1: Database lesson visibility and read isolation

**Files:**
- Create: `supabase/migrations/20261001000000_lesson_visibility.sql`
- Create: `supabase/tests/lesson_visibility.sql`

**Interfaces:**
- Produces: `public.lessons.visibility text not null default 'private' check (visibility in ('private','unlisted','public'))`; `SELECT` allowed for `visibility='public' OR user_id=auth.uid()`.
- Produces: ownerless lessons constrained to `public`; child and junction reads require the parent lesson to be RLS-readable.

- [x] **Step 1: Write failing pgTAP assertions** in `supabase/tests/lesson_visibility.sql`: every pre-existing row, if present, is public after migration; ownerless public inserts succeed and ownerless private inserts fail; a new owner/guest lesson defaults to private; its owner reads it, a second authenticated identity and unauthenticated `anon` cannot; owner can publish/unpublish; nonowner cannot; `unlisted` behaves privately. Assert direct SELECT denial for `terms`, `questions`, `concepts`, optional `lesson_texts`, `lesson_concepts`, `question_concepts`, `term_concepts`, `course_lessons`, and `curriculum_node_lessons`, while public content stays readable. Use transaction-local `role` and JWT `sub`/`is_anonymous` settings and roll back fixtures. Also run an upgrade smoke check with a legacy lesson inserted before applying the new migration, proving that backfill marks it public.
- [x] **Step 2: Run** `supabase test db supabase/tests/lesson_visibility.sql`; expect failures that identify the missing `visibility` column or current public-read policies.
- [x] **Step 3: Implement the migration.** Backfill existing rows before setting the private default; replace permissive `lessons_read_all` and child read policies; add restrictive parent-read guards where another permissive junction policy could otherwise expose a private lesson ID. Use conditional SQL for legacy `lesson_texts` if absent. Leave owner-only write policies intact.
- [x] **Step 4: Run** `supabase db reset --local`, `supabase test db supabase/tests/lesson_visibility.sql`, and `supabase db lint --local`; expect all passing and no lint errors. Check `pg_policies` for any surviving unconditional lesson/child SELECT policy.
- [x] **Step 5: Commit only** these migration/test files: `feat(db): make new user lessons private by default`.

### Task 2: Flutter visibility model, publication action, and auth-bound catalog

**Files:**
- Modify: `lib/models/lesson.dart`, `lib/models/lesson.g.dart`
- Modify: `lib/services/lesson/lesson_crud_service.dart`, `lib/services/lesson/lesson_catalog_service.dart`, `lib/services/lesson_service.dart`
- Modify: `lib/providers/available_lessons_provider.dart`, `lib/providers/lesson_provider.dart`
- Modify: `lib/screens/study/lesson_screen.dart`
- Test: `test/models/lesson_model_test.dart`, `test/services/lesson/lesson_crud_service_test.dart`, `test/services/lesson/lesson_catalog_service_test.dart`, `test/providers/available_lessons_provider_test.dart`, `test/providers/lesson_provider_asset_fallback_test.dart`, `test/widgets/lesson_visibility_test.dart`

**Interfaces:**
- Produces: `Lesson.visibility` as one of `private`, `unlisted`, `public`; old serialized/Hive or asset lessons deserialize as `public`.
- Produces: `LessonCrudService.setVisibility(String lessonId, String visibility) -> Future<Lesson>` and `LessonService.setVisibility(...)` wrapper; only private/public shown in v1 UI.

- [x] **Step 1: Write failing tests**: a Supabase insert omits `visibility` and parses returned `private`; legacy JSON/Hive data defaults to `public`; the catalog parses actual visibility; after an auth identity change, remote catalog and `lessonProvider(id)` refetch; owner-only lesson screen shows state and an explicit publish/make-private action; nonowner sees no publishing action; failed update leaves displayed state unchanged; private lesson does not offer a dead-end share link.
- [x] **Step 2: Run** the listed focused Flutter tests; expect failures in model/service/UI behavior, not infrastructure.
- [x] **Step 3: Implement** the new model field at Hive index 11 and regenerate only `lesson.g.dart`; map DB responses in CRUD/catalog/direct providers; make both catalog and lesson providers watch auth identity, and invalidate after a successful visibility update. Add the owner action and explicit confirmation before publishing; share a link only when public. Keep RLS as the authority, not client-side filters.
- [x] **Step 4: Run** the same focused tests and `flutter analyze`; expect passing tests and no analyzer issues. Inspect generated-file diff for unrelated changes.
- [x] **Step 5: Commit only** Task 2 hunks/files: `feat: expose private lesson visibility and publishing`.

### Task 3: Owner-only personal attachment table

**Files:**
- Create: `supabase/migrations/20261001000001_user_curriculum_resources.sql`
- Create: `supabase/tests/user_curriculum_resources.sql`

**Interfaces:**
- Produces: `public.user_curriculum_resources(id,user_id,curriculum_node_id,lesson_id,relationship,sort_order,created_at,updated_at)` with typed FKs and `UNIQUE(user_id,curriculum_node_id,lesson_id,relationship)`.
- Produces: owner-only SELECT/INSERT/UPDATE/DELETE; writes require owned lesson and a readable, published official target-version node; delete lesson cascades attachment.

- [x] **Step 1: Write failing pgTAP assertions**: owner/anonymous-auth guest can attach their own lesson to published node; unauthenticated caller and second identity cannot read or mutate; cross-owner lesson and unpublished/private node fail; duplicate upsert stays one row; deleting lesson removes link; deleting link leaves lesson; published `curriculum_node_lessons` remains unchanged.
- [x] **Step 2: Run** `supabase test db supabase/tests/user_curriculum_resources.sql`; expect missing-relation failure.
- [x] **Step 3: Implement** the table, FK cascades, owner/node index, updated-at handling, grants, and RLS. Do not store redundant target/version IDs or generic resource IDs.
- [x] **Step 4: Run** `supabase db reset --local`, both pgTAP files, and `supabase db lint --local`; expect all passing.
- [x] **Step 5: Commit only** Task 3 files: `feat(db): add owner-only curriculum lesson overlays`.

### Task 4: Typed attachment service and cache invalidation

**Files:**
- Create: `lib/models/user_curriculum_resource.dart`
- Create: `lib/services/user_curriculum_resource_service.dart`
- Create: `lib/providers/user_curriculum_resource_provider.dart`
- Test: `test/services/user_curriculum_resource_service_test.dart`, `test/providers/user_curriculum_resource_provider_test.dart`
- Modify: `test/test_helpers/fake_supabase_client.dart`

**Interfaces:**
- Produces: `UserCurriculumResource` with `id,userId,curriculumNodeId,lessonId,lessonTitle,relationship,sortOrder,createdAt,updatedAt`; `lessonTitle` is read via an RLS-filtered lesson join and is null only if the parent is inaccessible/deleted.
- Produces: `listForNodes(Set<String> nodeIds) -> Future<List<UserCurriculumResource>>`, `attachPersonalLesson({required String curriculumNodeId,required String lessonId}) -> Future<UserCurriculumResource>`, `removePersonalLesson({required String curriculumNodeId,required String lessonId}) -> Future<void>`.
- Produces: Riverpod family `userCurriculumResourcesForNodeProvider(String nodeId)`; auth identity is a dependency. Callers invalidate this family, affected target scope, and catalog after mutation.

- [x] **Step 1: Write failing service/provider tests**: IDs and `relationship='personal_study'` are sent correctly; repeated attach returns one logical row using the unique conflict target; remove deletes only attachment; failures propagate instead of returning success; list returns RLS-readable lesson titles in order, skips an empty node set, and refetches on identity change.
- [x] **Step 2: Run** the focused tests; expect missing type/service/provider failure.
- [x] **Step 3: Implement** the typed model, injectable Supabase service, and provider. Use database uniqueness for idempotence; do not insert official `curriculum_node_lessons`. Keep UI-facing failure states separate from this service.
- [x] **Step 4: Run** focused tests and `flutter analyze`; expect pass.
- [x] **Step 5: Commit only** Task 4 changes: `feat: add personal curriculum resource service`.

### Task 5: Create once, attach or recover in every creation route

**Files:**
- Create: `lib/widgets/lesson/personal_attachment_result.dart`
- Modify: `lib/screens/lessons/create_lesson_screen.dart`, `lib/screens/lessons/guided_generation_screen.dart`, `lib/screens/targets/target_outline_screen.dart`
- Modify: `lib/utils/lesson_creation_feedback.dart`, `lib/providers/router_provider.dart`
- Test: `test/utils/lesson_creation_feedback_test.dart`, `test/widgets/personal_lesson_creation_test.dart`, `test/widgets/target_screens_test.dart`

**Interfaces:**
- Consumes: `attachPersonalLesson` from Task 4.
- Produces: a creation result holding `lessonId` and `curriculumNodeId` until attach succeeds or the learner leaves; `retryAttachment()` calls attach only.

- [x] **Step 1: Write failing tests**: an official published topic passes exact `nodeId`/version into creation; Library creation has no attachment; successful save+attach uses the specified success copy and refreshes outline/scope; failed attach displays the specified failure copy and Retry while preserving the saved private lesson; retry invokes attachment again with the same IDs and no second lesson import; draft editable authoring retains its separate official-binding route; guest session works.
- [x] **Step 2: Run** the focused widget/feedback tests; expect failures in routing and recovery.
- [x] **Step 3: Implement** one shared post-save result widget/controller used by builder, JSON import, and guided generation. Distinguish `officialDraftBinding` from `personalStudyAttachment` in route intent rather than inferring from a nullable node ID. Do not pop on an attachment failure before Retry is available. Invalidate Task 4 providers only after successful attach.
- [x] **Step 4: Run** focused tests and `flutter analyze`; expect pass.
- [x] **Step 5: Commit only** Task 5 changes: `feat: recover personal lesson attachment after creation`.

### Task 6: Outline display, navigation, unlink, and deletion distinction

**Files:**
- Modify: `lib/screens/targets/target_outline_screen.dart`, `lib/providers/learning_target_provider.dart`, `lib/services/learning_target_service.dart`
- Create: `lib/widgets/targets/topic_lesson_sections.dart`
- Test: `test/widgets/target_screens_test.dart`, `test/services/learning_target_service_test.dart`

**Interfaces:**
- Consumes: official `getNodeLessons(nodeId)` and Task 4 owner-only attachments.
- Produces: topic detail with `Official material` and `Your study material`, direct lesson navigation, and `Remove from topic` using Task 4's unlink method.

- [x] **Step 1: Write failing tests**: a topic with two official and one personal lesson lists both sections and opens the selected lesson; selecting the topic does not auto-open the first official lesson; a topic with zero official lessons says so and still offers creation; unlink removes only overlay and keeps Library lesson; failed unlink remains visible with an error; deleting lesson uses existing delete flow and removes overlay on refresh.
- [x] **Step 2: Run** focused tests; expect missing sections/navigation failures.
- [x] **Step 3: Implement** a focused section widget and node-detail interaction. Fetch personal lesson titles through RLS-readable lessons; do not imply personal items are official or required. Keep direct access within two deliberate actions.
- [x] **Step 4: Run** focused tests and `flutter analyze`; expect pass.
- [x] **Step 5: Commit only** Task 6 changes: `feat: show personal lessons under target topics`.

### Task 7: Scope, contextual search, and practice

**Files:**
- Modify: `lib/models/scope.dart`, `lib/services/scope_resolver.dart`
- Test: `test/services/scope_resolver_test.dart`, `test/widgets/library_v2_test.dart`

**Interfaces:**
- Produces: `ScopedActivitySource { official, personal }`; `ScopedLearningActivity.source` defaults to official for old cached JSON and persists in new JSON; `isRequired` records official binding requirement (personal is always false).
- Consumes: Task 4 owner-only overlay service; `ResolvedScope.includesItem` remains the scoped Library predicate.

- [x] **Step 1: Write failing tests**: focused node plus descendants includes their personal lessons but excludes siblings/other versions/users; official activity precedes personal activity deterministically within a node and duplicate lesson IDs appear once; old Hive scope JSON reads as official; personal lesson term/question IDs enter scoped practice even without concept mappings; attaching/unlinking forces next online resolution and contextual Library search changes accordingly; switching auth identities does not reuse another user's cached overlay.
- [x] **Step 2: Run** focused tests; expect failures on missing source and overlay queries.
- [x] **Step 3: Implement** source/requirement serialization, owner-scoped overlay fetch during target resolution, deterministic merge, and child-content union for personal lesson IDs. Version the scope config hash and include `context.userId` so old entries refresh and another account cannot reuse them; offline snapshots may display for the same identity, but next online resolution reconciles with RLS rows. Let Library's existing `includesItem` filtering surface attached lessons.
- [x] **Step 4: Run** focused tests and `flutter analyze`; expect pass.
- [x] **Step 5: Commit only** Task 7 changes: `feat: include personal lessons in target scope`.

### Task 8: Recommendations without changing official completion

**Files:**
- Modify: `lib/providers/next_action_provider.dart`, `lib/services/next_action_engine.dart`
- Test: `test/services/next_action_engine_test.dart`, `test/providers/next_action_provider_test.dart`

**Interfaces:**
- Consumes: Task 7 `ScopedLearningActivity.source/isRequired`.
- Produces: `ContextSnapshot.officialRequiredCount` and `completedOfficialRequiredCount`, with `officialRequirementsComplete` true only when the required count is nonzero and all required official activities are complete.

- [x] **Step 1: Write failing tests**: incomplete required official lesson outranks unfinished personal lesson even if the personal node sorts earlier; explicit partial resume of personal lesson still outranks next official item; ten completed required official plus three unfinished personal yields `officialRequirementsComplete=true` and may recommend personal study; zero official requirements never reports completed; attaching or completing personal items never changes official denominator.
- [x] **Step 2: Run** focused tests; expect source/denominator failures.
- [x] **Step 3: Implement** official-only count and completed count in snapshot resolution; select the first incomplete official activity before supplemental activities, preserving existing resume/remediation precedence. Keep the pure engine independent of Supabase.
- [x] **Step 4: Run** focused tests and `flutter analyze`; expect pass.
- [x] **Step 5: Commit only** Task 8 changes: `feat: keep personal study separate from official completion`.

### Task 9: End-to-end local verification and release handoff

**Files:**
- Modify: `.github/workflows/flutter-ci.yml` to run `supabase test db` after reset/lint if the local pgTAP suite is stable
- Test: the complete Flutter and local Supabase suites

**Interfaces:**
- Produces: reproducible local and CI verification; no hosted schema or web deployment.

- [x] **Step 1: Add CI's pgTAP invocation** and verify it points to `supabase/tests` with no linked/hosted flag.
- [x] **Step 2: Run** `flutter pub get`, `flutter analyze`, `flutter test --reporter compact --no-color`, `flutter build web --release`, `supabase db reset --local`, `supabase test db`, and `supabase db lint --local`; expect success. Inspect any `pubspec.lock` diff and preserve semantic dependency changes only.
- [x] **Step 3: Inspect** `git diff --check --cached` for staged feature hunks, `git status --short`, migration ordering, RLS policies, and new tests. Report pre-existing unstaged whitespace warnings separately rather than normalizing unrelated user work. Review the whole branch against the spec; fix findings and rerun affected verification.
- [x] **Step 4: Commit only** the CI change, if any: `ci: verify lesson privacy and overlays locally`.
- [x] **Step 5: Report** passing evidence, known limitations, and the separate hosted migration/deployment decision. Do not push or deploy without authorization.
