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
2. **Educator Verifications (Base Table RLS)**:
   - Direct table `SELECT` is strictly restricted to the credential owner (`educator_id = auth.uid()`) and platform moderators (`private.is_moderator()`).
   - Only platform moderators can update `status` to `'verified'`, and must match `verified_by` (anti-forgery).
   - Normal users can insert or update records only with `status in ('unverified', 'pending')`.
   - Verified, rejected, and revoked records are immutable and cannot be deleted by non-moderators.
   - All authorized credential deletions (by owner or moderator) generate an immutable tombstone audit record in `educator_verification_audits` capturing the actor, previous status, and credential metadata.
3. **Follows**:
   - Following is strictly gated by `private.is_educator_profiles_public_enabled()`. While Gate 2 is closed, ordinary learners cannot follow educators.
   - When Gate 2 is enabled, following is permitted only for target educators whose profiles are `status = 'active'`.
   - Self-follows are blocked at check constraint level (`follower_id <> educator_id`).
   - Follow `SELECT` policy intentionally permits educator owner visibility (`educator_id = auth.uid()`):
     - While Gate 2 is closed, followed educators can view their own incoming follower relationships to support private beta and pilot monitoring, while general learner visibility remains disabled.
     - Platform moderators retain full operational visibility (`private.is_moderator()`).
     - Once Gate 2 is open, both followers and educators can query their respective follow edges.
   - Minors cannot be followed or create educator profiles (enforced pre-condition for Gate 2 public enablement).

### 3.3 Column-Shielded Public Verification View (`public.public_educator_verifications`)
To protect internal reviewer identities and sensitive unredacted credential references, public access is never granted directly to the base `educator_verifications` table.
- A secure view `public.public_educator_verifications` with `security_invoker = false` exposes strictly:
  `id, educator_id, verification_type, subject_id, jurisdiction, issuer, status, verified_at, expires_at, created_at`.
- Internal staff attribution (`verified_by`) and unredacted registration text (`credential_reference`) are omitted.
- The view evaluates `private.is_educator_profiles_public_enabled() AND status = 'verified'`, requires that the educator profile is `active`, and enforces `(expires_at is null or expires_at > now())` so that expired credentials are never exposed publicly as verified. Returns 0 rows while Gate 2 is closed.

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

---

## 5. Gate 2 Launch Dependencies (Pre-requisites for Public Enablement)

Before the global launch gate `educator_profiles_public_enabled` can be flipped to `true`, the following architectural safeguards must be fully implemented and verified:
1. **Server-Side Minor Eligibility & Age Verification**:
   Authoritative backend enforcement preventing minors from activating public educator profiles, following/being followed, or engaging in public educator interactions.
2. **Canonical Subject Taxonomy Registry Validation**:
   Enforce database-level validation (foreign key or authoritative registry check) on `educator_subjects.subject_id` against the canonical taxonomy before subject affiliations can be authoritatively published.
3. **Public Column Shielding & Verification Data Redaction**:
   Verification of the `public.public_educator_verifications` column-shielded view and ensuring any public references are validated and redacted prior to public display.
4. **Zero Hosted Changes Pre-Launch**:
   Production database baseline remains at 62 migrations with Gate 1 (`public_ugc_enabled`) deployed and locked at `false`, and Gate 2 (`educator_profiles_public_enabled`) not yet deployed or present in production (the configuration key, educator profiles schema, tables, and views remain entirely absent until a future migration deployment).
