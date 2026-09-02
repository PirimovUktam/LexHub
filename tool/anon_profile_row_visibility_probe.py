#!/usr/bin/env python3
"""ANON KALIT — `profiles` QATOR KO'RINISHI + EMBEDDED JOIN REGRESSIYASI.

NIMA UCHUN KERAK: `20260903000000_profiles_anon_row_visibility.sql` ikki
narsani BIRDAN o'zgartiradi — (a) mehmon uchun `profiles` qatorlarini
cheklaydi, (b) `authenticated` xulqini SAQLAB qoladi. Ikkinchisi buzilsa
forum tasmasida muallif ismi BO'SH bo'ladi va `!inner` join BUTUN qatorni
yo'qotadi. Shuning uchun bitta probe IKKI tomonni ham o'lchaydi:
  * ENUMERATSIYA yopildimi (profil soni, `role=eq.admin`, ism qidiruvi);
  * REGRESSIYA yo'qmi (ilovadagi AYNAN embedded join shakllari).

QO'LLASHDAN OLDIN va KEYIN bir xil yurgiziladi — natijalar TAQQOSLANADI.

PII QOIDASI: qator qiymatlari CHOP ETILMAYDI. Faqat SON, HTTP kodi va
`null / non-null` xulosasi chiqadi (CLAUDE.md — PII logga yozilmaydi).

Join shakllari repo'dan AYNAN olindi (o'lchandi, 2026-09-03):
  community_forum_remote_datasource.dart:227,250,358,380,575,678
    -> select('*, profiles(full_name, role, is_verified, avatar_url)')
  legal_experts_remote_datasource.dart:280 -> 'profiles!inner(full_name)'
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
H = {'apikey': ANON, 'Authorization': 'Bearer ' + ANON,
     'Accept': 'application/json'}


def get(path, count=False):
    headers = dict(H)
    if count:
        headers['Prefer'] = 'count=exact'
    req = urllib.request.Request(BASE + path, headers=headers, method='GET')
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            raw = resp.read().decode('utf-8', 'replace')
            rng = resp.headers.get('Content-Range', '')
            return resp.status, rng, raw
    except urllib.error.HTTPError as err:
        return err.code, '', err.read().decode('utf-8', 'replace')
    except Exception as err:                                   # transport
        return -1, '', type(err).__name__ + ': ' + str(err)[:120]


def err_code(raw):
    try:
        obj = json.loads(raw)
        return str(obj.get('code', '')) + ' ' + str(obj.get('message', ''))[:60]
    except ValueError:
        return raw[:60]


def counted(label, path, note=''):
    status, rng, raw = get(path, count=True)
    if status in (200, 206):
        total = rng.split('/')[-1] if '/' in rng else '?'
        print('  {:46} son={:>5}  {}'.format(label, total, note))
        return total
    print('  {:46} HTTP {}  {}'.format(label, status, err_code(raw).strip()))
    return None


def embedded(label, path, key='profiles'):
    """Join ISHLAYAPTIMI: qator soni + `profiles` non-null soni."""
    status, _, raw = get(path)
    if status not in (200, 206):
        print('  {:46} HTTP {}  {}'.format(label, status,
                                           err_code(raw).strip()))
        return None
    try:
        rows = json.loads(raw)
    except ValueError:
        print('  {:46} JSON EMAS'.format(label))
        return None
    if not isinstance(rows, list):
        print('  {:46} ro\'yxat EMAS'.format(label))
        return None
    filled = sum(1 for r in rows if isinstance(r, dict) and r.get(key))
    print('  {:46} qator={:>3}  `{}` non-null={:>3}'.format(
        label, len(rows), key, filled))
    return len(rows), filled


def main():
    print('=== 1. ENUMERATSIYA (kam bo\'lishi MAQSAD) ===')
    counted('profiles: JAMI ko\'rinadigan qator',
            '/rest/v1/profiles?select=id')
    counted('profiles: role=eq.admin', '/rest/v1/profiles?role=eq.admin'
            '&select=id', '<- 0 bo\'lishi MAQSAD')
    counted('profiles: role=eq.moderator',
            '/rest/v1/profiles?role=eq.moderator&select=id')
    counted('profiles: full_name ism qidiruvi (ilike *a*)',
            '/rest/v1/profiles?full_name=ilike.*a*&select=id')
    counted('profiles: is_verified=eq.true',
            '/rest/v1/profiles?is_verified=eq.true&select=id')

    print('\n=== 2. EMBEDDED JOIN — REGRESSIYA (ishlashi SHART) ===')
    embedded('questions + profiles(...) [forum tasmasi]',
             '/rest/v1/questions?is_anonymous=eq.false'
             '&select=id,profiles(full_name,role,is_verified,avatar_url)'
             '&limit=20')
    embedded('answers + profiles(...)',
             '/rest/v1/answers?select=id,profiles(full_name,role)&limit=20')
    embedded('expert_profiles + profiles!inner(full_name)',
             '/rest/v1/expert_profiles?select=id,profiles!inner(full_name)'
             '&limit=20')

    print('\n=== 3. MEHMON OQIMI TIRIKMI (o\'zgarmasligi SHART) ===')
    counted('public_questions_view: JAMI',
            '/rest/v1/public_questions_view?select=id')
    counted('questions: JAMI (baza jadvali)', '/rest/v1/questions?select=id')
    counted('question_categories: JAMI',
            '/rest/v1/question_categories?select=id')
    # `id` ustuni YO'Q (o'lchandi: `pg_attribute` -> `expert_id`). Xato ustun
    # nomi 42703 beradi va tekshiruv VAKUUM bo'lib qoladi.
    counted('public_expert_profiles_view: JAMI',
            '/rest/v1/public_expert_profiles_view?select=expert_id')

    print('\n=== 4. IJOBIY NAZORAT (detektor ko\'r emasligi) ===')
    status, _, raw = get('/rest/v1/profiles?select=phone&limit=1')
    code = err_code(raw).split(' ')[0] if status not in (200, 206) else ''
    print('  profiles?select=phone -> HTTP {} {}  {}'.format(
        status, code,
        'DETEKTOR ISHLAYDI' if code == '42501' else 'EHTIYOT: 42501 emas'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
