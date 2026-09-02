#!/usr/bin/env python3
"""ANON KALIT — UPDATE/DELETE TABLE-LEVEL HUQUQI (0-QATORLI PROBE).

NIMA UCHUN KERAK: `tool/anon_write_probe.py` faqat INSERT ni o'lchadi. Ya'ni
`anon` da UPDATE/DELETE huquqi bor-yo'qligi JONLI bazada HECH QACHON
o'lchanmagan edi (`20260830100000_rls_never_enabled_tables.sql:64` —
"Grant'lar jonli bazada o'lchanmagan (NOT VERIFIED)"). Migratsiya
`20260903001000_revoke_anon_write_grants.sql` shu huquqni qaytarib oladi;
huquq bor-yo'qligini bilmasdan uni "tuzatish" §0 buzilishi bo'lardi.

NIMA UCHUN MA'LUMOTGA XAVFSIZ (asosiy dizayn qarori):
  * FILTR HAR DOIM `id=is.null`, ya'ni `WHERE id IS NULL`. Bu jadvallarda
    `id` — NOT NULL PRIMARY KEY, demak shart HAR QANDAY qator uchun FALSE:
    mos keladigan qator NOL. PostgreSQL 0 qatorni yangilaydi/o'chiradi.
  * `FOR EACH ROW` triggerlar 0 qatorda ISHLAMAYDI; repo'da `FOR EACH
    STATEMENT` trigger BITTA HAM yo'q (grep, 2026-09-03).
  * Skript ishga tushishdan oldin filtrni O'ZI tekshiradi (pastdagi
    `assert`), ya'ni keyinchalik kimdir filtrni "yumshatib" qo'ysa —
    skript ishlamaydi, jimgina qator o'chirmaydi.

NATIJANI O'QISH:
  * `GRANT-RAD`    — `42501`/permission denied: anon da huquq YO'Q (maqsad).
  * `GRANT MAVJUD` — HTTP 200/204: huquq BOR (0 qator o'zgardi). RLS bu
                     yerda HECH NARSA aytmaydi: 0 qator + RLS-rad bir xil
                     ko'rinadi. Aynan shu — defence-in-depth uchun sabab.
  * `PROBE-XATO`   — `PGRST204`/`42703`: ustun/`id` nomi xato. Bu NATIJA
                     EMAS (huquq tekshiruvidan OLDIN qaytadi).
"""
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK = 'LEXHUB_ZERO_ROW_PROBE_2026-09-03'
IMPOSSIBLE = '?id=is.null'

# VAKUUM QARSHI ASSERT: filtr o'zgarsa skript ISHLAMAYDI.
assert IMPOSSIBLE == '?id=is.null', 'FILTR O\'ZGARGAN — qator o\'chishi mumkin'

with open(os.path.join(ROOT, 'env', 'prod.json'), encoding='utf-8') as fh:
    CFG = json.load(fh)

BASE = CFG['SUPABASE_URL'].rstrip('/')
ANON = CFG['SUPABASE_ANON_KEY']
H = {'apikey': ANON, 'Authorization': 'Bearer ' + ANON,
     'Content-Type': 'application/json', 'Accept': 'application/json'}

# (jadval, PATCH uchun mavjud ustun) — ustun nomlari `anon_write_probe.py`
# da JONLI o'lchov bilan TUZATILGAN ro'yxatdan olindi.
TARGETS = [
    ('profiles', 'full_name'),
    ('questions', 'title'),
    ('answers', 'content'),
    ('question_categories', 'name_uz'),
    ('question_tags', 'name'),
    ('bookmarks', 'title'),
    ('reports', 'reason'),
    ('payments', 'status'),
    ('user_documents', 'title'),
    ('user_notifications', 'title'),
    ('consultations', 'status'),
    ('expert_profiles', 'specialization'),
    ('client_error_logs', 'message'),
]


def request(method, path, body=None):
    headers = dict(H)
    headers['Prefer'] = 'return=minimal'
    data = json.dumps(body).encode('utf-8') if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers=headers,
                                 method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            return resp.status, '', ''
    except urllib.error.HTTPError as err:
        raw = err.read().decode('utf-8', 'replace')
        try:
            obj = json.loads(raw)
            return err.code, str(obj.get('code', '')), str(obj.get('message', ''))
        except ValueError:
            return err.code, '', raw[:120]
    except Exception as err:
        return -1, 'TRANSPORT', type(err).__name__ + ': ' + str(err)[:90]


def classify(status, code, message):
    low = (message or '').lower()
    if code == '42501' or 'permission denied' in low:
        return 'GRANT-RAD'
    if code in ('PGRST204', '42703') or code.startswith('PGRST1'):
        return 'PROBE-XATO'
    if status in (200, 204):
        return 'GRANT MAVJUD'
    return 'BOSHQA(' + str(status) + ')'


def main():
    print('=== 0-QATORLI UPDATE/DELETE HUQUQ PROBE (anon, production) ===')
    print('filtr: ' + IMPOSSIBLE + '  (WHERE id IS NULL -> 0 qator)\n')
    print('{:20} {:14} {:14}'.format('jadval', 'PATCH', 'DELETE'))
    for table, column in TARGETS:
        p_status, p_code, p_msg = request(
            'PATCH', '/rest/v1/' + table + IMPOSSIBLE, body={column: MARK})
        d_status, d_code, d_msg = request(
            'DELETE', '/rest/v1/' + table + IMPOSSIBLE)
        print('{:20} {:14} {:14}  {} | {}'.format(
            table, classify(p_status, p_code, p_msg),
            classify(d_status, d_code, d_msg),
            (p_code or p_status), (d_code or d_status)))

    # IJOBIY NAZORAT — probe VAKUUM emasligini isbotlaydi: `profiles.phone`
    # dan anon SELECT huquqi QAYTARIB OLINGAN (`20260829120000`), demak shu
    # HTTP yo'li `42501` ni KO'RSATA OLADI. Agar bu ham 200 qaytarsa —
    # yuqoridagi "GRANT MAVJUD" natijalari ISHONCHSIZ.
    print('\n=== IJOBIY NAZORAT: GET profiles?select=phone (42501 kutiladi) ===')
    status, code, message = request('GET', '/rest/v1/profiles?select=phone&limit=1')
    print('HTTP {} {} {}'.format(status, code, message[:100]))
    print('detektor holati: ' + (
        'ISHLAYDI (42501 ko\'rindi)' if code == '42501'
        else 'TEKSHIRILMADI — yuqoridagi natijalarga EHTIYOT bilan qara'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
