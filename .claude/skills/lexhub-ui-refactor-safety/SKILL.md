---
name: lexhub-ui-refactor-safety
description: Presentation qatlamini refaktoring qilishdan OLDIN va tugagach ishlatiladi — ekranni qayta yozish, widget'ni bo'lish/ko'chirish, sahifa tuzilishini o'zgartirish, navigatsiyani qayta tartiblash, mavzuni almashtirish yoki "vizual redizayn" turidagi ish. Qaysi shartnomalar (BLoC event/state, IndexedStack indekslari, navigatsiya argumentlari, ARB kalitlari, guard testlari) SINDIRILMASLIGI kerakligini va har bir o'zgarish qanday tekshirilishini beradi. Domain/Data qatlamiga tegish taklifi paydo bo'lganda ham chaqiriladi.
---

# LexHub — UI refaktoringda SINDIRILMAYDIGAN shartnomalar

Qoida: **vizual o'zgarish faqat Presentation qatlamida.** `lib/features/*/domain/`
va `lib/features/*/data/` ga dizayn uchun TEGILMAYDI. Entity, Model, Repository,
DataSource, UseCase imzosi o'zgarishi — refaktoring emas, regressiya.

## 1. BLoC shartnomasi

10 ta feature'da bloc bor. Refaktoring paytida:

- `add(<Event>)` chaqiruvlari **ayni shu Event nomi va parametrlari** bilan
  qoladi. Event'ni "qulayroq" qilib o'zgartirish taqiqlanadi.
- `BlocBuilder` / `BlocConsumer` / `BlocListener` **state tekshiruvlari**
  (`is XLoading`, `is XError`, `state.status ==`) o'z joyida qoladi.
- Widget faqat `Column` → `Stack` ga aylantirilsa ham, `context.read<XBloc>()`
  daraxtda YUQORIDA qolishi kerak: `BlocProvider` ni pastga tushirsang state
  yo'qoladi va ekran har `setState` da qayta yuklanadi.
- **Biznes logikasi widget'ga KO'CHIRILMAYDI** (§9). Widget ichida `if` bilan
  huquqiy qoida hisoblash, Supabase so'rovi yoki `Failure` tahlili — yo'q.

## 2. Navigatsiya

- **`IndexedStack` tartibi QULFLANGAN:** `0` Bosh sahifa, `1` Maslahat,
  `2` Hamjamiyat, `3` Xizmatlar, `4` Kabinet
  (`main_navigation_page.dart`). `LexBottomNav` faqat KO'RSATISH tartibini
  o'zgartiradi (`_NavSlot.stackIndex`). Indeksni almashtirish
  `onAskAITap: () => _navigateToTab(1)` kabi mavjud chaqiruvlarni jimgina
  boshqa ekranga olib boradi.
- Sahifa konstruktori parametrlari (`initialCategory`, `caseId`,
  `onSendQueryToAI`, …) o'zgarmaydi. Named route yo'q — hammasi
  `MaterialPageRoute` orqali, ya'ni kompilyator seni ushlamaydi.
- `IndexedStack` `AutomaticKeepAlive` beradi: tab almashganda holat
  saqlanadi. Uni `PageView` yoki `Navigator` bilan almashtirish — holat
  yo'qolishi va §14 buzilishi.

## 3. Lokalizatsiya va halollik

- Yangi ko'rinadigan matn = ARB (`app_uz.arb` + `app_en.arb`) →
  `flutter gen-l10n` → `context.l10n.<kalit>`. Literal yozish
  `no_hardcoded_ui_strings_test.dart` ni yiqitadi (ZONA A: nol tolerantlik).
- Mavjud ARB kalitini O'CHIRMA — boshqa ekran ishlatayotgan bo'lishi mumkin.
- Uchqun/`auto_awesome` piktogrammasi = "AI" da'vosi (§6). Faqat `isLlm`
  bo'lgan joyda. `ai_claim_honesty_test.dart` buni qulflagan.

## 4. Layout regressiyalari (bu loyihada REAL uchragan)

- **`GridView` + `childAspectRatio`** — `textScaleFactor` 1.3+ da yorliq
  plitkadan chiqadi ("BOTTOM OVERFLOWED"). O'rniga `Row` + `Expanded`
  ishlat, balandlikni mazmun belgilaydi.
- **`Row` ichida uzun matn** — `Expanded` + `maxLines` + `overflow` bo'lmasa
  gorizontal overflow. Kabinet `TabBar` yorlig'i hozir ham kesiladi (qarz).
- **Bosish maydoni ≥ 48×48 px** (Material minimumi). Hozir `_NavItem`
  ~47 px — bu QARZ, yangi kodda takrorlanmaydi. `InkWell` ni `Padding`
  bilan emas, `SizedBox`/`constraints` bilan kafolatlash to'g'ri.
- **`Transform.translate`** layout balandligini o'zgartirmaydi — ko'tarilgan
  element uchun ATAYLAB shunday (katta shrift masshtabida panel ekranni yeb
  qo'ymaydi). Lekin bosish maydoni translate'dan KEYIN ham slot ichida
  qolishini tekshir.
- **`Semantics(label:)` + ostidagi `Text`** = ekran o'quvchi yorliqni IKKI
  marta o'qiydi. Qobiqqa `button: true` / `selected:` ber, `label:` BERMA.

## 5. Har bir refaktoringdan keyin (majburiy ketma-ketlik)

```bash
flutter analyze
```
```bash
flutter test --reporter compact
```

Kutilgan: `No issues found!` va `+N ~24: All other tests passed!`.
`~24` — `test/support/live_gate.dart` ortidagi OSHKORA skip'lar; bu son
o'zgarsa, sen live testni jimgina o'chirgan bo'lasan.

**Test yiqilsa (§16): testni O'CHIRMA, assertion'ni YUMSHATMA.** Root
cause'ni top. Agar test ATAYLAB eskirgan bo'lsa (masalan yangi token
qo'shildi), testni yangilash SABABI bilan izohlanadi.

85 test fayli bor. Refaktoringda eng ko'p yiqiladigani:

| Test | Nima uchun yiqiladi |
|---|---|
| `no_hardcoded_ui_strings_test.dart` | widget'da yangi literal matn |
| `arb_parity_test.dart` | `uz` ga kalit qo'shib `en` ga qo'shmaslik |
| `ai_claim_honesty_test.dart` | uchqun ikonka / "AI" yorliq qo'shish |
| `color_contrast_test.dart` | mavzuga yangi rang token ulash |
| `lex_bottom_nav_test.dart` | slot tartibi / semantika o'zgarishi |

## 6. Vizual isbot

`flutter analyze` = 0 va testlar yashil bo'lishi **"dizayn ishlaydi" degani
EMAS** — faqat "regressiya yo'q". Vizual da'vo uchun:

1. `flutter build apk --release --dart-define-from-file=env/prod.json`
2. Qurilma va lokal APK SHA256 — **MATCH** bo'lishi shart (eski binarni
   o'lchash eng ko'p qilinadigan yolg'on).
3. Ikki mavzuda skrinshot + `lexhub-a11y-contrast` bo'yicha piksel o'lchovi.
4. `adb logcat -c` → harakat → darhol logcat: `RenderFlex`, `OVERFLOWED`,
   `E/flutter` qatorlari **0** bo'lishi kerak.

