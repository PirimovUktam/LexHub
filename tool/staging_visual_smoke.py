"""Local staging browser regression, 2026-09-20; not a Production/remote UI check.

Uses a disposable ordinary account supplied by the caller, who must delete it
afterwards. No storage state, tokens, passwords, HAR or console text are saved.
The real AI success and an injected HTTP 503 fallback are checked separately.
"""

import json
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
from threading import Thread
import os
from pathlib import Path
import re
from urllib.parse import urlsplit

from playwright.sync_api import expect, sync_playwright

from web_first_paint_probe import INIT_JS

STAGING_URL = "https://hzefvtfnsnqxihyygwtp.supabase.co"
AI_PATH = "/functions/v1/legal-ai"
AI_BADGE = "Server AI modeli tahlili"
FALLBACK_BADGE = "AI EMAS: qurilmadagi tekshirilgan qonun bazasi asosida"
LOADING = re.compile(
    r"^(Qonunchilik bazasidan moddalar qidirilmoqda|Lex\.uz me'yoriy hujjatlari taqqoslanmoqda|"
    r"Protsessual muddatlar va xavflar baholanmoqda|Oddiy tildagi xulosa va harakatlar rejasi tayyorlanmoqda)\.\.\.$"
)
# This staging corpus contains reviewed article 560; article 161 is absent.
# Success must use a server-verified source, not an untrusted client-only chunk.
QUERY = "Ishga tiklash nizosi bo'yicha sudga murojaat qilish muddati qanday? Mehnat kodeksining 560-moddasi haqida tushuntiring."


def main():
    email = os.environ.get("LEXHUB_TEST_EMAIL", "")
    password = os.environ.get("LEXHUB_TEST_PASSWORD", "")
    if not email or not password:
        raise SystemExit("Disposable staging test account environment is required")
    if os.environ.get("LEXHUB_STAGING_URL") != STAGING_URL:
        raise SystemExit("Refusing an unpinned staging backend")
    out = Path("build/staging_visual")
    out.mkdir(parents=True, exist_ok=True)
    (out / "results.json").unlink(missing_ok=True)
    state = {"flow": "initial_load", "inject_503": False, "injected": 0}
    results, ai_responses, auth_responses = [], [], []
    failed_requests, console_errors, page_errors, blocked = [], [], [], []
    ai_requests = []
    http_errors = []

    def passed(name):
        results.append(name)
        print(json.dumps({"flow": name, "status": "PASS"}), flush=True)

    def route_request(route):
        request = route.request
        url = urlsplit(request.url)
        allowed = {"127.0.0.1", urlsplit(STAGING_URL).hostname,
                   "www.gstatic.com", "fonts.gstatic.com", "fonts.googleapis.com"}
        if url.hostname not in allowed:
            blocked.append(url.hostname)
            route.abort()
        elif url.path == AI_PATH and request.method == "POST":
            ai_requests.append(bool(request.headers.get("authorization")))
            if state["inject_503"]:
                state["injected"] += 1
                route.fulfill(status=503, content_type="application/json",
                              body=json.dumps({"error": {"code": "ai_not_configured"}}))
            else:
                route.continue_()
        else:
            route.continue_()

    def response_received(response):
        path = urlsplit(response.url).path
        if response.status >= 400:
            expected = (path == AI_PATH and response.request.method == "POST"
                        and state["inject_503"] and response.status == 503)
            http_errors.append({"path": path, "status": response.status, "expected": expected})
        if path == AI_PATH and response.request.method == "POST":
            body = response.json()
            ai_responses.append({"status": response.status, "source": body.get("source"),
                                 "code": body.get("error", {}).get("code")})
        if path in ("/auth/v1/token", "/auth/v1/logout"):
            auth_responses.append({"path": path, "status": response.status})

    rules = json.loads(Path('vercel.json').read_text(encoding='utf-8'))['headers']

    class PreviewHandler(SimpleHTTPRequestHandler):
        def end_headers(self):
            for rule in rules:
                if rule['source'] in ('/(.*)', urlsplit(self.path).path):
                    for header in rule['headers']:
                        self.send_header(header['key'], header['value'])
            super().end_headers()

        def log_message(self, *_args):
            pass

    with ThreadingHTTPServer(('127.0.0.1', 0),
            partial(PreviewHandler, directory='build/web')) as server, sync_playwright() as playwright:
        Thread(target=server.serve_forever, daemon=True).start()
        local_url = 'http://127.0.0.1:' + str(server.server_address[1])
        browser = playwright.chromium.launch()
        context = browser.new_context(viewport={"width": 1280, "height": 900})
        context.route("**/*", route_request)
        page = context.new_page()
        page.add_init_script(INIT_JS + "\nwindow.addEventListener('flutter-first-frame', () => document.documentElement.setAttribute('data-first-frame', 'ready'));")
        page.on("response", response_received)
        page.on("requestfailed", lambda request: failed_requests.append(urlsplit(request.url).path))
        page.on("pageerror", lambda error: page_errors.append(type(error).__name__))
        page.on("console", lambda message: console_errors.append(
            state["inject_503"] and "503" in message.text
        ) if message.type == "error" else None)

        def replace_text(field, value):
            # Flutter's semantic input can retain its editing selection across
            # rebuilds. Use the same select/replace path as a keyboard user.
            field.click()
            field.press("Control+A")
            page.keyboard.insert_text(value)
            expect(field).to_have_value(value)

        try:
            initial = page.goto(local_url, wait_until="domcontentloaded")
            assert initial is not None
            assert "frame-ancestors 'none'" in initial.headers.get('content-security-policy', '')
            assert initial.headers.get('x-content-type-options') == 'nosniff'
            assert initial.headers.get('cache-control') == 'no-store'
            expect(page.locator('html')).to_have_attribute('data-first-frame', 'ready', timeout=90000)
            page.locator("flt-semantics-placeholder").dispatch_event("click")
            expect(page.get_by_role("button", name="Bosh sahifa", exact=True)).to_be_visible()
            page.screenshot(path=str(out / "01-home-desktop.png"))
            passed("initial_load")

            state["flow"] = "main_navigation"
            for tab, heading in [("Hamjamiyat", "Fuqarolar va Advokatlar minbari"),
                                 ("Xizmatlar", "Davlat xizmatlari va Qo'llanmalar"),
                                 ("Kabinet", "Shaxsiy Kabinet")]:
                page.get_by_role("button", name=tab, exact=True).click()
                expect(page.get_by_role("heading", name=heading, exact=True)).to_be_visible()
            passed("main_navigation")

            state["flow"] = "login_validation"
            page.get_by_role("button", name="Tizimga kirish / Ro'yxatdan o'tish", exact=True).click()
            page.screenshot(path=str(out / "02-login.png"))
            page.get_by_role("button", name="Tizimga kirish", exact=True).click()
            expect(page.get_by_text("Email manzilini kiriting", exact=True).last).to_be_visible()
            expect(page.get_by_role("textbox")).to_have_count(2)
            email_field = page.get_by_role("textbox").nth(0)
            password_field = page.get_by_role("textbox").nth(1)
            replace_text(email_field, "invalid-email")
            page.get_by_role("button", name="Tizimga kirish", exact=True).click()
            expect(page.get_by_text("To'g'ri email formatini kiriting", exact=True).last).to_be_visible()
            assert not auth_responses
            passed("login_form_validation")

            state["flow"] = "password_visibility"
            page.get_by_role("button", name="Parolni ko'rsatish", exact=True).click()
            page.mouse.move(0, 0)
            expect(password_field).to_have_attribute("type", "text")
            expect(page.get_by_role("button", name="Parolni yashirish", exact=True)).to_be_visible()
            page.get_by_role("button", name="Parolni yashirish", exact=True).click()
            page.mouse.move(0, 0)
            expect(password_field).to_have_attribute("type", "password")
            expect(page.get_by_role("button", name="Parolni ko'rsatish", exact=True)).to_be_visible()
            passed("password_visibility_accessible_labels")

            state["flow"] = "real_login"
            replace_text(email_field, email)
            replace_text(password_field, password)
            with page.expect_response(lambda r: urlsplit(r.url).path == '/auth/v1/token'
                                      and r.request.method == 'POST', timeout=30000) as login_response:
                page.get_by_role("button", name="Tizimga kirish", exact=True).click()
            assert login_response.value.status == 200
            expect(page.get_by_role("button", name="Tizimga kirish", exact=True)).to_have_count(0)
            expect(page.get_by_role("button", name="Kabinet", exact=True)).to_be_visible(timeout=30000)
            assert {"path": "/auth/v1/token", "status": 200} in auth_responses
            passed("real_login")

            state["flow"] = "legal_input_validation"
            page.get_by_role("button", name="Maslahat", exact=True).click()
            expect(page.get_by_role("textbox")).to_have_count(1)
            field = page.get_by_role("textbox").first
            submit = page.get_by_role("button", name="Huquqiy tahlil olish", exact=True)
            submit.click()
            expect(page.get_by_text("Iltimos, huquqiy savol yoki vaziyatingizni yozing.", exact=True).last).to_be_visible()
            assert not ai_requests
            passed("legal_input_validation")

            state["flow"] = "real_ai_success"
            replace_text(field, QUERY)
            submit.click()
            expect(page.get_by_text(LOADING, exact=True)).to_be_visible(timeout=15000)
            page.screenshot(path=str(out / "03-ai-loading.png"))
            passed("ai_loading")
            expect(page.get_by_text(AI_BADGE, exact=True)).to_be_visible(timeout=75000)
            assert ai_responses[-1] == {"status": 200, "source": "llm", "code": None}
            assert ai_requests == [True]
            page.get_by_text(AI_BADGE, exact=True).scroll_into_view_if_needed()
            page.screenshot(path=str(out / "04-ai-success.png"))
            passed("authenticated_ai_success")

            state["flow"] = "ai_error_fallback"
            state["inject_503"] = True
            replace_text(field, QUERY + " Sinov: xizmat vaqtincha mavjud emas.")
            submit.click()
            expect(page.get_by_text(FALLBACK_BADGE, exact=True)).to_be_visible(timeout=30000)
            expect(page.get_by_text(AI_BADGE, exact=True)).to_have_count(0)
            assert state["injected"] == 1
            assert ai_responses[-1]["status"] == 503
            page.get_by_text(FALLBACK_BADGE, exact=True).scroll_into_view_if_needed()
            page.screenshot(path=str(out / "05-ai-error-fallback.png"))
            passed("injected_ai_503_honest_fallback")
            state["inject_503"] = False

            state["flow"] = "logout"
            page.get_by_role("button", name="Kabinet", exact=True).click()
            page.get_by_role("button", name="Tizimdan chiqish", exact=True).click()
            expect(page.get_by_role("button", name="Tizimdan chiqish", exact=True)).to_have_count(0)
            page.get_by_role("button", name="Kabinet", exact=True).click()
            expect(page.get_by_text("Hisobingizga kiring", exact=True)).to_be_visible(timeout=30000)
            assert any(x["path"] == "/auth/v1/logout" and x["status"] in (200, 204) for x in auth_responses)
            passed("logout")

            state["flow"] = "unauthorized_protection"
            before = len(ai_requests)
            page.get_by_role("button", name="Maslahat", exact=True).click()
            replace_text(field, QUERY + " Sinov: mehmon rejimi.")
            submit.click()
            expect(page.get_by_text(FALLBACK_BADGE, exact=True)).to_be_visible(timeout=30000)
            expect(page.get_by_text("AI tahlili uchun tizimga kiring", exact=True)).to_be_visible()
            assert len(ai_requests) == before
            unauthorized = context.request.post(STAGING_URL + AI_PATH, data={"query_text": "Staging smoke"})
            assert unauthorized.status == 401
            passed("guest_no_ai_request_and_server_401")

            state["flow"] = "mobile_viewport"
            page.get_by_role("button", name="Bosh sahifa", exact=True).click()
            page.set_viewport_size({"width": 390, "height": 844})
            expect(page.get_by_role("button", name="Kabinet", exact=True)).to_be_visible()
            page.screenshot(path=str(out / "06-home-mobile.png"))
            passed("mobile_viewport")
            for width, height in [(320, 568), (360, 800), (390, 844), (430, 932),
                                  (768, 1024), (820, 1180), (1024, 768),
                                  (1280, 720), (1440, 900), (1920, 1080)]:
                page.set_viewport_size({"width": width, "height": height})
                for tab, marker in [("Bosh sahifa", "Huquqingizni biling,"),
                                    ("Maslahat", "Huquqiy vaziyatingizni yozing"),
                                    ("Hamjamiyat", "Fuqarolar va Advokatlar minbari"),
                                    ("Xizmatlar", "Davlat xizmatlari va Qo'llanmalar"),
                                    ("Kabinet", "Shaxsiy Kabinet")]:
                    state["flow"] = f"viewport_{width}_{height}_{tab}"
                    page.get_by_role("button", name=tab, exact=True).click()
                    expect(page.get_by_text(marker, exact=(tab != "Bosh sahifa")).first).to_be_visible()
                    page.mouse.move(width - 1, height - 1)
                    # Let Flutter rasterize resized fonts and loaded images.
                    page.wait_for_timeout(180)
                    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                    page.screenshot(path=str(out / f"viewport-{width}-{height}-{tab}.png"))
                # The cabinet tabs retain their original order and routes.
                for label in ["Konstruktor", "Oflayn Keyslar", "Konsultatsiyalar", "Profil"]:
                    state["flow"] = f"viewport_{width}_{height}_{label}"
                    page.get_by_role("tab", name=label, exact=True).click()
                    page.wait_for_timeout(250)
                    page.screenshot(path=str(out / f"viewport-{width}-{height}-{label}.png"))
                page.get_by_role("button", name="Tizimga kirish / Ro'yxatdan o'tish", exact=True).click()
                expect(page.get_by_role("textbox")).to_have_count(2)
                page.screenshot(path=str(out / f"viewport-{width}-{height}-login.png"))
                state["flow"] = f"viewport_{width}_{height}_register"
                page.get_by_role("button", name="Ro'yxatdan o'ting", exact=True).click()
                expect(page.get_by_role("textbox")).to_have_count(4)
                page.get_by_role("button", name="Ro'yxatdan o'tish", exact=True).click()
                expect(page.get_by_text("Ism-sharifingizni kiriting", exact=True).last).to_be_visible()
                # Capture error text after InputDecorator's fade animation.
                page.wait_for_timeout(350)
                page.screenshot(path=str(out / f"viewport-{width}-{height}-register.png"))
                page.get_by_role("button", name="Kirish", exact=True).click()
                page.get_by_role("button", name="Mehmon sifatida davom etish", exact=True).click()
                passed(f"viewport_{width}x{height}_main_auth_cabinet")
            page.set_viewport_size({"width": 390, "height": 844})
            page.get_by_role("button", name="Kabinet", exact=True).click()
            page.get_by_role("button", name="Sozlamalar", exact=True).click()
            state["flow"] = "settings_language_navigation"
            expect(page.get_by_role("button", name=re.compile(r"^Ilova tili"))).to_be_visible()
            page.screenshot(path=str(out / "07-settings-mobile.png"))
            page.get_by_role("button", name=re.compile(r"^Ilova tili")).click()
            page.screenshot(path=str(out / "08-language-mobile.png"))
            for width, height in [(320, 568), (360, 800), (390, 844), (430, 932),
                                  (768, 1024), (820, 1180), (1024, 768),
                                  (1280, 720), (1440, 900), (1920, 1080)]:
                page.set_viewport_size({"width": width, "height": height})
                page.screenshot(path=str(out / f"viewport-{width}-{height}-language.png"))
            passed("settings_language_navigation")
            page.emulate_media(color_scheme="dark")
            page.wait_for_timeout(350)
            page.screenshot(path=str(out / "09-language-dark.png"))
            passed("system_dark_theme")
            assert not blocked and not failed_requests and not page_errors
            assert all(error["expected"] for error in http_errors), "Unexpected HTTP errors"
            assert all(console_errors), "Unexpected browser console errors"
            passed("no_unexpected_console_or_network_errors")
            report = {"status": "PASS", "flows": results, "ai_responses": ai_responses,
                      "expected_503_console_errors": len(console_errors), "unexpected_errors": 0}
            report["http_errors"] = http_errors
            (out / "results.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
            return 0
        except Exception as error:
            page.screenshot(path=str(out / "failure.png"))
            print(json.dumps({"status": "FAIL", "flow": state["flow"],
                              "exception": type(error).__name__, "initial_error": str(error).splitlines()[0][:450] if state["flow"] == "initial_load" else None, "ai_responses": ai_responses,
                              "auth_responses": auth_responses,
                              "http_errors": http_errors,
                              "blocked_hosts": blocked, "failed_paths": failed_requests,
                              "page_error_count": len(page_errors)}), flush=True)
            return 1
        finally:
            context.close()
            browser.close()
            server.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
