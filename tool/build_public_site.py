#!/usr/bin/env python3
"""Dependency-free, offline static public LearningApp website builder.

No Supabase credentials, learner records, AI calls, remote content or network.
Editorial material is DRAFT until an explicit approved publication record is
provided. Preview output is universally noindex and may never be deployed.
"""
from __future__ import annotations

import argparse
import html
import json
import re
from datetime import date
from pathlib import Path
from urllib.parse import urlsplit
from xml.sax.saxutils import escape as xml_escape

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "public_site" / "content" / "pages.json"
CSS = ROOT / "public_site" / "assets" / "site.css"
VALID_TYPES = {"home", "guide", "about", "standards"}
RESERVED = {"admin", "api", "auth", "login", "settings", "account", "drafts"}
SLUG_PATTERN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*(?:/[a-z0-9]+(?:-[a-z0-9]+)*)*")


def canonical_origin(value: str) -> str:
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password
            or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
        raise ValueError("Origin must be an HTTPS site root without credentials, path, query, or fragment")
    if not re.fullmatch(r"[a-zA-Z0-9.-]+(?::[0-9]{2,5})?", parsed.netloc):
        raise ValueError("Invalid origin host")
    return value.rstrip("/")


def load_manifest(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("Unsupported editorial manifest version")
    pages = payload.get("pages")
    if not isinstance(pages, list) or not pages:
        raise ValueError("Editorial manifest requires pages")
    slugs: set[str] = set()
    for page in pages:
        if not isinstance(page, dict):
            raise ValueError("Each page must be an object")
        slug = page.get("slug")
        if not isinstance(slug, str) or (slug and not SLUG_PATTERN.fullmatch(slug)):
            raise ValueError("Invalid page slug")
        if slug in slugs or any(part in RESERVED for part in slug.split("/")):
            raise ValueError("Duplicate or reserved page slug")
        slugs.add(slug)
        if page.get("status") not in ("draft", "published") or page.get("type") not in VALID_TYPES:
            raise ValueError("Invalid status/type")
        for key in ("title", "description", "heading", "summary"):
            if not isinstance(page.get(key), str) or not page[key].strip():
                raise ValueError("Missing required public text: " + key)
        sections = page.get("sections")
        if not isinstance(sections, list) or not sections:
            raise ValueError("Each page needs substantive sections")
        for section in sections:
            if not isinstance(section, dict) or not isinstance(section.get("heading"), str) or not section["heading"].strip():
                raise ValueError("Section heading required")
            paragraphs = section.get("paragraphs")
            if not isinstance(paragraphs, list) or not paragraphs or any(not isinstance(p, str) or not p.strip() for p in paragraphs):
                raise ValueError("Sections require plain text paragraphs")
        if page["status"] == "published":
            review = page.get("review")
            if not isinstance(review, dict) or review.get("owner_approved") is not True:
                raise ValueError("Published page missing explicit owner approval")
            try:
                date.fromisoformat(review["reviewed_at"])
            except (ValueError, TypeError, KeyError):
                raise ValueError("Published page needs an ISO review date") from None
            if not isinstance(review.get("sources"), list) or not review["sources"]:
                raise ValueError("Published page must have a review evidence reference")
    return pages


def path_for(slug: str) -> str:
    return "/" if not slug else "/" + slug + "/"


def text(value: str) -> str:
    return html.escape(value, quote=True)


def json_ld(value: dict) -> str:
    # Escape all script-end openers even for manually reviewed source content.
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")


def render_page(page: dict, pages: list[dict], origin: str, app_origin: str, preview: bool) -> str:
    slug = page["slug"]
    url = origin + path_for(slug)
    is_home = slug == ""
    nav = "".join(
        '<a href="' + text(path_for(p["slug"])) + '">' + text(p["heading"]) + "</a>"
        for p in pages if p["slug"] in ("", "how-it-works", "review-standards", "about")
    )
    sections = "".join(
        "<section><h2>" + text(s["heading"]) + "</h2>"
        + "".join("<p>" + text(p) + "</p>" for p in s["paragraphs"])
        + "</section>"
        for s in page["sections"]
    )
    # Editorial evidence links are supplied as owner-review source references.
    # Internal repository filenames are audit evidence, not web links.
    external_sources = [
        source for source in page.get("review", {}).get("sources", [])
        if isinstance(source, str) and source.startswith("https://")
    ]
    for source in external_sources:
        parsed = urlsplit(source)
        if (parsed.scheme != "https" or not parsed.hostname or parsed.username
                or parsed.password or parsed.fragment or parsed.query
                or not re.fullmatch(r"[a-zA-Z0-9.-]+", parsed.hostname)):
            raise ValueError("Unsafe public source reference")
    if external_sources:
        sections += (
            "<section><h2>Original sources and next steps</h2><ul class=\"resource-links\">"
            + "".join(
                '<li><a rel="noopener noreferrer" href="' + text(source)
                + '">' + text(urlsplit(source).hostname or source) + "</a></li>"
                for source in external_sources
            )
            + "</ul></section>"
        )
    app_link = app_origin + "/#/learn"
    breadcrumbs = [] if is_home else [{
        "@type": "ListItem", "position": 1, "name": "Home", "item": origin + "/"
    }, {
        "@type": "ListItem", "position": 2, "name": page["heading"], "item": url
    }]
    structured = [{
        "@context": "https://schema.org",
        "@type": "WebPage",
        "name": page["title"],
        "url": url,
        "description": page["description"],
    }]
    if is_home:
        structured.append({
            "@context": "https://schema.org",
            "@type": "WebSite", "name": "LearningApp", "url": origin + "/"
        })
    else:
        structured.append({
            "@context": "https://schema.org",
            "@type": "BreadcrumbList", "itemListElement": breadcrumbs
        })
    robots = "noindex,nofollow" if preview else "index,follow"
    preview_banner = ('<p class="preview" role="status">Draft preview — not indexed or approved for release</p>'
                      if preview else "")
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="{robots}">
<meta name="referrer" content="strict-origin-when-cross-origin">
<title>{text(page["title"])}</title>
<meta name="description" content="{text(page["description"])}">
<link rel="canonical" href="{text(url)}">
<meta property="og:type" content="website">
<meta property="og:title" content="{text(page["title"])}">
<meta property="og:description" content="{text(page["description"])}">
<meta property="og:url" content="{text(url)}">
<meta name="twitter:card" content="summary">
<link rel="stylesheet" href="/assets/site.css">
<script type="application/ld+json">{json_ld(structured)}</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="site-header"><div class="wrap">
<a class="wordmark" href="/">LearningApp</a>
<nav aria-label="Main navigation">{nav}</nav>
<a class="app-link" href="{text(app_link)}">Open LearningApp</a>
</div></header>
<main id="main" class="wrap">
{preview_banner}
<p class="eyebrow">Independent learning guidance</p>
<h1>{text(page["heading"])}</h1>
<p class="lead">{text(page["summary"])}</p>
{sections}
<p class="cta"><a href="{text(app_link)}">Go to Learn in LearningApp</a></p>
</main>
<footer><div class="wrap"><p>LearningApp provides learning tools, not official exam or licensing decisions. Verify requirements with the relevant issuer.</p>
<p>No advertising or tracking scripts are used on these static pages.</p></div></footer>
</body>
</html>
"""


def build(manifest: Path, output: Path, origin: str, app_origin: str, preview: bool = False) -> int:
    origin = canonical_origin(origin)
    app_origin = canonical_origin(app_origin)
    pages = load_manifest(manifest)
    selected = pages if preview else [p for p in pages if p["status"] == "published"]
    if not preview and (not selected or not any(p["slug"] == "" for p in selected)):
        raise ValueError("No owner-approved published homepage; refusing public build")
    if preview and not any(p["slug"] == "" for p in selected):
        raise ValueError("Preview requires a homepage")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Output directory must be empty (no destructive cleanup)")
    output.mkdir(parents=True, exist_ok=True)
    (output / "assets").mkdir(exist_ok=True)
    (output / "assets" / "site.css").write_text(CSS.read_text(encoding="utf-8"), encoding="utf-8")
    for page in selected:
        slug = page["slug"]
        target = output / slug / "index.html" if slug else output / "index.html"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render_page(page, selected, origin, app_origin, preview), encoding="utf-8")
    sitemap_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    if not preview:
        for page in selected:
            sitemap_lines.append("  <url><loc>" + xml_escape(origin + path_for(page["slug"])) + "</loc></url>")
    sitemap_lines.append("</urlset>")
    (output / "sitemap.xml").write_text("\n".join(sitemap_lines) + "\n", encoding="utf-8")
    robots = ("User-agent: *\nDisallow: /\n" if preview
              else "User-agent: *\nAllow: /\nSitemap: " + origin + "/sitemap.xml\n")
    (output / "robots.txt").write_text(robots, encoding="utf-8")
    (output / "404.html").write_text("""<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="robots" content="noindex,nofollow">
<title>Page not found | LearningApp</title><meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="/assets/site.css"></head><body><main class="wrap">
<h1>Page not found</h1><p>This guide may have moved or is not published.</p>
<a href="/">Go to LearningApp guides</a></main></body></html>""", encoding="utf-8")
    return len(selected)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--origin", required=True, help="Approved HTTPS canonical public-site root")
    parser.add_argument("--app-origin", default="https://app.learningapp.io",
                        help="Existing LearningApp host, no path")
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--preview", action="store_true",
                        help="Render unapproved drafts with universal noindex and robots disallow")
    args = parser.parse_args()
    result = build(args.manifest, args.out, args.origin, args.app_origin, args.preview)
    print(f"Generated {result} {'preview' if args.preview else 'published'} pages; no network requests.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
