# Development va staging izolyatsiyasi

Bu hujjat target konfiguratsiyasi va tekshiruv usulini belgilaydi; muayyan
cloud projectning joriy holati yoki release ruxsati sifatida ishlatilmaydi.
Project identity, access, billing va runtime dalillari private operator
yozuvida saqlanadi. Production staging o'rniga ishlatilmaydi.

## Backend va client konfiguratsiyasi

- Alohida Supabase staging project: productiondan boshqa project ref/URL,
  key, database, Auth foydalanuvchilari va Storage obyektlari.
- `env/staging.json.example`dan ignored `env/staging.json` tayyorlang.
  `SUPABASE_URL`, `SUPABASE_ANON_KEY` va `LEGAL_AI_PROXY_URL` bir xil staging
  projectga tegishli bo'lsin. Publishable key client uchun; service key emas.
- Auth site URL/redirect allowlist faqat kerakli localhost/Preview manzillarini
  qamrasin. Storage bucket/policy va Auth/session konfiguratsiyasi reviewed
  baseline bilan tayyorlanadi. Production foydalanuvchi ma'lumotlari ko'chirilmaydi.
- `legal-ai` aynan stagingda ishlasin. `GEMINI_API_KEY` faqat shu Edge Function
  secret store'ida; Dart define, Vercel client env yoki asset ichida emas.
- Baseline/history bo'yicha [database runbook](STAGE1_DATABASE.md)dan
  foydalaning. Lokal bootstrapning cloud guardini chetlab o'tmang.

## Vercel Preview

| Variable | Preview qiymati |
|---|---|
| `SUPABASE_URL` | Staging API URL |
| `SUPABASE_ANON_KEY` | Shu stagingning public/publishable key'i |
| `LEGAL_AI_PROXY_URL` | Shu stagingning `legal-ai` endpointi |
| `LEXHUB_PRODUCTION_SUPABASE_URL` | Faqat build izolyatsiyasini tekshirish uchun production URL |

`VERCEL_ENV=preview`ni platforma belgilaydi. Productionga tegishli shared
qiymatni almashtirmang; Preview uchun alohida target yozuvlari va branch
override'larini tekshiring. Guard bir xil backend, begona AI host, noto'g'ri
URL yoki nazorat URL'i yo'qligida buildni rad etadi.

Qiymatlarni chiqarmasdan lokal Preview build:

```python
import json, os, subprocess
from pathlib import Path
staging = json.loads(Path('env/staging.json').read_text(encoding='utf-8-sig'))
production = json.loads(Path('env/prod.json').read_text(encoding='utf-8-sig'))
environment = dict(os.environ, VERCEL_ENV='preview')
environment['LEXHUB_PRODUCTION_SUPABASE_URL'] = production['SUPABASE_URL']
for name in ('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'LEGAL_AI_PROXY_URL'):
    environment[name] = staging[name]
subprocess.run(['python', 'tool/vercel_build.py', '--flutter-sdk', '<pinned-sdk-path>'],
               env=environment, check=True)
```

Pinned SDK va release workflow: [DEPLOY.md](DEPLOY.md).
Placeholder bilan build o'tishi ishlaydigan staging dalili emas.

## Qabul mezonlari

- Build `build/web`ni yaratadi; client bundle'da production host/private key yo'q.
- Browser Auth/REST/Storage/AI so'rovlari faqat stagingga ketadi.
- Oddiy synthetic A/B hisoblari bilan login, profil persistence, private avatar,
  cross-user denial, logout/session va huquqiy yordam oqimlari tekshiriladi.
- `tool/profile_staging_smoke.py --browser` mavjud pinned staging guardiga ega.
  Target/env mosligini tekshirib ishlating; service credential faqat test process
  muhitiga beriladi. Harness o'z vaqtinchalik hisob/fayllarini tozalaydi.
- HAR, browser storage state, token, parol yoki user matnini public artifactga
  saqlamang. Vercel Protectionni o'chirmang; ruxsatli session yo'q bo'lsa lokal
  staging build orqali browser tekshiruvini bajaring.

Test buyruqlari va ularning chegaralari: [TESTING.md](TESTING.md).
Backup/restore rehearsal alohida izolyatsiyalangan target va tasdiqlangan DBA
rejasini talab qiladi; staging smoke recovery muvaffaqiyatini isbotlamaydi.
