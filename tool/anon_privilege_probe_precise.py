#!/usr/bin/env python3
"""ANON IMTIYOZI — ANIQLASHTIRUVCHI PROBE'LAR (read-only).

1-fazada (`anon_privilege_probe.py`) ko'p jadval `HTTP 200 + 0 qator`
qaytardi. Bu IKKI XIL narsani bildirishi mumkin va ularni ARALASHTIRISH
soxta xulosa beradi:
  (a) RLS anon uchun hamma qatorni FILTRLAYDI (himoya ishlaydi), yoki
  (b) jadval shunchaki BO'SH (himoya O'LCHANMAGAN).

Bu skript farqni AJRATADI va eng muhim ikki narsani sinaydi:
  * anonim savol himoya VIEW'i (`public_questions_view`) HAQIQATAN
    `user_id` / `author_name` ni yashiradimi;
  * `SECURITY DEFINER` RPC'lar (RLS'ni AYLANIB O'TADI) anon uchun
    ochiqmi va nima qaytaradi.

QOIDA: PII va legal content LOGGA YOZILMAYDI. Shuning uchun qator
qiymatlari CHOP ETILMAYDI — faqat SON, ustun NOMI va `null/non-null`
xulosasi.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, 'env', 'prod.json'), encoding='utf-8') as fh:
    CFG = json.load(fh)

BASE = CFG['SUPABASE_URL'].rstrip('/')
ANON = CFG['SUPABASE_ANON_KEY']
H = {'apikey': ANON, 'Authorization': 'Bearer ' + ANON,
     'Accept': 'application/json'}


def _call(method, path, body=None, prefer=None):
    url = BASE + path
    headers = dict(H)
    if prefer:
        headers['Prefer'] = prefer
    data = None
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers,
                                 method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            raw = resp.read().decode('utf-8', 'replace')
            return resp.status, resp.headers.get('Content-Range', ''), raw
    except urllib.error.HTTPError as err:
        return err.code, '', err.read().decode('utf-8', 'replace')
    except Exception as err:
        return -1, '', type(err).__name__ + ': ' + str(err)[:120]


def count_only(label, path, expect_zero, why):
    """Faqat SONNI o'lchaydi — qiymat chop etilmaydi."""
    status, rng, raw = _call('GET', path, prefer='count=exact')
    total = rng.split('/')[-1] if '/' in rng else '?'
    if status in (200, 206):
        ok = (total == '0') if expect_zero else (total not in ('0', '?'))
        mark = 'OK' if ok else '!!! MUAMMO'
        print('{:2} {:52} son={:>4}  {}'.format(mark, label, total, why))
        return total, status
    err = ''
    try:
        err = str(json.loads(raw).get('code', '')) + ' ' + \
            str(json.loads(raw).get('message', ''))[:70]
    except ValueError:
        err = raw[:70]
    print('-- {:52} HTTP {}  {}'.format(label, status, err.strip()))
    return None, status


def null_summary(rows):
    """Har ustun uchun `null` / `non-null` xulosasi — QIYMAT YO'Q."""
    if not rows or not isinstance(rows[0], dict):
        return {}
    out = {}
    for key in rows[0]:
        vals = [r.get(key) for r in rows]
        out[key] = 'HAMMASI null' if all(v is None for v in vals) else \
            ('non-null BOR' if any(v is not None for v in vals) else '?')
    return out


def probe_rpc(name, args, note):
    status, _, raw = _call('POST', '/rest/v1/rpc/' + name, body=args)
    if status in (200, 206):
        try:
            payload = json.loads(raw)
        except ValueError:
            payload = None
        if isinstance(payload, list):
            print('OCHIQ  rpc {:32} HTTP {} qator={}  {}'.format(
                name, status, len(payload), note))
            summary = null_summary(payload)
            if summary:
                for key in sorted(summary):
                    print('           {:28} {}'.format(key, summary[key]))
        else:
            print('OCHIQ  rpc {:32} HTTP {} skalyar tur={} {}'.format(
                name, status, type(payload).__name__, note))
            if isinstance(payload, bool):
                print('           qiymat = {}'.format(payload))
    else:
        code = message = ''
        try:
            obj = json.loads(raw)
            code, message = str(obj.get('code', '')), str(obj.get('message', ''))[:80]
        except ValueError:
            message = raw[:80]
        print('YOPIQ  rpc {:32} HTTP {} {} {}'.format(
            name, status, code, message.strip()))


def main():
    print('=== A. ANONIM SAVOL HIMOYA VIEW\'i — SIZIB CHIQISH SINOVI ===')
    count_only('view: is_anonymous=true VA user_id NOT NULL',
               '/rest/v1/public_questions_view?is_anonymous=eq.true'
               '&user_id=not.is.null&select=id', True,
               '<- 0 BO\'LMASA anonim muallif OSHKOR')
    quoted = urllib.parse.quote('Anonim fuqaro')
    count_only('view: is_anonymous=true VA author_name!=Anonim fuqaro',
               '/rest/v1/public_questions_view?is_anonymous=eq.true'
               '&author_name=neq.' + quoted + '&select=id', True,
               '<- 0 BO\'LMASA haqiqiy ism OSHKOR')
    count_only('view: JAMI qator', '/rest/v1/public_questions_view?select=id',
               False, '<- bo\'sh bo\'lsa sinov VAKUUM')
    count_only('view: is_anonymous=true qatorlar',
               '/rest/v1/public_questions_view?is_anonymous=eq.true&select=id',
               False, '<- 0 bo\'lsa yuqoridagi ikki sinov VAKUUM')

    print('\n=== B. BAZA `questions` JADVALI — RLS filtrlaydimi yoki BO\'SHMI ===')
    count_only('questions: JAMI (anon ko\'zi bilan)',
               '/rest/v1/questions?select=id', True,
               '<- 0 = anon baza jadvalidan hech nima olmadi')
    count_only('questions: is_anonymous=false (ommaviy bo\'lishi kerak)',
               '/rest/v1/questions?is_anonymous=eq.false&select=id', True, '')
    count_only('answers: JAMI', '/rest/v1/answers?select=id', True, '')

    print('\n=== C. SECURITY DEFINER RPC\'lar — RLS\'ni AYLANIB O\'TADI ===')
    probe_rpc('is_admin_or_moderator', {},
              '<- anon uchun MAJBURIY false')
    probe_rpc('global_lexhub_search', {'query_text': 'mehnat',
                                       'limit_count': 5},
              '<- anonim muallif chiqmasligi kerak')
    probe_rpc('global_search', {'query_text': 'mehnat', 'filter_type': 'all',
                                'match_limit': 5},
              '<- anonim muallif chiqmasligi kerak')

    print('\n=== D. YOZISH IMTIYOZI YO\'Q ekanini xato KODI bilan o\'lchash ===')
    print('(bu fazada YOZILMAYDI — 2-faza alohida ruxsat bilan)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
