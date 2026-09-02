---
name: lexhub-legal-answer-safety
description: Foydalanuvchiga huquqiy MAZMUN chiqaradigan har qanday ish uchun ishlatiladi — AI javobi, diagnostika xulosasi, favqulodda huquqlar ekrani, hujjat shabloni matni, disclaimer so'zlashi, manba ko'rsatilishi, risk bahosi. Taqiqlangan absolyut iboralar, SABAB bilan beriladigan ishonch darajasi, modda darajasidagi grounding, eskirgan va amaldagi normani aralashtirmaslik, PII'ni logga yozmaslik va inson yuristga eskalatsiya qoidalarini beradi. UI'da biror narsani "AI" deb nomlashdan oldin ham majburiy.
---

# Huquqiy javob xavfsizligi

Bu skill AI **quvurini** emas (`lexhub-ai-proxy`), balki foydalanuvchi
KO'RADIGAN huquqiy mazmunni boshqaradi.

## 1. Taqiqlangan iboralar

"100% to'g'ri", "kafolatlanadi", "to'liq himoyalangan", "yuridik jihatdan
bexato", "aniq g'alaba qozonasiz", "hech qanday xavf yo'q".

O'rniga defensible wording: "hozirgi ma'lumotga ko'ra", "bu huquqiy maslahat
emas, yo'naltirish", "tasdiqlash uchun … ga murojaat qiling".

```bash
grep -rniE "100% to'g'ri|kafolatlan|to'liq himoyalangan|bexato" --include=*.dart --include=*.arb lib | grep -v 'l10n/gen'
```

## 2. Ishonch darajasi — SABAB bilan

Uch daraja: **Yuqori / O'rta / Qo'shimcha tekshiruv kerak**. Sababsiz daraja
ko'rsatish TAQIQ — sabab bo'lmasa daraja bezakka aylanadi.

Sabab shakllari: "modda topildi va matni keltirildi" / "modda topildi, amal
qilish sanasi tekshirilmagan" / "aniq modda topilmadi, umumiy tamoyil bo'yicha".

HOZIRGI HOLAT (O'LCHANDI 2026-08-30): UI'da ishonch modeli **YO'Q** —
`confidence` butun `lib/` da 1 marta uchraydi. Ya'ni bu bo'lim hali TALAB, amal
qilingan holat emas (triage: SHOULD FIX S1).

## 3. Grounding — modda darajasida

Har bir huquqiy da'vo manbaga bog'lansin: hujjat + modda + (bo'lsa) sana va URL.
Manba topilmasa — **"manba topilmadi"** deb ayt. To'qib chiqarish (§0) taqiq:
mavjud bo'lmagan modda raqami, mavjud bo'lmagan qaror sanasi YOZILMAYDI.

Eskirgan va amaldagi norma ARALASHMASIN. `effective_from` / `effective_to`
sxemada bugun YO'Q (O'LCHANDI: 0 marta) → shu sababli "amaldagi tahriri" degan
KAFOLAT bugun berilmaydi; faqat "manba: <hujjat>, <modda>" ko'rsatiladi.

Korpus hozir **17 modda**. Javob korpus tashqarisiga chiqsa, buni foydalanuvchiga
AYT — jimgina umumiy bilimdan javob berish grounding da'vosini yolg'on qiladi.

## 4. "AI" yorlig'i (§6)

Real LLM chaqirilmasa UI'da "AI" deb yozma. Deterministik shablon yoki qoidalar
jadvali — "AI" EMAS. Release build'da kalit bo'lmasa AI o'chadi — bu holatda
ekran "AI javobi" deb ko'rsatmasin, holatni oshkora aytsin.

## 5. PII va maxfiylik

- Foydalanuvchining huquqiy matni va PII **logga yozilmaydi**
  (`crash_reporter`, `client_error_logs`).
- Shaxsiy huquqiy ma'lumot AI training uchun **avtomatik ishlatilmaydi**.
- Model'ga yuborishdan oldin `lib/core/legal_safety/pii_anonymizer.dart`
  orqali o'tkaz (telefon, PINFL, pasport, email, ism).
- Anonim savol **EGASI** oshkor bo'lmasin — bu P0 sinf, bir marta sodir bo'lgan
  va yopilgan (commit `8ba78c1`).

## 6. Inson yuristga eskalatsiya

Yuqori xavf belgilari: da'vo/shikoyat muddati, jinoiy javobgarlik, sud jarayoni,
hibs, bola va oila huquqi, katta summa, mulkdan mahrum bo'lish. Bu holatlarda
javob **inson yuristga yo'naltirish** bilan yakunlansin — AI oxirgi instansiya
sifatida ko'rsatilmasin.

## 7. Tekshiruv

- Matn ARB'da bo'lsin, widget ichida literal YO'Q (`lexhub-l10n`).
- Da'vo ↔ realitet tafovuti: `lexhub-demo-audit`.
- Yangi qoidani test bilan qulflaganda vakuumga tushmaslik: `lexhub-test-trust`.
