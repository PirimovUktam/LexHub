# Web release (Vercel)

Bu runbook build va web release uchun. Supabase migration, Auth policy yoki
provider secretlarini o'zgartirish web deployning bir qismi emas.

## Reproduktiv build

`vercel.json` build command sifatida `python3 tool/vercel_build.py`, output
sifatida `build/web`ni belgilaydi. Skript Flutter `3.45.0-0.1.pre`, revision
`2948345beccc28a13af34024f61080f62282b58b`ni tekshiradi; SDK drift, noto'g'ri
client key va bo'sh artifactda build to'xtaydi.

| Variable | Client bundle | Manba |
|---|---|---|
| `SUPABASE_URL` | Ha | Target backend API URL |
| `SUPABASE_ANON_KEY` | Ha | Shu backendning public/publishable yoki anon key'i |
| `LEGAL_AI_PROXY_URL` | Ha | Target backenddagi `legal-ai` endpointi |
| `LEXHUB_PRODUCTION_SUPABASE_URL` | Yo'q | Preview izolyatsiyasi uchun nazorat URL'i |

Private/service-role va AI provider kalitlari bu jadvalga kirmaydi.
Preview va Production qiymatlari alohida scope'da boshqariladi; shared
variable qiymatini almashtirish Productionga ham ta'sir qilishi mumkin.
[Staging izolyatsiyasi](STAGING.md) builddan oldin tekshiriladi.

Repository konfiguratsiyasida `git.deploymentEnabled.main = true`.
Bu remote Vercel project setting yoki oxirgi deployment holati tasdig'i emas.
Git trigger faqat remote loyiha, branch, build command va env to'g'ri
sozlanganda ishlaydi. Bu faylni o'qish push/deploy ruxsati bermaydi.

Lokal, faqat build uchun (qiymatlar outputga chiqarilmaydi):

```python
import json, os, subprocess
from pathlib import Path
config = json.loads(Path('env/prod.json').read_text(encoding='utf-8-sig'))
environment = dict(os.environ)
for name in ('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'LEGAL_AI_PROXY_URL'):
    environment[name] = config[name]
subprocess.run(['python', 'tool/vercel_build.py', '--flutter-sdk', '<pinned-sdk-path>'],
               env=environment, check=True)
```

## Vakolatli release tartibi

1. Toza, tekshirilgan commit/worktree'dan yuqoridagi buildni yarating.
2. `flutter analyze`, Flutter/Python testlar va secret/client bundle scan o'tsin.
   Production buildda staging host, test config yoki private key bo'lmasin.
3. Mavjud production deployment ID va artifact hashlarini private release
   yozuviga qayd eting. Source checkpoint `9ce9f10` rollback manbasi bo'lib
   qoladi; u avtomatik ravishda joriy ishlaydigan artifact degani emas.
4. Faqat deploy ruxsati bilan, oldindan yaratilgan `build/web` katalogini
   to'g'ri Vercel projectga link qiling va deploy qiling. Static artifact uchun
   amaldagi `vercel.json` security headers saqlansin; root Flutter build
   commandini static katalogda qayta bajarmang.
5. Avval `vercel deploy --prod --skip-domain` orqali artifactni tayyorlash,
   so'ng tekshirilgan deploymentni `vercel promote` bilan public aliasga
   o'tkazish mumkin. Qiymatlar va targetni taxmin qilmang.
6. [Production sayt](https://lexhub-theta.vercel.app) HTTP 200, startup,
   Auth/profile, asosiy navigation va security smoke'dan o'tsin. Remote
   `main.dart.js` hamda release manifest hashlarini aynan lokal build bilan
   solishtiring; commit metadata mos bo'lsin.

## Rollback

Vakolatli operator nosoz web release'da oldindan saqlangan ishlaydigan
Vercel deploymentga rollback qiladi. Main branchni force/reset qilish yoki
DB migrationni avtomatik qaytarish kerak emas. Web rollback Edge Function,
database va secretlarni qaytarmaydi. Har bir sirt alohida review qilinadi.

Build/tool regressiyalari: [TESTING.md](TESTING.md).
Android tarqatish: [RELEASE_SIGNING.md](RELEASE_SIGNING.md).
