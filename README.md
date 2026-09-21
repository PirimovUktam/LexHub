# LexHub

<img src="assets/images/app_logo.png" alt="LexHub" width="88">

**Huquqiy muammodan manbaga, tushuntirishga va keyingi amaliy qadamga.**

LexHub — O'zbekiston foydalanuvchilari uchun Flutter asosidagi huquqiy yordam
platformasi. Qonun matnini topish va undan keyin nima qilishni tushunish orasidagi
masofani qisqartiradi: savol, manbalar, hujjat loyihasi va mutaxassislar katalogi
bitta ilovada jamlangan.

**[Ishlayotgan web ilova va demo](https://lexhub-theta.vercel.app)** ·
[Testlar](docs/TESTING.md) · [Staging](docs/STAGING.md) · [Web release](docs/DEPLOY.md)

## Asosiy imkoniyatlar

- **Huquqiy yordam:** savol va foydalanuvchi faktlari asosida manbali tushuntirish,
  xavf va keyingi qadamlar. Dalil yetishmasa xavfsiz fallback ishlatiladi.
- **Manba va hujjat:** qonun havolalari bilan tanishish, hujjat shablonlarini
  to'ldirish va saqlangan ishlarni qayta ochish. Hujjat loyihasi qonun manbasi emas.
- **Hamjamiyat va mutaxassislar:** savol-javob, ekspert profillari va konsultatsiya
  oqimlari. Xizmat mavjudligi tegishli backend va operator konfiguratsiyasiga bog'liq.
- **Shaxsiy kabinet:** profilni tahrirlash, private avatar va hisobga ajratilgan
  lokal tarix. Interfeys o'zbekcha va inglizcha, mobil hamda keng ekranlarga mos.

AI natijasi individual yurist maslahati yoki huquqiy kafolat hisoblanmaydi.
Muhim qaror oldidan keltirilgan rasmiy manba va malakali mutaxassis bilan tekshiring.

## Arxitektura

```text
Flutter UI → BLoC/Cubit → Use case / Repository → Data source
                                                ├─ Supabase Auth / PostgREST / Storage
                                                ├─ legal-ai Edge Function → Gemini
                                                └─ Hive local storage
```

Feature'lar `presentation`, `domain`, `data` qatlamlariga ajratilgan.
GetIt dependency injectionni, `core/` umumiy konfiguratsiya, networking,
lokalizatsiya va xatolarni boshqaradi. Huquqiy javob yo'lida retrieval,
grounding va javob tekshiruvi bor; provider kaliti serverda qoladi.

**Stack:** Flutter/Dart, BLoC, GetIt, Supabase/PostgreSQL, Deno/TypeScript,
Dio/http, Hive va Flutter localization. Web artifact Vercel orqali tarqatiladi.

## Lokal ishga tushirish

Release toolchain'i `tool/vercel_build.py`da Flutter **3.45.0-0.1.pre**,
revision `2948345beccc28a13af34024f61080f62282b58b` bilan pin qilingan.

1. Shu SDK'ni va development qurilma/browserini tayyorlang.
2. `flutter pub get` bajaring.
3. `env/dev.json.example`dan ignored `env/dev.json` nusxasini yarating.
4. Alohida development/staging backendning `SUPABASE_URL`,
   `SUPABASE_ANON_KEY` (faqat public/publishable) va `LEGAL_AI_PROXY_URL`
   qiymatlarini kiriting. Production backendini development uchun ishlatmang.
5. Ilovani ishga tushiring:

```sh
flutter run --dart-define-from-file=env/dev.json
```

Flutter JSON faylni avtomatik o'qimaydi; explicit define'lar konfiguratsiyani
takrorlanadigan qiladi. Backend tayyorlash va Preview izolyatsiyasi:
[STAGING.md](docs/STAGING.md). Private/service/provider kalitlari Dart define,
asset yoki Git'ga kiritilmaydi.

## Xavfsizlik va tekshiruv

Serverda ownership/RLS, private avatar Storage policy'lari, auth abuse guardlari,
sessiya tekshiruvi va AI quota mavjud. Client guardlari server avtorizatsiyasini
almashtirmaydi. Lokal testning o'tishi remote policy yoki deployment dalili emas.

```sh
flutter analyze
flutter test
python -m unittest discover -s tool -p "test_*.py"
deno test --allow-env supabase/functions
python tool/validate_sql_syntax.py
```

Suite unit/widget, synthetic va security regression testlarini o'z ichiga oladi.
Remote write testlar default holatda oshkora skip qilinadi. Alohida lokal SQL,
staging va browser sinovlari: [TESTING.md](docs/TESTING.md).

## Repository tuzilishi

| Katalog | Vazifasi |
|---|---|
| `lib/core`, `lib/features` | Umumiy infratuzilma va feature qatlamlari |
| `lib/l10n` | ARB tarjimalari va generated localization |
| `supabase` | Edge Function, migration manbalari va verification SQL |
| `test` | Flutter regression, widget va gated integration testlar |
| `tool` | Build, lokal DB validation va staging/browser vositalari |
| `env/*.json.example` | Qiymatsiz konfiguratsiya shablonlari |
| `assets`, `web`, platform kataloglari | UI resurslari va platform sozlamalari |

[Database bootstrap](docs/STAGE1_DATABASE.md) faqat bo'sh lokal baza uchun.
[Android signing](docs/RELEASE_SIGNING.md) va [web deploy](docs/DEPLOY.md)
alohida release jarayonlari. Build/cache, lokal env, test dalillari va signing
materiallari source control'ga kiritilmaydi.
