"""2026-09-22: local Flutter + isolated staging advocate browser acceptance.

Only synthetic data. Credentials and browser state remain in memory. This is
not a production/browser engine coverage claim. Caller owns account cleanup.
"""
from functools import partial
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import traceback
from pathlib import Path
from threading import Thread
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright, expect
from web_first_paint_probe import INIT_JS
from advocate_staging_smoke import BASE, PNG, StagingFixture


def run_browser(f):
    labels = json.loads(Path('lib/l10n/arb/app_uz.arb').read_text(encoding='utf-8'))
    owner, client = f.user(), f.user()
    errors, failures, forbidden, http_errors = [], [], [], []
    saves = []
    phase = {'name': 'startup', 'reload': False, 'inject': False}

    class Handler(SimpleHTTPRequestHandler):
        def end_headers(self):
            for rule in json.loads(Path('vercel.json').read_text())['headers']:
                if rule['source'] in ('/(.*)', urlsplit(self.path).path):
                    for header in rule['headers']:
                        self.send_header(header['key'], header['value'])
            super().end_headers()

        def log_message(self, *_args):
            pass

    with ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory='build/web')) as server, sync_playwright() as pw:
        Thread(target=server.serve_forever, daemon=True).start()
        local = 'http://127.0.0.1:' + str(server.server_address[1])
        browser = pw.chromium.launch()
        contexts = []

        def page_for(user):
            context = browser.new_context(viewport={'width': 1280, 'height': 900})
            contexts.append(context)

            def route(r):
                url = urlsplit(r.request.url)
                if url.hostname not in {'127.0.0.1', urlsplit(BASE).hostname, 'www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'}:
                    forbidden.append('unexpected_host')
                    r.abort()
                elif phase['inject'] and url.path == '/rest/v1/rpc/save_advocate_profile':
                    r.fulfill(status=503, content_type='application/json', body='{"message":"synthetic_unavailable"}')
                else:
                    r.continue_()

            context.route('**/*', route)
            page = context.new_page()
            page.set_default_timeout(15000)
            page.add_init_script(INIT_JS + "\nwindow.addEventListener('flutter-first-frame', () => document.documentElement.setAttribute('data-first-frame','ready'));")
            page.on('pageerror', lambda _: errors.append(phase['name']))
            page.on('console', lambda msg: errors.append(phase['name']) if msg.type == 'error' and not (phase['inject'] and '503' in msg.text) else None)
            page.on('requestfailed', lambda req: failures.append(phase['name']) if not (phase['reload'] and 'ERR_ABORTED' in (req.failure or '')) else None)
            page.on('response', lambda r: http_errors.append((phase['name'], r.status)) if r.status >= 400 and not (phase['inject'] and r.status == 503) else None)
            page.on('response', lambda r: saves.append(r.status) if urlsplit(r.url).path == '/rest/v1/rpc/save_advocate_profile' else None)
            home(page)
            click(page, page.get_by_role('button', name='Kabinet', exact=True))
            click(page, page.get_by_role('button', name="Tizimga kirish / Ro'yxatdan o'tish", exact=True))
            inputs = page.get_by_role('textbox')
            fill(page, inputs.nth(0), user['email'])
            fill(page, inputs.nth(1), user['password'])
            click(page, page.get_by_role('button', name='Tizimga kirish', exact=True))
            expect(page.get_by_role('button', name='Kabinet', exact=True)).to_be_visible(timeout=30000)
            return page

        def home(page):
            phase['reload'] = True
            page.goto(local)
            expect(page.locator('html')).to_have_attribute('data-first-frame', 'ready', timeout=90000)
            placeholder = page.locator('flt-semantics-placeholder')
            if placeholder.count():
                placeholder.dispatch_event('click')
            expect(page.get_by_role('button', name='Kabinet', exact=True)).to_be_visible(timeout=30000)
            page.wait_for_timeout(500)
            phase['reload'] = False

        def seek(page, loc):
            for _ in range(30):
                dx, dy = 0, 260
                width, height = page.viewport_size['width'], page.viewport_size['height']
                pointer_y = height * 3 // 4
                if loc.count() and loc.first.is_visible():
                    box = loc.first.bounding_box()
                    if box and box['width'] > 0 and box['height'] > 0:
                        # Playwright visibility alone accepts offscreen Flutter
                        # semantics. Require the rendered control/content inside
                        # the viewport, below the fixed app bar.
                        if box['y'] < 60:
                            dy = max(-260, box['y'] - 80)
                        elif box['y'] + box['height'] > height - 12:
                            dy = min(260, box['y'] + box['height'] - height + 28)
                        elif box['x'] < 0 or box['x'] + box['width'] > width:
                            pointer_y = box['y'] + box['height'] / 2
                            dx = box['x'] - 12 if box['x'] < 0 else box['x'] + box['width'] - width + 12
                            dy = 0
                        else:
                            return loc.first
                page.mouse.move(width // 2, pointer_y)
                page.mouse.wheel(dx, dy)
                page.wait_for_timeout(150)
            raise AssertionError('browser_control_unavailable_' + phase['name'])

        def click(page, loc):
            seek(page, loc).click()
            page.wait_for_timeout(350)

        def fill(page, loc, value):
            field = seek(page, loc)
            field.click()
            expect(field).to_be_focused()
            page.wait_for_timeout(150)
            field.press('Control+A')
            page.keyboard.insert_text(value)
            page.wait_for_timeout(150)
            expect(field).to_have_value(value)

        def field(page, key):
            return page.get_by_role('textbox', name=labels[key], exact=False)

        def button(page, key):
            return page.get_by_role('button', name=labels[key], exact=True)

        def content(page, value):
            # Cards/ListTiles merge their text in Flutter web semantics. Both
            # representations must still contain the actual expected value.
            return page.get_by_text(value, exact=False).or_(
                page.get_by_label(value, exact=False)).first

        def my_profile(page):
            click(page, page.get_by_role('button', name='Kabinet', exact=True))
            click(page, page.get_by_text(labels['advocateMyProfile'], exact=True))

        def tab(page, key):
            # Flutter ChoiceChip exposes a radio/checkbox depending on SDK.
            page.mouse.move(page.viewport_size['width'] // 2, page.viewport_size['height'] // 2)
            page.mouse.wheel(0, -10000)
            page.wait_for_timeout(250)
            loc = page.get_by_role('radio', name=labels[key], exact=True).or_(
                page.get_by_role('checkbox', name=labels[key], exact=True)).or_(
                page.get_by_role('button', name=labels[key], exact=True)).or_(
                page.get_by_text(labels[key], exact=True))
            click(page, loc.first)

        def saved(page):
            # The persisted response and closed editor are stable acceptance
            # evidence; a short-lived SnackBar is not a synchronization hook.
            with page.expect_response(lambda r: r.request.method in ('POST', 'PATCH')
                    and ('/rest/v1/' in r.url) and '/object/' not in r.url) as response:
                click(page, button(page, 'profileSave'))
            assert response.value.status in (200, 201), 'browser_save_http'
            expect(page.get_by_role('textbox')).to_have_count(0, timeout=30000)

        try:
            phase['name'] = 'owner_create'
            page = page_for(owner)
            my_profile(page)
            click(page, button(page, 'advocateCreate'))
            fill(page, field(page, 'profileFirstName'), 'Synthetic')
            fill(page, field(page, 'profileLastName'), 'BrowserAdvocate')
            fill(page, field(page, 'expertMetricExperience'), '5')
            fill(page, field(page, 'advocateSpecializations'), 'Mehnat')
            fill(page, field(page, 'advocateLanguages'), 'Uzbek, English')
            fill(page, field(page, 'advocateWorkplace'), 'Synthetic office')
            fill(page, field(page, 'profileAddress'), 'Synthetic address')
            fill(page, field(page, 'profileBio'), 'Synthetic browser biography')
            saved(page)
            status, profile = f.rpc('get_my_advocate_profile', owner['token'])
            f.check('browser_create_persisted', status == 200 and profile['full_name'] == 'Synthetic BrowserAdvocate'
                    and profile['bio'] == 'Synthetic browser biography' and not profile['verified'])
            eid = profile['id']
            f.approve_fixture(owner, eid)
            assert f.rpc('save_advocate_profile', owner['token'], {'p_profile': {'is_published': True, 'accepting_clients': True}})[0] == 200
            phase['name'] = 'owner_edit_avatar'
            home(page)
            my_profile(page)
            click(page, button(page, 'profileEditDetails'))
            with page.expect_file_chooser() as chooser:
                click(page, button(page, 'profileChoosePhoto'))
            chooser.value.set_files({'name': 'synthetic.png', 'mimeType': 'image/png', 'buffer': PNG})
            fill(page, field(page, 'profileBio'), 'Synthetic updated browser biography')
            phase['inject'] = True
            click(page, button(page, 'profileSave'))
            expect(page.get_by_text(labels['errorServer'], exact=True)).to_be_visible(timeout=30000)
            f.check('browser_save_failure_keeps_editor', page.get_by_text(labels['advocateSaved'], exact=True).count() == 0)
            phase['inject'] = False
            saved(page)
            profile = f.rpc('get_my_advocate_profile', owner['token'])[1]
            f.check('browser_edit_avatar_persisted', profile['bio'] == 'Synthetic updated browser biography' and bool(profile['avatar_path']))
            phase['name'] = 'owner_service'
            home(page)
            my_profile(page)
            tab(page, 'advocateServices')
            click(page, button(page, 'advocateAdd'))
            fill(page, field(page, 'advocateServiceTitle'), 'Synthetic browser service')
            fill(page, field(page, 'advocateDescription'), 'Synthetic service description')
            fill(page, field(page, 'advocatePrice'), '150000')
            fill(page, field(page, 'advocateDuration'), '30')
            saved(page)
            profile = f.rpc('get_my_advocate_profile', owner['token'])[1]
            f.check('browser_service_create', len(profile['services']) == 1 and profile['services'][0]['title'] == 'Synthetic browser service')
            service_id = profile['services'][0]['id']
            phase['name'] = 'owner_document'
            tab(page, 'advocateDocuments')
            click(page, button(page, 'advocateAdd'))
            fill(page, field(page, 'advocateDocumentTitle'), 'Synthetic browser certificate')
            with page.expect_file_chooser() as chooser:
                click(page, button(page, 'advocateDocumentPhoto'))
            chooser.value.set_files({'name': 'synthetic.png', 'mimeType': 'image/png', 'buffer': PNG})
            expect(page.get_by_text(labels['advocateSaved'], exact=True)).to_be_visible(timeout=30000)
            profile = f.rpc('get_my_advocate_profile', owner['token'])[1]
            f.check('browser_document_private_upload', len(profile['documents']) == 1 and not profile['documents'][0]['is_public'])
            # Publish this synthetic photo through its ordinary owner policy.
            doc_id = profile['documents'][0]['id']
            assert f.call('PATCH', '/rest/v1/advocate_documents?id=eq.' + doc_id, owner['token'], {'is_public': True})[0] == 200
            # Real ordinary-owner rows, not browser response mocks.
            for table, values in {
                'experience': {'organization': 'Synthetic practice', 'position': 'Synthetic advocate', 'start_date': '2020-01-01'},
                'education': {'institution': 'Synthetic institution', 'qualification': 'Synthetic degree', 'start_year': 2015},
                'working_hours': {'weekday': 1, 'opens_at': '09:00', 'closes_at': '18:00'},
            }.items():
                assert f.call('POST', '/rest/v1/advocate_' + table, owner['token'], dict(values, expert_id=eid))[0] == 201
            status, completed = f.call('POST', '/rest/v1/consultations', admin=True, body={
                'citizen_id': client['id'], 'expert_id': eid, 'scheduled_at': datetime.now(timezone.utc).isoformat(),
                'status': 'completed', 'fee': 0, 'notes': 'Synthetic browser fixture only'})
            assert status == 201
            assert f.rpc('save_advocate_review', client['token'], {'p_consultation_id': completed[0]['id'],
                'p_rating': 4, 'p_comment': 'Synthetic browser review'})[0] == 200
            phase['name'] = 'public_profile'
            public_page = page_for(client)
            home(public_page)
            click(public_page, public_page.get_by_role('button', name=labels['navHome'], exact=True))
            click(public_page, public_page.get_by_role('button', name=labels['navExperts'], exact=False).first)
            fill(public_page, public_page.get_by_role('textbox'), 'Synthetic BrowserAdvocate')
            # The tappable directory card merges its text into one semantics
            # label; locate that public identity rather than an exact Text node.
            click(public_page, content(public_page, 'Synthetic BrowserAdvocate'))
            expect(content(public_page, labels['advocateVerified'])).to_be_visible(timeout=30000)
            f.check('browser_public_profile_real_identity', True)
            for width, height in [(320, 568), (390, 844), (1280, 900)]:
                phase['name'] = 'responsive_' + str(width)
                public_page.set_viewport_size({'width': width, 'height': height})
                public_page.mouse.wheel(0, -10000)
                public_page.wait_for_timeout(300)
                for key in ('advocateOverview', 'advocateServices', 'advocateReviews', 'advocateDocuments'):
                    tab(public_page, key)
                    expected = {'advocateOverview': 'Synthetic updated browser biography',
                        'advocateServices': 'Synthetic browser service',
                        'advocateReviews': 'Synthetic browser review',
                        'advocateDocuments': 'Synthetic browser certificate'}[key]
                    expect(seek(public_page, content(public_page, expected))).to_be_visible()
                    assert public_page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'browser_horizontal_overflow'
                public_page.screenshot(path='build/advocate_checks/public_' + str(width) + '.png')
                f.check('browser_four_tabs_' + str(width), True)
            public_page.set_viewport_size({'width': 1280, 'height': 900})
            phase['name'] = 'client_request'
            tab(public_page, 'advocateServices')
            click(public_page, button(public_page, 'advocateConsult').last)
            fill(public_page, field(public_page, 'advocateRequestMessage'), 'Synthetic browser request without private data')
            click(public_page, button(public_page, 'advocateSend'))
            expect(public_page.get_by_text(labels['advocateSent'], exact=True)).to_be_visible(timeout=30000)
            status, requests = f.call('GET', '/rest/v1/advocate_consultation_requests?expert_id=eq.' + eid, client['token'])
            f.check('browser_selected_service_request', status == 200 and len(requests) == 1 and requests[0]['service_id'] == service_id)
            phase['name'] = 'advocate_reply'
            home(page)
            click(page, page.get_by_role('button', name='Kabinet', exact=True))
            click(page, page.get_by_text(labels['advocateInbox'], exact=True))
            click(page, content(page, 'Synthetic browser service'))
            click(page, button(page, 'advocateAccept'))
            fill(page, page.get_by_role('textbox'), 'Synthetic browser advocate reply')
            click(page, button(page, 'advocateSend'))
            expect(content(page, 'Synthetic browser advocate reply')).to_be_visible(timeout=30000)
            f.check('browser_advocate_accept_reply', True)
            phase['name'] = 'client_reply'
            home(public_page)
            click(public_page, public_page.get_by_role('button', name='Kabinet', exact=True))
            click(public_page, public_page.get_by_text(labels['advocateInbox'], exact=True))
            click(public_page, content(public_page, 'Synthetic browser service'))
            expect(content(public_page, 'Synthetic browser advocate reply')).to_be_visible(timeout=30000)
            fill(public_page, public_page.get_by_role('textbox'), 'Synthetic browser client reply')
            click(public_page, button(public_page, 'advocateSend'))
            expect(content(public_page, 'Synthetic browser client reply')).to_be_visible(timeout=30000)
            f.check('browser_client_reads_and_replies', True)
            for current in (page, public_page):
                phase['name'] = 'logout'
                home(current)
                click(current, current.get_by_role('button', name='Kabinet', exact=True))
                click(current, current.get_by_role('button', name='Tizimdan chiqish', exact=True))
                expect(current.get_by_role('button', name='Tizimdan chiqish', exact=True)).to_have_count(0)
            f.check('browser_both_users_logout', True)
            f.check('browser_no_unexpected_console_page_network_errors', not errors and not failures and not forbidden and not http_errors)
        except Exception as exc:
            # Deliberately no exception string: Playwright may include typed credentials.
            print(json.dumps({'browser_phase': phase['name'], 'save_http_statuses': saves,
                              'http_errors': http_errors, 'page_console_errors': len(errors),
                              'network_errors': len(failures)}), flush=True)
            if phase['name'] not in ('owner_create', 'public_profile') or saves:
                current = public_page if phase['name'] in ('public_profile', 'client_request', 'client_reply') or phase['name'].startswith('responsive_') else page
                current.screenshot(path='build/advocate_checks/browser_failure.png')
            lines = [str(frame.lineno) for frame in traceback.extract_tb(exc.__traceback__)
                     if frame.filename.endswith('advocate_browser_smoke.py')]
            raise AssertionError('browser_' + phase['name'] + '_' + type(exc).__name__ + '_lines_' + '_'.join(lines)) from None
        finally:
            for context in contexts:
                context.close()
            browser.close()
            server.shutdown()


if __name__ == '__main__':
    fixture = None
    try:
        fixture = StagingFixture()
        run_browser(fixture)
        print(json.dumps({'browser_checks': len(fixture.results), 'status': 'PASS'}))
    except Exception as failure:
        print(json.dumps({'status': 'FAIL', 'check': str(failure) if isinstance(failure, AssertionError) else 'browser_execution'}))
        raise SystemExit(1) from None
    finally:
        if fixture is not None:
            fixture.cleanup()
