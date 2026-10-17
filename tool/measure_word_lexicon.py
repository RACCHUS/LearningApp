#!/usr/bin/env python3
"""Measure W1 spelling asset size and ensure Flutter web ships the same file.

Only standard-library dependencies. The compressed metric represents an
estimated gzip-transfer size, not a guarantee about hosting headers.
"""
from __future__ import annotations

import gzip
from pathlib import Path

SOURCE = Path("assets/lexicons/en_us_scowl_roots.txt")
WEB_COPY = Path("build/web/assets/assets/lexicons/en_us_scowl_roots.txt")
RAW_BUDGET = 600_000
GZIP_BUDGET = 350_000


def main() -> None:
    content = SOURCE.read_bytes()
    published = WEB_COPY.read_bytes()
    if published != content:
        raise SystemExit("Flutter web asset is missing or differs from source.")

    words = [w for w in content.decode("utf-8").splitlines()
             if w and not w.startswith("#")]
    gzipped = gzip.compress(content, compresslevel=9, mtime=0)
    print(f"Word Learning lexicon: {len(words):,} base entries")
    print(f"  Raw asset (web): {len(published):,} bytes")
    print(f"  Gzip estimate:   {len(gzipped):,} bytes")
    print(f"  Raw budget:      {RAW_BUDGET:,} bytes")
    print(f"  Gzip budget:     {GZIP_BUDGET:,} bytes")
    if len(published) > RAW_BUDGET or len(gzipped) > GZIP_BUDGET:
        raise SystemExit("W1 spelling lexicon exceeds its documented size budget.")


if __name__ == "__main__":
    main()
