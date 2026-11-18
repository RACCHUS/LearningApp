"""Registered learner → browser JSON import → reload → persisted lesson readback.

Only runs with the intentionally separate local-Supabase CI build. It does not
mock authentication, use OAuth, or point at any hosted Supabase service.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from uuid import uuid4

from playwright.sync_api import expect, sync_playwright

BASE_URL = os.environ.get("E2E_BASE_URL", "")
API_URL = os.environ.get("LOCAL_SUPABASE_URL", "")
SERVICE_KEY = os.environ.get("LOCAL_SUPABASE_SERVICE_ROLE_KEY", "")
ARTIFACT_DIR = Path(os.environ.get("E2E_ARTIFACT_DIR", "build/e2e-artifacts"))
LOOPBACK = {"127.0.0.1", "localhost", "::1"}
ALLOWED_EXTERNAL = {"www.gstatic.com", "fonts.gstatic.com"}

expect.set_options(timeout=15_000)


def _require_local_configuration() -> None:
    for name, url in (("E2E_BASE_URL", BASE_URL), ("LOCAL_SUPABASE_URL", API_URL)):
        parsed = urlparse(url)
        if parsed.scheme != "http" or parsed.hostname not in LOOPBACK:
            raise AssertionError(f"{name} must be an explicit loopback HTTP address")
    if not SERVICE_KEY:
        raise AssertionError("LOCAL_SUPABASE_SERVICE_ROLE_KEY missing (local admin cleanup required)")


def _admin(path: str, method: str, payload: dict | None = None):
    # Only call after _require_local_configuration. Never print the service key.
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        API_URL.rstrip("/") + path,
        data=data,
        method=method,
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        },
    )
    with urlopen(request, timeout=15) as response:
        body = response.read()
        return json.loads(body) if body else None


def test_registered_learner_import_reload_and_readback():
    _require_local_configuration()
    email = f"browser-it-{uuid4()}@example.test"
    password = f"BrowserIT-{uuid4()}!"
    title = f"Browser persistence {uuid4().hex[:12]}"
    learner_id = None
    page = None
    errors = []
    observed_hosts = set()
    failed = False

    try:
        user = _admin("/auth/v1/admin/users", "POST", {
            "email": email, "password": password, "email_confirm": True,
        })
        learner_id = user["id"]
        # Provision the app's FK-backed profile before the UI write. The
        # normal AuthProvider profile sync still runs after sign-in.
        _admin("/rest/v1/users", "POST", {
            "id": learner_id, "email": email,
        })

        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            context = browser.new_context(viewport={"width": 1280, "height": 800})
            context.on("request", lambda req: observed_hosts.add(urlparse(req.url).hostname or req.url))
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            try:
                page.goto(BASE_URL.rstrip("/") + "/#/login")
                expect(page.get_by_role("textbox", name="Local test email")).to_be_visible(timeout=45_000)
                page.get_by_role("textbox", name="Local test email").click()
                page.keyboard.type(email)
                page.get_by_role("textbox", name="Local test password").click()
                page.keyboard.type(password)
                page.get_by_role("button", name="Sign in to local test account").click()
                expect(page.get_by_role("button", name="Help")).to_be_visible(timeout=45_000)
                page.wait_for_function("location.hash === '#/learn'")

                # Actual widget interaction, production LessonImportService and PostgREST.
                page.goto(BASE_URL.rstrip("/") + "/#/create-lesson?tab=json")
                expect(page.get_by_text("Create New Lesson")).to_be_visible(timeout=45_000)
                payload = {
                    "lesson": {
                        "title": title,
                        "description": "Synthetic registered-browser integration lesson",
                        "tags": ["browser-it"],
                    },
                    "content": [
                        {"type": "term", "term": "Browser Alpha",
                         "definition": "The first persisted browser term"},
                        {"type": "mcq", "question": "Browser question: two plus two?",
                         "options": ["3", "4", "5", "6"], "correct_answer": 1,
                         "explanation": "Two plus two is four."},
                    ],
                }
                page.get_by_role("textbox").first.click()
                page.keyboard.insert_text(json.dumps(payload))
                import_button = page.get_by_role("button", name="Import Lesson")
                expect(import_button).to_be_enabled(timeout=20_000)
                with page.expect_response(
                    lambda response: response.request.method == "POST"
                    and "/rest/v1/lessons" in response.url
                    and 200 <= response.status < 300,
                    timeout=25_000,
                ) as created_response:
                    import_button.click()
                created = created_response.value.json()
                lesson_row = created[0] if isinstance(created, list) else created
                lesson_id = lesson_row["id"]
                assert lesson_row["user_id"] == learner_id, "lesson belongs to a different learner"
                assert lesson_row["visibility"] == "private", "new lesson must be private"

                # Full document reload, not SPA-only route change, followed by
                # a fresh production lesson-provider fetch with the same session.
                page.goto(BASE_URL.rstrip("/") + f"/#/lesson/{lesson_id}")
                page.reload()
                expect(page.get_by_text(title).first).to_be_visible(timeout=45_000)
                expect(page.get_by_text("Private").first).to_be_visible()
                page.get_by_role("button", name="Lesson Mode").click()
                expect(page.get_by_text("Browser Alpha").first).to_be_visible(timeout=30_000)
                page.get_by_role("button", name="Next").click()
                expect(page.get_by_text("Browser question: two plus two?").first).to_be_visible()

                # Independent persisted DB check, not a cached browser object.
                lesson_rows = _admin(f"/rest/v1/lessons?id=eq.{lesson_id}&select=id,user_id,visibility", "GET")
                term_rows = _admin(f"/rest/v1/terms?lesson_id=eq.{lesson_id}&select=term,definition", "GET")
                question_rows = _admin(
                    f"/rest/v1/questions?lesson_id=eq.{lesson_id}&select=question_text,correct_answer,explanation",
                    "GET",
                )
                assert len(lesson_rows) == 1 and lesson_rows[0]["user_id"] == learner_id
                assert term_rows == [{"term": "Browser Alpha", "definition": "The first persisted browser term"}]
                assert len(question_rows) == 1
                assert question_rows[0]["correct_answer"] == 1
                assert question_rows[0]["explanation"] == "Two plus two is four."
                unexpected = observed_hosts - LOOPBACK - ALLOWED_EXTERNAL
                assert not unexpected, f"unexpected browser request hosts: {sorted(unexpected)}"
                assert not errors, f"uncaught page errors: {errors}"
            except BaseException:
                failed = True
                ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
                if page is not None:
                    page.screenshot(path=str(ARTIFACT_DIR / "signed-in-readback.png"), full_page=True)
                raise
            finally:
                context.close()
                browser.close()
    finally:
        if learner_id:
            # Cleanup must run after success or failure. All requests are local,
            # with synthetic records only. Foreign-key children cascade on lesson removal.
            cleanup_errors = []
            for path, method in [
                (f"/rest/v1/lessons?user_id=eq.{learner_id}", "DELETE"),
                (f"/rest/v1/users?id=eq.{learner_id}", "DELETE"),
                (f"/auth/v1/admin/users/{learner_id}", "DELETE"),
            ]:
                try:
                    _admin(path, method)
                except Exception as exc:
                    cleanup_errors.append(type(exc).__name__)
            if cleanup_errors and not failed:
                raise AssertionError(f"local synthetic-user cleanup failed: {cleanup_errors}")
