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
