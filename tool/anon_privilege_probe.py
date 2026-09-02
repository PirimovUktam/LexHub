#!/usr/bin/env python3
"""ANON KALIT IMTIYOZLARINI LIVE BAZADA O'LCHASH (read-only faza).

NIMA UCHUN: `sb_publishable_` (anon) kalit release artefaktida OCHIQ turadi
(2026-09-02 da o'lchandi: `main.dart.js` ichida ochiq matn, `libapp.so` ichida
3 ABI). Ya'ni kalitni har qanday foydalanuvchi chiqarib oladi va yakuniy
chegara FAQAT RLS bo'lib qoladi. `p0_security_remediation_test.dart` esa
faqat `schema.sql` MATNINI qulflaydi — LIVE holat o'lchanmagan.

QOIDA (loyiha CLAUDE.md): PII va legal content LOGGA YOZILMAYDI. Shuning
uchun bu skript qator QIYMATLARINI hech qachon chop etmaydi — faqat:
  * HTTP status,
  * qaytgan qator SONI,
  * ustun NOMLARI,
  * PostgREST xato `code`/`message`.

Bu faza HECH NARSA YOZMAYDI — faqat GET.
"""
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, 'env', 'prod.json'), encoding='utf-8') as fh:
    CFG = json.load(fh)

BASE = CFG['SUPABASE_URL'].rstrip('/')
ANON = CFG['SUPABASE_ANON_KEY']

# ANON = autentifikatsiyasiz mijoz. `Authorization` ham anon kalit bilan
# yuboriladi, chunki mijoz sessiyasiz aynan shunday so'rov yuboradi.
HEADERS = {
    'apikey': ANON,
    'Authorization': 'Bearer ' + ANON,
    'Accept': 'application/json',
}

TABLES = [
    'answers', 'bookmarks', 'citizen_services', 'consultations',
    'document_templates', 'expert_profiles', 'expert_schedules',
    'law_article_chunks', 'payment_audit_logs', 'payments', 'profiles',
    'question_categories', 'question_tag_mappings', 'question_tags',
    'questions', 'reports', 'service_steps', 'user_documents',
    'user_notifications', 'votes',
    # Migratsiya bilan qo'shilgan telemetriya cho'kmasi — anon O'QIMASLIGI kerak.
    'client_error_logs',
]

VIEWS = ['public_expert_profiles_view', 'public_questions_view']


def probe_read(name):
    """`GET /rest/v1/<name>?select=*&limit=1` — qiymatlar chop ETILMAYDI."""
    url = '{}/rest/v1/{}?select=*&limit=1'.format(BASE, name)
    req = urllib.request.Request(url, headers=dict(HEADERS, **{
        'Prefer': 'count=exact',
    }))
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode('utf-8', 'replace')
            rng = resp.headers.get('Content-Range', '')
            rows = json.loads(body) if body.strip() else []
            cols = sorted(rows[0].keys()) if rows and isinstance(rows[0], dict) else []
            return {
                'status': resp.status,
                'rows': len(rows),
                'count_header': rng,
                'columns': cols,
                'code': '',
                'message': '',
            }
    except urllib.error.HTTPError as err:
        raw = err.read().decode('utf-8', 'replace')
        try:
            payload = json.loads(raw)
        except ValueError:
            payload = {}
        return {
            'status': err.code,
            'rows': 0,
            'count_header': '',
            'columns': [],
            'code': str(payload.get('code', ''))[:40],
            'message': str(payload.get('message', ''))[:120],
        }
    except Exception as err:  # tarmoq xatosi — YASHIRILMAYDI
        return {
            'status': -1, 'rows': 0, 'count_header': '', 'columns': [],
            'code': 'TRANSPORT', 'message': type(err).__name__ + ': ' + str(err)[:100],
        }


def main():
    results = []
    for kind, names in (('JADVAL', TABLES), ('VIEW', VIEWS)):
        for name in names:
            res = probe_read(name)
            res['kind'] = kind
            res['name'] = name
            results.append(res)
            # UCH HOLATNI AJRATISH SHART (birlashtirish soxta xulosa beradi):
            #   * `42501 permission denied` -> anon'da TABLE-LEVEL huquq YO'Q;
            #   * HTTP 200/206 + qator BOR -> anon HAQIQIY qator O'QIDI;
            #   * HTTP 200 + 0 qator -> huquq BOR, lekin RLS filtrladi YOKI
            #     jadval BO'SH. Bu IKKI holat bu probe bilan AJRALMAYDI
            #     (PostgREST RLS-deny uchun ham HTTP 200 + `[]` qaytaradi) —
            #     shuning uchun "YOPIQ" deb YOZILMAYDI.
            if res['status'] in (200, 206) and res['rows'] > 0:
                verdict = 'QATOR O\'QILDI'
            elif res['status'] in (200, 206):
                verdict = 'HUQUQ BOR / 0 QATOR (noaniq)'
            else:
                verdict = 'HUQUQ YO\'Q'
            print('{:6} {:34} HTTP {:4} {:28} rows={} {}'.format(
                kind, name, res['status'], verdict, res['rows'],
                (res['code'] + ' ' + res['message']).strip()[:70]))
            if res['status'] == 200 and res['columns']:
                print('       -> ustunlar: ' + ', '.join(res['columns']))
            if res['count_header']:
                print('       -> Content-Range: ' + res['count_header'])

    out = os.path.join(ROOT, 'build', 'anon_probe_read.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump(results, fh, indent=2, ensure_ascii=False)
    print('\nnatija: ' + out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
