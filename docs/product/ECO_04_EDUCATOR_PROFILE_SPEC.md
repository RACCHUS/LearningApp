# ECO-04 — Educator Profile & Subject Affiliation Architecture Specification

**Status:** Approved Architecture Specification  
**Version:** 1.0  
**Date:** October 21, 2026  
**Project:** `RACCHUS/LearningApp`  
**Roadmap Reference:** `docs/product/COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md` (Epic ECO-04, Phase 2, W2)  
**Security & Privacy Gate:** Phase 2 Launch Gate (`educator_profiles_public_enabled = false` until Gate 2 clearance)  

---

## 1. Context and Vision

As defined in Section W2 ("Teach a topic without creating a course") of the Community & Educator Knowledge Roadmap:
> A knowledgeable person should be able to sign up to teach a subject, answer questions, tutor, host sessions, or review content. Creating a full course is optional.

Historically, learning platforms forced teachers into course-creation monoliths. In `LearningApp`:
1. **Teacher Does Not Own the Subject or Course**: Concepts and learning destinations exist canonically. Multiple educators can teach, explain, and contribute answers to the same concept.
2. **Strict Verification vs. Claim Separation**: Self-declared expertise is strictly isolated from platform-vetted experience and third-party verified regulatory/professional credentials (e.g. Florida DBPR, CNA, CPA, EPA certifications).
3. **Private Launch Gate**: In accordance with the project's gate-controlled roadmap, educator profiles and subject associations are developed privately in parallel, queryable only by the profile owner and platform moderators until Gate 2 operational clearance.
4. **Minor Safety (COPPA/FERPA)**: Minors cannot create public educator profiles, broadcast private details, or receive direct communications.

---

## 2. Domain Entities & Database Schema

### 2.1 `public.educator_profiles`
The root profile for any user opting in to teach, mentor, or publish answers.
- `id` (UUID, PK): References `auth.users(id)` ON DELETE CASCADE.
- `display_name` (TEXT, NOT NULL): 2 to 100 characters.
- `headline` (TEXT): Brief professional headline (up to 150 characters).
- `bio` (TEXT): Extended teaching philosophy/background (up to 2000 characters).
- `avatar_url` (TEXT): HTTPS URI or platform storage path.
- `languages` (TEXT[]): Languages spoken (default `['en']`).
- `is_accepting_questions` (BOOLEAN): Whether the educator accepts incoming learner questions.
- `status` (TEXT): `'draft'`, `'active'`, `'paused'`, or `'archived'`.
- `created_at` / `updated_at` (TIMESTAMPTZ).

### 2.2 `public.educator_subjects`
Associates an educator with specific learning concepts, goals, or domains without course ownership.
- `id` (UUID, PK, default `gen_random_uuid()`).
- `educator_id` (UUID, NOT NULL): References `public.educator_profiles(id)`.
- `subject_id` (TEXT, NOT NULL): Canonical topic identifier (e.g. `literacy.cvc`, `licensure.real_estate`).
- `subject_name` (TEXT, NOT NULL): Human-readable name.
- `experience_summary` (TEXT): Summary of instructional experience in this specific subject.
- `status` (TEXT): `'active'` or `'inactive'`.
- `created_at` (TIMESTAMPTZ).
- Unique constraint on `(educator_id, subject_id)`.

### 2.3 `public.educator_verifications`
Tracks self-declared claims vs platform-vetted and third-party credentials.
- `id` (UUID, PK, default `gen_random_uuid()`).
- `educator_id` (UUID, NOT NULL): References `public.educator_profiles(id)`.
- `verification_type` (TEXT, NOT NULL):
  - `'self_declared'`: User-entered statement of experience.
  - `'platform_vetted'`: Reviewed and corroborated by platform editorial staff.
  - `'licensed_credential'`: Formally verified state license or accredited standard.
- `subject_id` (TEXT): Optional subject scope.
- `jurisdiction` (TEXT): E.g. `'FL'`, `'US'`, `'CA'`.
- `issuer` (TEXT): E.g. `'Florida DBPR'`, `'Prometric'`, `'State Board of Nursing'`.
- `credential_reference` (TEXT): Redacted or public registration/license number.
- `status` (TEXT): `'unverified'`, `'pending'`, `'verified'`, `'rejected'`, or `'expired'`.
- `verified_at` (TIMESTAMPTZ): Set only upon moderator approval.
- `expires_at` (TIMESTAMPTZ): Expiration date where applicable.
- `created_at` / `updated_at` (TIMESTAMPTZ).

### 2.4 `public.educator_follows`
Enables learners to bookmark and follow trusted educators.
- `id` (UUID, PK, default `gen_random_uuid()`).
- `follower_id` (UUID, NOT NULL): References `auth.users(id)`.
- `educator_id` (UUID, NOT NULL): References `public.educator_profiles(id)`.
- `created_at` (TIMESTAMPTZ).
- Invariant: `follower_id <> educator_id` (cannot follow oneself).
- Unique on `(follower_id, educator_id)`.

---

## 3. Row-Level Security & Gate Policies

### 3.1 Launch Gate Invariant
```sql
create or replace function private.is_educator_profiles_public_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select value::boolean from public.community_config where key = 'educator_profiles_public_enabled'),
    false
  );
$$;
```

### 3.2 Access Rules
1. **Educator Profiles**:
   - `SELECT`: `id = auth.uid() OR private.is_moderator() OR (private.is_educator_profiles_public_enabled() AND status = 'active')`
   - `INSERT`: `id = auth.uid()`
   - `UPDATE`: `id = auth.uid() OR private.is_moderator()`
2. **Educator Verifications**:
   - Only platform moderators (`private.is_moderator()`) can update `status` to `'verified'` or populate `verified_at`.
   - Normal users can insert or update records with `status in ('unverified', 'pending')`.
3. **Follows**:
   - Minors cannot be followed or create educator profiles.
   - Self-follows are blocked at both trigger and check constraint levels.

---

## 4. Verification & Testing Protocol

1. **pgTAP Database Security Suite** (`supabase/tests/educator_profiles_test.sql`):
   - Schema structure and foreign key validation.
   - RLS isolation: unauthenticated and peer users cannot inspect draft/private profiles.
   - Credential verification privilege protection: regular users cannot mark their own credentials as `verified`.
   - Self-follow prevention checks.
2. **Dart Service Unit Tests** (`test/services/community/educator_service_test.dart`):
   - Creation, retrieval, subject association, and verification submission.
   - Follow and unfollow operations.
   - Error handling and authorization checks.
3. **Guarded History Invariants**:
   - Migration 63 strictly append-only, verified via `verify_migration_history.dart`.
