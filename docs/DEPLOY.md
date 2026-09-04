# LEXHUB — WEB DEPLOY (Vercel)

## O'LCHANGAN HODISA (2026-09-02) — `main` ga PUSH SAYTNI O'LDIRARDI

`https://lexhub-theta.vercel.app` `404: NOT_FOUND` (`X-Vercel-Error: NOT_FOUND`)
qaytardi. Sabab zanjiri O'LCHANDI:

1. Vercel loyihasi (`lexhub`, `prj_oDtTAi3Av7pWR6rPdTorOKaeLgZS`) GitHub
   `main` shoxiga BOG'LANGAN — buni `lexhub-git-main-*.vercel.app` alias'i
   isbotlaydi.
2. Har `git push origin main` 4 sekund ichida YANGI Production deployment
   yaratardi. Vaqt mosligi (`vercel ls` va `git log`):

   | deployment | vaqt | commit |
   |---|---|---|
   | `lexhub-ayonuemio` | 22:33:58 | `4755e97` @ 22:33:54 |
   | `lexhub-5uob6nxmj` | 22:59:48 | `b4d0230` @ 22:59:44 |
   | `lexhub-j26wnxz0i` | 23:23:16 | `17b95ef` @ 23:23:12 |
   | `lexhub-8iy2lh1qh` | 23:26:27 | `1e65b40` @ 23:26:23 |

3. Bu Git deployment'lari repo ILDIZIDAN quriladi. Ildizda `index.html` YO'Q,
   Flutter web chiqishi esa `build/web` da va u gitignore'da (`.gitignore:53`
   -> `/build/`). `vercel.json` ham yo'q edi, ya'ni Vercel'ga "Flutter'ni qur"
   deb aytilmagan. Natijada deployment BO'SH chiqardi
   (`vercel inspect` -> `Builds: . [0ms]`).
4. Bo'sh Production deployment ishlaydigan CLI deployment'idan Production
   alias'ini TORTIB OLADI. Shundan keyin `/`, `/index.html`, `/main.dart.js`,
   `/favicon.png` — HAMMASI 404.

Ya'ni sayt "o'zidan" buzilmagan: har push uni qayta o'ldirardi.

## TUZATISH

`vercel.json` (repo ildizi) `main` uchun Git avto-deploy'ni O'CHIRADI:

```json
{ "git": { "deploymentEnabled": { "main": false } } }
```

Qulf: `test/support/vercel_deploy_config_test.dart` — bu sozlama o'chib
qolsa test QIZIL bo'ladi.

## TO'G'RI DEPLOY QILISH

Production faqat CLI orqali yangilanadi (ishlab turgan yo'l shu edi):

```bash
flutter build web --release --dart-define-from-file=env/prod.json
cd build/web && vercel deploy --prod --yes
```

`build/web/.vercel/project.json` loyihaga bog'lab qo'yilgan, shuning uchun
`build/web` ichidan yurgizish SHART (repo ildizidan emas).

Tekshirish:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://lexhub-theta.vercel.app/
```

## TEZ ORTGA QAYTISH (ROLLBACK)

Ikki mustaqil sirt bor va ULAR ALOHIDA qaytariladi: web (Vercel) va
`legal-ai` Edge Function (Supabase). Bittasini qaytarish ikkinchisiga
TA'SIR QILMAYDI.

`<REF>` — Supabase project ref, `env/prod.json` (gitignored) ichidan:

```bash
python -c "import json;print(json.load(open('env/prod.json',encoding='utf-8-sig'))['SUPABASE_URL'].split('//')[1].split('.')[0])"
```

### 1. WEB (Vercel) — bir buyruq, ~10 sekund

Production alias'ni oldingi ISHLAGAN deployment'ga qaytaradi (qayta
build QILMAYDI — tayyor artefakt allaqachon Vercel'da turadi):

```bash
vercel rollback <deployment-url> --scope pirimovuktams-projects --yes
```

Holatni ko'rish: `vercel rollback status lexhub --scope pirimovuktams-projects`

MA'LUM YAXSHI NUQTALAR (`vercel ls` bilan yangilanadi):

| deployment | nima bor |
|---|---|
| `lexhub-b1f8yotcy-pirimovuktams-projects.vercel.app` | `64d61de` — mehmonga AI kirish taklifi. `main.dart.js` SHA256 `05269b6c…d22e` (4 233 716 B), jonli == lokal O'LCHANGAN |
| `lexhub-i09ycxobn-pirimovuktams-projects.vercel.app` | undan oldingi Production |

Tekshirish (200 kutiladi):

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://lexhub-theta.vercel.app/
```

### 2. EDGE FUNCTION (`legal-ai`)

HALOL CHEKLOV: Supabase CLI'da `functions rollback` YO'Q. Qaytish = eski
manbani OLDINGA deploy qilish; `version` raqami PASAYMAYDI (38 -> 39 -> 40).

MA'LUM YAXSHI NUQTA: **version 38**, `ezbr_sha256`
`c567596420564380d1921aca2b1f68dd04246c664aa94ddc221879d391ee0464`.
O'LCHANGAN (2026-09-04): v38 manbasi `supabase functions download` bilan
yuklab olindi va commit `64d61de` bilan solishtirildi — izohlardan tashqari
KOD AYNAN BIR XIL. Ya'ni git shu nuqtaning ishonchli manbasi.

```bash
git stash                      # ishdagi o'zgarishlar saqlanadi
git checkout 64d61de -- supabase/functions/legal-ai/
supabase functions deploy legal-ai --project-ref <REF>
git checkout HEAD -- supabase/functions/legal-ai/ && git stash pop
```

Jonli manbani ISHDAGI daraxtga TEGMASDAN yuklab olish (tekshirish uchun):

```bash
mkdir -p /tmp/fn && cp supabase/config.toml /tmp/fn/supabase/ 2>/dev/null
supabase functions download legal-ai --project-ref <REF> --workdir /tmp/fn
```

### 3. SECRETS (model zanjiri) — deploy TALAB QILMAYDI

Model nomlari kodda emas, secret'da. Ya'ni Gemini kvotasi tugasa
funksiyani QAYTA DEPLOY QILMASDAN model almashtiriladi:

```bash
supabase secrets set LEGAL_AI_MODEL=gemini-3.7-flash --project-ref <REF>
supabase secrets set LEGAL_AI_MODEL_FALLBACK=gemini-3.6-flash --project-ref <REF>
```

O'LCHANGAN (2026-09-04): Gemini bepul kvotasi HAR MODEL uchun ALOHIDA —
`gemini-3.6-flash` 429 "You exceeded your current quota" berganda
`gemini-3.7-flash` AYNI daqiqada 200 qaytardi. Shuning uchun zanjirni
almashtirish haqiqiy tiklash yo'li.

Tekshirish: `python tool/probe_legal_ai_latency.py` (3 so'rov; `200 source=llm`
kutiladi). DIQQAT: har yurish kunlik kvotani sarflaydi.

## E'TIBOR — HALOL CHEKLOVLAR

* Git deploy'ni QAYTA yoqish uchun `vercel.json` dagi `git` kalitini olib
  tashlash yetarli. Lekin avval Vercel build'ida Flutter SDK va
  `env/prod.json` qiymatlari (Vercel env sifatida) bo'lishi kerak — aks
  holda bo'sh deployment muammosi QAYTADI.
* Jonli sayt CanvasKit'ni Google CDN'dan oladi
  (`www.gstatic.com/flutter-canvaskit/.../canvaskit.wasm` — O'LCHANDI),
  garchi `build/web/canvaskit/` ham yuklangan bo'lsa ham. Ya'ni har bir
  tashrifchi Google'ga so'rov yuboradi. Buni uzish uchun
  `--no-web-resources-cdn` kerak — HOZIRCHA QILINMAGAN.
* Deployment URL'lari (`lexhub-<hash>-*.vercel.app`) Vercel SSO bilan
  himoyalangan (302 -> `vercel.com/sso-api`), Production alias esa ochiq.
  Bu Vercel'ning "Deployment Protection" sozlamasi.
