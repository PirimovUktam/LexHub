"""2026-09-21: local Flutter build against disposable staging profile.
No auth state, credentials, HAR or response bodies are written to disk.
"""
import json
import traceback
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.parse import urlsplit
from playwright.sync_api import sync_playwright, expect
from web_first_paint_probe import INIT_JS
from profile_staging_smoke import BASE, PNG


def run_browser(email, password, passed):
    labels = json.loads(Path('lib/l10n/arb/app_uz.arb').read_text(encoding='utf-8'))
    out = Path('build/profile_checks')
    out.mkdir(parents=True, exist_ok=True)
    errors, failed, blocked, updates = [], [], [], []
    uploads, avatar_paths = [], []
    injecting = {'error':False}
    navigation = {'phase':'steady'}

    class Handler(SimpleHTTPRequestHandler):
        def end_headers(self):
            # Exercise the deployed CSP locally, including its blob-XHR denial.
            for rule in json.loads(Path('vercel.json').read_text())['headers']:
                if rule['source'] in ('/(.*)',urlsplit(self.path).path):
                    for header in rule['headers']:
                        self.send_header(header['key'],header['value'])
            super().end_headers()

        def log_message(self, *_args):
            pass

    with ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory='build/web')) as server, sync_playwright() as pw:
        Thread(target=server.serve_forever,daemon=True).start()
        browser = pw.chromium.launch()
        context = browser.new_context(viewport={'width':1280,'height':900})

        def route(r):
            host = urlsplit(r.request.url).hostname
            if host not in {'127.0.0.1',urlsplit(BASE).hostname,'www.gstatic.com','fonts.gstatic.com','fonts.googleapis.com'}:
                blocked.append(host)
                r.abort()
            elif injecting['error'] and urlsplit(r.request.url).path == '/rest/v1/rpc/update_my_profile':
                r.fulfill(status=503,content_type='application/json',body='{"message":"synthetic_unavailable"}')
            else:
                r.continue_()

        context.route('**/*',route)
        page = context.new_page()
        page.add_init_script(INIT_JS + "\nwindow.addEventListener('flutter-first-frame', () => document.documentElement.setAttribute('data-first-frame', 'ready'));")
        page.on('console',lambda msg: errors.append('expected_503' if '503' in msg.text else 'console') if msg.type=='error' else None)
        page.on('pageerror',lambda _:errors.append('pageerror'))
        page.on('requestfailed',lambda request:failed.append({
            'kind':'aborted' if 'ERR_ABORTED' in (request.failure or '') else 'network',
            'phase':navigation['phase'],
            'path':urlsplit(request.url).path.split('/')[1:4]}))
        page.on('response',lambda r:updates.append(r.status) if urlsplit(r.url).path=='/rest/v1/rpc/update_my_profile' else None)
        page.on('response',lambda r:uploads.append(r.status) if r.request.method=='POST' and '/storage/v1/object/user-avatars/' in r.url else None)
        page.on('response',lambda r:avatar_paths.append(r.json().get('avatar_path')) if r.status==200 and urlsplit(r.url).path=='/rest/v1/rpc/get_my_profile' else None)
        page.set_default_timeout(20000)

        def fill(field, value):
            field.click()
            expect(field).to_be_focused()
            page.wait_for_timeout(100)
            field.press('Control+A')
            page.keyboard.insert_text(value)
            # Flutter's text input bridge applies platform edits on a frame.
            page.wait_for_timeout(100)
            expect(field).to_have_value(value)

        def semantics():
            expect(page.locator('html')).to_have_attribute('data-first-frame','ready',timeout=90000)
            placeholder=page.locator('flt-semantics-placeholder')
            if placeholder.count():
                placeholder.dispatch_event('click')

        def cabinet():
            page.get_by_role('button',name='Kabinet',exact=True).click()

        def login():
            cabinet()
            page.get_by_role('button',name="Tizimga kirish / Ro'yxatdan o'tish",exact=True).click()
            fields = page.get_by_role('textbox')
            fill(fields.nth(0),email)
            fill(fields.nth(1),password)
            page.get_by_role('button',name='Tizimga kirish',exact=True).click()
            expect(page.get_by_role('button',name='Kabinet',exact=True)).to_be_visible(timeout=30000)
            cabinet()

        def edit():
            page.get_by_role('button',name=labels['profileEditDetails'],exact=True).click()
            expect(page.get_by_role('textbox',name=labels['profileFirstName'],exact=False)).to_be_visible()
            # Semantics can exist before the Material route transition ends.
            page.wait_for_timeout(350)

        def textbox(key):
            return page.get_by_role('textbox',name=labels[key],exact=False)

        def save():
            button=page.get_by_role('button',name=labels['profileSave'],exact=True)
            button.scroll_into_view_if_needed()
            with page.expect_response(lambda r:urlsplit(r.url).path=='/rest/v1/rpc/update_my_profile') as response:
                button.click()
            assert response.value.status==200,'browser_save_status'
            expect(page.get_by_role('button',name=labels['profileEditDetails'],exact=True)).to_be_visible()
            return response.value.json()

        def visible_profile_value(value):
            # SelectableText is canvas-rendered until its editing connection is
            # focused. Verify exact persisted text through the real editor;
            # card text is additionally covered by widget assertions/screenshots.
            edit()
            textbox('profileBio').click()
            expect(textbox('profileBio')).to_have_value(value)
            page.get_by_role('button',name=labels['profileCancel'],exact=True).click()

        try:
            page.goto('http://127.0.0.1:'+str(server.server_address[1]),wait_until='load')
            semantics()
            expect(page.get_by_role('button',name='Kabinet',exact=True)).to_be_visible(timeout=60000)
            login()
            edit()
            # Flutter materializes the semantic editing value when focused.
            textbox('profileEmail').click()
            expect(textbox('profileEmail')).to_have_value(email)
            textbox('profileEmail').press('A')
            expect(textbox('profileEmail')).to_have_value(email)
            fill(textbox('profilePhone'),'123')
            page.get_by_role('button',name=labels['profileSave'],exact=True).click()
            # InputDecorator exposes validation on its semantic wrapper.
            error_node=page.locator('flt-semantics').filter(has_text=labels['profileInvalidPhone'])
            try:
                expect(error_node.last).to_be_visible(timeout=3000)
            except AssertionError:
                nodes=page.locator('flt-semantics').evaluate_all('''(els) => els.filter(e =>
                    (e.getAttribute('aria-label') || '').includes('Telefon')).map(e => ({
                    role:e.getAttribute('role'), label:e.getAttribute('aria-label'),
                    invalid:e.getAttribute('aria-invalid'), description:e.getAttribute('aria-description')}))''')
                print(json.dumps({'phone_validation_semantics':nodes}),flush=True)
                raise
            assert not updates,'client_validation_before_rpc'
            fill(textbox('profilePhone'),'+998901234567')
            fill(textbox('profileFirstName'),'Browser')
            fill(textbox('profileLastName'),'Profile')
            fill(textbox('profileAddress'),'Synthetic browser address')
            fill(textbox('profileOccupation'),'Browser tester')
            fill(textbox('profileBio'),'Synthetic browser biography')
            passed('browser_real_form_validation_and_auth_email')
            photo_button=page.get_by_role('button',name=labels['profileChoosePhoto'],exact=True)
            assert avatar_paths,'initial_profile_response'
            previous_avatar=avatar_paths[-1]
            photo_button.scroll_into_view_if_needed()
            with page.expect_file_chooser() as picker:
                photo_button.click()
            picker.value.set_files({'name':'synthetic.png','mimeType':'image/png','buffer':PNG})
            expect(photo_button).to_be_enabled()
            expect(page.get_by_text(labels['profilePhotoInvalid'],exact=True)).to_have_count(0)
            saved=save()
            assert saved.get('avatar_path'),'browser_avatar_reference_saved'
            assert saved['avatar_path']!=previous_avatar and uploads==[200],'new_private_avatar_uploaded'
            expect(page.get_by_text('Browser Profile',exact=True)).to_be_visible()
            visible_profile_value('Synthetic browser biography')
            passed('browser_pick_preview_upload_save_and_real_profile')
            page.wait_for_load_state('networkidle')
            navigation['phase']='reload'
            page.reload(wait_until='load')
            semantics()
            navigation['phase']='steady'
            cabinet()
            visible_profile_value('Synthetic browser biography')
            edit()
            textbox('profileFirstName').click()
            expect(textbox('profileFirstName')).to_have_value('Browser')
            textbox('profileOccupation').click()
            expect(textbox('profileOccupation')).to_have_value('Browser tester')
            # DatePicker is real; changing via its calendar needs no text fixtures.
            page.get_by_role('button',name=labels['profileClearDate'],exact=True).click()
            save()
            passed('browser_reload_persistence_and_date_clear')
            edit()
            fill(textbox('profileBio'),'Unsaved synthetic change')
            injecting['error']=True
            with page.expect_response(lambda r:urlsplit(r.url).path=='/rest/v1/rpc/update_my_profile') as rejected:
                page.get_by_role('button',name=labels['profileSave'],exact=True).click()
            assert rejected.value.status==503,'error_injected'
            expect(page.get_by_role('button',name=labels['profileSave'],exact=True)).to_be_enabled()
            assert updates[-1]==503,'error_injected'
            expect(textbox('profileBio')).to_have_value('Unsaved synthetic change')
            injecting['error']=False
            page.get_by_role('button',name=labels['profileCancel'],exact=True).click()
            visible_profile_value('Synthetic browser biography')
            passed('browser_save_error_preserves_auth_and_saved_profile')
            for width,height in [(320,568),(390,844),(768,1024),(1280,720),(1440,900)]:
                page.set_viewport_size({'width':width,'height':height})
                edit()
                expect(textbox('profileFirstName')).to_be_visible()
                button=page.get_by_role('button',name=labels['profileSave'],exact=True)
                page.mouse.move(width//2,height-80)
                page.mouse.wheel(0,1800)
                page.wait_for_timeout(250)
                expect(button).to_be_visible()
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),'horizontal_overflow'
                page.screenshot(path=str(out/f'profile-{width}x{height}.png'))
                page.get_by_role('button',name=labels['profileCancel'],exact=True).click()
                passed(f'profile_responsive_{width}x{height}')
            page.wait_for_load_state('networkidle')
            navigation['phase']='logout'
            page.get_by_role('button',name='Tizimdan chiqish',exact=True).click()
            expect(page.get_by_role('button',name='Tizimdan chiqish',exact=True)).to_have_count(0)
            navigation['phase']='steady'
            login()
            visible_profile_value('Synthetic browser biography')
            passed('browser_logout_login_persistence')
            unexpected=[error for error in errors if error!='expected_503']
            unexpected_requests=[request for request in failed if not (
                request['kind']=='aborted' and request['phase'] in ('reload','logout')
                and request['path']==['storage','v1','object'])]
            print(json.dumps({'browser_errors':unexpected,'expected_503':errors.count('expected_503'),
                              'failed_requests':failed,'blocked_hosts_count':len(blocked)}),flush=True)
            assert errors.count('expected_503')<=1 and updates.count(503)==1,'only_injected_503'
            assert not unexpected and not unexpected_requests and not blocked,'browser_error_counts'
            passed('browser_no_console_network_or_production_requests')
        except Exception:
            trace=traceback.extract_tb(__import__('sys').exc_info()[2])
            print(json.dumps({'browser_failure_lines':[frame.lineno for frame in trace
                if frame.filename.endswith('profile_browser_smoke.py')]}),flush=True)
            # Synthetic account only; screenshot aids layout diagnosis, no secrets.
            page.screenshot(path=str(out/'failure.png'))
            raise
        finally:
            context.close()
            browser.close()
            server.shutdown()
