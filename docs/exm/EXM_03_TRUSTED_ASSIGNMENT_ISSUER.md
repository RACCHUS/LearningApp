# EXM-03 — Trusted learner-authenticated assignment issuance

**Draft engineering contract.** The scoring service remains service-role-only.
The issue RPC is intentionally not connected to the learner UI until
portability, retention and end-to-end scoring submission pass release gates.

## Issuance

`exm03_issue_assigned_practice(target_version_id, exam_part_key)` is a
server-side database transaction callable only as `authenticated`. It has
only these two caller-controlled inputs. The caller **cannot** provide its
own learner ID, question IDs, correct answers, item fingerprint, manifest,
curriculum root, expiry or score.

The function validates `auth.uid()`, exact JWT `role=authenticated`,
`is_anonymous=false`, a UUID-shaped `session_id` and the matching *live*
row in `auth.sessions` (including `not_after` expiry). It fails closed for
missing/revoked or foreign-user sessions; Supabase's JWT verification occurs
before this database function is invoked through the Data API.

The function independently resolves a public published target version,
exactly one typed EXM exam part and its version-owned root, plus a published,
independently reviewed, currently effective reference manifest.
Candidate questions are randomly selected by PostgreSQL, not supplied by
the learner. Only canonical version-owned single-choice questions with
independently published/rights-approved item bindings and matching current
server-calculated fingerprints are eligible. Every mapped concept must be
part-exclusive core content; shared/outside concepts are intentionally
excluded for part-specific attribution.

Each assignment has exactly **six distinct questions from at least three
distinct core concepts**, a 90-minute validity window, a maximum of two
active incomplete assignments and a bound of 12 issuances in a rolling 24
hours per learner. Per-owner advisory locking protects quota checks against
concurrent requests. The output contains only opaque assignment ID,
target-version/part identity, practice expiry and the exact question IDs,
prompt text and visible choices. It never returns scoring specs, approved
answer keys, private reviewer records or canonical item hashes.

The issued set remains private in `exam_part_practice_assignments`.
A separate previously reviewed *service-role-only*
`exm03_record_assigned_practice` transaction revalidates canonical
content and calculates practice scores. **No client-submit proxy or
learner-facing saved attempt UI is enabled yet.** This milestone is not an
official exam, pass forecast or issuer endorsement.

## Automated regression tests

The six-question synthetic database integration tests verify:
- unauthenticated caller denied; authenticated role privilege only
- unconfigured Part B fails without target-wide fallback
- genuine live owner session produces six canonical Part A questions
- question payload excludes private scores, correct index and SHA-256
- exact owner assignment saved; two pending allowed; third denied
- invalid/missing Auth session denied even when claimed `sub` matches
- existing canonical grading, exact replay/changed answer rejection,
  and irreversible assignment+attempt erasure still work

## Release gates remaining

- Complete account-wide **R1–R4 plus new EXM-03** privacy inventory, safe
  paginated export, deletion confirmation and retention/recovery contract
- Trusted submission adapter/service with real client JWT authorization and
  per-account request binding; no browser access to service-role credentials
- Additional interaction types with independently verified scoring behavior
- Browser/mobile real-session and concurrent-login/revocation acceptance
- Content authority/rights and exam edition date validations
- Explicit owner approval for migration deployment, live data operations or
  any merge. All automated CI uses disposable test data only.

Security references: Supabase database functions and user sessions guidance.
