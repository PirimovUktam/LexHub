"""Staging-only bounded abuse regression (2026-09-20), not production evidence.

Uses one disposable citizen and seeds only its synthetic signup counter instead
of sending repeated logins/emails. Caller supplies staging credentials in memory.
"""
import json
import secrets
import uuid
from urllib import request, error

STAGING = 'https://hzefvtfnsnqxihyygwtp.supabase.co'


def run(url, anon, service, sql):
    if url != STAGING:
        raise RuntimeError('Pinned staging target required')
    results = []
    uid = None
    email = 'abuse-smoke-' + uuid.uuid4().hex + '@example.invalid'
    signup_email = 'blocked-signup-' + uuid.uuid4().hex + '@example.invalid'
    password = secrets.token_urlsafe(32)

    class NoRedirect(request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = request.build_opener(NoRedirect())

    def call(method, path, body=None, token=None, admin=False, raw=None):
        key = service if admin else anon
        headers = {'apikey': key, 'Content-Type': 'application/json'}
        if token or admin:
            headers['Authorization'] = 'Bearer ' + (token or key)
        data = raw if raw is not None else json.dumps(body).encode() if body is not None else None
        req = request.Request(url + path, data=data, headers=headers, method=method)
        try:
            with opener.open(req, timeout=65) as response:
                status, headers, data = response.status, response.headers, response.read()
        except error.HTTPError as response:
            status, headers, data = response.code, response.headers, response.read()
        except TimeoutError:
            raise RuntimeError('Failed check: transport timeout for ' + method +
                               ' ' + path.split('?')[0]) from None
        try:
            parsed = json.loads(data) if data else None
        except (ValueError, UnicodeError):
            parsed = None
        return status, headers, parsed

    def check(name, condition):
        if not condition:
            raise RuntimeError('Failed check: ' + name)
        results.append(name)

    try:
        status, _, user = call('POST', '/auth/v1/admin/users', admin=True,
                              body={'email': email, 'password': password, 'email_confirm': True})
        check('ordinary disposable user', status in (200, 201) and bool(user.get('id')))
        uid = user['id']
        status, _, login = call('POST', '/auth/v1/token?grant_type=password',
                               body={'email': email, 'password': password})
        check('login', status == 200 and bool(login.get('access_token')))
        token = login['access_token']
        refresh = login['refresh_token']
        status, _, profile = call('POST', '/rest/v1/rpc/get_my_profile', {}, token)
        check('citizen role', status == 200 and profile['role'] == 'citizen')
        status, _, denial = call('PATCH', '/rest/v1/profiles?id=eq.' + uid,
                                 {'role': 'admin'}, token)
        # The existing profile trigger raises P0001, mapped by PostgREST to 400.
        # Match that guard exactly; an unrelated HTTP error is not proof.
        check('self admin escalation denied', status == 400 and
              denial.get('code') == 'P0001' and denial.get('message') ==
              'Privilege Escalation Blocked: Role can only be modified by system administrators.')
        status, _, profile = call('POST', '/rest/v1/rpc/get_my_profile', {}, token)
        check('denied escalation preserves citizen role',
              status == 200 and profile['role'] == 'citizen')
        status, _, _ = call('POST', '/functions/v1/legal-ai', {'query_text': 'Synthetic'})
        check('unauthenticated AI 401', status == 401)
        status, _, _ = call('POST', '/functions/v1/legal-ai', token=token, raw=b'{')
        check('malformed JSON 400', status == 400)
        status, _, _ = call('POST', '/functions/v1/legal-ai', token=token, raw=b' ' * (256 * 1024 + 1))
        check('oversized body 413', status == 413)
        for _ in range(10):
            status, _, quota = call('POST', '/rest/v1/rpc/consume_legal_ai_quota', {}, token)
            check('atomic quota slot', status == 200 and quota['allowed'] is True)
        status, headers, body = call('POST', '/functions/v1/legal-ai', {'query_text': 'Synthetic'}, token)
        check('real AI limit 429 + Retry-After', status == 429 and
              int(headers.get('Retry-After', '0')) > 0 and body['error']['code'] == 'rate_limited')
        check('safe rate-limit schema', set(body['error']) == {'code', 'message'})
        # Bounded seed: no brute-force, no email delivery, no real account target.
        sql("INSERT INTO auth_guard.attempt_windows(action,scope,identity_hash,started_at,attempts) VALUES ('signup','identifier',auth_guard.identity_key('" + signup_email + "'),now(),3)", False)
        status, _, body = call('POST', '/auth/v1/signup', {'email': signup_email, 'password': password})
        check('real signup identifier limit 429', status == 429)
        check('blocked signup never creates an account', sql("SELECT count(*)::int AS n FROM auth.users WHERE email='" + signup_email + "'")[0]['n'] == 0)
        status, _, _ = call('POST', '/auth/v1/logout?scope=global', token=token)
        check('global logout', status in (200, 204))
        status, _, _ = call('POST', '/auth/v1/token?grant_type=refresh_token', {'refresh_token': refresh})
        check('revoked refresh rejected', status in (400, 401, 403))
        access_status, _, _ = call('GET', '/auth/v1/user', token=token)
        ai_status, _, _ = call('POST', '/functions/v1/legal-ai',
                               {'query_text': 'Synthetic'}, token)
        check('logged-out access token cannot call AI', ai_status == 401)
        profile_status, _, denial = call('POST', '/rest/v1/rpc/get_my_profile', {}, token)
        check('logged-out JWT cannot call protected profile RPC',
              profile_status == 403 and denial.get('code') == '42501')
        for path in ['/rest/v1/user_documents?select=id',
                     '/rest/v1/profiles?select=id',
                     '/rest/v1/rpc/consume_legal_ai_quota']:
            method = 'POST' if '/rpc/' in path else 'GET'
            status, _, denial = call(method, path, {} if method == 'POST' else None, token)
            check('logged-out JWT denied at ' + path.split('?')[0],
                  status == 403 and denial.get('code') == '42501')
        status, _, fresh = call('POST', '/auth/v1/token?grant_type=password',
                               {'email': email, 'password': password})
        check('fresh login after global logout', status == 200 and bool(fresh.get('access_token')))
        status, _, profile = call('POST', '/rest/v1/rpc/get_my_profile', {}, fresh['access_token'])
        check('fresh session reads own profile', status == 200 and profile['id'] == uid)
        # Auth/AI and PostgREST can treat the same revoked session differently.
        # Record each boundary; Auth rejection does not prove REST revocation.
        return {'passed': len(results), 'checks': results,
                'access_after_logout_http': access_status,
                'ai_after_logout_http': ai_status,
                'profile_after_logout_http': profile_status,
                'auth_api_immediate_access_revocation': access_status in (401, 403),
                'rest_access_valid_until_jwt_expiry': profile_status == 200}
    finally:
        sql("DELETE FROM auth_guard.attempt_windows WHERE action='signup' AND scope='identifier' AND identity_hash=auth_guard.identity_key('" + signup_email + "')", False)
        if uid:
            status, _, _ = call('DELETE', '/auth/v1/admin/users/' + uid, admin=True)
            if status not in (200, 204):
                raise RuntimeError('Disposable user cleanup failed')
            status, _, _ = call('GET', '/auth/v1/admin/users/' + uid, admin=True)
            if status != 404:
                raise RuntimeError('Disposable user cleanup not verified')
