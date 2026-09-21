"""2026-09-21: disposable citizen profile/Storage regression on pinned staging.

Never prints response bodies, credentials or auth headers. No production access.
This verifies real PostgREST/Auth/Storage; --browser adds the local Flutter build.
"""
import io
import json
import os
import secrets
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from PIL import Image

BASE = 'https://hzefvtfnsnqxihyygwtp.supabase.co'
_fixture = io.BytesIO()
Image.new('RGB', (64, 64), '#5B5BD6').save(_fixture, format='PNG')
PNG = _fixture.getvalue()


def main():
    assert os.environ.get('LEXHUB_STAGING_URL') == BASE, 'staging_identity'
    public_key = os.environ['LEXHUB_STAGING_ANON_KEY']
    service_key = os.environ['LEXHUB_STAGING_SERVICE_KEY']
    results, users, paths = [], [], []

    def request(method, path, token=None, body=None, raw=None):
        headers = {'apikey': public_key, 'Authorization': 'Bearer ' + (token or public_key),
                   'Content-Type': 'image/png' if raw is not None else 'application/json'}
        req = urllib.request.Request(BASE + path, method=method, headers=headers,
            data=raw if raw is not None else json.dumps(body).encode() if body is not None else None)
        try:
            with urllib.request.urlopen(req, timeout=35) as response:
                data = response.read()
                return response.status, json.loads(data or b'null') if 'json' in response.headers.get('Content-Type', '') else data
        except urllib.error.HTTPError as error:
            # Response bodies can contain private values: retain no error body.
            return error.code, None

    def passed(name):
        results.append(name)
        print(json.dumps({'check': name, 'status': 'PASS'}), flush=True)

    def login(email, password):
        status, value = request('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': password})
        assert status == 200, 'login_status'
        return value['access_token']

    def read(token):
        status, profile = request('POST', '/rest/v1/rpc/get_my_profile', token, {})
        assert status == 200 and isinstance(profile, dict), 'own_read'
        return profile

    try:
        for _ in range(2):
            email = 'profile-stage-' + uuid.uuid4().hex + '@example.invalid'
            password = secrets.token_urlsafe(36)
            status, user = request('POST', '/auth/v1/admin/users', service_key,
                {'email': email, 'password': password, 'email_confirm': True,
                 'user_metadata': {'full_name': 'Synthetic Profile'}})
            assert status in (200, 201), 'create_disposable_citizen'
            users.append({'id': user['id'], 'email': email, 'password': password,
                          'token': login(email, password)})
        a, b = users
        pa = read(a['token'])
        assert pa['role'] == 'citizen' and pa['email'] == a['email']
        assert all(pa[k] is None for k in ['first_name','last_name','date_of_birth','gender','address','occupation','avatar_path'])
        passed('new_user_null_fields_and_auth_email')
        changes = {'first_name':'Synthetic', 'last_name':'Staging', 'phone':'+998901234567',
                   'date_of_birth':'2000-02-29','gender':'female','address':'Synthetic address',
                   'occupation':'Tester','bio':'Synthetic persisted biography'}
        status, saved = request('POST','/rest/v1/rpc/update_my_profile',a['token'],{'p_changes':changes})
        assert status == 200 and all(saved[k] == v for k,v in changes.items()), 'save_values'
        assert read(a['token']) == saved
        passed('own_update_and_new_request_persistence')
        if '--browser-only' in sys.argv:
            from profile_browser_smoke import run_browser
            run_browser(a['email'],a['password'],passed)
            Path('build/profile_checks/browser_results.json').write_text(json.dumps({'passed':results,'count':len(results)}))
            return
        for field in ['phone','bio','first_name','last_name','date_of_birth','gender','address','occupation','avatar_path']:
            assert request('GET','/rest/v1/profiles?select='+field+'&id=eq.'+a['id'],b['token'])[0] == 403, 'private_column_'+field
        assert read(b['token'])['id'] == b['id']
        assert request('POST','/rest/v1/rpc/get_my_profile',body={})[0] in (401,403)
        assert request('PATCH','/rest/v1/profiles?id=eq.'+a['id'],b['token'],{'full_name':'Intruder'})[0] in (200,204)
        request('DELETE','/rest/v1/profiles?id=eq.'+a['id'],b['token'])
        assert read(a['token']) == saved
        passed('anonymous_and_cross_user_private_access_denied')
        for changes_bad in [{'id':b['id']},{'email':'other@example.invalid'}, {'role':'admin'}, {'is_verified':'true'},
                            {'gender':'unsupported'},{'date_of_birth':'2025-02-29'}, {'date_of_birth':'9999-01-01'},
                            {'date_of_birth':'2000-01-01T00:00:00Z'}, {'bio':'x'*301}, {'address':'x'*501},
                            {'occupation':'x'*129},{'phone':'123'},{'first_name':'x'*65}, {'bio':42}, [], None]:
            assert request('POST','/rest/v1/rpc/update_my_profile',a['token'],{'p_changes':changes_bad})[0] == 400, 'invalid_changes'
        passed('server_validation_16_negative_cases')
        path = a['id'] + '/' + str(uuid.uuid4()) + '.png'
        assert request('POST','/storage/v1/object/user-avatars/'+path,a['token'],raw=PNG)[0] in (200,201), 'avatar_upload'
        paths.append(path)
        assert request('POST','/rest/v1/rpc/update_my_profile',a['token'],{'p_changes':{'avatar_path':path}})[0] == 200
        assert request('GET','/storage/v1/object/authenticated/user-avatars/'+path,a['token']) == (200,PNG)
        passed('own_private_avatar_upload_download_and_reference')
        assert request('GET','/storage/v1/object/authenticated/user-avatars/'+path,b['token'])[0] in (400,403,404)
        assert request('GET','/storage/v1/object/public/user-avatars/'+path)[0] in (400,403,404)
        assert request('POST','/storage/v1/object/sign/user-avatars/'+path,b['token'],{'expiresIn':60})[0] in (400,403,404)
        assert request('PUT','/storage/v1/object/user-avatars/'+path,b['token'],raw=PNG)[0] in (400,403,404)
        request('DELETE','/storage/v1/object/user-avatars',b['token'],{'prefixes':[path]})
        assert request('GET','/storage/v1/object/authenticated/user-avatars/'+path,a['token']) == (200,PNG)
        assert request('POST','/rest/v1/rpc/update_my_profile',b['token'],{'p_changes':{'avatar_path':path}})[0] == 400
        passed('cross_user_avatar_download_sign_modify_delete_denied')
        old = a['token']
        assert request('POST','/auth/v1/logout?scope=global',old)[0] in (200,204)
        status, revoked = request('POST','/rest/v1/rpc/get_my_profile',old,{})
        assert status in (401,403) or (status == 200 and revoked is None)
        a['token'] = login(a['email'],a['password'])
        pa = read(a['token'])
        assert pa['avatar_path'] == path and all(pa[k] == v for k,v in changes.items())
        passed('logout_revocation_and_relogin_persistence')
        if '--browser' in sys.argv:
            from profile_browser_smoke import run_browser
            run_browser(a['email'],a['password'],passed)
        Path('build/profile_checks').mkdir(parents=True,exist_ok=True)
        Path('build/profile_checks/staging_results.json').write_text(json.dumps({'passed':results,'count':len(results)}))
    finally:
        for user in users:
            # Include browser-created private uploads before removing the account.
            status, objects = request('POST','/storage/v1/object/list/user-avatars',service_key,
                {'prefix':user['id'],'limit':100})
            assert status == 200 and isinstance(objects,list), 'cleanup_inventory'
            owned = [user['id']+'/'+item['name'] for item in objects if item.get('id')]
            if owned:
                assert request('DELETE','/storage/v1/object/user-avatars',service_key,{'prefixes':owned})[0] == 200, 'cleanup_objects'
            assert request('DELETE','/auth/v1/admin/users/'+user['id'],service_key)[0] in (200,204), 'cleanup_user'
            assert request('GET','/auth/v1/admin/users/'+user['id'],service_key)[0] == 404, 'cleanup_verify'
        print(json.dumps({'temporary_users_cleaned':len(users)}),flush=True)
    print(json.dumps({'profile_staging_groups':len(results),'status':'PASS'}),flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # No traceback/response payload can leak the temporary credentials.
        print(json.dumps({'status':'FAIL','type':type(error).__name__,
                          'check':str(error) if isinstance(error,AssertionError) and '\n' not in str(error) else 'execution'}))
        raise SystemExit(1) from None
