# LEXHUB — `legal-ai` LATENCY DRAYVERINI ajratish probe'i (diagnostika vositasi).
#
# NIMA UCHUN KERAK: production'da o'lchangan (2026-08-26) — `gemini-3.7-flash`
# to'liq so'rov uchun `LEGAL_AI_TIMEOUT_MS=40000` byudjetiga sig'mayapti va
# client HAR SAFAR deterministik fallback oladi. Savol: byudjetni yorib
# o'tayotgan narsa so'rov VAZNIMI (prompt + chunk'lar + uzun JSON javob), yoki
# model umuman javob bermay osilib qolayaptimi?
#
# NIMA QILADI: BITTA probe sessiyasi bilan AYNI endpoint'ga bir necha xil
# vaznli payload yuboradi va HAR BIRI uchun aniq o'tgan vaqtni o'lchaydi.
# Production secret'lariga TEGMAYDI (`LEGAL_AI_MODEL` ham o'zgartirilmaydi).
#
# KALIT: `GEMINI_API_KEY` bu skriptga HECH QACHON kerak emas — u serverda
# yashaydi. Bu yerda faqat anon key + probe user sessiyasi ishlatiladi.
# PROJECT REF repo'ga YOZILMAYDI — `env/prod.json`dan olinadi (gitignore'da).
#
# ISHLATISH:
#   python tool/probe_legal_ai_latency.py

import json
import os
import time
import urllib.error
import urllib.request

PASSWORD = 'Password123!'
# Client `receiveTimeout` 55s; server byudjeti 50s. 75s beramiz — kesishni HAR
# DOIM server bajarishi kerak, aks holda `error.code` yo'qoladi.
HTTP_TIMEOUT = 75

CHUNK_LONG = (
    "Ish haqi har oyda kamida ikki marta, mehnat shartnomasida belgilangan "
    "muddatlarda to'liq to'lanadi. Ish beruvchi ish haqini kechiktirgan har bir "
    "kun uchun qonunda belgilangan miqdorda kompensatsiya to'laydi. Mehnat "
    "shartnomasi bekor qilinganda barcha hisob-kitoblar ishdan bo'shatilgan "
    "kunda amalga oshiriladi."
)


def post(url, body, headers, timeout=HTTP_TIMEOUT):
    """Status, tana va O'TGAN VAQTni (ms) qaytaradi."""
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), method='POST',
        headers={'Content-Type': 'application/json', **headers})
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode(), (time.monotonic() - t0) * 1000
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(), (time.monotonic() - t0) * 1000
    except Exception as e:                                # noqa: BLE001
        return 0, f'{type(e).__name__}: {e}', (time.monotonic() - t0) * 1000


def chunk(n, title, content):
    return {
        'document_name': "O'zbekiston Respublikasining Mehnat kodeksi",
        'article_number': n,
        'article_title': title,
        'content': content,
        'lex_url': 'https://lex.uz',
    }


# Payload'lar YENGILDAN OG'IRGA. Birinchisi cold start'ni ham o'ziga oladi,
# shuning uchun keyingilari uchun o'lchov TOZAROQ bo'ladi.
CASES = [
    (
        'yengil: 1 chunk, qisqa savol',
        'Ish haqi berilmayapti',
        [chunk(161, "Ish haqini to'lash muddatlari",
               "Ish haqi belgilangan muddatda to'liq to'lanadi.")],
    ),
    (
        "o'rta: 1 chunk, uzun matn",
        'Ish beruvchi meni asossiz ishdan bo\'shatdi va 2 oylik ish haqimni '
        'bermayapti',
        [chunk(161, "Ish haqini to'lash muddatlari", CHUNK_LONG)],
    ),
    (
        "og'ir: 3 chunk (live test bilan AYNI)",
        'Ish beruvchi meni asossiz ishdan bo\'shatdi va 2 oylik ish haqimni '
        'bermayapti',
        [
            chunk(161, "Ish haqini to'lash muddatlari", CHUNK_LONG),
            chunk(333, "Mehnat shartnomasini bekor qilish asoslari", CHUNK_LONG),
            chunk(560, "Mehnat nizolarini ko'rib chiqish", CHUNK_LONG),
        ],
    ),
]


def main():
    cfg = json.load(open('env/prod.json', encoding='utf-8-sig'))
    url = cfg['SUPABASE_URL'].rstrip('/')
    anon = cfg['SUPABASE_ANON_KEY']
    proxy = cfg['LEGAL_AI_PROXY_URL']

    # YANGI HISOB YARATILMAYDI (o'zgartirildi 2026-09-04): har yurish
    # `legalai_lat_<ts>@lexhub.uz` qoldirardi va bu hisoblar bazada MANGU
    # qolardi — `email_confirmed_at IS NOT NULL` + REPO'DA turgan ma'lum
    # parol = parolni tiklash orqali egallash yuzasi. Shuning uchun MAVJUD
    # `commwrite_probe_*` hisobi QAYTA ISHLATILADI (`test/integration/
    # cleanup_live_test_data_test.dart:47-56` da ro'yxati bor, ayni parol).
    # Boshqa hisob kerak bo'lsa: `LEXHUB_PROBE_EMAIL=... python ...`.
    email = os.environ.get(
        'LEXHUB_PROBE_EMAIL',
        'commwrite_probe_a_1788353108280359@lexhub.uz',
    )
    st, body, _ = post(f'{url}/auth/v1/token?grant_type=password',
                       {'email': email, 'password': PASSWORD},
                       {'apikey': anon})
    token = json.loads(body).get('access_token') if st == 200 else None
    if not token:
        print(f'BLOCKED: mavjud probe sessiyasi olinmadi (status={st}) '
              f'{body[:160]}')
        return 1
    print(f'probe user = {email} (MAVJUD, yangi hisob yaratilmadi)\n')

    headers = {'Authorization': f'Bearer {token}', 'apikey': anon}
    for label, query, chunks in CASES:
        st, body, ms = post(proxy, {
            'query_text': query,
            'category': 'Mehnat huquqi',
            'retrieved_chunks': chunks,
        }, headers)
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {}
        chars = sum(len(c['content']) for c in chunks) + len(query)
        head = f'{label:42} in={chars:5}b  {ms:7.0f} ms  -> {st}'
        if st == 200:
            print(f'{head}  OK source={parsed.get("source")} '
                  f'moddalar={len(parsed.get("legal_basis", []))} '
                  f'xulosa={len(parsed.get("relatable_summary", ""))}b')
        else:
            err = parsed.get('error', {})
            print(f'{head}  {err.get("code")} {err.get("message", "")[:60]}')
            # `LEGAL_AI_DEBUG_UPSTREAM=1` yoqilgan bo'lsa bu maydonlar keladi.
            for k in ('upstream_status', 'upstream_variant', 'upstream_model',
                      'upstream_detail'):
                if k in err:
                    print(f'{"":42}    {k} = {err[k]}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
