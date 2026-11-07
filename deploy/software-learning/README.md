# XLSX Pilot Worker — Isolation Contract

**Status: prototype. Not a production service, upload endpoint, or trusted-assessment path.**

This worker reads the raw bytes of **one** .xlsx document on standard input, extracts a strictly bounded `Budget` worksheet snapshot, and returns one JSON object on standard output. It does **not** access Supabase, execute formulas/macros, calculate skill proficiency, store files, or transfer workbook data to AI.

## Local image build

From repository root:

```sh
docker build -f deploy/software-learning/Dockerfile \
  -t learningapp-xlsx-worker:pilot tool/software_learning
```

## Isolation requirements for the invoking host

The orchestrator must use equivalent or stricter isolation to this prototype invocation:

```sh
docker run --rm -i --network none --read-only \
  --user 65532:65532 --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 32 --memory 128m --cpus 0.5 \
  --ulimit nofile=64:64 --ulimit fsize=10485760:10485760 \
  --tmpfs /tmp:rw,nosuid,noexec,size=8m \
  learningapp-xlsx-worker:pilot budget.xlsx < synthetic-budget.xlsx
```

Do **not** run uploads inside Flutter or a privileged Supabase function. Do not expose Docker sockets to application requests. No network egress, persistent writable mounts, secrets, or ambient cloud credentials may be present in the worker environment. Before production, pin the base image digest, enforce elapsed-time limits in the orchestrator, verify the container/sandbox platform's security defaults, and run hostile-file fixtures *inside* the container.

The worker has explicit input byte, archive part count, decompression ratio and expanded-byte bounds. Those parser-level limits supplement but **do not replace** process and kernel isolation. Only a narrow subset of otherwise valid XLSX packages is supported. A rejected workbook is not an assessment failure and cannot lower a learner's competency.

## Server integration remains blocked

Do not enable a public file route or trusted evidence until all of these are reviewed and implemented:

- authenticated, server-issued per-learner/per-attempt dataset, expiring capability, and storage object ownership;
- access and rate limits, worker scheduling and concurrency quotas;
- private object storage with a documented retention/deletion lifecycle and erasure tests;
- server-only expected values and deterministic checker version pinning;
- trust reconciliation with `record_events` and the unified software/simulation evidence envelope;
- idempotent submission/grade recording and cross-account negative tests;
- accessible mobile upload UI with plain-language privacy notice;
- no AI transfer without informed learner consent;
- host-container smoke tests, adversarial parser tests, deployment review and owner approval.

**Security note:** this is a prototype image; using it on untrusted input without enforcing the runtime isolation above would be unsafe.

## Backend processing handoff (source-only)

New source components:

- `tool/software_learning/private_assessment.py` accepts a **server-verified bearer identity**, a repository-backed **single-use claim**, and a private object adapter. It never accepts a learner-selected object URL and never returns raw workbook cells or expected answers.
- `tool/software_learning/private_assessment_db.py` binds the claim/completion/failure calls to parameterized SQL through an exclusively owned privileged database connection. The claim transaction commits **before** downloading any file, freezing further uploads.
- `tool/software_learning/container_worker_runner.py` permits only a digest-pinned image reference and runs the parser with a fixed, read-only, no-network, no-new-privileges Docker command, capped memory, CPU, process count and execution time. This runner cannot be instantiated with a client-supplied image name.
- Migration `20261107140000_software_learning_excel_processing_lease.sql` (migration **96**) exposes **private service-role-only** claim/complete/fail methods. Claims atomically change the state from `issued` to `processing`, disable further uploads, and issue a unique lease. Completion is compare-and-swap and records **provisional** feedback and artifact hash only. No learning event or competency update is emitted.
- `supabase/tests/software_learning_processing_claim_test.sql` and Python unit suites test cross-owner/invalid sessions, replay, abnormal worker output, object revision changes, timeout, one-time receipt and rejection of verified-status forgery.

This is **not** a deployable API. The processing module uses explicitly injected adapters rather than exposing a public endpoint. An actual backend host, server-verified Supabase Auth gateway, strictly bounded Storage API downloader, immutable object-version binding, secret management, concurrency limits and signed-upload race testing must exist before enabling any authenticated user upload.

The **trusted host** (not the parser container) needs restricted Storage and database credentials. **Never** pass Auth tokens, Supabase secrets, database connections or raw private expected inputs to the Docker parser. The isolated worker receives only the uploaded workbook bytes; expected input comparison happens in the trusted host after worker output validation.

### Provisional receipt and trust

A formula check can return `pass`, `fail` or `inconclusive`, but every result remains `unverified_checker_only` and `skill_award_enabled=false`. The private database receipt records an artifact SHA-256 and outcome for accountability; it does not prove who authored the workbook, create a `record_events` event, or raise a skill level.

The worker host must not be deployed merely because its isolated unit tests pass. Threat-model and verify Storage API deletion, revocation during processing, retries after a host crash, signed URL expiration, malicious archive rejection under hosted resource quotas, object/account erasure, telemetry redaction and opt-in AI handling before a learner-facing submission can be enabled.
