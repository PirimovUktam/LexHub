---
name: lexhub-null-safety
description: `!`, `as Tip`, `map[key]!`, `.first`/`.single` yozishdan OLDIN va "Null check operator used on a null value" xatosi ko'ringanda ishlatiladi. Supabase qatorini modelga o'girishda, modelga yangi maydon qo'shishda va biror narsani "null-safe" deb e'lon qilishdan oldin ham majburiy. Audit buyruqlarini (o'lchangan sonlar bilan), xavfsiz almashtirishlarni, xato oqimini (§20) va xato KO'RSATUVCHI kod ichidagi null-crash tuzog'ini beradi.
---

# Null-xavfsizlik — o'lchov bilan

Loyihaning ASL nuqsoni shu sinfdan edi (register `Null check operator` crash).
Shuning uchun bu yerda taxmin emas, buyruq va son bor.

## Hozirgi holat (O'LCHANDI 2026-08-30)

```bash
grep -rnoE '[]A-Za-z0-9_)]!' --include=*.dart lib | grep -v 'lib/l10n/gen' | wc -l
```

→ **119 moslik / 43 fayl**. DIQQAT: bu MEXANIK sanoq, YUQORI CHEGARA. Ichida
satr literali ichidagi undov ham bor — masalan
`legal_assistant_remote_datasource.dart:85` o'zbekcha ogohlantirish matni
`...qo'l qo'ymang!`. "119 ta xavf" degani EMAS.

DIQQAT (2): ERE'da `[...]` ichida `\]` ishlamaydi — `]` bracket'da BIRINCHI
turishi kerak. `[A-Za-z0-9_\)\]]!` shakli jimgina faqat `...]!` ni sanaydi va
sonni 119 dan 14 ga tushiradi. Sanoq patterni ham tekshirilishi kerak
(`lexhub-test-trust` §3).

Eng xavfli sinf — indekslangan shakl:

```bash
grep -rnE ']!' --include=*.dart lib | grep -v 'lib/l10n/gen'
```

→ 9 satr, hammasi qo'lda ko'rildi va XAVFSIZ: `Colors.grey[800]!` (Material
palitrada kalit const), `match[0]!` (RegExp 0-guruhi har doim bor), `m[2]!`
(`_titledNameRegex` da 2-guruh majburiy), `event.initialValues![field.id]!`
(`!= null && containsKey(...)` gvardi ichida). Yagona xavfli joy —
`bootstrap_strings.dart:71` — test bilan qulflangan.

## ErrorWidget tuzog'i (eng qimmat xato)

Xato **KO'RSATUVCHI** kod ichidagi null-crash ASL xatoni butunlay yashiradi:

```dart
_values[_locale.languageCode]?[key] ??
_values[AppLocales.fallback.languageCode]![key]!;   // bootstrap_strings.dart:70-71
```

Bu yerga `ErrorWidget.builder` va `ConfigurationErrorApp` tayanadi. Kelajakda
faqat `en` ga qo'shilgan kalit "Null check operator used on a null value" ni
AYNAN xato ekrani chizilayotganda beradi va foydalanuvchi asl sababni MANGU
ko'rmaydi. Yopildi: `test/core/localization/bootstrap_strings_key_parity_test.dart`.

**Qoida:** xato yo'lidagi kod (error widget, crash reporter, bootstrap, config
validator) HECH QACHON null-assertion ishlatmasin — `??` bilan fallback bersin.

## Xavfsiz almashtirishlar

| O'rniga | Yoz |
|---|---|
| `map[key]!` | parite testi bilan qulfla YOKI `?? '<fallback>'` |
| `list.first` | `if (list.isEmpty) return <typed failure>;` |
| `x as T` | `x is T ? x : <failure>`; JSON'da `tryParse` va tip tekshiruvi |
| `session!.user!` | `if (session == null) return Left(Failure(code: …));` |
| async'dan keyin `context` | `if (!mounted) return;` |
| `response.data!` | Supabase javobi nullable — `null` ni ALOHIDA failure qil |

## Xato oqimi (§20)

backend error → **typed `Failure` + `FailureCode`** → `lexhub-l10n` bo'yicha
lokalizatsiya → UI'da sabab + retry. Bir xil ko'rinadigan uch xil sabab
(timeout, RLS rad, parse xatosi) BIR XIL xabar bermasin.

Jim yutish TAQIQ:

```bash
grep -rnoE 'catch \(_\) \{\s*\}' --include=*.dart lib
```

O'LCHANDI 2026-08-30: `lib/` da **0 ta** haqiqiy jim yutish. Buyruq 10 moslik
qaytaradi — hammasi olib tashlanganini hujjatlashtiruvchi IZOH matni. Ya'ni
moslikni ko'rganda kontekstni o'qi, sanamasdan xulosa chiqarma.

## Ishlayotgan kodni "himoya uchun" refactor qilma

§16 jarrohlik intizomi: gvard bilan yopilgan `!` ni almashtirish diffni
kattalashtiradi va regressiya xavfini oshiradi. Tartib: (1) xavf BORLIGINI
mutatsiya bilan isbotla, (2) test bilan qulfla, (3) faqat test yozib
bo'lmaydigan holatda kodni o'zgartir.
