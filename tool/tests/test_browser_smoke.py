"""Real-browser guest smoke journeys against a built Flutter web release (plan PR-7, §10 F).

Run against a locally served ``flutter build web --release`` built from
``.env.example`` (placeholder backend, no credentials):

    E2E_BASE_URL=http://127.0.0.1:8765/ python -m pytest tool/tests/test_browser_smoke.py -v

Selectors use the Flutter web accessibility tree (``main.dart`` calls
``SemanticsBinding.instance.ensureSemantics()``), i.e. the same roles and
names a screen reader gets, never canvas coordinates or engine internals.

Every test also enforces two browser-wide guards:

* no uncaught page error, and
* every request goes to an allow-listed host: the app itself, the
  configured Supabase host, and Flutter's own engine/font CDNs. A guest
  session must never contact analytics, AI providers or other third parties.

Journey 2 of the plan (create a lesson as a signed-in learner and read it
back after reload) needs authentication against a local backend and is an
explicit, documented gap here; the database job's
``lesson_import_local_supabase_test.dart`` proves create/readback at the
service layer. This file checks only that a guest save fails closed.
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from urllib.parse import urlparse

import pytest
from playwright.sync_api import Page, expect, sync_playwright

BASE_URL = os.environ.get("E2E_BASE_URL", "")
ARTIFACT_DIR = Path(os.environ.get("E2E_ARTIFACT_DIR", "build/e2e-artifacts"))
FLUTTER_CDN_HOSTS = {"www.gstatic.com", "fonts.gstatic.com"}
VIEWPORT = {"width": 1280, "height": 800}  # >= 900dp: NavigationRail layout
APP_READY_TIMEOUT_MS = 45_000

expect.set_options(timeout=15_000)


def _supabase_host(env_text: str) -> str | None:
    for line in env_text.splitlines():
        if line.strip().startswith("SUPABASE_URL="):
            return urlparse(line.split("=", 1)[1].strip()).hostname
    return None


@pytest.fixture(scope="module")
def browser():
    if not BASE_URL:
        pytest.fail("E2E_BASE_URL is not set; serve build/web and point E2E_BASE_URL at it")
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        yield browser
        browser.close()


@pytest.fixture(scope="module")
def allowed_hosts(browser) -> set[str]:
    page = browser.new_page()
    try:
        response = page.request.get(BASE_URL.rstrip("/") + "/assets/.env")
        assert response.ok, f"could not read the served .env asset ({response.status})"
        supabase = _supabase_host(response.text())
    finally:
        page.close()
    assert supabase, "served .env has no SUPABASE_URL"
    return {urlparse(BASE_URL).hostname, supabase} | FLUTTER_CDN_HOSTS


@pytest.fixture
def page(browser, allowed_hosts, request):
    """Fresh guest (empty storage) per test, with page-error and host guards."""
    context = browser.new_context(viewport=VIEWPORT)
    hosts: set[str] = set()
    errors: list[str] = []
    context.on("request", lambda req: hosts.add(urlparse(req.url).hostname or req.url))
    page = context.new_page()
    page.on("pageerror", lambda exc: errors.append(str(exc)))
    failed_before = request.session.testsfailed
    yield page
    if request.session.testsfailed > failed_before:
        # Failure evidence only; synthetic guest data, nothing sensitive.
        ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(ARTIFACT_DIR / f"{request.node.name}.png"), full_page=True)
    context.close()
    unexpected = sorted(h for h in hosts if h not in allowed_hosts and not h.startswith("data:"))
    assert not unexpected, f"guest session contacted non-allow-listed hosts: {unexpected}"
    assert not errors, f"uncaught page errors: {errors}"


def open_app(page: Page, route: str = "/learn", *, reload: bool = False) -> None:
    page.goto(f"{BASE_URL.rstrip('/')}/#{route}")
    if reload:
        page.reload()  # a hash-only goto keeps the running app; force a cold start
    page.get_by_role("button", name="Help").wait_for(timeout=APP_READY_TIMEOUT_MS)


def expect_route(page: Page, route: str) -> None:
    page.wait_for_function("r => location.hash === '#' + r", arg=route)


def announced(page: Page, pattern):
    """Text a screen reader announces: plain text or an accessible name."""
    return page.get_by_text(pattern).or_(page.get_by_label(pattern)).first


def rail(page: Page, label: str):
    # NavigationRail destinations: "Library\nTab 2 of 3"
    return page.get_by_role("button", name=re.compile(rf"^{label}\b"))


def test_guest_navigation_and_explicit_pre_reader_routing(page: Page):
    open_app(page)
    expect_route(page, "/learn")
    expect(rail(page, "Learn")).to_have_attribute("aria-current", "true")

    # Ordinary navigation: every primary destination, Help always reachable,
    # and nothing diverts a guest into the literacy track uninvited.
    for label, route in [("Library", "/library"), ("Progress", "/progress"), ("Learn", "/learn")]:
        rail(page, label).click()
        expect_route(page, route)
        expect(rail(page, label)).to_have_attribute("aria-current", "true")
        expect(page.get_by_role("button", name="Help")).to_be_visible()

    # Explicit pre-reader entry: a path must be chosen before starting.
    page.get_by_role("button", name=re.compile("Start with Pictures")).click()
    start = page.get_by_role("button", name=re.compile("Start Learning"))
    expect(start).to_have_attribute("aria-disabled", "true")
    expect(page.get_by_role("button", name="Pause spoken guidance")).to_be_attached()
    page.get_by_role("button", name=re.compile("Adult Learning")).click()
    expect(start).not_to_have_attribute("aria-disabled", "true")
    start.click()
    expect_route(page, "/literacy")

    # The choice persists in browser storage across a full reload, Learn
    # offers to continue it, and ordinary navigation is not hijacked.
    open_app(page, "/learn", reload=True)
    expect_route(page, "/learn")
    expect(page.get_by_text("Foundational Literacy (Adult)").first).to_be_visible()
    expect(page.get_by_role("button", name=re.compile("Continue with Pictures"))).to_be_visible()
    rail(page, "Library").click()
    expect_route(page, "/library")


def test_guest_goal_save_fails_closed(page: Page):
    open_app(page)
    page.get_by_role("button", name=re.compile("Create your own")).click()
    expect(page.get_by_text("Create Learning Goal")).to_be_visible()
    # Flutter web text fields take real key events, not a DOM value fill.
    page.get_by_role("textbox", name=re.compile("Title or Target Role")).click()
    page.keyboard.type("E2E synthetic goal")
    page.get_by_role("button", name="Create Goal").click()
    # No backend session: an honest error, the dialog stays open, no fake success.
    expect(page.get_by_text(re.compile("Could not save a private goal"))).to_be_visible()
    expect(page.get_by_text("Create Learning Goal")).to_be_visible()


GATED_ROUTES = [
    ("/admin/features", "Administrator access required"),
    ("/admin/analytics", "administrative permission required"),
    ("/moderation", 'must have the "moderator" or "admin" role'),
    ("/observability", 'must have the "admin" role'),
    ("/moderation/contributions", "Only moderators and admins can review contributions"),
]


@pytest.mark.parametrize("route,message", GATED_ROUTES, ids=[r for r, _ in GATED_ROUTES])
def test_guest_deep_link_to_protected_console_is_denied(page: Page, route: str, message: str):
    page.goto(f"{BASE_URL.rstrip('/')}/#{route}")
    expect(announced(page, re.compile(re.escape(message)))).to_be_visible(timeout=APP_READY_TIMEOUT_MS)
    expect_route(page, route)
    # Denied consoles expose no management controls.
    for role in ("switch", "checkbox", "slider", "textbox"):
        expect(page.get_by_role(role)).to_have_count(0)


def test_guest_deep_link_to_official_simulation_requires_registration(page: Page):
    page.goto(f"{BASE_URL.rstrip('/')}/#/target/e2e-target/simulation/e2e-version")
    expect(announced(page, re.compile("Registered Account Required"))).to_be_visible(
        timeout=APP_READY_TIMEOUT_MS)
    expect(announced(page, re.compile("Anonymous guest sessions are not eligible"))).to_be_visible()
    expect(page.get_by_role("button", name=re.compile(r"^Sign In .{1,3} Register"))).to_be_visible()
    expect(page.get_by_role("button", name=re.compile(r"\b(Start|Begin)\b.*(exam|simulation|attempt)", re.I))).to_have_count(0)
