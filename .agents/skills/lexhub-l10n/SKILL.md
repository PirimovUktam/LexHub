---
name: lexhub-l10n
description: LexHub'ga yangi UI matni qo'shish yoki mavjud matnni o'zgartirishning to'g'ri tartibi (ARB → gen-l10n → widget). uz va en pariteti, hardcoded string taqiqi, xato xabarlarini `FailureCode` orqali lokalizatsiya qilish. Widget ichida matn literal yozilmoqchi bo'lganda yoki `arb_parity_test` / `no_hardcoded_ui_strings_test` yiqilganda ishlatiladi.
---

# LexHub — lokalizatsiya tartibi

`uz` — shablon (template) til, `en` — to'liq ikkinchi UI tili. Til tanlovi **Hive**da
saqlanadi (`lexhub_settings` box, `app_locale` kalit) — `shared_preferences` faqat
dev_dependency, release build'da YO'Q, shuning uchun unga tayanma.

## Yangi matn qo'shish (tartib MUHIM)

1. `lib/l10n/arb/app_uz.arb` ga kalit qo'sh (+ `@kalit` description).
2. `lib/l10n/arb/app_en.arb` ga **AYNI SHU** kalitni tarjima bilan qo'sh.
   Tushib qolsa `gen-l10n` uni o'zbekcha qiymat bilan to'ldiradi va ingliz UI'da
   o'zbekcha matn ko'rinadi — buni hech kim sezmaydi.
3. ```bash
   flutter gen-l10n
   ```
4. Widget'da `context.l10n.<kalit>` ishlat. String literal YOZMA.
5. ```bash
   flutter test test/l10n
   ```

## Qulflangan invariantlar

| Test | Nimani qulflaydi |
|---|---|
| `test/l10n/arb_parity_test.dart` | uz ↔ en kalit pariteti (ikki tomonlama), bo'sh qiymat yo'q, tarjima qilinmagan (aynan bir xil) qiymatlar ro'yxati |
| `test/l10n/no_hardcoded_ui_strings_test.dart` | Widget qatlamida hardcoded matn — ZONA A: nol tolerantlik, ZONA B: har bir faylning literal soni |
| `test/l10n/locale_persistence_test.dart` | Til tanlovi Hive box yopilib-ochilgandan keyin saqlanadi |

`uz` va `en` da matn ataylab bir xil bo'lsa (atoqli nom, xalqaro qisqartma, namuna ism) —
`arb_parity_test.dart` ichidagi `_identicalAllowed` mapiga **SABABI bilan** qo'sh.
Sababsiz qo'shish taqiqlanadi; ro'yxat eskirsa alohida test yiqiladi.

ZONA B sonini oshirish faqat ataylab: `_pending` mapidagi son va
`expect(total, N)` ni birga yangila, izohda nima uchun oshganini yoz.
`tool/l10n_scan.py` bilan Dart porti bir xil son berishi SHART.

## Xato xabarlarini lokalizatsiya qilish

Xato matnini `Failure.message` ga yozib qo'yish bilan cheklanma — u tildan mustaqil
bo'lishi kerak:

1. `lib/core/errors/failure_code.dart` — `FailureCode` enum'iga kod qo'sh.
2. `lib/core/errors/error_handler.dart` — kodni markazda o'rnat (`_codeForStatus`).
3. Presentation qatlamida `failureText` / `errorStateText` / `failureMessageFor` orqali
   ARB matnini tanla. `uz` locale muallif yozgan sanitizatsiya qilingan `message`ni
   ishlatadi, boshqa tillar kod bo'yicha ARB matnini oladi.
4. Texnik tafsilot `Failure.details` ga boradi, UI'ga chiqmaydi.

## Tekshiruv

```bash
flutter analyze
```
```bash
flutter test test/l10n test/features/auth --reporter compact
```

Ingliz UI'ni qo'lda ham ko'r: Settings → English → navigation, dialog, SnackBar,
empty state va xato ekranlarida o'zbekcha matn qolmasligi kerak.
