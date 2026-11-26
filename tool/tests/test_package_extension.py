"""tool/package_extension.py: the store limits are checked before upload."""
from __future__ import annotations

import json
import shutil
import sys
import zipfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_extension as pkg  # noqa: E402


def test_the_committed_extension_passes():
    assert pkg.check() == []


@pytest.fixture
def copy(tmp_path, monkeypatch):
    ext = tmp_path / "extension"
    shutil.copytree(pkg.EXT, ext)
    monkeypatch.setattr(pkg, "EXT", ext)
    monkeypatch.setattr(pkg, "OUT", tmp_path / "out")
    return ext


def _edit(ext: Path, browser: str, change) -> None:
    path = ext / browser / "manifest.json"
    m = json.loads(path.read_text(encoding="utf-8"))
    change(m)
    path.write_text(json.dumps(m), encoding="utf-8")


def test_a_description_over_132_characters_is_refused(copy):
    _edit(copy, "chrome", lambda m: m.update(description="x" * 133))
    assert any("description is 133" in p for p in pkg.check())


def test_a_second_permission_is_refused(copy):
    _edit(copy, "firefox", lambda m: m.update(permissions=["activeTab", "tabs"]))
    assert any("permissions must be exactly" in p for p in pkg.check())


def test_an_icon_of_the_wrong_size_is_refused(copy):
    shutil.copy(copy / "chrome" / "icon-16.png", copy / "chrome" / "icon-128.png")
    assert any("icon-128.png is 16x16" in p for p in pkg.check())


def test_different_versions_are_refused(copy):
    _edit(copy, "chrome", lambda m: m.update(version="9.9.9"))
    assert any("different versions" in p for p in pkg.check())


def test_each_zip_holds_only_what_its_manifest_names(copy):
    (copy / "chrome" / "notes.txt").write_text("not for the store", encoding="utf-8")
    chrome, firefox = pkg.build()
    names = zipfile.ZipFile(chrome).namelist()
    assert "manifest.json" in names and "background.js" in names
    assert "notes.txt" not in names
    assert "panel.html" in zipfile.ZipFile(firefox).namelist()
