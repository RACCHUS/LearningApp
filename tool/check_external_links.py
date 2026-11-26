"""Scheduled dead-link check for external resources (master plan v2.6 §7.5,
§9.3): every source and companion URL in content/bridges and
content/companions must still respond, and so must every link of a catalog
resource that has an objective map (data/resource_maps/): only those can
be recommended. A resource without a map is not checked, because some
publishers refuse automated requests. Exits 1 when any link is dead, so
the scheduled workflow fails and the owner is notified; nothing in the app
changes automatically.

    python tool/check_external_links.py
"""
from __future__ import annotations

import glob
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
USER_AGENT = "LearningApp-link-check/1 (+https://learningapp-2ed8a.web.app)"


def collect_urls(root: Path = REPO) -> dict[str, list[str]]:
    """URL -> files that cite it."""
    found: dict[str, list[str]] = {}
    for path in sorted(glob.glob(str(root / "content" / "bridges" / "*.bridge.json"))
                       + glob.glob(str(root / "content" / "companions" / "*.companion.json"))):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        urls = [s.get("url") for s in data.get("sources") or []]
        urls.append((data.get("resource") or {}).get("url"))
        for url in urls:
            if isinstance(url, str) and url.startswith("https://"):
                found.setdefault(url, []).append(Path(path).name)
    import yaml  # only the catalog part needs it

    mapped: dict[str, list[str]] = {}
    for path in sorted(glob.glob(str(root / "data" / "resource_maps" / "*.yaml"))):
        doc = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
        urls = [s.get("locator") for c in doc.get("coverage") or [] for s in c.get("sections") or []]
        mapped.setdefault(str(doc.get("resource_id")), []).extend(u for u in urls if u)
        for url in urls:
            if isinstance(url, str) and url.startswith("https://"):
                found.setdefault(url, []).append(Path(path).name)
    for rid in mapped:
        record = root / "data" / "external_resources" / f"{rid}.yaml"
        if record.exists():
            url = (yaml.safe_load(record.read_text(encoding="utf-8")) or {}).get("canonical_url")
            if isinstance(url, str) and url.startswith("https://"):
                found.setdefault(url, []).append(record.name)
    return found


def check(url: str) -> int | str:
    """HTTP status, or an error name. HEAD first; some sites refuse HEAD."""
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.status
        except urllib.error.HTTPError as e:
            if method == "HEAD" and e.code in (403, 405):
                continue
            return e.code
        except (urllib.error.URLError, TimeoutError) as e:
            if method == "HEAD":
                continue
            return type(e).__name__
    return "unreachable"


def is_dead(status: int | str) -> bool:
    return not (isinstance(status, int) and status < 400)


def main() -> int:
    urls = collect_urls()
    dead = []
    for url, files in sorted(urls.items()):
        status = check(url)
        mark = "DEAD" if is_dead(status) else "ok"
        print(f"{mark:4} {status} {url}  ({', '.join(files)})")
        if is_dead(status):
            dead.append(url)
    print(f"{len(urls)} link(s) checked, {len(dead)} dead.")
    return 1 if dead else 0


if __name__ == "__main__":
    raise SystemExit(main())
