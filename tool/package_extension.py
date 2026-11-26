#!/usr/bin/env python3
"""Package the browser extension for the stores (companion plan v1.0 EX-9).

    python tool/package_extension.py            # write build/extension/*.zip
    python tool/package_extension.py --check    # CI: validate only

Each zip holds exactly the files one browser folder needs, with
manifest.json at the root, which is what the Chrome Web Store, Edge Add-ons
and Firefox Add-ons ask for. The checks are the store limits that a manual
upload would otherwise only report after the fee is paid:

  * manifest name at most 75 characters, description at most 132;
  * a 128-pixel icon (Chrome's listing needs it) and every icon the manifest
    names exists with the size it claims;
  * activeTab is the only permission, with no host permissions or content
    scripts (the privacy promise in extension/README.md);
  * both folders carry the same version and the same background.js.
"""
from __future__ import annotations

import json
import struct
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / "extension"
OUT = ROOT / "build" / "extension"
BROWSERS = ("chrome", "firefox")
NAME_MAX = 75
DESCRIPTION_MAX = 132


def png_size(path: Path) -> tuple[int, int]:
    """Width and height from a PNG's header (no imaging library needed)."""
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError(f"{path.name} is not a PNG")
    return struct.unpack(">II", head[16:24])


def _icons(manifest: dict) -> dict[str, str]:
    found: dict[str, str] = {}
    for holder in (manifest, manifest.get("action") or {}, manifest.get("sidebar_action") or {}):
        icons = holder.get("icons") if holder is manifest else holder.get("default_icon")
        if isinstance(icons, dict):
            found.update(icons)
    return found


def files_for(browser: str) -> list[str]:
    m = json.loads((EXT / browser / "manifest.json").read_text(encoding="utf-8"))
    names = {"manifest.json", *(_icons(m).values())}
    bg = m.get("background") or {}
    names.update(bg.get("scripts") or [])
    if bg.get("service_worker"):
        names.add(bg["service_worker"])
    panel = (m.get("sidebar_action") or {}).get("default_panel")
    if panel:
        names.add(panel)
    return sorted(names)


def check() -> list[str]:
    problems: list[str] = []
    versions = set()
    for browser in BROWSERS:
        folder = EXT / browser
        m = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        versions.add(m.get("version"))
        if len(m.get("name", "")) > NAME_MAX:
            problems.append(f"{browser}: name is longer than {NAME_MAX} characters")
        if len(m.get("description", "")) > DESCRIPTION_MAX:
            problems.append(
                f"{browser}: description is {len(m['description'])} characters; the stores allow {DESCRIPTION_MAX}"
            )
        if m.get("permissions") != ["activeTab"]:
            problems.append(f"{browser}: permissions must be exactly ['activeTab']")
        for key in ("host_permissions", "optional_permissions", "optional_host_permissions", "content_scripts"):
            if key in m:
                problems.append(f"{browser}: must not declare {key}")
        icons = _icons(m)
        if "128" not in (m.get("icons") or {}):
            problems.append(f"{browser}: needs a 128-pixel icon")
        for size, name in icons.items():
            path = folder / name
            if not path.exists():
                problems.append(f"{browser}: icon {name} is missing")
                continue
            try:
                w, h = png_size(path)
            except ValueError as e:
                problems.append(f"{browser}: {e}")
                continue
            if (w, h) != (int(size), int(size)):
                problems.append(f"{browser}: {name} is {w}x{h}, manifest says {size}")
        for name in files_for(browser):
            if not (folder / name).exists():
                problems.append(f"{browser}: {name} is named in the manifest but missing")
    if len(versions) != 1:
        problems.append(f"the two manifests carry different versions: {sorted(map(str, versions))}")
    scripts = {(EXT / b / "background.js").read_text(encoding="utf-8").replace("\r\n", "\n") for b in BROWSERS}
    if len(scripts) != 1:
        problems.append("chrome/background.js and firefox/background.js differ")
    return problems


def build() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for browser in BROWSERS:
        m = json.loads((EXT / browser / "manifest.json").read_text(encoding="utf-8"))
        target = OUT / f"learningapp-companion-{browser}-{m['version']}.zip"
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
            for name in files_for(browser):
                z.write(EXT / browser / name, name)
        written.append(target)
    return written


def main(argv: list[str]) -> int:
    problems = check()
    if problems:
        for p in problems:
            print(f"FAIL {p}")
        return 1
    if "--check" in argv:
        print("Extension package check PASS: " + ", ".join(f"{b} ({len(files_for(b))} files)" for b in BROWSERS))
        return 0
    for path in build():
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
