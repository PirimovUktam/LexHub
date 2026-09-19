---
name: lexhub-design-system
description: LexHub Presentation qatlamida vizual ish qilishda ishlatiladi — yangi widget yoki ekran yasash, mavjud ekranni "zamonaviy/premium/kreativ" qilish, karta-badge-tugma-input ko'rinishini o'zgartirish, gradient/soya/glassmorphism qo'shish, animatsiya va mikro-interaksiya qo'shish, rang/masofa/radius tanlash. Token jadvali O'LCHANGAN WCAG qiymatlari bilan beriladi va qaysi rang MATN uchun, qaysi biri faqat FON yoki GRAFIK uchun ekanini ajratadi. Shuningdek "chiroyliroq qilaylik" turidagi so'rov kelganda ham chaqiriladi.
---

# LexHub dizayn tizimi

Bu fayl "did bo'yicha chiroyli" emas, **o'lchangan** qoidalar to'plami. Har bir
raqam `python` bilan WCAG 2.1 formulasi orqali hisoblangan yoki `adb exec-out
screencap` pikselidan olingan.

## 0. Uchta qat'iy qoida — buzilsa test yiqiladi

1. **To'yingan aksentni O'Z tinti ustida MATN qilib yozma.** Bu ilovada
   o'lchangan va tuzatilgan nuqson: `1092` #10B981 o'z 12% tinti ustida
   **2.10:1** berardi. `test/core/theme/color_contrast_test.dart` dagi salbiy
   test buni ATAYLAB qulflagan.
2. **`withOpacity` YOZMA** — deprecated, `flutter analyze` ogohlantiradi.
   Faqat `withValues(alpha: …)`.
3. **Raqam yozma** — `AppSpacing` / `AppRadius` / `AppIconSize` / `AppMotion`
   (`lib/core/theme/app_dimens.dart`) dan ol.

## 1. Rang: MATN rangi ≠ AKSENT rangi

O'lchangan (kontrast nisbati, fon → matn):

| Rang | oq #FFF | bgL #F8FAFC | bgD #0A192F | cardD #1E293B |
|---|---|---|---|---|
| #3B82F6 blue500 | **3.68 ✗** | **3.52 ✗** | 4.79 ✓ | **3.98 ✗** |
| #2563EB blue600 | 5.17 ✓ | 4.94 ✓ | **3.41 ✗** | **2.83 ✗** |
| #6366F1 indigo | **4.47 ✗** | **4.27 ✗** | **3.94 ✗** | **3.27 ✗** |
| #4F46E5 indigoDark | 6.29 ✓ | 6.01 ✓ | **2.80 ✗** | **2.33 ✗** |
| #818CF8 indigoOnDark | **2.98 ✗** | **2.85 ✗** | 5.90 ✓ | 4.90 ✓ |
| #38BDF8 lexBlueOnDark | **2.14 ✗** | **2.05 ✗** | 8.22 ✓ | 6.83 ✓ |
| #34D399 emeraldOnDark | **1.92 ✗** | **1.84 ✗** | 9.16 ✓ | 7.61 ✓ |
| #065F46 emeraldStrong | 7.68 ✓ | 7.34 ✓ | **2.29 ✗** | **1.90 ✗** |
| #075985 lexBlueStrong | 7.56 ✓ | 7.23 ✓ | **2.33 ✗** | **1.93 ✗** |
| #B91C1C emergencyStrong | 6.47 ✓ | 6.18 ✓ | **2.72 ✗** | **2.26 ✗** |
| #F87171 emergencyDark | **2.77 ✗** | **2.64 ✗** | 6.36 ✓ | 5.29 ✓ |
| #64748B textMutedLight | 4.76 ✓ | 4.55 ✓ | **3.70** g | **3.07** g |
| #F59E0B amber | **2.15 ✗** | **2.05 ✗** | 8.20 ✓ | 6.81 ✓ |
| #B45309 amber700 | 5.02 ✓ | 4.80 ✓ | **3.51 ✗** | **2.91 ✗** |
| #10B981 emerald | **2.54 ✗** | **2.42 ✗** | 6.94 ✓ | 5.77 ✓ |
| #EF4444 crimson | **3.76 ✗** | **3.60 ✗** | 4.68 ✓ | **3.89 ✗** |
| #9333EA purple | 5.38 ✓ | 5.14 ✓ | **3.27 ✗** | **2.72 ✗** |

**XULOSA — "neon" ranglar matn uchun yaramaydi.** #3B82F6 va #6366F1 yorug'
mavzuda AA'dan O'TMAYDI, oq matn ostida fon bo'lganda ham (#3B82F6 → 3.68).
Shuning uchun:

- **Yorug' mavzuda MATN/IKONKA:** `*Strong` yoki `*Dark` variant.
- **Qorong'i mavzuda MATN/IKONKA:** `*OnDark` yoki `300` darajali variant.
- **To'yingan neon (`#3B82F6`, `indigo`, `emerald`, `amber`):** faqat **fon
  tinti, chegara, gradient, glow va soya** uchun. Hech qachon matn emas.
- **Oq matn qo'yiladigan FON:** faqat ≥4.5:1 beradigan to'q variant —
  `primary`, `primaryDark`, `blue600`, `indigoDark`, `emergencyStrong`,
  `purple`. `crimson`, `emerald`, `amber`, `blue500` oq matn ostida YARAMAYDI.

Belgilar: ✓ = MATN uchun AA (≥4.5:1), ✗ = matn uchun yaramaydi,
`g` = faqat GRAFIK/ikonka uchun yetadi (≥3:1, matn uchun emas).

## 2. Chuqurlik: soya, hoshiya, glass

Yassi qutilardan chiqish uchun **uch qatlam** ishlatiladi, hammasi
`elevation: 0` ustiga qo'lda quriladi (M3 `elevation` LexHub'da ishlatilmaydi):

1. **Ambient rangli soya** — kartaning o'z aksentida, juda xira:
   `BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 24, offset: Offset(0, 8))`.
   Yorug' mavzuda `AppColors.primary.withValues(alpha: 0.04..0.06)`.
   **Qorong'i mavzuda soya KO'RINMAYDI** — o'rniga hoshiya yorqinligi oshiriladi.
2. **Hairline hoshiya** — 1 px:
   - qorong'i: `Colors.white.withValues(alpha: 0.08)`
   - yorug': `AppColors.borderLight` (oq ustiga oq hoshiya KO'RINMAYDI —
     `Colors.white.withValues(...)` ni yorug' mavzuda YOZMA)
3. **Ichki yorug'lik (faqat qorong'i)** — yuqoridan pastga `LinearGradient`
   `[Colors.white.withValues(alpha: 0.05), Colors.transparent]`.

**Glassmorphism qayerda RUXSAT etiladi:** pastki navigatsiya, modal
`BottomSheet`, `AppBar` va suzuvchi qatlamlar. **Qayerda TAQIQLANADI:**
`ListView`/`GridView` elementi ichida. Sabab: `BackdropFilter` har bir kadrda
orqa fonni qayta blur qiladi; ro'yxatda 10 ta blur qatlam Android'da kadr
tushishini beradi. Har bir `BackdropFilter` `ClipRRect` ichida bo'lishi SHART,
aks holda blur butun ekranga tarqaydi.

## 3. Tipografika

Manba: `AppTheme` (`GoogleFonts.plusJakartaSans*`). Widget'da `fontSize`
yozish o'rniga `theme.textTheme.<style>` ol va faqat `copyWith` bilan
`fontWeight`/`color` o'zgartir.

| Uslub | O'lcham | Vazn | Ishlatilishi |
|---|---|---|---|
| `displayLarge` | ~57 | w800, ls −0.5 | faqat splash/onboarding |
| `headlineMedium` | ~28 | w700, ls −0.3 | ekran sarlavhasi |
| `titleLarge` | ~22 | w700, ls −0.2 | hero sarlavhasi |
| `titleMedium` | ~16 | w600 | karta sarlavhasi |
| `titleSmall` | ~14 | w600 | bo'lim sarlavhasi |
| `bodyLarge` | 15 / 1.55 | w400 | qonun matni, javob tanasi |
| `bodyMedium` | 14 / 1.45 | w400 | oddiy izoh |
| `bodySmall` | 12 | w400 | meta (sana, "N ta javob") |

**11 px dan kichik matn YOZMA.** Mavjud `fontSize: 10.5` ikki joyda bor
(`lex_bottom_nav.dart`, `quick_access_grid.dart`) — bu QARZ, yangi kodda
takrorlanmaydi.

## 4. Harakat (motion) — `AppMotion`

| Token | Qiymat | Ishlatilishi |
|---|---|---|
| `AppMotion.fast` | 120 ms | bosish reaksiyasi (scale) |
| `AppMotion.base` | 220 ms | rang/o'lcham o'zgarishi |
| `AppMotion.slow` | 380 ms | kirish animatsiyasi (fade+slide) |
| `AppMotion.stagger` | 60 ms | ro'yxat elementlari orasidagi kechikish |
| `AppMotion.curve` | `Curves.easeOutCubic` | standart |
| `AppMotion.emphasis` | `Curves.easeOutBack` | ko'tarilgan tugma |

**MAJBURIY: `reduce motion` hurmat qilinadi.**

```dart
final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
```

`reduce == true` bo'lsa: davomiylik `Duration.zero`, **takrorlanuvchi
(`repeat()`) animatsiya UMUMAN ishga tushmaydi**. Bu vestibulyar buzilish
uchun accessibility talabi, "chiroyliroq" dan ustun turadi.

**Cheksiz animatsiya qoidasi:** `repeat()` faqat SOS/`LIVE` kabi holat
signali uchun. Har biri `RepaintBoundary` ichida bo'lishi va faqat
`AnimatedBuilder` ning eng kichik ostki daraxtini qayta qurishi SHART —
aks holda butun ekran har kadrda qayta quriladi.

**Stagger:** `ListView.builder` da indeks bo'yicha kechikish BERILMAYDI
(element qayta ishlatilganda animatsiya qaytadan boshlanadi va skroll
"sakraydi"). Faqat statik `Column` yoki birinchi ekran uchun.

## 5. Badge / chip retsepti (eng ko'p buziladigan joy)

Talab: "nozik rangli fon + to'yingan matn". **To'g'ri bajarilishi:**

```dart
// FON — to'yingan aksent, past alfa. MATN — kontrast variant.
Container(
  padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
  decoration: BoxDecoration(
    color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
    borderRadius: BorderRadius.circular(AppRadius.xs),
    border: Border.all(color: accent.withValues(alpha: 0.25)),
  ),
  child: Text(label, style: TextStyle(color: onAccent, /* ≠ accent */ )),
)
```

`accent` va `onAccent` juftliklari (`AppColors`):

| Ma'no | tint (`accent`) | yorug' matn | qorong'i matn |
|---|---|---|---|
| Muvaffaqiyat | `emerald` | `emeraldStrong` | `emeraldOnDark` |
| Ogohlantirish | `amber` | `amberStrong` | `amber` |
| Xato / SOS | `crimson` | `emergencyStrong` | `emergencyDark` |
| Ma'lumot | `lexBlue` | `lexBlueStrong` | `lexBlueOnDark` |
| Brend | `indigo` | `indigoDark` | `indigoOnDark` |
| Elektr ko'k | `electricBlueOnDark` | `electricBlue` | `electricBlueOnDark` |

Bu juftliklarni **o'zboshimchalik bilan almashtirma** — har biri
`test/core/theme/color_contrast_test.dart` da alfa 0.00..0.20 oralig'ida
qulflangan.

## 6. Halollik (§6) va lokalizatsiya (§7) — dizayn ham buzadi

- **Uchqun/sparkle piktogrammasi (`auto_awesome`, `bolt`) "AI" da'vosidir.**
  U faqat `isLlm == true` bo'lgan joyda ko'rinadi
  (`relatable_summary_card.dart`). Qidiruv paneliga, bosh sahifa hero'siga
  yoki pastki navigatsiyaga uchqun QO'YMA — server modeli faqat tizimga
  kirgan foydalanuvchi uchun chaqiriladi.
- Yorliqlar: `navAI` = "Maslahat", `homeAiAnalyzeButton` = "Qidirish".
  Dizayn uchun "AI Search", "Smart AI" kabi matn QO'SHILMAYDI.
- **Yangi matn = ARB'ga.** `app_uz.arb` + `app_en.arb` + `flutter gen-l10n`.
  Widget'da string literal `no_hardcoded_ui_strings_test.dart` ni yiqitadi.

## 7. Tekshiruv (dizayn ishi tugagach)

```bash
flutter analyze
```
```bash
flutter test test/core/theme test/l10n --reporter compact
```

Yangi rang tokeni qo'shsang, `color_contrast_test.dart` dagi
`kKnownTextTokens` xaritasiga ham qo'sh — aks holda test "xarita eskirgan"
deb yiqiladi (bu ATAYLAB shunday).

Vizual da'vo qilishdan oldin: `lexhub-a11y-contrast` skill'idagi qurilma
o'lchovi. Skrinshotga qarab "yaxshi ko'rinadi" deb yozish EVIDENCE emas.



