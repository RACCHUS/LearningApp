#!/usr/bin/env python3
"""No-network contract check for the site-wide feature registry (FLAG-010).

Feature keys in the Dart typed catalog must match the effective, append-only
SQL seed history exactly: the original foundation seed plus every later
additive migration that inserts into private.site_feature_controls (master
plan v2.6 §15.0 "v2.5 append-only registry rule"). A key seeded twice is an
error because ON CONFLICT DO NOTHING would silently ignore the second row.
Only explicitly grandfathered, existing TEL capabilities may start enabled.
This does NOT prove every feature has backend gate coverage; each feature PR
must separately implement an integration test for the relevant side effect.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DART = ROOT / "lib" / "models" / "governance" / "site_feature_keys.dart"
MIGRATIONS = ROOT / "supabase" / "migrations"
FOUNDATION = "20261110220000_marketing_feature_control_foundation.sql"
SEED_MARKER = "INSERT INTO private.site_feature_controls"
SAFE_ON = {"tel.fast", "tel.overview"}
KEY_RE = re.compile(r"static const String [A-Za-z0-9_]+ = '([^']+)';")
SEED_RE = re.compile(
    r"^\s*\('(?P<key>[a-z][a-z0-9_.]+)',\s*'[^']+',\s*'[^']+',"
    r"\s*'(?P<kind>[^']+)',\s*(?P<enabled>true|false),"
    r"\s*'(?P<maturity>experimental|verified)',"
    r"\s*(?P<ready>true|false),",
    re.MULTILINE,
)


def verify(dart_text: str, sql_text: str) -> list[str]:
    errors: list[str] = []
    dart_keys = KEY_RE.findall(dart_text)
    sql_seed = list(SEED_RE.finditer(sql_text))
    sql_keys = [m["key"] for m in sql_seed]

    if not dart_keys or not sql_keys:
        return ["No typed keys or SQL seed entries found; inspect schema."]

    if len(dart_keys) != len(set(dart_keys)):
        errors.append("Duplicate Dart feature key.")
    if len(sql_keys) != len(set(sql_keys)):
        errors.append("Duplicate SQL feature key.")
    if set(dart_keys) != set(sql_keys):
        errors.append(
            f"Dart/SQL feature-key mismatch: "
            f"only Dart={sorted(set(dart_keys) - set(sql_keys))}, "
            f"only SQL={sorted(set(sql_keys) - set(dart_keys))}"
        )

    for m in sql_seed:
        key = m["key"]
        if m["enabled"] == "true" and key not in SAFE_ON:
            errors.append(f"New or risky feature {key} cannot seed enabled=true.")
        if m["enabled"] == "true" and m["ready"] != "true":
            errors.append(f"{key} enabled with release_ready=false.")
        if m["enabled"] == "false" and m["ready"] == "true" and key not in SAFE_ON:
            errors.append(f"Unreviewed feature {key} incorrectly seeded release-ready.")
    return errors


def effective_seed_sql(migrations_dir: Path = MIGRATIONS) -> str:
    """Concatenates, in version order, every migration that seeds the registry.

    The foundation seed must be present; later additive seeds are appended.
    """
    files = sorted(migrations_dir.glob("*.sql"))
    names = [f.name for f in files]
    if FOUNDATION not in names:
        raise FileNotFoundError(f"Missing foundation seed {FOUNDATION}")
    parts = [
        f.read_text(encoding="utf-8")
        for f in files
        if SEED_MARKER in f.read_text(encoding="utf-8")
    ]
    return "\n".join(parts)


def main() -> int:
    errors = verify(DART.read_text(encoding="utf-8"), effective_seed_sql())
    if errors:
        for error in errors:
            print("Feature registry contract FAIL:", error, file=sys.stderr)
        return 1
    print("Feature registry contract PASS: typed IDs and safe SQL defaults aligned.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
