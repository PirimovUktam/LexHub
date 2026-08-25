---
name: lexhub-demo-audit
description: Hakamlar/investor demosidan OLDIN LexHub'ning har bir e'lon qilingan imkoniyatini real ishlashiga qarab tekshiradi va rostgo'y "capability matrix" tuzadi — nima haqiqatan ishlaydi, nima deterministik/shablon, nima bo'sh. Da'vo bilan realitet orasidagi tafovutni (masalan "AI" deb nomlangan hardcoded matn, bo'sh jadval, ma'lumotsiz ekran) topadi va demo oldidan tuzatish ro'yxatini beradi.
---

# LexHub — demo rostgo'ylik auditi

Maqsad: hakam «buni ko'rsating» deganda ishlamaydigan yoki e'lon qilinganidan
boshqacha ishlaydigan hech narsa qolmasligi. Da'vo–realitet tafovuti demo'da
topilsa, butun loyihaga bo'lgan ishonchni yo'qotadi.

## 1. Da'volarni yig'

Da'vo manbalari: UI matnlari (`lib/l10n/arb/app_uz.arb`), navigatsiya nomlari,
README, pitch deck, taqdimot skripti.

```bash
python -c "
import json;d=json.load(open('lib/l10n/arb/app_uz.arb',encoding='utf-8-sig'))
for k,v in d.items():
    if k.startswith('@'): continue
    s=str(v)
    if any(t in s.lower() for t in ['ai','intellekt','avtomatik','tahlil']) and len(s)<200: print(f'{k:32} {s[:100]}')
"
```

## 2. Har bir da'vo uchun MANBANI kuzat

Har bir "AI/avtomatik/tahlil" matni ortida nima turganini kodda TOP:

- haqiqiy tashqi model chaqiruvi (`dio.post(... generativelanguage ...)`) — va u release'da
  ishlaydimi (`kReleaseMode` shartlarini tekshir)?
- deterministik qoida / kalit so'z shoxlari?
- to'g'ridan-to'g'ri string literal (eng xavfli holat)?

Ma'lum misol: `community_forum_remote_datasource.dart:389` va
`ask_community_dialog.dart:186` — `ai_summary` string literal, lekin UI'da
"LexHub AI tezkor xulosasi" deb ko'rsatiladi.

## 3. Ma'lumot mavjudligini live tekshir (read-only)

```bash
python -c "
import json,urllib.request,urllib.error
c=json.load(open('env/prod.json'));u,k=c['SUPABASE_URL'],c['SUPABASE_ANON_KEY']
for t in ['law_article_chunks','questions','answers','expert_profiles','categories','citizen_services','document_templates']:
    r=urllib.request.Request(f'{u}/rest/v1/{t}?select=*&limit=1',headers={'apikey':k,'Authorization':f'Bearer {k}','Prefer':'count=exact','Range':'0-0'})
    try: print(f'{t:22}', urllib.request.urlopen(r,timeout=20).headers.get('Content-Range'))
    except urllib.error.HTTPError as e: print(f'{t:22} HTTP {e.code}')
"
```

Bo'sh jadval = demo'da bo'sh ekran. Har bir bo'sh jadval uchun: seed qilinadimi yoki
o'sha ekran demo skriptidan olib tashlanadimi — QAROR yoz.

## 4. Capability matrix (yakuniy artefakt)

| Imkoniyat | UI da'vosi | HAQIQIY mexanizm | Live evidence | Demo'ga tayyor |
|---|---|---|---|---|
| ... | ... | LLM / deterministik qoida / string literal / bo'sh | buyruq + chiqish | HA / YO'Q / RISK |

"Deterministik qoida" — kamchilik EMAS: yuridik domenda bu ataylab tanlangan,
hallucination qilmaydigan yechim. Kamchilik — uni **AI deb nomlash**.

## 5. Demo oldidan tuzatish tartibi

1. **Nomlanishni haqiqatga moslash** (eng arzon, eng tez): har bir "AI" yorlig'i ortida
   real model chaqiruvi bo'lmasa, matnni o'zgartir. `uz` + `en` pariteti majburiy
   (`flutter test test/l10n`).
2. Bo'sh jadvallarni seed qil YOKI o'sha ekranni demo yo'lidan chiqar.
3. `README.md`ni to'ldir — hozir Flutter shablon matni turadi; hakam birinchi
   ochadigan fayl shu.
4. `lexhub-verify` bilan yakuniy o'tkazish (analyze + test + live + APK hash).
5. Demo skriptini yoz: har bir qadam uchun kutilgan natija + agar internet/backend
   yiqilsa nima ko'rsatiladi (fallback).

## 6. Hakam savollariga tayyorlik

Har bir «RISK» yoki «YO'Q» band uchun bitta rostgo'y jumla tayyorla:
nima ishlaydi, nima hali yo'q, nega shunday qaror qilingan, keyingi qadam nima.
Yashirish emas — sanoq bilan aytish. Bu texnik yetuklik sifatida qabul qilinadi.
