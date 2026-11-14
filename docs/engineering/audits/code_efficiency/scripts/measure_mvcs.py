"""Deterministic MVCS measurement for the frozen task manifest (plan v0.6 section 7).

Reads Git blobs at the manifest pin only. Zero model calls.

Usage (repository root):
    python -I docs/engineering/audits/code_efficiency/scripts/measure_mvcs.py \
        docs/engineering/audits/code_efficiency/data/task_manifest.json \
        docs/engineering/audits/code_efficiency/data/mvcs_baseline.json

Bytes (primary): raw blob bytes exactly as committed (no line-ending
normalisation; some blobs, e.g. tool/ingest_curriculum.dart, are committed with
CRLF). Whole-file footprint sums each distinct file once; bounded-range
footprint sums the union of the listed line ranges (str.splitlines convention),
each selected line counted with its own stored line ending.
Tokens (secondary): tiktoken o200k_base if importable, else "not_measured".
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys


def blob_text(pin: str, path: str) -> str:
    raw = subprocess.run(["git", "show", f"{pin}:{path}"], check=True, capture_output=True).stdout
    return raw.decode("utf-8")


def selected_lines(text: str, ranges: list[str]) -> str:
    lines = text.splitlines(keepends=True)
    if ranges == ["all"]:
        return text
    keep: set[int] = set()
    for r in ranges:
        a, b = (int(x) for x in r.split("-"))
        if not 1 <= a <= b <= len(lines):
            raise SystemExit(f"range {r} out of bounds (1-{len(lines)})")
        keep.update(range(a, b + 1))
    return "".join(lines[i - 1] for i in sorted(keep))


def main() -> None:
    manifest_path, out_path = sys.argv[1], sys.argv[2]
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    pin = manifest["pin"]

    try:
        import tiktoken

        enc = tiktoken.get_encoding("o200k_base")
        vocab_hash = hashlib.sha256(
            b"".join(k + b"\0" + str(v).encode() for k, v in sorted(enc._mergeable_ranks.items()))
        ).hexdigest()
        tok = lambda s: len(enc.encode(s, disallowed_special=()))
        tokenizer = {"library": f"tiktoken {tiktoken.__version__}", "encoding": "o200k_base", "ranks_sha256": vocab_hash}
    except Exception as exc:  # noqa: BLE001 - record and continue bytes-only
        tok = None
        tokenizer = {"status": "not_measured", "reason": repr(exc)}

    def tokens(s: str):
        return tok(s) if tok else "not_measured"

    cache: dict[str, str] = {}

    def text(path: str) -> str:
        if path not in cache:
            cache[path] = blob_text(pin, path)
        return cache[path]

    results = []
    for t in manifest["tasks"]:
        files = []
        for item in t["mvcs"]:
            full = text(item["path"])
            part = selected_lines(full, item["ranges"])
            files.append({
                "path": item["path"],
                "role": item["role"],
                "ranges": item["ranges"],
                "whole_bytes": len(full.encode()),
                "range_bytes": len(part.encode()),
                "whole_tokens": tokens(full),
                "range_tokens": tokens(part),
            })
        mvcs_range_by_path = {f["path"]: f["range_bytes"] for f in files}

        route = []
        for step in t["baseline_route"]:
            if step.startswith("grep:"):
                route.append({"step": step, "bytes": 0})
            else:
                b = len(text(step).encode())
                route.append({"step": step, "bytes": b, "outside_mvcs": b - mvcs_range_by_path.get(step, 0)})
        owner_step = t["owner_step"]
        before_owner = route[: owner_step - 1]
        file_hops = [s for s in route if not s["step"].startswith("grep:")]

        results.append({
            "id": t["id"],
            "kind": t["kind"],
            "files": len(files),
            "whole_file_bytes": sum(f["whole_bytes"] for f in files),
            "bounded_range_bytes": sum(f["range_bytes"] for f in files),
            "whole_file_tokens": sum(f["whole_tokens"] for f in files) if tok else "not_measured",
            "bounded_range_tokens": sum(f["range_tokens"] for f in files) if tok else "not_measured",
            "by_role_range_bytes": {
                r: sum(f["range_bytes"] for f in files if f["role"] == r)
                for r in sorted({f["role"] for f in files})
            },
            "scripted_route": route,
            "scripted_hops_to_owner": owner_step,
            "scripted_route_file_reads": len(file_hops),
            "scripted_route_bytes": sum(s["bytes"] for s in route),
            "avoidable_bytes_before_owner": sum(s.get("outside_mvcs", 0) for s in before_owner),
            "false_owner_candidates": t.get("false_owner_candidates", []),
            "map_section_owner": "not_measured",
            "map_section_contract": "not_measured",
            "map_section_tests": "not_measured",
            "files_detail": files,
        })

    out = {
        "pin": pin,
        "manifest_sha256": hashlib.sha256(open(manifest_path, "rb").read()).hexdigest(),
        "python": sys.version.split()[0],
        "tokenizer": tokenizer,
        "live_model_calls": 0,
        "tasks": results,
    }
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
