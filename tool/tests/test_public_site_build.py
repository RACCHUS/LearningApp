"""Offline regression tests for the public-site publish and 200/404 contracts."""
from __future__ import annotations

import copy
import functools
import http.server
import json
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import build_public_site as site  # noqa: E402

ORIGIN = "https://www.example.test"
APP = "https://app.example.test"


class PublicSiteTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data = json.loads(site.MANIFEST.read_text(encoding="utf-8"))

    def manifest(self, data):
        path = self.root / "pages.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def approved(self):
        data = copy.deepcopy(self.data)
        for page in data["pages"]:
            if page["slug"] in ("", "how-it-works"):
                page["status"] = "published"
                page["review"]["owner_approved"] = True
                page["review"]["reviewed_at"] = "2026-11-10"
        return data

    def test_drafts_cannot_be_published_without_approval(self):
        with self.assertRaisesRegex(ValueError, "No owner-approved"):
            site.build(self.manifest(self.data), self.root / "public", ORIGIN, APP)
        self.assertFalse((self.root / "public").exists())

    def test_preview_is_noindex_and_sitemap_empty(self):
        out = self.root / "preview"
        self.assertEqual(site.build(self.manifest(self.data), out, ORIGIN, APP, preview=True), 5)
        html = (out / "index.html").read_text()
        self.assertIn('content="noindex,nofollow"', html)
        self.assertIn("Draft preview", html)
        self.assertIn('<h1>Learn with a clear path</h1>', html)
        self.assertIn('href="https://app.example.test/#/learn"', html)
        self.assertIn('rel="canonical" href="https://www.example.test/"', html)
        self.assertIn('type="application/ld+json"', html)
        self.assertNotIn('"QAPage"', html)
        self.assertEqual((out / "robots.txt").read_text(), "User-agent: *\nDisallow: /\n")
        self.assertNotIn("<url><loc>", (out / "sitemap.xml").read_text())
        self.assertTrue((out / "404.html").is_file())

    def test_public_build_only_includes_approved_pages(self):
        out = self.root / "published"
        self.assertEqual(site.build(self.manifest(self.approved()), out, ORIGIN, APP), 2)
        self.assertTrue((out / "how-it-works" / "index.html").is_file())
        for name in ("about", "review-standards", "clep-psychology-study-roadmap"):
            self.assertFalse((out / name / "index.html").exists())
        home = (out / "index.html").read_text()
        self.assertIn('content="index,follow"', home)
        self.assertIn('href="/how-it-works/"', home)
        self.assertNotIn('href="/about/"', home)
        sitemap = (out / "sitemap.xml").read_text()
        self.assertEqual(sitemap.count("<url><loc>"), 2)
        self.assertIn("https://www.example.test/how-it-works/", sitemap)
        self.assertNotIn("<lastmod>", sitemap)
        self.assertIn("Sitemap: https://www.example.test/sitemap.xml", (out / "robots.txt").read_text())

    def test_publish_requires_reviewed_home_and_sources(self):
        data = self.approved()
        home = next(p for p in data["pages"] if p["slug"] == "")
        home["review"]["owner_approved"] = False
        with self.assertRaisesRegex(ValueError, "explicit owner approval"):
            site.build(self.manifest(data), self.root / "public", ORIGIN, APP)
        home["review"]["owner_approved"] = True
        home["review"]["sources"] = []
        with self.assertRaisesRegex(ValueError, "review evidence"):
            site.build(self.manifest(data), self.root / "public", ORIGIN, APP)
        home["review"]["sources"] = ["README.md"]
        home["status"] = "draft"
        with self.assertRaisesRegex(ValueError, "homepage"):
            site.build(self.manifest(data), self.root / "public", ORIGIN, APP)

    def test_reject_traversal_reserved_slugs_and_bad_origins(self):
        data = copy.deepcopy(self.data)
        for slug in ("../secrets", "/admin", "admin", "api/private", "a//b", "a?token=b"):
            data["pages"][0]["slug"] = slug
            with self.subTest(slug=slug), self.assertRaises(ValueError):
                site.load_manifest(self.manifest(data))
        for origin in ("http://example.test", "https://u:p@example.test",
                       "https://example.test/path", "https://example.test/?token=s",
                       "javascript:alert(1)"):
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                site.canonical_origin(origin)

    def test_html_escapes_editorial_text_and_script_end(self):
        data = self.approved()
        home = next(p for p in data["pages"] if p["slug"] == "")
        home["title"] = '</script><script>alert("x")</script>'
        home["sections"][0]["paragraphs"][0] = '<img src=x onerror=alert(1)>'
        out = self.root / "published"
        site.build(self.manifest(data), out, ORIGIN, APP)
        page = (out / "index.html").read_text()
        self.assertNotIn('<script>alert(', page)
        self.assertNotIn('<img src=x', page)
        self.assertIn("&lt;img src=x", page)
        self.assertIn("\\u003c/script\\u003e", page)

    def test_psychology_draft_links_to_verified_sources_in_preview(self):
        output = self.root / "preview"
        site.build(self.manifest(self.data), output, ORIGIN, APP, preview=True)
        page = (output / "clep-psychology-study-roadmap" / "index.html").read_text()
        self.assertIn("approximately 95 questions", page)
        self.assertIn("13 areas", page)
        self.assertIn("Original sources and next steps", page)
        self.assertIn('href="https://clep.collegeboard.org/clep-exams/introductory-psychology"', page)
        self.assertIn('rel="noopener noreferrer"', page)
        self.assertIn('content="noindex,nofollow"', page)

    def test_unsafe_source_url_is_rejected_by_renderer(self):
        data = self.approved()
        data["pages"][0]["review"]["sources"] = ["https://user:pass@example.test/path"]
        with self.assertRaisesRegex(ValueError, "Unsafe public source"):
            site.build(self.manifest(data), self.root / "published", ORIGIN, APP)

    def test_manual_emergency_artifact_excludes_all_drafts_and_sitemap(self):
        output = self.root / "emergency"
        site.build_emergency(output, ORIGIN)
        home = (output / "index.html").read_text()
        self.assertIn('content="noindex,nofollow"', home)
        self.assertIn("Public guides temporarily unavailable", home)
        self.assertNotIn("CLEP Introductory Psychology", home)
        self.assertNotIn("Learn with a clear path", home)
        self.assertFalse((output / "clep-psychology-study-roadmap").exists())
        self.assertEqual((output / "robots.txt").read_text(),
                         "User-agent: *\nDisallow: /\n")
        self.assertNotIn("<url>", (output / "sitemap.xml").read_text())
        with self.assertRaisesRegex(ValueError, "must be empty"):
            site.build_emergency(output, ORIGIN)

    def test_nonempty_output_is_never_replaced(self):
        out = self.root / "occupied"
        out.mkdir()
        (out / "important.txt").write_text("safe")
        with self.assertRaisesRegex(ValueError, "must be empty"):
            site.build(self.manifest(self.approved()), out, ORIGIN, APP)
        self.assertEqual((out / "important.txt").read_text(), "safe")

    def test_real_local_http_returns_200_for_published_and_404_for_drafts(self):
        out = self.root / "published"
        site.build(self.manifest(self.approved()), out, ORIGIN, APP)

        class QuietHandler(http.server.SimpleHTTPRequestHandler):
            def log_message(self, fmt, *args):
                pass

        handler = functools.partial(QuietHandler, directory=str(out))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            host = "http://127.0.0.1:" + str(server.server_port)
            with urllib.request.urlopen(host + "/how-it-works/") as response:
                self.assertEqual(response.status, 200)
                self.assertIn(b"<h1>How LearningApp works</h1>", response.read())
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(host + "/clep-psychology-study-roadmap/")
            self.assertEqual(error.exception.code, 404)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
