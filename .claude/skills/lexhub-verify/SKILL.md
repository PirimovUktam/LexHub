---
name: lexhub-verify
description: LexHub uchun CLAIM≠EVIDENCE verifikatsiya konveyeri. Biror feature/fix "ishlaydi", "fixed", "deployed" yoki "VERIFIED" deb e'lon qilinishidan OLDIN ishlatiladi. flutter analyze + default test suite + gated live production testlar + release APK secret scan'ni ketma-ket bajaradi va har bir band uchun VERIFIED / PARTIALLY VERIFIED / BLOCKED / NOT VERIFIED verdikt beradi. Shuningdek "test o'tdi, demak ishlaydi" degan xulosa chiqarilmoqchi bo'lganda ham chaqiriladi.
---

# LexHub — verifikatsiya konveyeri

CLAUDE.md qoidasi: kod mavjudligi, migration fayli mavjudligi, unit/mock test, `flutter analyze = 0`
**isbot EMAS**. VERIFIED faqat 5 shart bajarilganda: real muhit, real runtime execution,
kutilgan natija, negative/security stsenariy, qayta takrorlanadigan evidence.

## 1. Statik qatlam (isbot emas, regressiya qo'riqchisi)

```bash
flutter analyze
```
```bash
flutter test --reporter compact
```

Kutilgan: `No issues found!` va `+N ~M: All other tests passed!`.
`~M` — `test/support/live_gate.dart` ostidagi OSHKORA skip'lar. Ular jim skip emas:
har bir gated fayl `skip:` sababini reporter'ga chiqaradi. Default run production'ga TEGMAYDI.

**Bu bosqich yashil bo'lsa "feature ishlaydi" deb YOZMA.** Faqat "regressiya yo'q".

## 2. Live production qatlam (haqiqiy isbot)

```bash
flutter test test/integration --dart-define-from-file=env/prod.json --dart-define=LEXHUB_LIVE_WRITE_TESTS=true --reporter expanded
```

Bir fayl uchun yo'lni almashtir. `LEXHUB_LIVE_WRITE_TESTS` — `bool.fromEnvironment`
compile-time konstantasi, shell env bilan chetlab o'tilmaydi.

DIQQAT: bu REAL Supabase Cloud'ga YOZADI (probe auth user, savollar). Faqat ataylab.

Evidence sifatida `stdout.writeln` chiqargan `EVIDENCE ...` qatorlarini AYNAN ko'chir.
UUID'lar redaktsiya qilingan holda (`first8…last4`) chiqadi — to'liq ID yozma.

## 3. Release binary qatlami

```bash
flutter build apk --release --dart-define-from-file=env/prod.json
```
```bash
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Secret scan: APK'ni **ochib** skanerla (siqilgan zip'da 3 harfli qidiruv soxta hit beradi):

```bash
rm -rf build/_apkscan && mkdir -p build/_apkscan && unzip -q -o build/app/outputs/flutter-apk/app-release.apk -d build/_apkscan && for p in service_role eyJ AIza GEMINI_API_KEY sb_secret_ PAYME BEGIN_PRIVATE; do printf '%-18s %s\n' "$p" "$(grep -rao "$p" build/_apkscan | wc -l)"; done
```

Har bir hit uchun KONTEKSTNI ko'r (`grep -rao ".\{0,40\}<p>.\{0,60\}"`) va nima ekanini yoz.
Ma'lum va xavfsiz hitlar: `eyJ` → libapp.so symbol table'dagi `…KeyJ` bo'lagi;
`sb_secret_` → SDK prefiks konstantasi (`supabase/lib/src/api_key.dart:5`);
`sb_publishable_` → dizayn bo'yicha public anon key. Oxirida `rm -rf build/_apkscan`.

## 4. Verdikt jadvali

Har bir band uchun ayni shu formatda yoz:

| Band | Verdikt | Evidence |
|---|---|---|
| <nima> | VERIFIED / PARTIALLY VERIFIED / BLOCKED / NOT VERIFIED | <buyruq + real chiqish qatori> |

- Environment/data yetishmasa → **BLOCKED**, `markTestSkipped` sababi bilan. PASS deb yozma.
- Faqat statik test o'tgan bo'lsa → **PARTIALLY VERIFIED**.
- Hech qanday runtime chiqish bo'lmasa → **NOT VERIFIED**.

Hech qachon mavjud bo'lmagan log, stack trace yoki server javobini o'ylab topma.
