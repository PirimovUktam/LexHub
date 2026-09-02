---
name: lexhub-a11y-contrast
description: Rang kontrasti yoki o'qilishi haqida DA'VO qilinishidan oldin ishlatiladi — "kontrast yaxshi", "AA'dan o'tadi", "o'qilishi yaxshilandi", "matn ko'rinadi" deb yozish oldidan. Real qurilma pikselidan o'lchash zanjirini (adb screencap + PIL namunasi), WCAG formulasini, "katta matn" chegarasini va tint ustidagi matn uchun alfa-konvert qulf testini beradi. Shuningdek yangi rang tokeni qo'shilganda yoki mavjud tokenning qiymati o'zgartirilganda majburiy.
---

# LexHub — kontrastni ISBOTLASH

CLAUDE.md: skrinshotga qarash, dizayn niyati va "modelga ko'ra" hisob — bularning
hech biri evidence emas. Kontrast **o'lchanadi**.

## 1. Nima talab qilinadi (WCAG 2.1 AA)

| Nima | Talab |
|---|---|
| Oddiy matn | **4.5:1** |
| "Katta" matn | 3:1 — chegara: **18 pt / 24 px oddiy** yoki **14 pt / 18.66 px bold** |
| Ikonka, chegara, UI komponenti | **3:1** |
| Dekorativ ajratgich, soya | talab yo'q |

**Eng ko'p qilinadigan xato:** `fontSize: 15, FontWeight.bold` ni "katta matn"
deb hisoblash. 15 px bold — chegaradan PAST, ya'ni **4.5:1 talab qilinadi**.
Aynan shu xato `Tezkor Huquqlar` ishonch raqamlarida topilgan.

## 2. Formula (Dart va Python'da bir xil)

```python
def lum(h):
    h = h.lstrip('#'); r, g, b = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def cr(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
```

Nazorat qiymatlari (formula buzilmaganini tekshirish): qora↔oq = **21.00**,
bir xil rang = **1.00**, `#767676` oq ustida = **4.54** (WebAIM).

## 3. Qurilmadan o'lchash zanjiri

Har bir `adb` chaqiruvida `MSYS2_ARG_CONV_EXCL='*'` SHART.

```bash
MSYS2_ARG_CONV_EXCL='*' adb exec-out screencap -p > build/measure.png
```

Keyin PIL bilan namuna ol:

```bash
python -c "
from PIL import Image; from collections import Counter
im = Image.open('build/measure.png').convert('RGB')
box = im.crop((L, T, R, B))            # o'lchanadigan soha
px  = list(box.getdata())
bg  = Counter(px).most_common(1)[0][0]  # eng ko'p uchragan = FON
def lm(c):
    f = lambda v: v/12.92 if v/255<=0.03928 else ((v/255+0.055)/1.055)**2.4
    return 0.2126*f(c[0])+0.7152*f(c[1])+0.0722*f(c[2])
fg = min(px, key=lm) if lm(bg) > 0.5 else max(px, key=lm)  # matn YADROSI
hi, lo = max(lm(bg), lm(fg)), min(lm(bg), lm(fg))
print(bg, fg, round((hi+0.05)/(lo+0.05), 2))
"
```

- **FON** = `most_common` (yassi maydon), **MATN** = yorqinlik bo'yicha
  ekstremum (anti-aliasing chetlari o'rtacha qiymat beradi — ular EMAS).
- Ikki mavzuda ham o'lcha (yorug' + qorong'i), aks holda yarim ish.

## 4. NIMA UCHUN model YETMAYDI — o'lchangan farq

`accent.withValues(alpha: 0.12)` ni oddiy sRGB alpha blend deb hisoblab
model qurilgan edi. Real qurilma boshqa piksel beradi:

| Joy | MODEL | QURILMA |
|---|---|---|
| `102` fon | #F7EBED → 3.24:1 | **#EFE3E6 → 3.01:1** |
| `1092` fon | #E5F5F2 → 2.26:1 | **#DDEDEB → 2.10:1** |

Teskari yechilgan alfa kanal bo'yicha mos kelmadi (~0.11..0.17), ya'ni
kompozit oddiy sRGB blend EMAS (ehtimol Impeller / keng gamut). **Xulosa:
finding uchun QURILMA pikseli, qulf uchun ENVELOPE.**

## 5. Qulf testi — alfa konverti (envelope)

Bitta modellashtirilgan alfa qiymatini qulflash NOTO'G'RI (real alfa boshqa
chiqadi). O'rniga **0.00 → 0.20 butun oralig'idagi eng yomon holat**
tekshiriladi. Nisbat alfa bo'yicha monoton, shuning uchun ikki uchi o'tsa
orasi ham o'tadi:

```dart
double worstOverBand(Color text, Color tint, Color page) {
  var worst = 21.0;
  for (var step = 0; step <= 20; step++) {
    final ratio = contrast(text, over(tint, step / 100, page));
    if (ratio < worst) worst = ratio;
  }
  return worst;
}
```

Fayl: `test/core/theme/color_contrast_test.dart`. Uning uchta xususiyati
ATAYLAB shunday:

1. **`ThemeData` YARATILMAYDI.** `AppTheme.lightTheme` `GoogleFonts` ni ishga
   soladi, u testda shrift I/O ga urinadi va xato test TUGAGANDAN KEYIN kelib
   suite'ni yiqitadi. O'rniga mavzu→token ULANISHI `app_theme.dart`
   MANBASIDAN o'qiladi (`themeTokenFor`).
2. **Salbiy testlar bor.** `emergency` oq matn ostida AA'dan O'TMASLIGI va
   to'yingan aksent o'z tinti ustida AA'dan O'TMASLIGI qulflangan. Kimdir
   `onTint` ni olib tashlasa yoki palitrani "yumshatsa" — test yiqiladi.
3. **`kKnownTextTokens` QO'LDA yuritiladi.** Mavzuga yangi token ulansa test
   "xarita eskirgan" deb yiqiladi va kimdir uni ATAYLAB baholashi shart.

## 6. Da'vo formati

Faqat shu shakl qabul qilinadi:

> `<joy>` `<mavzu>`: fon `#RRGGBB`, matn `#RRGGBB`, **N.NN:1** — talab
> `M.M:1` (`<manba: qurilma pikseli / WCAG hisob>`)

"Yaxshilandi", "yetarli", "AA'dan o'tadi" degan raqamsiz gap — **NOT VERIFIED**.

