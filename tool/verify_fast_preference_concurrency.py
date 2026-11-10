#!/usr/bin/env python3
"""Two-session concurrency verifier for public.update_context_fast_preferences.

Verifies true cross-session advisory-lock contention and compare-and-set (CAS)
serialization against a running local Supabase PostgreSQL container without
hardcoded credentials or dblink loopback connections:

1. Session 1 starts a transaction, acquires the per-context transaction-scoped
   advisory lock via public.update_context_fast_preferences (rev 0 -> rev 1),
   and holds the transaction open.
2. While Session 1 holds the open transaction:
   - Session 2a attempts a concurrent update on the same context with
     lock_timeout = '80ms' and is rejected with SQLSTATE 55P03 (lock timeout),
     proving the per-context advisory lock actively serializes concurrent
     sessions.
   - Session 2b starts a concurrent update with expected_revision = 0 that waits
     on Session 1's advisory lock until Session 1 commits, then unblocks,
     observes the newly committed revision = 1, and returns conflict = true
     with Session 1's authoritative preference state intact.
"""

from __future__ import annotations

import json
import subprocess
import sys
import threading
import time

TEST_USER_ID = "d1100000-0000-4000-8000-000000000099"
TEST_CONTEXT_ID = "d2200000-0000-4000-8000-000000000099"
TEST_TARGET_ID = "00000000-0000-4000-8000-000000000101"


def find_supabase_db_container() -> str:
    result = subprocess.run(
        ["docker", "ps", "--filter", "name=supabase_db_", "--format", "{{.Names}}"],
        capture_output=True,
        text=True,
        check=True,
    )
    containers = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not containers:
        raise RuntimeError("No running supabase_db_* container found.")
    return containers[0]


def run_psql(container: str, sql: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = [
        "docker",
        "exec",
        "-i",
        container,
        "psql",
        "-X",
        "-q",
        "-t",
        "-A",
        "-v",
        "ON_ERROR_STOP=1",
        "-U",
        "postgres",
        "-d",
        "postgres",
    ]
    return subprocess.run(cmd, input=sql, capture_output=True, text=True, check=check)


def seed_fixture(container: str) -> None:
    sql = f"""
    DELETE FROM public.learning_contexts WHERE id = '{TEST_CONTEXT_ID}'::uuid;
    DELETE FROM auth.users WHERE id = '{TEST_USER_ID}'::uuid;

    INSERT INTO auth.users (id, email)
    VALUES ('{TEST_USER_ID}'::uuid, 'tel01b-concurrency@example.invalid');

    INSERT INTO public.learning_contexts (
      id, user_id, label, root_type, root_id, scope_config
    ) VALUES (
      '{TEST_CONTEXT_ID}'::uuid,
      '{TEST_USER_ID}'::uuid,
      'Concurrency Verification Context',
      'target',
      '{TEST_TARGET_ID}',
      '{{"preserve_me": true}}'::jsonb
    );
    """
    run_psql(container, sql)


def cleanup_fixture(container: str) -> None:
    sql = f"""
    DELETE FROM public.learning_contexts WHERE id = '{TEST_CONTEXT_ID}'::uuid;
    DELETE FROM auth.users WHERE id = '{TEST_USER_ID}'::uuid;
    """
    run_psql(container, sql, check=False)


def main() -> int:
    container = find_supabase_db_container()
    print(f"[concurrency-test] Using Supabase DB container: {container}")
    seed_fixture(container)

    session1_proc = subprocess.Popen(
        [
            "docker",
            "exec",
            "-i",
            container,
            "psql",
            "-X",
            "-q",
            "-t",
            "-A",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            "postgres",
            "-d",
            "postgres",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    try:
        assert session1_proc.stdin is not None
        assert session1_proc.stdout is not None

        # Start Session 1 transaction and acquire the per-context advisory lock.
        session1_setup_sql = f"""
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '{TEST_USER_ID}', true);
SELECT 'S1_PAYLOAD:' || public.update_context_fast_preferences(
  '{TEST_CONTEXT_ID}'::uuid,
  0,
  'mut-session-1',
  'fast',
  45,
  NULL,
  ARRAY['lesson-1']
)::text;
SELECT 'S1_LOCK_HELD';
"""
        session1_proc.stdin.write(session1_setup_sql)
        session1_proc.stdin.flush()

        s1_payload = None
        deadline = time.time() + 15.0
        while time.time() < deadline:
            line = session1_proc.stdout.readline()
            if not line:
                stderr_out = session1_proc.stderr.read() if session1_proc.stderr else ""
                raise RuntimeError(f"Session 1 exited prematurely: {stderr_out}")
            stripped = line.strip()
            if stripped.startswith("S1_PAYLOAD:"):
                s1_payload = json.loads(stripped[len("S1_PAYLOAD:") :])
            elif stripped == "S1_LOCK_HELD":
                break
        else:
            raise TimeoutError("Timed out waiting for Session 1 to acquire advisory lock.")

        assert s1_payload is not None, "Session 1 did not return a payload."
        assert s1_payload.get("conflict") is False, f"Expected S1 conflict=False, got: {s1_payload}"
        assert s1_payload["preference"]["revision"] == 1, f"Expected S1 revision=1, got: {s1_payload}"
        print("[concurrency-test] Session 1 acquired advisory lock and wrote revision=1 (uncommitted).")

        # Session 2a: Concurrent update with short lock_timeout must block on Session 1's advisory lock.
        s2a_sql = f"""
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL lock_timeout = '80ms';
SELECT set_config('request.jwt.claim.sub', '{TEST_USER_ID}', true);
SELECT public.update_context_fast_preferences(
  '{TEST_CONTEXT_ID}'::uuid,
  0,
  'mut-session-2-timeout',
  'standard',
  15,
  NULL,
  ARRAY[]::text[]
);
COMMIT;
"""
        s2a_res = run_psql(container, s2a_sql, check=False)
        if s2a_res.returncode == 0:
            raise AssertionError(
                "Session 2a unexpectedly succeeded while Session 1 held the advisory lock!"
            )
        if "lock timeout" not in s2a_res.stderr.lower():
            raise AssertionError(
                f"Expected Session 2a to fail with lock timeout (55P03), got stderr: {s2a_res.stderr}"
            )
        print("[concurrency-test] Session 2a blocked on Session 1 advisory lock (verified 55P03 lock timeout).")

        # Session 2b: Concurrent update without short lock_timeout blocks until Session 1 commits,
        # then observes committed revision = 1 and returns conflict = true.
        s2b_result_holder: dict[str, object] = {}

        def run_session_2b() -> None:
            s2b_sql = f"""
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '{TEST_USER_ID}', true);
SELECT 'S2B_PAYLOAD:' || public.update_context_fast_preferences(
  '{TEST_CONTEXT_ID}'::uuid,
  0,
  'mut-session-2-race',
  'standard',
  15,
  NULL,
  ARRAY[]::text[]
)::text;
COMMIT;
"""
            s2b_result_holder["proc"] = run_psql(container, s2b_sql, check=True)

        s2b_thread = threading.Thread(target=run_session_2b, daemon=True)
        s2b_thread.start()

        # Give Session 2b 200ms to enter the advisory lock wait queue before Session 1 commits.
        time.sleep(0.2)
        assert s2b_thread.is_alive(), "Session 2b finished before Session 1 committed!"

        # Commit Session 1 so Session 2b unblocks.
        session1_proc.stdin.write("COMMIT;\n\\q\n")
        session1_proc.stdin.flush()
        session1_proc.wait(timeout=10)
        s2b_thread.join(timeout=10)
        if s2b_thread.is_alive():
            raise TimeoutError("Session 2b did not finish after Session 1 committed.")

        s2b_proc = s2b_result_holder.get("proc")
        if not isinstance(s2b_proc, subprocess.CompletedProcess):
            raise RuntimeError("Session 2b failed to produce a completed process result.")

        s2b_payload = None
        for line in s2b_proc.stdout.splitlines():
            stripped = line.strip()
            if stripped.startswith("S2B_PAYLOAD:"):
                s2b_payload = json.loads(stripped[len("S2B_PAYLOAD:") :])
                break

        assert s2b_payload is not None, f"Session 2b produced no payload: {s2b_proc.stdout}"
        assert s2b_payload.get("conflict") is True, (
            f"Expected Session 2b conflict=True after waiting on Session 1 commit, got: {s2b_payload}"
        )
        assert s2b_payload.get("actual_revision") == 1, (
            f"Expected Session 2b actual_revision=1, got: {s2b_payload}"
        )
        assert s2b_payload["preference"]["strategy"] == "fast", (
            f"Expected Session 2b conflict payload to preserve strategy='fast', got: {s2b_payload}"
        )
        assert s2b_payload["preference"]["optional_total_minutes"] == 45, (
            f"Expected Session 2b conflict payload to preserve optional_total_minutes=45, got: {s2b_payload}"
        )
        print(
            "[concurrency-test] Session 2b waited for Session 1 commit and received conflict=True at actual_revision=1."
        )

        # Verify authoritative persisted state in public.context_fast_preferences.
        verify_sql = f"""
SELECT json_build_object(
  'strategy', strategy,
  'revision', revision,
  'optional_total_minutes', optional_total_minutes,
  'last_mutation_id', last_mutation_id
)::text
FROM public.context_fast_preferences
WHERE context_id = '{TEST_CONTEXT_ID}'::uuid;
"""
        verify_res = run_psql(container, verify_sql)
        persisted = json.loads(verify_res.stdout.strip())
        assert persisted == {
            "strategy": "fast",
            "revision": 1,
            "optional_total_minutes": 45,
            "last_mutation_id": "mut-session-1",
        }, f"Unexpected persisted row state: {persisted}"
        print("[concurrency-test] Verified persisted row state matches Session 1 authoritative write.")
        return 0
    finally:
        if session1_proc.poll() is None:
            session1_proc.kill()
        cleanup_fixture(container)


if __name__ == "__main__":
    sys.exit(main())
