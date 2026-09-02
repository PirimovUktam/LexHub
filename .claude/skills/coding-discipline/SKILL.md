---
name: coding-discipline
description: LLM'ning eng ko'p uchraydigan kodlash xatolarini oldini oladi — taxminni fakt deb olish, so'ralmagan "yaxshilash", ortiqcha abstraksiya, qo'shni kodni sababsiz refactor qilish va tekshiruvsiz "bajarildi" deb yozish. Quyidagi hollarda MAJBURIY: yangi feature yozish oldidan; mavjud faylni tahrirlash oldidan; talab bir nechta ma'noda tushunilsa; 200 satrdan oshadigan yechim yozayotganda; ko'p bosqichli topshiriq boshlanishida. Manba: Karpathy `CLAUDE.md` (behavioral guidelines), LexHub qoidalariga moslashtirilgan.
---

# Kodlash intizomi (4 qoida)

Bu qoidalar TEZLIKDAN ko'ra EHTIYOTKORLIKNI tanlaydi. Arzimas topshiriqda
(bitta harf typo, bitta izoh) o'z hukmingni ishlat — qolgan hamma joyda amal qil.

## 1. Kod yozishdan OLDIN o'yla

**Taxmin qilma. Chalkashlikni yashirma. Tanlovni oshkora qo'y.**

- Taxminlaringni AYTIB o't. Ishonchsiz bo'lsang — so'ra.
- Talab bir nechta ma'noda tushunilsa, HAMMASINI ko'rsat — jim bittasini tanlab olma.
- Oddiyroq yo'l bo'lsa, shuni AYT. Kerak bo'lsa e'tiroz bildir.
- Biror narsa noaniq bo'lsa — TO'XTA. Nima chalkash ekanini nomla. So'ra.

LEXHUB MOSLASHUVI: bu "har bir kichik qarorni tasdiqlatib ol" degani EMAS
(foydalanuvchi buni ataylab man qilgan). Chegara: turli o'qishlar BOSHQA-BOSHQA
ishga olib borsa — so'ra. Aks holda o'zing qaror qil va qarorni yozib qo'y.

## 2. Avval SODDALIK

**Muammoni yechadigan ENG KAM kod. Hech qanday spekulyativ narsa.**

- So'ralganidan tashqari feature YO'Q.
- Bir joyda ishlatiladigan kod uchun abstraksiya YO'Q.
- So'ralmagan "moslashuvchanlik" va "sozlanuvchanlik" YO'Q.
- MUMKIN BO'LMAGAN holatlar uchun error handling YO'Q.
- 200 satr yozgan bo'lsang va u 50 satr bo'la olsa — qaytadan yoz.

Savol: "senior engineer buni ORTIQCHA MURAKKAB deb aytarmidi?" Ha bo'lsa — soddalashtir.

## 3. Jarrohlik o'zgarish

**Faqat KERAKLI joyga teg. Faqat O'Z axlatingni yig'ishtir.**

- Qo'shni kodni, izohlarni, formatlashni "yaxshilama".
- Buzilmagan narsani refactor qilma.
- Mavjud uslubga mos yoz — o'zingcha boshqacha qilgan bo'lsang ham.
- Aloqasiz o'lik kod ko'rsang — AYT, lekin O'CHIRMA.

O'zgarishing yetim qoldirgan narsalar:
- SENING o'zgarishing keraksiz qilgan import/o'zgaruvchi/funksiyani olib tashla.
- Oldindan mavjud o'lik kodni so'ralmasa olib tashlama.

Sinov: har bir o'zgargan satr foydalanuvchining so'roviga TO'G'RIDAN-TO'G'RI
bog'lanishi kerak.

## 4. Maqsadga yo'naltirilgan bajarish

**Muvaffaqiyat mezonini aniqla. Tasdiqlanmaguncha davom et.**

Topshiriqni tekshiriladigan maqsadga aylantir:
- "Validatsiya qo'sh" → "noto'g'ri kirish uchun test yoz, keyin o'tkaz"
- "Xatoni tuzat" → "xatoni QAYTA HOSIL QILADIGAN test yoz, keyin o'tkaz"
- "X ni refactor qil" → "oldin ham, keyin ham testlar o'tishini ta'minla"

Ko'p bosqichli topshiriq uchun qisqa reja ayt:
```
1. [Qadam] → tekshiruv: [nima]
2. [Qadam] → tekshiruv: [nima]
```

Kuchli mezon mustaqil ishlashga imkon beradi. Kuchsiz mezon ("ishlasin")
doimiy so'rab-surishtirishni talab qiladi.

## LexHub qoidalari bilan bog'lanish

Bu skill mavjud qoidalarni ALMASHTIRMAYDI, ular ustida ishlaydi:

| Bu skill | LexHub qoidasi |
|---|---|
| Taxminni fakt deb olma | `CLAUDE.md` §0 CLAIM ≠ EVIDENCE; §14 no-false-success |
| Testni maqsad qil | §21 assertionni yumshatma, `skip` bilan yashirma |
| So'ralmagan feature yo'q | §26 scope creep yo'q |
| Faqat kerakli joyga teg | ZERO-BREAKING: UI ishi uchun Domain/Data o'zgartirma |
| Jim fallback yo'q | §20 `catch (_) {}` yo'q, feyk success yo'q |

## Bu qoidalar ISHLAYOTGANINING belgisi

Diff'da keraksiz o'zgarish kamayadi; ortiqcha murakkablik sababli qayta yozish
kamayadi; aniqlashtiruvchi savol XATODAN KEYIN emas, IMPLEMENTATSIYADAN OLDIN
beriladi.

## Manba va litsenziya

Karpathy `CLAUDE.md` (behavioral guidelines), MIT —
https://x.com/karpathy/status/2015883857489522876

Upstream skill nomi `karpathy-guidelines`. Bu yerda LexHub `CLAUDE.md` §0-§16
ga moslashtirilib `coding-discipline` nomi bilan o'rnatilgan (2026-08-29).
Upstream nusxasi ATAYLAB qo'shimcha o'rnatilmadi: bir xil 4 qoidaning ikki
skilli bir-biriga qarama-qarshi tanlanishi mumkin.

