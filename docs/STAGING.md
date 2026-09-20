# LexHub staging tayyorlash — 2026-09-20

**Repository konfiguratsiyasi tayyor; ajratilgan Supabase staging NOT VERIFIED.**
Ushbu ishda project/branch yaratilmadi, migration/deploy yoki production nusxasi
olinmadi. Preview deployment nomi database isolation dalili emas.

## Joriy holat

`env/dev.json` va `env/prod.json` bir production hostini ishlatadi. Ularni
staging deb ishlatmang. Avvalgi read-only inventory'da faqat 1 production
Supabase loyiha va 0 branch topilgan. Bu boshqa admin hisobidagi infratuzilmani
inkor qilmaydi. Vercel'da uch client env yozuvi production+preview targetiga
biriktirilgan edi; yangi qiymatlarning remote holati NOT VERIFIED.

## Admin tayyorlaydigan izolyatsiya

1. Alohida Supabase staging project ajrating; productiondan boshqa project ref,
   API key, Auth userlar va Storage bucketlar bo'lsin. Sintetik ma'lumot ishlating.
   Production backup nusxasi oddiy staging uchun shart emas; recovery rehearsal
   alohida cheklangan muhitda bajariladi.
2. Staging SMTP/scheduler/webhook/payment tashqi ta'sirlarini o'chirilgan yoki
   test transportlariga yo'naltirilgan holatda tasdiqlang. Production Gemini,
   payment yoki mail secretlarini ko'chirmang. `legal-ai` staging projectiga
   alohida tasdiqlangan release orqali chiqariladi; bu ishda deploy qilinmadi.
3. `env/staging.json.example`dan ignored `env/staging.json` yarating. Uch client
   qiymatini faqat stagingga moslang. `env/prod.json` va `env/dev.json` o'zgarmaydi.
   `SUPABASE_ANON_KEY` faqat publishable/anon, server/service-role key emas.
4. Vercel **Preview** targetida shu uch qiymatni Productiondan ajrating.
   Production target qiymatlariga tegmang. Preview uchun qo'shimcha
   `LEXHUB_PRODUCTION_SUPABASE_URL`ni haqiqiy production URL bilan belgilang;
   bu taqqoslash uchun control qiymati, client JS'ga uzatilmaydi. Uni uydirma
   URL bilan to'ldirish isolationni isbotlamaydi. Branch override'larni ham tekshiring.
5. Vercel system env `VERCEL_ENV=preview` buildga uzatilishini tasdiqlang.
   Build production hosti bilan bir xil DBni, boshqa projectdagi AI endpointni,
   yo'q production control qiymatini rad etadi. Staging AI URL shakli:
   `https://<staging-ref>.supabase.co/functions/v1/legal-ai` yoki
   `https://<staging-ref>.functions.supabase.co/legal-ai`.

Kalitning aynan qaysi projectga tegishliligi, custom domain aliaslari va Auth
settings faqat URL tekshiruvi bilan isbotlanmaydi; admin dashboard/runtime
dalili ham kerak. Guard custom proxylarni avtomatik ishonchli deb olmaydi.

## Lokal konfiguratsiya va build tekshiruvi

Quyidagi Python kodi qiymatlarni chiqarmasdan izolyatsiya tekshiruvi va aynan
Vercel build yo'lini bajaradi. Targetdagi Auth/AI'ga so'rov yubormaydi.
`<pinned-sdk-path>`ni [DEPLOY.md](DEPLOY.md)dagi revision SDK yo'liga almashtiring.

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

Bo'sh template buildga yetarli emas; placeholder haqiqiy konfiguratsiya deb
hisoblanmaydi. Production ma'lumotini templatega yoki Git'ga qo'ymang.

## Database upgrade rehearsal

- [STAGE1_DATABASE.md](STAGE1_DATABASE.md)dagi yetti history gapni DBA DDL bilan
  solishtiradi. Local `rebuild.sql`ning cloud/empty guardi chetlab o'tilmaydi.
- Alohida cloud staging uchun boshlang'ich schema va migration-history mapping
  DBA tomonidan review qilinishi kerak: local bootstrapdan tayyorlangan schema
  exportini yoki tasdiqlangan baseline'ni ishlating. Production data/secret
  export qilinmaydi. Bu reviewed baseline hozir remote'da mavjudligi NOT VERIFIED.
- Candidate-oldi staging baseline'da preflight 10/10; so'ng ruxsatlangan staging
  operatori `20260919001000` → `20260919002000`ni har biri alohida transactionda
  qo'llaydi. Postflightning joriy nusxasi 9/9 kutiladi. History/DDL mos kelmasa STOP.
- A/B/moderator sintetik hisoblar bilan answer edit/accept/switch, begona UPDATE,
  forged author INSERT, expert verification/rating INSERT, apply/approve/cooldown,
  verified booking fee va anon RPC denial Auth/PostgREST orqali tekshiriladi.
- Huquqiy parcha/URL, service step, draft/source, model prose fallback va account
  switch smoke bajariladi. Logs faqat status/son/ref beradi; user matni/token yo'q.

Mavjud gated live testlar production konfiguratsiyasiga qarshi YOQILMAYDI.
Staging ref'i qayta tekshirilgach faqat shu target va sintetik fixturelar bilan
kerakli write testlar operator tomonidan alohida bajariladi. PGlite PASS
Auth/PostgREST, SMTP, Storage yoki cloud recovery isboti emas.
