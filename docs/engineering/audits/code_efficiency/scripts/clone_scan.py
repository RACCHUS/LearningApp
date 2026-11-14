"""Bounded clone candidate scan (plan v0.6 section 4A / Phase 0 step 4).

Reads Git blobs at a pin. Scope: classes authored-application and
authored-support-tool only (classification from phase0_inventory.classify).
Method: normalise each line (strip, collapse whitespace; drop blank lines,
comment-only lines, import/export/part lines and lone braces), then hash every
window of WINDOW consecutive normalised lines. Windows seen in more than one
place are merged into maximal runs per location pair. Output is CANDIDATES
only; semantic confirmation is manual.

Usage (repository root):
    python -I docs/engineering/audits/code_efficiency/scripts/clone_scan.py <pin> <out.json> [window]
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from phase0_inventory import classify  # noqa: E402

TRIVIAL = re.compile(r"^(\}|\]|\)|\}\);|\);|\],|\},|\)\,|\{|else \{|\} else \{|return;|break;|pass)$")
COMMENT = re.compile(r"^(//|///|#|/\*|\*)")
IMPORT = re.compile(r"^(import |export |part |from \S+ import )")


def git(*a: str) -> bytes:
    return subprocess.run(["git", *a], check=True, capture_output=True).stdout


def normalise(text: str):
    out = []
    for no, line in enumerate(text.splitlines(), 1):
        s = " ".join(line.split())
        if not s or COMMENT.match(s) or IMPORT.match(s) or TRIVIAL.match(s):
            continue
        out.append((no, s))
    return out


def main() -> None:
    pin, out_path = sys.argv[1], sys.argv[2]
    window = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    paths = [
        p for p in git("ls-tree", "-r", "--name-only", pin).decode().splitlines()
        if p.startswith(("lib/", "tool/")) and p.endswith((".dart", ".py"))
        and classify(p) in ("authored-application", "authored-support-tool")
    ]
    norm = {p: normalise(git("show", f"{pin}:{p}").decode("utf-8", "replace")) for p in paths}
    eligible_logical = sum(len(v) for v in norm.values())

    index = defaultdict(list)  # hash -> [(path, window_start_idx)]
    for p, lines in norm.items():
        for i in range(len(lines) - window + 1):
            h = hashlib.sha1("\n".join(s for _, s in lines[i:i + window]).encode()).hexdigest()
            index[h].append((p, i))

    # Pair occurrences and extend into maximal runs.
    pairs = defaultdict(set)  # (pA, pB) -> set of (iA, iB)
    for occ in index.values():
        if len(occ) < 2 or len(occ) > 20:  # >20 copies is boilerplate, not a cluster
            continue
        for a in range(len(occ)):
            for b in range(a + 1, len(occ)):
                (pa, ia), (pb, ib) = sorted([occ[a], occ[b]])
                if pa == pb and abs(ia - ib) < window:
                    continue
                pairs[(pa, pb)].add((ia, ib))
    runs = []
    for (pa, pb), starts in pairs.items():
        for ia, ib in sorted(starts):
            if (ia - 1, ib - 1) in starts:
                continue  # not the start of a run
            n = 0
            while (ia + n, ib + n) in starts:
                n += 1
            length = n + window - 1
            la, lb = norm[pa], norm[pb]
            runs.append({
                "a": pa, "a_lines": f"{la[ia][0]}-{la[ia + length - 1][0]}",
                "b": pb, "b_lines": f"{lb[ib][0]}-{lb[ib + length - 1][0]}",
                "logical_lines": length,
                "same_file": pa == pb,
                "sample": la[ia][1][:100],
            })
    runs.sort(key=lambda r: (-r["logical_lines"], r["a"], r["a_lines"]))
    dup_lines = set()
    for r in runs:
        for side in ("a", "b"):
            s, e = (int(x) for x in r[f"{side}_lines"].split("-"))
            dup_lines.update((r[side], n) for n, _ in norm[r[side]] if s <= n <= e)
    json.dump({
        "pin": git("rev-parse", pin).decode().strip(),
        "window_logical_lines": window,
        "eligible_files": len(paths),
        "eligible_logical_lines": eligible_logical,
        "candidate_runs": len(runs),
        "candidate_logical_lines_in_any_run": len(dup_lines),
        "candidate_rate_unconfirmed": round(len(dup_lines) / eligible_logical, 4),
        "runs": runs,
    }, open(out_path, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
