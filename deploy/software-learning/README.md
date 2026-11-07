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
