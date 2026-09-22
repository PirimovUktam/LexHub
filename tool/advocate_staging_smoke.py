"""2026-09-22: actual advocate CRUD, publication and isolation on pinned staging.

Only disposable synthetic fixtures are written. No credentials, response bodies,
user identifiers or browser auth state are printed or saved. Not production proof.
"""
import argparse
from datetime import datetime, timezone
import json
import secrets
import shutil
import subprocess
import uuid
from urllib import error, request

from profile_staging_smoke import PNG

REF = 'hzefvtfnsnqxihyygwtp'
BASE = 'https://' + REF + '.supabase.co'


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, *_args):
        return None


class StagingFixture:
    def __init__(self):
        result = subprocess.run(
            [shutil.which('supabase') or 'supabase', 'projects', 'api-keys', '--project-ref', REF, '--output', 'json'],
            capture_output=True, text=True, timeout=45)
        assert result.returncode == 0, 'staging_cli_credentials'
        keys = json.loads(result.stdout)
        self.anon = next(k['api_key'] for k in keys if k['name'] == 'anon')
        self.service = next(k['api_key'] for k in keys if k['name'] == 'service_role')
        self.users = []
        self.results = []
        self.opener = request.build_opener(NoRedirect())

    def call(self, method, path, token=None, body=None, raw=None, admin=False):
        assert path.startswith('/') and not path.startswith('//'), 'relative_staging_path'
        key = self.service if admin else self.anon
        headers = {'apikey': key, 'Authorization': 'Bearer ' + (token or key),
                   'Content-Type': 'image/png' if raw is not None else 'application/json',
                   'Prefer': 'return=representation'}
        payload = raw if raw is not None else json.dumps(body).encode() if body is not None else None
        req = request.Request(BASE + path, data=payload, method=method, headers=headers)
        try:
            with self.opener.open(req, timeout=35) as response:
                content, status = response.read(), response.status
        except error.HTTPError as failure:
            content, status = failure.read(), failure.code
        try:
            return status, json.loads(content) if content else None
        except (ValueError, UnicodeDecodeError):
            return status, content

    def rpc(self, name, token=None, body=None):
        return self.call('POST', '/rest/v1/rpc/' + name, token, body or {})

    def check(self, name, condition):
        assert condition, name
        self.results.append(name)
        print(json.dumps({'check': name, 'status': 'PASS'}), flush=True)

    def user(self):
        email = 'advocate-smoke-' + uuid.uuid4().hex + '@example.invalid'
        password = secrets.token_urlsafe(36)
        status, user = self.call('POST', '/auth/v1/admin/users', admin=True, body={
            'email': email, 'password': password, 'email_confirm': True,
            'user_metadata': {'full_name': 'Synthetic Advocate Fixture'}})
        assert status in (200, 201), 'create_synthetic_user'
        fixture = {'id': user['id'], 'email': email, 'password': password}
        self.users.append(fixture)
        status, session = self.call('POST', '/auth/v1/token?grant_type=password',
                                   body={'email': email, 'password': password})
        assert status == 200, 'synthetic_login'
        fixture['token'] = session['access_token']
        return fixture

    def approve_fixture(self, owner, expert_id):
        # Only the disposable synthetic identity created by this process.
        assert owner in self.users, 'owned_fixture_only'
        assert self.call('PATCH', '/rest/v1/profiles?id=eq.' + owner['id'], admin=True,
                         body={'role': 'verified_expert', 'is_verified': True})[0] == 200, 'fixture_role'
        assert self.call('PATCH', '/rest/v1/expert_profiles?id=eq.' + expert_id, admin=True,
                         body={'verified_at': datetime.now(timezone.utc).isoformat(),
                               'license_number': 'SYNTHETIC-TEST-ONLY'})[0] == 200, 'fixture_approval'

    def cleanup(self):
        failed = []
        for user in reversed(self.users):
            status, objects = self.call('POST', '/storage/v1/object/list/advocate-documents',
                                        admin=True, body={'prefix': user['id'], 'limit': 1000})
            if status != 200 or not isinstance(objects, list):
                failed.append('object_inventory')
                continue
            paths = [user['id'] + '/' + item['name'] for item in objects if item.get('id')]
            if paths and self.call('DELETE', '/storage/v1/object/advocate-documents', admin=True,
                                   body={'prefixes': paths})[0] != 200:
                failed.append('object_delete')
                continue
            if user.get('token'):
                status, _ = self.call('POST', '/auth/v1/logout?scope=global', user['token'])
                if status not in (200, 204, 401, 403):
                    failed.append('logout')
            if self.call('DELETE', '/auth/v1/admin/users/' + user['id'], admin=True)[0] not in (200, 204):
                failed.append('user_delete')
            if self.call('GET', '/auth/v1/admin/users/' + user['id'], admin=True)[0] != 404:
                failed.append('user_delete_verification')
        assert not failed, 'synthetic_cleanup_' + '_'.join(failed)
        print(json.dumps({'cleanup': 'PASS', 'temporary_accounts': len(self.users)}), flush=True)


def run(f):
    owner, client, other = f.user(), f.user(), f.user()
    draft = {'first_name': 'Synthetic', 'last_name': 'Advocate',
             'bio': 'Synthetic professional biography', 'address': 'Synthetic office',
             'specializations': ['Mehnat'], 'languages': ['O‘zbek', 'English'],
             'experience_years': 5, 'workplace': 'Synthetic office',
             'accepting_clients': True, 'is_published': False}
    status, profile = f.rpc('save_advocate_profile', owner['token'], {'p_profile': draft})
    f.check('profile_create_real_backend', status == 200 and profile['is_owner'] and not profile['verified'])
    expert_id = profile['id']
    payload = {'p_expert_id': expert_id}
    f.check('draft_hidden_from_guest_and_other',
            f.rpc('get_advocate_profile', body=payload) == (200, None)
            and f.rpc('get_advocate_profile', other['token'], payload) == (200, None))
    edited = dict(draft, bio='Synthetic edited biography')
    status, saved = f.rpc('save_advocate_profile', owner['token'], {'p_profile': edited})
    f.check('profile_edit_reload_persistence', status == 200 and saved['bio'] == edited['bio']
            and f.rpc('get_my_advocate_profile', owner['token'])[1]['bio'] == edited['bio'])
    for forbidden in ('verified', 'user_id', 'rating', 'reviews_count', 'consultations_count'):
        f.check('cannot_self_assign_' + forbidden,
                f.rpc('save_advocate_profile', owner['token'], {'p_profile': {forbidden: True}})[0] == 400)
    f.check('profile_direct_write_denied', f.call('PATCH', '/rest/v1/advocate_profiles?expert_id=eq.' + expert_id,
            other['token'], {'bio': 'forged'})[0] in (401, 403))
    f.approve_fixture(owner, expert_id)
    status, published = f.rpc('save_advocate_profile', owner['token'], {'p_profile': {'is_published': True}})
    status_public, public = f.rpc('get_advocate_profile', body=payload)
    f.check('verified_published_profile_public_read', status == status_public == 200
            and published['verified'] and public['full_name'] == 'Synthetic Advocate' and not public['is_owner'])
    f.check('public_private_field_separation', public['rating'] is None and public['reviews_count'] == 0
            and public['consultations_count'] == 0 and not any(k in public for k in
            ('email', 'phone', 'date_of_birth', 'gender', 'reputation_points', 'license_document_url')))
    children = {
        'services': {'title': 'Synthetic consultation', 'description': 'Synthetic service', 'price_uzs': 100000,
                     'duration_minutes': 30, 'delivery_mode': 'online'},
        'experience': {'organization': 'Synthetic office', 'position': 'Advocate', 'start_date': '2020-01-01'},
        'education': {'institution': 'Synthetic institution', 'qualification': 'Synthetic degree', 'start_year': 2015, 'end_year': 2019},
        'working_hours': {'weekday': 1, 'opens_at': '09:00', 'closes_at': '18:00', 'is_closed': False}}
    created = {}
    for kind, fields in children.items():
        table = '/rest/v1/advocate_' + kind
        status, rows = f.call('POST', table, owner['token'], dict(fields, expert_id=expert_id))
        f.check(kind + '_create', status == 201 and len(rows) == 1)
        row = rows[0]
        created[kind] = row
        filter_path = table + '?id=eq.' + row['id']
        for method, body in [('GET', None), ('PATCH', fields), ('DELETE', None)]:
            status, value = f.call(method, filter_path, other['token'], body)
            f.check(kind + '_cross_user_' + method.lower() + '_denied', status == 200 and value == [])
        f.check(kind + '_unauthorized_insert_denied', f.call('POST', table, other['token'],
                dict(fields, expert_id=expert_id))[0] == 403)
        status, value = f.call('PATCH', filter_path, owner['token'], fields)
        f.check(kind + '_owner_update_preserved', status == 200 and len(value) == 1 and value[0]['id'] == row['id'])
    f.check('hours_unique_weekday', f.call('POST', '/rest/v1/advocate_working_hours', owner['token'],
            dict(children['working_hours'], expert_id=expert_id))[0] == 409)
    f.check('service_invalid_price_denied', f.call('PATCH', '/rest/v1/advocate_services?id=eq.' + created['services']['id'],
            owner['token'], {'price_uzs': -1})[0] == 400)
    public = f.rpc('get_advocate_profile', body=payload)[1]
    f.check('aggregate_real_child_rows', all(len(public[k]) == 1 for k in children))
    path = owner['id'] + '/' + str(uuid.uuid4()) + '.png'
    f.check('private_document_upload', f.call('POST', '/storage/v1/object/advocate-documents/' + path,
            owner['token'], raw=PNG)[0] in (200, 201))
    status, rows = f.call('POST', '/rest/v1/advocate_documents', owner['token'],
                        {'expert_id': expert_id, 'title': 'Synthetic certificate photo',
                         'kind': 'certificate', 'object_path': path, 'is_public': False})
    f.check('private_document_metadata_create', status == 201 and len(rows) == 1)
    document = rows[0]
    for label, token in [('guest', None), ('other', other['token'])]:
        f.check('private_document_' + label + '_denied', f.call('POST', '/storage/v1/object/sign/advocate-documents/' + path,
                token, {'expiresIn': 60})[0] in (400, 401, 403, 404))
    f.check('private_document_aggregate_hidden', not f.rpc('get_advocate_profile', body=payload)[1]['documents'])
    f.check('storage_cross_user_replace_denied', f.call('PUT', '/storage/v1/object/advocate-documents/' + path,
            other['token'], raw=PNG)[0] in (400, 401, 403, 404))
    f.check('storage_cross_user_path_reference_denied', f.rpc('save_advocate_profile', client['token'],
            {'p_profile': dict(draft, avatar_path=path)})[0] == 400)
    f.check('document_publication', f.call('PATCH', '/rest/v1/advocate_documents?id=eq.' + document['id'],
            owner['token'], {'is_public': True})[0] == 200
            and len(f.rpc('get_advocate_profile', body=payload)[1]['documents']) == 1)
    status, signed = f.call('POST', '/storage/v1/object/sign/advocate-documents/' + path,
                            body={'expiresIn': 60})
    f.check('explicit_public_document_signed_read', status == 200 and bool(signed.get('signedURL')))
    f.check('bucket_stays_private', f.call('GET', '/storage/v1/object/public/advocate-documents/' + path)[0] in (400, 403, 404))
    f.check('avatar_save', f.rpc('save_advocate_profile', owner['token'], {'p_profile': {'avatar_path': path}})[0] == 200)
    f.check('avatar_aggregate_real_path', f.rpc('get_advocate_profile', body=payload)[1]['avatar_path'] == path)
    request_body = {'p_expert_id': expert_id, 'p_service_id': created['services']['id'],
                    'p_kind': 'consultation', 'p_message': 'Synthetic consultation request. No real legal case.'}
    status, conversation = f.rpc('send_advocate_request', client['token'], request_body)
    f.check('consultation_request_real_service_snapshot', status == 200 and conversation['status'] == 'pending'
            and conversation['service_title'] == children['services']['title'] and conversation['price_uzs'] == 100000)
    rid = conversation['id']
    for user, label in [(owner, 'advocate'), (client, 'requester')]:
        status, rows = f.call('GET', '/rest/v1/advocate_consultation_requests?id=eq.' + rid, user['token'])
        f.check(label + '_inbox_real_request', status == 200 and len(rows) == 1)
        status, sent = f.rpc('send_advocate_message', user['token'], {'p_request_id': rid, 'p_body': 'Synthetic reply'})
        f.check(label + '_message_send', status == 200 and sent['body'] == 'Synthetic reply')
    f.check('outsider_conversation_hidden', f.call('GET', '/rest/v1/advocate_consultation_requests?id=eq.' + rid,
            other['token']) == (200, []) and f.call('GET', '/rest/v1/advocate_messages?request_id=eq.' + rid,
            other['token']) == (200, []))
    f.check('outsider_message_send_denied', f.rpc('send_advocate_message', other['token'],
            {'p_request_id': rid, 'p_body': 'Forged'})[0] == 403)
    f.check('requester_cannot_accept', f.rpc('update_advocate_request_status', client['token'],
            {'p_request_id': rid, 'p_status': 'accepted'})[0] == 400)
    f.check('advocate_can_accept', f.rpc('update_advocate_request_status', owner['token'],
            {'p_request_id': rid, 'p_status': 'accepted'})[0] == 200)
    f.check('requester_confirms_completion', f.rpc('update_advocate_request_status', client['token'],
            {'p_request_id': rid, 'p_status': 'completed'})[0] == 200)
    f.check('closed_conversation_message_denied', f.rpc('send_advocate_message', client['token'],
            {'p_request_id': rid, 'p_body': 'Synthetic late reply'})[0] == 400)
    # A service request is not a paid/scheduled consultation and cannot mint ratings.
    f.check('request_cannot_forge_completed_consultation', f.rpc('save_advocate_review', client['token'],
            {'p_consultation_id': rid, 'p_rating': 5, 'p_comment': 'Forged review'})[0] == 403)
    status, consultations = f.call('POST', '/rest/v1/consultations', admin=True, body={
        'citizen_id': client['id'], 'expert_id': expert_id, 'scheduled_at': datetime.now(timezone.utc).isoformat(),
        'status': 'completed', 'fee': 0, 'notes': 'Synthetic fixture, no payment or legal advice'})
    f.check('completed_consultation_fixture', status == 201 and len(consultations) == 1)
    cid = consultations[0]['id']
    f.check('outsider_review_denied', f.rpc('save_advocate_review', other['token'],
            {'p_consultation_id': cid, 'p_rating': 5, 'p_comment': 'Forged review'})[0] == 403)
    f.check('real_client_review', f.rpc('save_advocate_review', client['token'],
            {'p_consultation_id': cid, 'p_rating': 4, 'p_comment': 'Synthetic review'})[0] == 200)
    public = f.rpc('get_advocate_profile', body=payload)[1]
    f.check('rating_counts_from_actual_rows', public['rating'] == 4 and public['reviews_count'] == 1
            and public['consultations_count'] == 1 and public['reviews'][0]['comment'] == 'Synthetic review'
            and 'reviewer_id' not in public['reviews'][0])
    f.check('review_upsert_not_duplicate', f.rpc('save_advocate_review', client['token'],
            {'p_consultation_id': cid, 'p_rating': 3, 'p_comment': 'Synthetic updated review'})[0] == 200
            and f.rpc('get_advocate_profile', body=payload)[1]['reviews_count'] == 1)
    for _ in range(2):
        assert f.rpc('send_advocate_request', client['token'], request_body)[0] == 200, 'rate_fixture'
    f.check('request_rate_limit', f.rpc('send_advocate_request', client['token'], request_body)[0] == 429)
    for kind, row in created.items():
        status, rows = f.call('DELETE', '/rest/v1/advocate_' + kind + '?id=eq.' + row['id'], owner['token'])
        f.check(kind + '_owner_delete', status == 200 and len(rows) == 1
                and not f.rpc('get_advocate_profile', owner['token'], payload)[1][kind])
    f.check('service_delete_preserves_request_snapshot', f.call('GET', '/rest/v1/advocate_consultation_requests?id=eq.' + rid,
            client['token'])[1][0]['service_title'] == children['services']['title'])
    f.check('document_owner_delete', f.call('DELETE', '/rest/v1/advocate_documents?id=eq.' + document['id'], owner['token'])[0] == 200)
    f.check('unpublish_hides_profile_and_objects', f.rpc('save_advocate_profile', owner['token'],
            {'p_profile': {'is_published': False}})[0] == 200
            and f.rpc('get_advocate_profile', body=payload) == (200, None)
            and f.call('POST', '/storage/v1/object/sign/advocate-documents/' + path, body={'expiresIn': 60})[0] in (400, 403, 404))
    f.check('logout', f.call('POST', '/auth/v1/logout?scope=global', owner['token'])[0] in (200, 204))
    f.check('old_session_rejected', f.rpc('get_my_advocate_profile', owner['token'])[0] == 403)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--browser', action='store_true')
    args = parser.parse_args()
    assert args.execute, 'explicit_staging_execution_required'
    fixture = StagingFixture()
    try:
        run(fixture)
        if args.browser:
            from advocate_browser_smoke import run_browser
            run_browser(fixture)
    finally:
        fixture.cleanup()
    print(json.dumps({'status': 'PASS', 'checks': len(fixture.results)}), flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as failure:
        # Fixed assertion identifiers only; never emit network exception bodies.
        print(json.dumps({'status': 'FAIL', 'type': type(failure).__name__,
                          'check': str(failure) if isinstance(failure, AssertionError) else 'execution'}))
        raise SystemExit(1) from None
