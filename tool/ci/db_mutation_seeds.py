#!/usr/bin/env python3
"""Two *database-level* mutations caught by the existing pgTAP security suite.

Run ONLY against a fresh disposable Supabase local stack. This runner edits
migration source in a clean working tree, resets the local database with the
mutant, requires the targeted pgTAP failure, then restores the file and
rebuilds/verifies an unmutated local database. No hosted database calls.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
TAP_SUITE = "supabase/tests/clep_simulation_bank_and_privacy_test.sql"
LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}


@dataclass(frozen=True)
class DbSeed:
    id: str
    file: str
    before: str
    after: str
    expected_failure: str


SEEDS = (
    DbSeed(
        id="db-cross-learner-attempt-select",
        file="supabase/migrations/20261108140000_clep_simulation_bank_and_item_privacy.sql",
        before="  using (user_id = (select auth.uid()));",
        after="  using (true);",
        expected_failure=r"User 2 cannot read User 1 attempt",
    ),
    DbSeed(
        id="db-simulation-issue-leaks-scoring-spec",
        file="supabase/migrations/20261110180000_clep_simulation_domain_quota_and_metadata_validation.sql",
        before="      'response_spec', jsonb_build_object('options', i.response_spec->'options'),",
        after="      'response_spec', jsonb_build_object('options', i.response_spec->'options'),\n"
              "      'scoring_spec', i.scoring_spec,",
        expected_failure=r"Security violation: scoring_spec was returned",
    ),
)


def mutate(seed: DbSeed, content: bytes) -> bytes:
    before = seed.before.encode()
    if content.count(before) != 1:
        raise ValueError(f"{seed.id}: expected exactly one source match, found {content.count(before)}")
    newline = b"\r\n" if b"\r\n" in content else b"\n"
    replacement = seed.after.replace("\n", newline.decode()).encode()
    return content.replace(before, replacement, 1)


def check(seeds=SEEDS) -> list[str]:
    issues = []
    for seed in seeds:
        try:
            mutate(seed, (ROOT / seed.file).read_bytes())
        except (OSError, ValueError) as exc:
            issues.append(str(exc))
    return issues


def _command(args: list[str], timeout: int) -> subprocess.CompletedProcess[str]:
    # No --linked, --remote, --db-url or programmatic production connection.
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True,
                          timeout=timeout, check=False)


def require_local_stack() -> None:
    if os.environ.get("SUPABASE_DB_URL") or os.environ.get("DATABASE_URL"):
        raise RuntimeError("refusing inherited database URL overrides for SQL mutation tests")
    state = _command(["supabase", "status", "-o", "env"], timeout=45)
    if state.returncode != 0:
        raise RuntimeError("Supabase local stack not running")
    fields = dict(
        line.split("=", 1) for line in state.stdout.splitlines()
        if "=" in line and not line.startswith("#")
    )
    for key in ("API_URL", "DB_URL"):
        raw = fields.get(key, "").strip().strip('"')
        parsed = urlparse(raw)
        if parsed.hostname not in LOCAL_HOSTS:
            raise RuntimeError(f"refusing non-loopback {key} in Supabase local status")


def _tap(timeout: int) -> subprocess.CompletedProcess[str]:
    return _command(["supabase", "test", "db", TAP_SUITE, "--local"], timeout)


def _reset(timeout: int) -> None:
    proc = _command(["supabase", "db", "reset", "--local"], timeout)
    if proc.returncode:
        raise RuntimeError("local DB reset/migration failed (not a killed mutant): "
                           + (proc.stdout + proc.stderr)[-900:])


def _baseline(timeout: int) -> None:
    proc = _tap(timeout)
    if proc.returncode:
        raise RuntimeError("clean pgTAP baseline fails: " + (proc.stdout + proc.stderr)[-1200:])


def _clean_checkout(path: str) -> None:
    status = _command(["git", "status", "--porcelain", "--", path], 30)
    if status.returncode or status.stdout.strip():
        raise RuntimeError(f"{path} has uncommitted changes; refusing to mutate")


def execute(seeds=SEEDS, timeout: int = 900) -> list[tuple[str, str]]:
    require_local_stack()
    _baseline(timeout)
    results = []
    for seed in seeds:
        _clean_checkout(seed.file)
        path = ROOT / seed.file
        original = path.read_bytes()
        changed = mutate(seed, original)
        try:
            path.write_bytes(changed)
            _reset(timeout)
            proc = _tap(timeout)
            output = proc.stdout + "\n" + proc.stderr
            # A syntax error, timeout, missing service, or unrelated failing
            # assertion is not a kill. Require the *specific* privacy signal.
            if proc.returncode == 0:
                raise RuntimeError(f"{seed.id}: SURVIVED (pgTAP unexpectedly passed)")
            if not re.search(seed.expected_failure, output, re.IGNORECASE):
                raise RuntimeError(f"{seed.id}: failed for the wrong reason; "
                                   "expected targeted pgTAP privacy diagnostic. "
                                   + output[-1200:])
            results.append((seed.id, "killed"))
        finally:
            path.write_bytes(original)
            # Never leave a local DB with a deliberately weakened policy or
            # answer-leaking function; this runs even if the mutation survives.
            _reset(timeout)
            _baseline(timeout)
    return results


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args(argv)
    known = {seed.id for seed in SEEDS}
    if set(args.only) - known:
        print(f"unknown database mutation seed id(s): {sorted(set(args.only) - known)}", file=sys.stderr)
        return 2
    seeds = tuple(s for s in SEEDS if not args.only or s.id in args.only)
    stale = check(seeds)
    if stale:
        print("\n".join(stale), file=sys.stderr)
        return 2
    if args.check:
        print(f"All {len(seeds)} database mutation source anchors apply exactly once.")
        return 0
    try:
        results = execute(seeds, args.timeout)
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"SQL mutation verification ERROR: {exc}", file=sys.stderr)
        return 2
    for seed_id, status in results:
        print(f"{seed_id}: {status} (targeted pgTAP security failure, baseline restored)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
