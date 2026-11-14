#!/usr/bin/env python3
"""Check the structured references in docs/engineering/CODEBASE_MAP.md.

Only ``<!-- map-ref ... -->`` comments are parsed; prose, backticked paths and
fenced code blocks are ignored. For each reference it checks that the path is
repository-relative, stays inside the repository, is a tracked file, and that an
optional ``lines="a-b"`` range is within the file. It also checks that every
``## ... {#anchor}`` section has an owner (or policy) and a test reference, and
that the map stays within its size caps.

It proves references resolve. It does NOT prove the referenced file still owns
the behaviour; that needs a human reading the section.

Usage:
    python3 tool/verify_codebase_map.py [--root DIR] [--map PATH]

Exit 0 when clean, 1 when any check fails (all failures are printed).
No network, no third-party dependencies.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

DEFAULT_MAP = "docs/engineering/CODEBASE_MAP.md"
MAX_LINES = 250
MAX_BYTES = 20 * 1024

REF = re.compile(
    r'^<!-- map-ref path="([^"]+)" role="(owner|contract|test|policy)"'
    r'(?: lines="([1-9][0-9]*)-([1-9][0-9]*)")? -->$'
)
SECTION = re.compile(r"^## .*\{#([a-z0-9-]+)\}\s*$")


def tracked_files(root: Path) -> set[str] | None:
    """Tracked paths, or None when root is not a git work tree."""
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            check=True, capture_output=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return {p for p in out.decode("utf-8").split("\0") if p}


def unsafe_path(path: str) -> bool:
    if not path or "\\" in path or path.startswith("/") or re.match(r"^[A-Za-z]:", path):
        return True
    return ".." in PurePosixPath(path).parts


def check(root: Path, map_path: Path) -> list[str]:
    errors: list[str] = []
    raw = map_path.read_bytes()
    text = raw.decode("utf-8")
    lines = text.splitlines()
    rel_map = map_path.relative_to(root).as_posix() if map_path.is_relative_to(root) else str(map_path)

    if len(lines) > MAX_LINES or len(raw) > MAX_BYTES:
        errors.append(
            f"{rel_map}: map exceeds cap ({len(lines)} lines / {len(raw)} bytes;"
            f" max {MAX_LINES} / {MAX_BYTES})"
        )

    tracked = tracked_files(root)
    real_root = root.resolve()
    sections: dict[str, set[str]] = {}
    current: str | None = None
    in_fence = False

    for no, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = SECTION.match(line)
        if m:
            current = m.group(1)
            sections.setdefault(current, set())
            continue
        if line.startswith("## "):
            current = None
            continue
        if not line.startswith("<!-- map-ref"):
            continue

        m = REF.match(line)
        if not m:
            errors.append(f"{rel_map}:{no}: malformed map-ref")
            continue
        path, role, start, end = m.groups()
        if current:
            sections[current].add(role)
        if unsafe_path(path):
            errors.append(f"{rel_map}:{no}: path escapes repository: {path}")
            continue
        target = root / path
        try:
            inside = target.resolve().is_relative_to(real_root)
        except OSError:
            inside = False
        if not inside:
            errors.append(f"{rel_map}:{no}: path escapes repository: {path}")
            continue
        if not target.is_file() or (tracked is not None and path not in tracked):
            errors.append(f"{rel_map}:{no}: missing or untracked: {path}")
            continue
        if start:
            a, b = int(start), int(end)
            count = len(target.read_bytes().decode("utf-8", errors="replace").splitlines())
            if a > b or b > count:
                errors.append(
                    f"{rel_map}:{no}: range {a}-{b} out of bounds for {path} (file has {count} lines)"
                )

    for anchor, roles in sections.items():
        if not roles & {"owner", "policy"} or "test" not in roles:
            errors.append(f"{rel_map}: section #{anchor} lacks an owner/policy or a test reference")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="repository root (default: .)")
    parser.add_argument("--map", default=DEFAULT_MAP, help=f"map path relative to root (default: {DEFAULT_MAP})")
    args = parser.parse_args(argv)
    root = Path(args.root)
    map_path = root / args.map
    if not map_path.is_file():
        print(f"map not found: {map_path}", file=sys.stderr)
        return 1
    errors = check(root, map_path)
    for e in errors:
        print(e)
    if errors:
        print(f"{len(errors)} codebase map problem(s)")
        return 1
    print("codebase map references OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
