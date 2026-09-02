---
name: lexhub-test-trust
description: Test, validator yoki gate ni "himoya" deb e'lon qilishdan OLDIN ishlatiladi. Yashil test VAKUUM bo'lishi (hech narsa o'lchamasligi) va tekshirgichning O'ZI soxta xato yoki soxta OK berishi mumkin. Mutatsiya protokolini (nuqsonni ataylab kirit → QIZIL → tikla → `git diff` bo'sh), vakuumga qarshi pol assertionlarini va shu loyihada O'LCHANGAN tekshirgich nuqsonlarini beradi. Yangi test yozilganda, test birinchi urinishda o'tganda yoki yashil tool tushunarsiz xato bergan holatda majburiy.
---

# Yashil ≠ himoya

Ikki xato sinfi bir xil ko'rinadi:

| Sinf | Ko'rinishi | Isboti |
|---|---|---|
| Vakuum test | `+N` yashil, lekin nuqson kirsa ham yashil qoladi | mutatsiya QIZIL bermasa |
| Yolg'onchi tekshirgich | soxta `[XATO]` yoki soxta `[OK]` | tekshirgichning o'zini mutatsiya bilan sinash |

## 1. Mutatsiya protokoli (5 qadam, majburiy)

1. Testni yoz, o'tishini ko'r.
2. HIMOYALANAYOTGAN nuqsonni manbaga ATAYLAB kirit — bitta kalitni olib tashla,
   bitta `END IF;` ni buz, bitta ustunni o'zgartir.
3. Qayta ishga tushir → **QIZIL bo'lishi SHART**. Yashil bo'lsa test hech narsa
   o'lchamaydi: o'chir yoki qaytadan yoz.
4. Manbani **baytma-bayt** tikla.
5. `git diff --stat` → **bo'sh**. Aks holda mutatsiya qoldig'i commit'ga tushadi.

O'LCHANGAN 2026-08-30: `bootstrap_strings.dart` ning `_values['en']` blokidan
`configKeysHint` olib tashlandi → **3 test QIZIL** → manba tiklandi → `git diff`
bo'sh. Shundan keyingina test "himoya" deb yozildi.

## 2. Vakuumga qarshi pol (floor assertion)

Manbani regexp bilan skanerlaydigan test HECH NARSA topmasa ham "o'tadi".
Har bir skanerda pol bo'lishi shart:

```dart
expect(_keysOfLocale(source, 'uz').length, greaterThanOrEqualTo(5),
    reason: "o'lchangan 2026-08-30: 5 bootstrap matni");
```

Ro'yxat QO'LDA yozilgan bo'lsa (Flutter'da `dart:mirrors` YO'Q), ro'yxat
uzunligini manbadagi SON bilan taqqosla — aks holda ro'yxat eskiradi va yangi
element jimgina TEKSHIRILMAY qoladi.

## 3. Tekshirgichni ham tekshir

O'LCHANGAN 2026-08-30: `tool/validate_sql_syntax.py` bitta migratsiyada soxta
`[XATO]` bergan. Sabab SQL'da emas, TEKSHIRGICHDA edi: `FUNC_RE` `--` IZOH
ichidagi `CREATE OR REPLACE FUNCTION` dan boshlanib, non-greedy `.*?` bilan
keyingi HAQIQIY funksiyani ham qamragan (moslik 13→123 satr).

Ikkinchi tomoni ham muhim: tuzatilgandan keyin ikki PL/pgSQL tanasi (87–123,
164–241) **birinchi marta** parse qilindi — soxta xato haqiqiy qamrovni ham
yashirgan edi.

Ko'r nuqta ham o'lchandi: `NEW.updated_at := ;` mutatsiyasi `[OK]` bergan.
plpgsql parseri GAP TUZILISHINI tekshiradi, gap ICHIDAGI ifodani YO'Q.
Ya'ni `[OK]` ≠ "ifoda to'g'ri".

**Qoida:** tushunarsiz `[XATO]` yoki juda oson `[OK]` kelganda AVVAL
tekshirgichga shubha qil, keyin manbaga. Ikkisini mutatsiya bilan ajrat:
nuqsonni kirit — tekshirgich ko'rmasa, muammo tekshirgichda.

## 4. Taqiqlar

- assertionni yumshatish (aniq qiymat → `greaterThan(0)`);
- `skip:` bilan yashirish — faqat `test/support/live_gate.dart` ning OSHKORA
  gate'i ruxsat, sababi reporter'ga chiqadi;
- `try { … } catch { }` bilan testni yiqilmaydigan qilish;
- `expect(true, isTrue)` turidagi bo'sh assertion;
- oldingi run natijasini YANGI testning evidence'i sifatida ishlatish.

## 5. Header majburiyati

Har bir yangi test faylining boshida uch narsa: **qaysi nuqsonni** qo'riqlaydi,
**o'lchangan sana**, va **nima ISBOT EMAS** (masalan "bu deployment isboti emas").

## Buyruqlar

```bash
flutter test test/<yo-l> --reporter expanded
```

```bash
git diff --stat
```

```bash
python tool/validate_sql_syntax.py
```
