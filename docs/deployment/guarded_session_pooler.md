# Guarded deployment over the session pooler

Both protected workflows set `SUPABASE_DEPLOY_CONNECTION=session_pooler`.
Supabase CLI remains pinned to 2.67.1. The project dashboard's Connect > Direct >
Session pooler was checked on 2026-11-10 and showed:

- Host: `aws-0-us-east-2.pooler.supabase.com`
- Port: `5432` (session mode, not transaction port 6543)
- User: `postgres.xzvkdwebtbxlrxagtzlv`
- Database: `postgres`

The shared process boundary replaces `--linked` with the reviewed `--db-url`
for migration listing and both dry-run and live push. Preflight, postflight and
failure-state inspection inherit the same mode. The URL requires verified TLS,
percent-encodes the password from the environment, and never enters workflow
text, commits, console output or audit JSON. Subprocess output and exceptions
are scrubbed before reaching the existing log/report paths. Arbitrary URLs and
unknown modes are not accepted. CLI link and project-ref verification remain.
The unset mode retains the previous linked connection for local tooling.

The migration-history gate, immutable migration baseline, lock, exact dry-run
set comparison, production reviewer, main restriction and approved SHA check
are unchanged. This fix does not authorize production deployment.

After source review and merge, run the read-only preflight on main. Stop on
an authentication failure; do not reset the password. Review the full pending
set from that run before requesting separate production approval.

## Recovery prerequisite

The project's Free plan has no scheduled backups. No manual backup was created
by this code change. Before any production deployment, create a private manual
backup of roles, schema and data, including migration history; verify that it
can be restored in an isolated database. Do not upload a database backup to
public GitHub artifacts or the repository. A successful migration dry-run is
not a backup or restore test.

References:
- https://supabase.com/docs/guides/database/connecting-to-postgres
- https://supabase.com/docs/reference/cli/supabase-migration-list
- https://supabase.com/docs/reference/cli/supabase-db-push
