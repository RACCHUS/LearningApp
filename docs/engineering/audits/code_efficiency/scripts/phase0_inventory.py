"""Phase 0 read-only inventory for the codebase simplification plan (v0.6).

Audit evidence only: reads Git objects at a pinned commit and writes JSON/CSV.
It never reads the working tree for sizes (core.autocrlf on Windows checkouts
inflates working-tree bytes), never modifies the repository, and calls no model.

Usage (from the repository root):
    python -I docs/engineering/audits/code_efficiency/scripts/phase0_inventory.py <pin_sha> <out_dir>

Outputs:
    inventory.json        totals, root Markdown, instruction surface, empty files
    top25_size.csv        top 25 blobs by Git byte size under lib/ or tool/
    churn_eligible.csv    frozen 90x24h churn ranking (authored code only)

Line convention: Python str.splitlines() on the UTF-8 decoded blob.
"""

from __future__ import annotations

import csv
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import PurePosixPath

# --- Frozen classification rules (plan §2.3) --------------------------------

PROTECTED_OPERATIONS = {
    "lib/services/governance/guarded_deployment_manager.dart",
    "lib/services/reset_service.dart",
    "tool/ingest_curriculum.dart",
    "tool/ingest_official_taxonomies.dart",
}
DATA_IN_LIB_FILES = {
    "lib/services/taxonomy/official_taxonomy_sources.dart",
    # Provisional: data/model-shaped mixed file; manual classification pending.
    "lib/models/overview_outline.dart",
}
GENERATED_SUFFIXES = (".g.dart", ".freezed.dart", ".mocks.dart", ".gr.dart", ".config.dart")
INSTRUCTION_SURFACE = [
    "AGENTS.md",
    ".agents/rules/mcp-tooling.md",
    ".github/instructions/Main.instructions.md",
    ".github/agents/lesson-generator.agent.md",
    ".github/prompts/generate-lesson.prompt.md",
    ".github/pull_request_template.md",
]


def classify(path: str) -> str:
    p = PurePosixPath(path)
    name = p.name
    if path.startswith("supabase/migrations/"):
        return "migration"
    if path.endswith(".md"):
        return "documentation"
    if path.startswith(("test/", "tool/tests/", "supabase/tests/")) or "/test/" in path:
        return "test"
    if path.endswith(GENERATED_SUFFIXES) or path.startswith("lib/l10n/generated/"):
        return "generated"
    if path in PROTECTED_OPERATIONS or (
        path.startswith("tool/") and name.startswith("verify_") and p.suffix in (".dart", ".py")
    ):
        return "protected-operations"
    if path.startswith("tool/curriculum_"):
        return "curriculum-as-code"
    if path.startswith("lib/data/") or path in DATA_IN_LIB_FILES:
        return "data-in-lib"
    if path.startswith("lib/"):
        return "authored-application"
    if path.startswith("tool/"):
        return "authored-support-tool"
    return "other"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True, encoding="utf-8"
    ).stdout


def blob_lines(pin: str, path: str) -> int:
    raw = subprocess.run(["git", "show", f"{pin}:{path}"], check=True, capture_output=True).stdout
    return len(raw.decode("utf-8", errors="replace").splitlines())


def main() -> None:
    pin, out_dir = sys.argv[1], sys.argv[2]
    pin = git("rev-parse", pin).strip()
    committer_iso = git("show", "-s", "--format=%cI", pin).strip()
    end_utc = datetime.fromisoformat(committer_iso).astimezone(timezone.utc)
    start_utc = end_utc - timedelta(hours=90 * 24)

    entries = []  # (path, bytes)
    tree_entries = 0
    for line in git("ls-tree", "-r", "-t", "-l", pin).splitlines():
        meta, path = line.split("\t", 1)
        _mode, kind, _obj, size = meta.split()
        tree_entries += 1
        if kind == "blob":
            entries.append((path, int(size)))
    sizes = dict(entries)

    def count(pred):
        sel = [(p, s) for p, s in entries if pred(p)]
        return {"files": len(sel), "bytes": sum(s for _, s in sel)}

    root_md = sorted(
        ((p, s) for p, s in entries if "/" not in p and p.endswith(".md")), key=lambda x: -x[1]
    )
    inventory = {
        "pin": pin,
        "pin_committer_time": committer_iso,
        "pin_committer_time_utc": end_utc.isoformat(),
        "git_version": git("--version").strip(),
        "python_version": sys.version.split()[0],
        "measurement": "Git blob bytes at pin (git ls-tree -l); lines = str.splitlines()",
        "tree_entries_files_and_dirs": tree_entries,
        "dart_all": count(lambda p: p.endswith(".dart")),
        "dart_lib": count(lambda p: p.startswith("lib/") and p.endswith(".dart")),
        "dart_test": count(lambda p: p.startswith("test/") and p.endswith(".dart")),
        "python_all": count(lambda p: p.endswith(".py")),
        "python_tool": count(lambda p: p.startswith("tool/") and p.endswith(".py")),
        "root_markdown": {
            "files": len(root_md),
            "bytes": sum(s for _, s in root_md),
            "by_file": [{"path": p, "bytes": s} for p, s in root_md],
        },
        "instruction_surface": [
            {"path": p, "bytes": sizes.get(p), "lines": blob_lines(pin, p) if p in sizes else None}
            for p in INSTRUCTION_SURFACE
        ],
        "empty_blobs_in_lib_tool_test": sorted(
            p for p, s in entries if s == 0 and p.startswith(("lib/", "tool/", "test/"))
        ),
        "class_totals_lib_tool": {},
    }
    for p, s in entries:
        if p.startswith(("lib/", "tool/")):
            c = classify(p)
            t = inventory["class_totals_lib_tool"].setdefault(c, {"files": 0, "bytes": 0})
            t["files"] += 1
            t["bytes"] += s

    top = sorted(
        ((p, s) for p, s in entries if p.startswith(("lib/", "tool/"))), key=lambda x: (-x[1], x[0])
    )[:25]
    with open(f"{out_dir}/top25_size.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["rank", "path", "git_bytes", "lines", "class"])
        for i, (p, s) in enumerate(top, 1):
            w.writerow([i, p, s, blob_lines(pin, p), classify(p)])

    # --- Frozen churn method (plan §2.4) -------------------------------------
    eligible = sorted(
        p
        for p, _ in entries
        if p.startswith(("lib/", "tool/"))
        and p.endswith((".dart", ".py"))
        and classify(p) in ("authored-application", "authored-support-tool")
    )
    rows = []
    since, until = start_utc.strftime("%Y-%m-%dT%H:%M:%SZ"), end_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    for p in eligible:
        out = git(
            "log", pin, "--no-merges", "--follow", f"--since={since}", f"--until={until}",
            "--numstat", "--format=@@%H", "--", p,
        )
        commits, changed, binary = set(), 0, False
        for ln in out.splitlines():
            if ln.startswith("@@"):
                commits.add(ln[2:])
            elif ln.strip():
                a, d, _ = ln.split("\t", 2)
                if a == "-" or d == "-":
                    binary = True
                else:
                    changed += int(a) + int(d)
        if commits:
            rows.append((p, len(commits), changed, binary, sizes[p], classify(p)))
    rows.sort(key=lambda r: (-r[1], -r[2], r[0]))
    with open(f"{out_dir}/churn_eligible.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["rank", "path", "nonmerge_commits", "added_plus_deleted", "binary_seen", "git_bytes", "class"])
        for i, r in enumerate(rows, 1):
            w.writerow([i, *r])
    inventory["churn"] = {
        "window_start_utc": since,
        "window_end_utc": until,
        "eligible_files": len(eligible),
        "files_with_churn": len(rows),
        "renames": "git log --follow per single path; numstat counted on whatever path the commit touched",
        "binary": "numstat '-' counted as 0 lines and flagged binary_seen",
    }
    with open(f"{out_dir}/inventory.json", "w", encoding="utf-8") as fh:
        json.dump(inventory, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
