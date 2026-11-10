# MKT-002B — MCP security and release classification (Phase 0)

**Status:** Local developer MCP remains available; **remote learner MCP stays OFF**.
**Source:** `tool/mcp_server/` in `RACCHUS/LearningApp` and the approved v1.6 master plan.
No production MCP endpoint, credential, payment service or new inference provider is activated.

| Existing local MCP tool | Planned external classification | Release blockers |
|---|---|---|
| `search_catalog` | `public_read` after verified publication | Published-only catalog, source review, bounds and caching |
| `get_target_outline` | `public_read` for reviewed targets | No draft or private curriculum; verified version/provenance |
| `get_exam_blueprint` | `public_read` for authoritative metadata | No fabricated passing thresholds; source freshness |
| `get_learner_state` | `authenticated_read` | Token-derived identity, no caller-supplied `user_id`; remove synthetic fallback readiness |
| `get_due_items` | `authenticated_read` | Same owner isolation and row-level security |
| `explain_item` | `never_external` for protected summative items | Do not reveal confidential answer/rationale; explicit formative-only replacement |
| `compute_item_analytics` | `never_external` except admin/reviewer | Protect bank keys, psychometric and small-cohort data |
| `submit_review` | `conditional_write` | Auth owner bound, issued attempt, idempotency and reversible audit |
| `validate_lesson` | `public_read` only if safe and bounded | Size/time limits, schema constraints, no arbitrary IO |
| `propose_item_fix` | `conditional_write` | Authentication, moderation queue, quotas, draft-only |

## Confirmed blockers in repository

1. The stdio entrypoint accepts `SUPABASE_SERVICE_ROLE_KEY` and may load it from the local `.env`. That is for **trusted developer tooling only**. Never ship a privileged key in a public browser or hosted multi-tenant MCP endpoint.
2. The current tool schema permits caller-supplied `user_id` for learner reads and writes. A hosted personal MCP endpoint must ignore caller identity claims and derive scope from an authenticated, revocable token.
3. `getLearnerState` falls back to a fixed synthetic readiness score and concept weaknesses. Never expose this as a real learner readiness score.
4. `explain_item` can return correct answers and explanations. A hosted endpoint must not disclose protected exam-bank material or post-submission answer keys.
5. The raw local stdio transport is not a production OAuth remote connector. Remote MCP needs authorization, origin/host tests, rate limits, size limits, provenance, error redaction, and off-path testing.

## Planned order

- First expose **published catalog search and verified outline** read-only, with a separate explicit allowlist.
- Add authenticated learner tools only after cross-user negative tests and owner-approved OAuth/RLS, and with **no server-funded model inference**.
- Add write tools only after atomic server authorization, queue/idempotency and rollback review.
- Keep all remaining local tools and curriculum capabilities available for internal development. Do not delete them merely because public exposure is blocked.

No MCP command is enabled in production by this branch. `ai.external_mcp`, `mcp.remote`, `mcp.personal_read` and `mcp.write_review` remain default OFF and not release-ready.
