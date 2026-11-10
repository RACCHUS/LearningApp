# ANA-103 / ANA-105 — Privacy activation and operational runbook

**Status:** Code and tests in PR #214. **No real product-event collection is authorized or enabled.**  
**Owner issue:** [#213](https://github.com/RACCHUS/LearningApp/issues/213)  
**Target:** Supabase project `xzvkdwebtbxlrxagtzlv`; protected GitHub `main`.

## What is implemented but intentionally off

- `analytics.product_events` and `analytics.product_consents` remain browser-inaccessible. Browser roles can call reviewed, authenticated RPCs only. The product event dictionary rejects raw searches, free text, lesson answers, URLs and payment information.
- Server consent status comes from `auth.users.is_anonymous`, trusted `raw_app_meta_data.product_analytics_eligible`, and the private consent row. `raw_user_meta_data` cannot enable collection.
- The new user privacy screen at **Settings → Optional Product Analytics Privacy** supports status, withdrawal (with server raw event deletion), local queue erasure and paginated export. It shows genuine unavailability if the migration is not deployed.
- Export supports arbitrary server-side keyset pages of 100 entries; the in-app copy-to-clipboard helper caps the assembled export at 10,000 events and gives an explicit error instead of exporting a misleading partial file. Large exports can be paged with the RPC by an approved portability process.
- `ProductEventOutbox` uses persisted account-namespaced immutable keys and exact ACK deletion, not an in-memory-only queue. Maximum 100 pending events; records older than seven days are purged and reported. Queue-full, corrupt storage, missing consent, offline delivery and account switches fail visibly. **There is no automatic emitter using this queue today**; the existing product analytics service still defaults to disabled/no-op.
- The new server status does **not** indicate `policy_ready` or `collection_active`. Even a previously eligible account cannot turn collection on from the UI until a separate, explicitly reviewed activation change.
- Server-side changes in the additive ANA-103 migration: eligibility downgrade deletes raw events and revokes consent; keyset export, privileged retention health, and a transaction-scoped per-account rate guard.

## Owner action 1: approve the privacy and eligibility policy (required)

A privacy/legal/product owner must approve, in writing, **before any collection**:

1. Exact purposes and allowed event categories; adult and minor/school-managed status rules; whether any jurisdiction-specific notice, institutional authority or guardian consent is required. Do not infer age from arbitrary account fields or user-editable metadata.
2. The user-facing notice and separate affirmative opt-in wording, withdrawal behavior and scope of collected event fields. Approval must identify a policy version and a responsible reviewer.
3. Raw retention policy (90 days proposed), rights/access/export process, user-account erasure, third-party recipients (none for this first-party pipeline) and exception handling.
4. Coverage limits, five-user small-cohort suppression and metric labels; do not market opt-in sample counts as all-user DAU, enrollment, revenue or outcomes.
5. Operational escalation for privacy incidents, unexpectedly collected events or missed retention cleanup.

**Until this decision, leave trusted eligibility unset/false, leave opt-in enrollment blocked, and do not enable a product telemetry sink.** A completed technical implementation is not a substitute for consent or legal review.

## Owner action 2: guarded deployment dry run (no production writes)

The repository explicitly prohibits directly applying migration SQL through MCP, dashboard SQL or ad hoc Postgres migrations. Its sole production path is the guarded tool.

Set up the GitHub repository **Environment `analytics-preflight`**, ideally with required reviewers, then add encrypted environment Secrets:

- `SUPABASE_ACCESS_TOKEN`: a *project-scoped* Supabase access token with the minimum read/link scope required by the CLI.
- `SUPABASE_DB_PASSWORD`: the password for the intended Supabase project, never committed to the repository.

From the repository **Actions** tab choose **Analytics guarded Supabase preflight (dry-run only)**, select `main`, check the explicit acknowledgment, and run it. The workflow uses pinned Supabase CLI `2.67.1`, Flutter `3.47.7`, validates the linked project ref, and runs exactly:

```bash
dart run tool/guarded_supabase_deploy.dart \
  --dry-run \
  --project-ref xzvkdwebtbxlrxagtzlv \
  --base-ref origin/main \
  --report-dir build/analytics_preflight_reports
```

Review its non-secret audit artifact and entire pending migration set. The hosted ledger previously reported **97 applied migrations, latest `20261108000000`**; that is a snapshot, not permission to deploy. A dry run may identify additional CLEP, progress or analytics changes. If history diverges, stop and request an evidence-backed owner review—**never** `supabase migration repair` or `--allow-no-base`.

**Live deployment is a separate explicit owner decision.** When reviewed, use only the repository's guarded deployment command in a credentialed owner environment. No workflow in this PR can push live migrations.

## Owner action 3: enable reviewed retention maintenance

The repository has a disabled-by-default GitHub workflow **Product analytics retention (owner-gated)**. It invokes *only* the previously deployed `analytics.purge_expired_product_events()` routine and verifies no expired raw records remain.

1. Create the GitHub **Environment `analytics-retention`** and require an environment reviewer.
2. Add encrypted Environment Secret `ANALYTICS_RETENTION_DATABASE_URL` for the correct Supabase project with a privileged, purpose-limited PostgreSQL login permitted to invoke the retained routine. Use TLS certificate verification (`sslmode=verify-full`), and preferably a service-specific credential. The workflow validates project identity without printing the URL.
3. After the ANA-102/103 migrations are deployed and reviewed, set GitHub repository **Actions Variable** `ANALYTICS_RETENTION_ENABLED=true`. The workflow stays inactive while the variable is missing/false.
4. Run the workflow manually once, verify its success and retention audit without inspecting raw event contents. Then confirm its daily 05:20 UTC schedule runs and is monitored. Retention is **not operationally complete** before this step.

GitHub Actions is already part of the repository; this design avoids a paid analytics vendor or enabling `pg_cron`. This workflow performs routine retention DML, **not schema deployment**.

## Owner action 4: eligibility provisioning and release activation

After written policy approval and guarded deployment, use a protected **server-side** Auth administration workflow to set `auth.users.raw_app_meta_data.product_analytics_eligible=true` **only** for independently reviewed, explicitly eligible permanent accounts. Do not use a Flutter/admin browser secret, unreviewed bulk update, mutable user metadata, guessed age, or automatic guest upgrade. Reclassification to guest/ineligible causes the ANA-103 trigger to revoke consent and delete prior raw events.

Activate capture only in a **separate reviewed PR** that:
- publishes the approved policy version and accurate user notice;
- makes the server return verified `policy_ready=true` and `collection_active=true` only after all gates; 
- wires the bounded, ACK-gated outbox to the previously disabled product event sink **only after fresh server consent verification**;
- includes browser multi-tab/account switch, offline restart, opt-out race and assisted-accessibility integration tests;
- monitors pipeline errors and actual retention service health;
- proves non-admin and guest analytics denial, opt-out deletion, and five-user suppression against the deployed schema.

The client **must remain default-off until this activation PR is reviewed and merged**; this runbook does not authorize an automatic mass opt-in or an unannounced deployment.

## Test and rollback checklist

- [ ] The reviewed migrations are append-only and pass local clean/incremental Supabase + pgTAP.
- [ ] Flutter analyze, tests and two web build variants pass.
- [ ] A reviewed eligible test account opts in explicitly; unreviewed and anonymous accounts cannot.
- [ ] A missing backend never appears as `consented=false` or `0 users`; it says unavailable.
- [ ] Events with invalid fields, raw queries/URLs, wrong user, future/expired timestamps, oversized batch, changed replay and excess rate are denied.
- [ ] Exactly once event ACK, repeated retries, queue restart, full queue, expiry, account change, withdrawn consent and absent server are tested.
- [ ] Account demotion erases private events and consent; re-eligibility does not automatically re-consent.
- [ ] Keyset export retrieves >100 records, does not mix users and refuses malformed continuation cursors.
- [ ] Retention produces zero expired rows after a successful operator run and does not log record contents.
- [ ] Admin overview shows `not_measured`, suppressed small cohort, opt-in coverage and server timestamp accurately.
- [ ] Rollback of collection: leave client feature off, revoke eligibility for affected accounts, withdraw consent / erase raw events; do not rewrite migration history. Investigate before reactivation.

## Operator limitations and privacy implications

- This chat environment has GitHub repository and read-only Supabase inspection capabilities, but no checked-out credentialed `dart`/`supabase` CLI or GitHub repository environment-secret management. It can author code, run repo CI through PRs, and inspect hosted migration history; it cannot safely perform the repository's **required guarded live push** or set protected credentials for the owner.
- These actions require the owner's explicit connection and review. The system should continue to work without product telemetry until then.
