#!/usr/bin/env python3
"""ANON KALIT — YOZISH IMTIYOZI PROBE'LARI (2-faza).

NIMA UCHUN: 1-faza o'lchadi — `anon` roli `profiles` dan TASHQARI barcha
jadvalda TABLE-LEVEL huquqqa EGA (PostgREST `42501` bermadi). Ya'ni
maxfiylik VA yaxlitlik butunlay RLS policy'lariga tayanadi. Yozish tomoni
hech qachon jonli o'lchanmagan
(`20260830100000_rls_never_enabled_tables.sql:62` — "Grant'lar jonli bazada
o'lchanmagan (NOT VERIFIED)").

TO'RT NATIJA HOLATI AJRATILADI (birlashtirish soxta xulosa beradi):
  * GRANT-RAD      — `42501` / `permission denied`: rol huquqi YO'Q;
  * RLS-RAD        — `42501 new row violates row-level security policy`
                     yoki PostgREST RLS xatosi: huquq bor, POLICY rad etdi;
  * CHEKLOV-GACHA  — `23502`/`23503`/`23514`/`PGRST204`: so'rov CONSTRAINT
                     bosqichigacha YETDI, ya'ni yozish yo'li OCHIQ bo'lishi
                     mumkin (RLS aniqlanmadi) — bu HAM signal;
  * YOZILDI        — qator KIRDI: bu P0.

XAVFSIZLIK QARORLARI (ataylab):
  * `answers` va `votes` ga INSERT YUBORILMAYDI — ularda hisoblagich
    triggerlari bor (`trg_handle_answer_counter`, `trg_handle_vote_counter`)
    va muvaffaqiyatli yozuv HAQIQIY savol qatorini o'zgartiradi.
  * `client_error_logs` ATAYLAB ijobiy nazorat sifatida sinaladi: loyiha
    dizayni bo'yicha anon INSERT qila OLADI (`20260830010000:140`). Agar u
    ham rad etilsa — probe'ning O'ZI buzuq, ya'ni boshqa "rad etildi"
    natijalari VAKUUM bo'lardi.
  * Har bir yuboriladigan qiymat `LEXHUB_ANON_PROBE_2026-09-02` bilan
    BELGILANADI va yozilib qolsa DARHOL o'chirishga urinib ko'riladi;
    o'chirish natijasi HALOL yozib boriladi.
"""
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK = 'LEXHUB_ANON_PROBE_2026-09-02'

with open(os.path.join(ROOT, 'env', 'prod.json'), encoding='utf-8') as fh:
    CFG = json.load(fh)

BASE = CFG['SUPABASE_URL'].rstrip('/')
ANON = CFG['SUPABASE_ANON_KEY']
H = {'apikey': ANON, 'Authorization': 'Bearer ' + ANON,
     'Content-Type': 'application/json', 'Accept': 'application/json'}

ZERO_UUID = '00000000-0000-0000-0000-000000000000'

# (jadval, payload, kutilgan_natija_izohi)
#
# USTUN NOMLARI TUZATILDI (2026-09-02): birinchi yurishda taxmin qilingan
# nomlar (`amount_uzs`, `event_type`, `description`, `body`, `question_id`,
# `name`) JONLI sxemada YO'Q va PostgREST `PGRST204` qaytardi. Bu DRIFT
# EMAS — `supabase/schema.sql` ham xuddi shu nomlarni bermaydi, ya'ni
# taxminim XATO edi. `PGRST204` schema-cache bosqichida, HUQUQ tekshiruvidan
# OLDIN qaytadi — shuning uchun u yozish imtiyozi haqida HECH NARSA
# aytmaydi va natija sifatida hisoblanmaydi.
#
# `client_error_logs` ijobiy nazorati ATAYLAB OLIB TASHLANDI: u dizayn
# bo'yicha YOZILADI (`GRANT INSERT ... TO anon`), lekin o'sha migratsiya
# DELETE policy BERMAYDI ("yozuv o'zgartirilmaydi — audit izi"), ya'ni
# qator O'CHIRILMAY QOLADI. Qaytarib bo'lmaydigan production yozuvi
# alohida ruxsat talab qiladi. Probe'ning VAKUUM emasligi boshqacha
# isbotlangan: `profiles` -> GRANT-RAD, uch jadval -> RLS-RAD, ya'ni
# detektor QATLAMLARNI ajratadi va bir xilda "rad etildi" bermaydi.
INSERT_PROBES = [
    ('profiles', {'id': ZERO_UUID, 'full_name': MARK},
     'GRANT qaytarib olingan (20260829120000) — GRANT-RAD kutiladi'),
    ('question_categories', {'name_uz': MARK},
     'ma\'lumotnoma — mehmon YOZMASLIGI kerak'),
    ('question_tags', {'name': MARK, 'slug': MARK},
     'ma\'lumotnoma — mehmon YOZMASLIGI kerak'),
    ('question_tag_mappings', {'question_id': ZERO_UUID, 'tag_id': ZERO_UUID},
     'ma\'lumotnoma — mehmon YOZMASLIGI kerak'),
    ('bookmarks', {'user_id': ZERO_UUID, 'item_type': 'question',
                   'item_id': ZERO_UUID, 'title': MARK},
     'SHAXSIY — mehmon YOZMASLIGI kerak'),
    ('reports', {'target_type': 'question', 'target_id': ZERO_UUID,
                 'reason': MARK},
     'moderatsiya — mehmon YOZMASLIGI kerak (spam yuzasi)'),
    ('payments', {'amount_tiyin': 1, 'status': 'pending'},
     'MOLIYA — mehmon YOZSA P0 (to\'lov holati manipulyatsiyasi)'),
    ('payment_audit_logs', {'action': MARK},
     'AUDIT IZI — mehmon YOZSA P0 (iz soxtalashtirish)'),
    ('user_documents', {'title': MARK},
     'SHAXSIY hujjat — mehmon YOZMASLIGI kerak'),
    ('user_notifications', {'user_id': ZERO_UUID, 'title': MARK,
                            'message': MARK},
     'mehmon boshqa foydalanuvchiga xabar YOZMASLIGI kerak'),
    ('questions', {'title': MARK, 'description': MARK},
     'forum spam yuzasi — mehmon YOZMASLIGI kerak'),
    ('consultations', {'status': 'pending'},
     'mehmon uchrashuv BAND QILMASLIGI kerak'),
    ('expert_profiles', {'specialization': MARK},
     'mehmon o\'zini ADVOKAT deb yozmasligi kerak'),
]

RLS_TOKENS = ('row-level security', 'row level security')


def classify(status, code, message):
    low = (message or '').lower()
    if status in (200, 201, 204):
        return 'YOZILDI (P0)'
    if any(tok in low for tok in RLS_TOKENS):
        return 'RLS-RAD'
    if code == '42501' or 'permission denied' in low:
        return 'GRANT-RAD'
    # `PGRST204` schema-cache bosqichida, HUQUQ tekshiruvidan OLDIN qaytadi:
    # ustun nomi noto'g'ri. Bu NATIJA EMAS — probe'ning O'ZI xato.
    if code == 'PGRST204':
        return 'PROBE-XATO'
    if code in ('23502', '23503', '23514', '23505'):
        return 'CHEKLOV-GACHA'
    if code.startswith('PGRST'):
        return 'PROBE-XATO'
    return 'BOSHQA(' + str(status) + ')'


def request(method, path, body=None, prefer=None):
    headers = dict(H)
    if prefer:
        headers['Prefer'] = prefer
    data = json.dumps(body).encode('utf-8') if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers=headers,
                                 method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            return resp.status, '', '', resp.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as err:
        raw = err.read().decode('utf-8', 'replace')
        try:
            obj = json.loads(raw)
            return err.code, str(obj.get('code', '')), str(obj.get('message', '')), raw
        except ValueError:
            return err.code, '', raw[:150], raw
    except Exception as err:
        return -1, 'TRANSPORT', type(err).__name__ + ': ' + str(err)[:100], ''


def cleanup(table, payload):
    """Yozilib qolgan probe qatorini o'chirishga urinish."""
    key = 'message' if table == 'client_error_logs' else (
        'name' if 'name' in payload else (
            'title' if 'title' in payload else (
                'reason' if 'reason' in payload else (
                    'event_type' if 'event_type' in payload else None))))
    if key is None:
        return 'O\'CHIRISH KALITI YO\'Q — QOLDIQ bo\'lishi mumkin'
    status, code, message, _ = request(
        'DELETE', '/rest/v1/{}?{}=eq.{}'.format(
            table, key, urllib.request.quote(MARK)))
    if status in (200, 204):
        return 'o\'chirildi (HTTP {})'.format(status)
    return 'O\'CHIRILMADI HTTP {} {} {} -> QOLDIQ'.format(status, code, message[:60])


def main():
    print('=== INSERT PROBE\'LARI (anon kalit, production) ===')
    print('belgi: ' + MARK + '\n')
    residue = []
    for table, payload, note in INSERT_PROBES:
        status, code, message, _ = request(
            'POST', '/rest/v1/' + table, body=payload,
            prefer='return=minimal')
        verdict = classify(status, code, message)
        print('{:16} {:14} HTTP {:4} {:8} {}'.format(
            table, verdict, status, code, message[:78]))
        print('                 kutilgan: ' + note)
        if verdict == 'YOZILDI (P0)':
            result = cleanup(table, payload)
            print('                 TOZALASH: ' + result)
            if 'QOLDIQ' in result:
                residue.append(table)
        print()

    print('=== QOLDIQ ===')
    print('qoldiq qolgan jadvallar: ' + (', '.join(residue) if residue
                                         else 'YO\'Q'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
