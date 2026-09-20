"""Disposable staging-only API isolation checks, measured 2026-09-20.

Exercises real PostgREST/Storage with ordinary A/B sessions. The supplied staging
service credential provisions/deletes only these fixtures; it is never output.
This does not prove production deployment or a working end-user Storage feature.
"""
import json
import secrets
from urllib import error, request
import uuid

STAGING_URL = 'https://hzefvtfnsnqxihyygwtp.supabase.co'


class SmokeFailure(RuntimeError):
    pass


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def run(staging_url, anon_key, service_key):
    if staging_url != STAGING_URL or not anon_key or not service_key:
        raise SmokeFailure('Pinned staging URL and credential inputs required')
    opener = request.build_opener(NoRedirect())
    users, objects, results = [], [], []

    def call(method, path, token=None, body=None, admin=False, raw=False):
        if not path.startswith('/') or path.startswith('//'):
            raise SmokeFailure('Invalid staging request path')
        key = service_key if admin else anon_key
        headers = {'apikey': key, 'Authorization': 'Bearer ' + (token or key),
                   'Content-Type': 'text/plain' if raw else 'application/json',
                   'Prefer': 'return=representation'}
        payload = body if raw else (json.dumps(body).encode() if body is not None else None)
        req = request.Request(staging_url + path, data=payload, headers=headers, method=method)
        try:
            with opener.open(req, timeout=30) as response:
                status, content = response.status, response.read()
        except error.HTTPError as failure:
            status, content = failure.code, failure.read()
        except Exception:
            raise SmokeFailure('Staging request transport failed') from None
        try:
            return status, json.loads(content) if content else None
        except (ValueError, UnicodeDecodeError):
            return status, None

    def check(name, passed):
        if not passed:
            raise SmokeFailure(name)
        results.append(name)

    try:
        for _ in range(2):
            email = 'security-smoke-' + uuid.uuid4().hex + '@example.invalid'
            password = secrets.token_urlsafe(32)
            status, user = call('POST', '/auth/v1/admin/users', admin=True, body={
                'email': email, 'password': password, 'email_confirm': True,
                'user_metadata': {'full_name': 'Synthetic Security Fixture'},
            })
            check('temporary ordinary account provisioned', status in (200, 201) and isinstance(user, dict) and bool(user.get('id')))
            users.append({'id': user['id']})
            status, login = call('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': password})
            check('temporary ordinary account login', status == 200 and isinstance(login, dict) and bool(login.get('access_token')))
            users[-1]['token'] = login['access_token']
        a, b = users

        status, mine = call('POST', '/rest/v1/rpc/get_my_profile', token=a['token'], body={})
        check('owner RPC and citizen role', status == 200 and mine.get('id') == a['id'] and mine.get('role') == 'citizen')
        status, _ = call('PATCH', '/rest/v1/profiles?select=id&id=eq.' + a['id'], token=a['token'], body={'phone': 'SYNTHETIC-PRIVATE'})
        check('owner private-field update with safe returning', status in (200, 204))
        status, mine = call('POST', '/rest/v1/rpc/get_my_profile', token=a['token'], body={})
        check('owner private-field read', status == 200 and mine.get('phone') == 'SYNTHETIC-PRIVATE')
        for column in ('phone', 'bio', 'license_number'):
            status, body = call('GET', '/rest/v1/profiles?select=' + column + '&id=eq.' + a['id'], token=b['token'])
            check('cross-user private profile ' + column, status == 403 and body.get('code') == '42501')
        status, _ = call('POST', '/rest/v1/rpc/get_my_profile', body={})
        check('guest cannot call private profile RPC', status in (401, 403))
        status, rows = call('GET', '/rest/v1/profiles?select=id,full_name,role,is_verified,avatar_url&id=eq.' + a['id'], token=b['token'])
        check('public profile embedding columns preserved', status == 200 and len(rows) == 1)

        status, rows = call('POST', '/rest/v1/user_documents', token=a['token'], body={
            'user_id': a['id'], 'title': 'Synthetic security fixture', 'category': 'test',
            'generated_text': 'Synthetic non-personal text', 'form_values': {},
        })
        check('owner document creation', status == 201 and len(rows) == 1)
        doc_id = rows[0]['id']
        for method, payload in [('GET', None), ('PATCH', {'title': 'Forged'}), ('DELETE', None)]:
            status, rows = call(method, '/rest/v1/user_documents?id=eq.' + doc_id, token=b['token'], body=payload)
            check('cross-user document ' + method, status == 200 and rows == [])
        status, rows = call('GET', '/rest/v1/user_documents?id=eq.' + doc_id, token=a['token'])
        check('denied writes preserve owner document', status == 200 and len(rows) == 1 and rows[0]['title'] == 'Synthetic security fixture')
        status, _ = call('PATCH', '/rest/v1/user_documents?id=eq.' + doc_id, token=a['token'], body={'user_id': b['id']})
        check('document owner reassignment denied', status == 403)
        status, rows = call('GET', '/rest/v1/user_documents?id=eq.' + doc_id)
        check('guest document read denied', status == 200 and rows == [])

        status, rows = call('POST', '/rest/v1/expert_profiles', token=a['token'], body={'user_id': a['id'], 'license_number': 'SYNTHETIC-PRIVATE'})
        check('pending expert application safe insert', status == 201 and len(rows) == 1 and rows[0]['verified_at'] is None)
        status, rows = call('GET', '/rest/v1/expert_profiles?user_id=eq.' + a['id'], token=b['token'])
        check('pending expert private licence isolation', status == 200 and rows == [])
        # Storage is deliberately deny-all today (no app upload implementation).
        # Seed only our own synthetic objects, then prove public/guest/A/B denial.
        for bucket in ('legal-documents', 'user-avatars'):
            object_name = a['id'] + '/security-' + uuid.uuid4().hex + '.txt'
            object_path = '/storage/v1/object/' + bucket + '/' + object_name
            status, _ = call('POST', object_path, admin=True, raw=True, body=b'Synthetic security fixture')
            check(bucket + ' synthetic object provisioned', status in (200, 201))
            objects.append((bucket, object_name))
            for label, token in [('guest', None), ('other-user', b['token'])]:
                status, _ = call('GET', object_path, token=token)
                check(bucket + ' ' + label + ' direct object denied', status in (400, 401, 403, 404))
                status, body = call('POST', '/storage/v1/object/sign/' + bucket + '/' + object_name, token=token, body={'expiresIn': 60})
                check(bucket + ' ' + label + ' signed URL creation denied', status in (400, 401, 403, 404) and not (isinstance(body, dict) and body.get('signedURL')))
            status, _ = call('GET', '/storage/v1/object/public/' + bucket + '/' + object_name)
            check(bucket + ' public object route denied', status in (400, 401, 403, 404))
            status, _ = call('PUT', object_path, token=b['token'], raw=True, body=b'Forged')
            check(bucket + ' unauthorized update denied', status in (400, 401, 403, 404))
            status, rows = call('DELETE', '/storage/v1/object/' + bucket, token=b['token'], body={'prefixes': [object_name]})
            check(bucket + ' unauthorized delete denied', status in (400, 401, 403, 404) or (status == 200 and rows == []))
            status, _ = call('GET', object_path, admin=True)
            check(bucket + ' denied writes preserve fixture object', status == 200)
        return {'status': 'PASS', 'checks': len(results), 'results': results}
    finally:
        cleanup_failed = False
        for bucket, object_name in objects:
            status, _ = call('DELETE', '/storage/v1/object/' + bucket, admin=True, body={'prefixes': [object_name]})
            cleanup_failed |= status != 200
        for user in reversed(users):
            status, _ = call('DELETE', '/auth/v1/admin/users/' + user['id'], admin=True)
            cleanup_failed |= status not in (200, 204)
            status, _ = call('GET', '/auth/v1/admin/users/' + user['id'], admin=True)
            cleanup_failed |= status != 404
        if cleanup_failed:
            raise SmokeFailure('Temporary staging fixture cleanup needs attention')
