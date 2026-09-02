# LEXHUB — `legal-ai` uchun MODEL NOMINI ANIQLASH probe'i (vaqtinchalik vosita).
#
# NIMA UCHUN KERAK: bu Supabase CLI versiyasida `supabase functions logs` YO'Q,
# ya'ni upstream (Google) qaysi model uchun 404, qaysi biri uchun 503 qaytarganini
# faqat funksiyaning DEBUG javobidan bilish mumkin
# (`LEGAL_AI_DEBUG_UPSTREAM=1`).
#
# NIMA QILADI: bitta probe foydalanuvchi sessiyasi ochadi va berilgan model
# nomlarini KETMA-KET sinaydi. Har bir nom uchun `LEGAL_AI_MODEL` secret'i
# o'rnatiladi (redeploy SHART EMAS — faqat yangi isolate kerak).
#
# KALIT: `GEMINI_API_KEY` bu skriptga HECH QACHON kerak bo'lmaydi — u faqat
# serverda yashaydi. Bu yerda faqat anon key va probe user sessiyasi ishlatiladi.
#
# ISHLATISH:
#   python tool/probe_legal_ai_model.py gemini-3.7-flash gemini-3.6-flash

import json
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

# PROJECT REF repo'ga YOZILMAYDI — `env/prod.json`dagi SUPABASE_URL dan
# olinadi (u gitignore'da). Shu sababli bu fayl xavfsiz commit qilinadi.
PASSWORD = 'Password123!'

# Windows'da `supabase` npm shim'i `.cmd` fayl — `CreateProcess` uni to'g'ridan
# ishga tushira olmaydi, shuning uchun aniq yo'lni topamiz.
SUPABASE = (shutil.which('supabase') or shutil.which('supabase.cmd')
            or 'supabase')


def post(url, body, headers, timeout=90):
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), method='POST',
        headers={'Content-Type': 'application/json', **headers})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def main():
    models = sys.argv[1:]
    if not models:
        print('Model nomlari berilmadi.')
        return 2

    cfg = json.load(open('env/prod.json'))
    url = cfg['SUPABASE_URL'].rstrip('/')
    ref = url.split('//')[1].split('.')[0]
    anon = cfg['SUPABASE_ANON_KEY']
    proxy = cfg['LEGAL_AI_PROXY_URL']

    email = f'legalai_probe_{int(time.time())}@lexhub.uz'
    st, body = post(f'{url}/auth/v1/signup', {'email': email, 'password': PASSWORD},
                    {'apikey': anon})
    token = json.loads(body).get('access_token') if st == 200 else None
    if not token:
        st, body = post(f'{url}/auth/v1/token?grant_type=password',
                        {'email': email, 'password': PASSWORD}, {'apikey': anon})
        token = json.loads(body).get('access_token')
    if not token:
        print(f'BLOCKED: probe sessiyasi olinmadi (status={st})')
        return 1
    print(f'probe user = {email}\n')

    payload = {
        'query_text': 'Ish beruvchi ish haqini bermayapti',
        'category': 'Mehnat huquqi',
        'retrieved_chunks': [{
            'document_name': "O'zbekiston Respublikasining Mehnat kodeksi",
            'article_number': 161,
            'article_title': 'Ish haqini to\'lash',
            'content': 'Ish haqi belgilangan muddatda to\'liq to\'lanadi.',
            'lex_url': 'https://lex.uz',
        }],
    }
    headers = {'Authorization': f'Bearer {token}', 'apikey': anon}

    for model in models:
        subprocess.run([SUPABASE, 'secrets', 'set', f'LEGAL_AI_MODEL={model}',
                        '--project-ref', ref],
                       capture_output=True, text=True, shell=False)
        time.sleep(6)  # yangi isolate `MODEL`ni qayta o'qishi uchun
        st, body = post(proxy, payload, headers)
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {}
        if st == 200:
            print(f'{model:26} -> 200 OK  source={parsed.get("source")} '
                  f'moddalar={len(parsed.get("legal_basis", []))}')
            return 0
        err = parsed.get('error', {})
        used = err.get('upstream_model', '?')
        detail = str(err.get('upstream_detail', ''))[:110].replace('\n', ' ')
        print(f'{model:26} -> {st} {err.get("code")} '
              f'upstream={err.get("upstream_status")} used={used}')
        if detail:
            print(f'{"":26}    {detail}')
    return 1


if __name__ == '__main__':
    sys.exit(main())
