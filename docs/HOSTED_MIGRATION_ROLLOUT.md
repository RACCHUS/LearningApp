# Hosted Migration Rollout Plan & Visibility Semantics

## 1. Lesson Visibility Semantics (`public.lessons.visibility`)

### Current Schema Status
The database constraint enforces:
```sql
CONSTRAINT lessons_visibility_check CHECK (visibility IN ('private', 'unlisted', 'public'))
```

### RLS and Current Behavior
- **`public`**: Readable by all users, including unauthenticated/anonymous guests (`auth.uid() IS NULL` or authenticated).
- **`private`**: Restricted strictly to the creator (`created_by = auth.uid()`).
- **`unlisted`**: Currently restricted strictly to the creator (`created_by = auth.uid()`), identical to `private`.

### Why `unlisted` is currently private-equivalent
In the UI, users can toggle between Private and Public. The `unlisted` state is explicitly reserved for future "anyone with the secret link" functionality. Full link-sharing for unlisted lessons will require either:
1. A signed share-token or hash parameter passed to the client and validated in RLS / Edge Function, or
2. A dedicated RLS policy allowing read access by lesson ID when accessed via direct share link.

Until that capability is implemented, `unlisted` is schema-valid and backfilled safely, but functions as private for access control.

---

## 2. Hosted Database Migration Rollout Plan

### Context & Invariant
The local repository migration history features a clean-start baseline:
- `20241228000000_legacy_base_tables.sql` (backdated baseline)
- `20260929000001_v2_core_schema.sql` through `20261001000002_user_curriculum_resources.sql`

Because `20241228000000_legacy_base_tables.sql` is timestamped earlier than migrations that may already have been recorded in the hosted project's `supabase_migrations.schema_migrations` table, executing an unconsidered `supabase db push` against the hosted instance could either attempt to execute an old migration out-of-order or raise a migration ordering conflict.

### Pre-Deployment Verification Checklist

1. **Compare Local vs. Hosted Migration Records**:
   Before running migration commands on production, run:
   ```bash
   supabase migration list --linked
   ```
   Inspect which migrations are already marked as applied on the remote project versus local migrations.

2. **Handle the Backdated Baseline (`20241228000000`)**:
   - `20241228000000_legacy_base_tables.sql` is written with `CREATE TABLE IF NOT EXISTS`, `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object ... END $$`, and safe idempotent guards.
   - If the hosted database already contains these base tables from prior deployments:
     Do NOT run `db reset` on production (which deletes data). Instead, mark the baseline migration as recorded using:
     ```bash
     supabase migration repair --status applied 20241228000000 --linked
     ```
   - If starting on a fresh remote database environment, the migrations will execute chronologically in order without conflict.

3. **Incremental Migration Rollout**:
   After resolving the baseline migration record, apply subsequent incremental V2 migrations:
   ```bash
   supabase db push --linked
   ```
   Verify that all tables, foreign keys, triggers, and RLS policies are applied.

4. **Run Verification on Hosted Project**:
   Confirm that:
   - `user_curriculum_resources` table exists with RLS enabled.
   - `lessons.visibility` column is present and defaulted to `'private'`.
   - Anonymous access can view public official targets and public lessons, but cannot read private lessons or insert personal overlays on unowned targets.

5. **Staged Deployment Order**:
   Always apply and verify database migrations **before** deploying the compiled web app release (`build/web`).
