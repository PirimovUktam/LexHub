---
name: lexhub-rls-coverage
description: "Bu jadval himoyalanganmi?" degan savolga javob berishdan yoki jadvalni "yopildi" deb e'lon qilishdan OLDIN ishlatiladi. Repo bo'ylab RLS QAMROVI auditi — RLS hech qachon yoqilmagan jadval, RLS yoqilib policy berilmagan (DENY-ALL) jadval, va SELECT policy bor lekin YOZISH policy'si yo'q jadvalni topish tartibi. Yangi `CREATE TABLE` qo'shilganda va `supabase/schema.sql` bilan `supabase/migrations/` bir-biriga qarama-qarshi gapirganda ham majburiy. Migration YOZISH tartibi uchun — `lexhub-migration`.
---

# RLS qamrovi auditi

Bu skill migration yozishni o'rgatmaydi (`lexhub-migration`), balki **qaysi
jadval qopqoqsiz qolganini** topadi.

## Uch xil teshik

| Holat | Natija | Belgisi |
|---|---|---|
| RLS **yoqilmagan** | jadval TO'LIQ OCHIQ: mehmon o'qiydi, **YOZADI**, **O'CHIRADI** — Supabase `public` sxemada `anon`/`authenticated` ga default grant beradi | `relrowsecurity = false` |
| RLS yoqilgan, policy **0** | **DENY-ALL** — himoya nomidan FEATURE buziladi (ochiq ma'lumotnoma o'qilmay qoladi) | `pg_policies` bo'sh |
| SELECT bor, yozish policy'si **yo'q** | yozish jim rad; `FOR ALL` bo'lsa — aksincha OCHIQ | `cmd` ro'yxatida INSERT/UPDATE/DELETE/ALL yo'q |

O'LCHANGAN 2026-08-30: `bookmarks`, `question_categories`, `question_tags`,
`question_tag_mappings` — migratsiyalar bo'ylab BIRON MARTA `ENABLE ROW LEVEL
SECURITY` olmagan (`ENABLE ROW LEVEL SECURITY` 21 marta uchraydi, bu to'rttasida
yo'q). `schema.sql` esa ularni yoqadi, lekin `question_tags` va
`question_tag_mappings` ga policy BERMAYDI → o'sha bazada DENY-ALL. Ya'ni jonli
holat IKKI SHOXLI bo'lib qoldi.

## Authority zinapoyasi (bunga rioya qilinmasa xulosa yolg'on bo'ladi)

1. **Jonli baza** — yagona authority.
2. `supabase/migrations/` — NIYAT, holat emas. "Fayl bor" = **NOT DEPLOYED**.
3. `supabase/schema.sql` — **authority EMAS**. Fayl o'zi jonli bazaga mos
   kelmasligini yozadi (`schema.sql:7-23`). Uni "production shunday" deb o'qish
   xato; qarama-qarshilik chiqsa migratsiya IKKI SHOXDA HAM to'g'ri ishlashi kerak.

## Mexanik audit

```bash
grep -rhoE 'CREATE TABLE (IF NOT EXISTS )?(public\.)?[a-z_]+' supabase/migrations | awk '{print $NF}' | sed 's/public\.//' | sort -u
```

```bash
grep -rhoE 'ALTER TABLE (public\.)?[a-z_]+ ENABLE ROW LEVEL SECURITY' supabase/migrations | awk '{print $3}' | sed 's/public\.//' | sort -u
```

Ikki ro'yxatning AYIRMASI — RLS olmagan jadvallar. Keyin har biri uchun
`CREATE POLICY` borligini va qaysi `cmd` qamralganini tekshir.

```bash
comm -23 <(grep -rhoE 'CREATE TABLE (IF NOT EXISTS )?(public\.)?[a-z_]+' supabase/migrations | awk '{print $NF}' | sed 's/public\.//' | sort -u) <(grep -rhoE 'ALTER TABLE (public\.)?[a-z_]+ ENABLE ROW LEVEL SECURITY' supabase/migrations | awk '{print $3}' | sed 's/public\.//' | sort -u)
```

O'LCHANGAN BAZA (2026-08-30, `20260830100000` qo'shilgandan keyin): 21 jadval
yaratilgan, 21 jadvalda `ENABLE ROW LEVEL SECURITY` bor, **ayirma BO'SH**. Ya'ni
repo darajasida qamrov to'liq. Ayirma bo'sh bo'lmasa — yangi jadval qopqoqsiz.
Bu **jonli baza isboti EMAS** (§0).

Repo'dagi qulflar: `test/core/security/rls_enabled_for_all_tables_test.dart`,
`test/core/security/write_policy_parity_test.dart`.

## `pg_policies` o'qishning nozik joylari

- **INSERT policy'da `qual` NULL** — predikat `with_check` da. `qual` bo'yicha
  filtrlash INSERT policy'sini KO'RMAYDI.
- **`cmd = 'ALL'` yozishni ham qamraydi** — "yozish policy'si yo'q" degan xulosa
  `ALL` ni ham hisobga olishi shart.
- **Permissive policy'lar OR bilan birlashadi**: bitta `USING (true)` qolgan
  hamma cheklovni BEKOR qiladi. Teshik izlayotganda eng ochiq policy'ni izla.
- `TO authenticated` yozilmasa anon ham predikatga tushadi. `auth.uid()` anon
  uchun NULL — odatda fail-closed, lekin `USING (true)` bilan birga OCHIQ.

## FILL-ONLY qoidasi

Boshqa migratsiyaning policy'sini `DROP POLICY` qilma. Faqat **o'zing nom
bergan** policy uchun `DROP POLICY IF EXISTS` + qayta yarat. Aks holda ilgari
yopilgan teshik qayta ochiladi va buni hech qanday test tutmaydi.

## Live isbot va uning cheklovi

Anon zond FARQLAY OLMAYDI: "policy yo'q" ham, "policy sessiya talab qiladi" ham
`42501` qaytaradi. Shuning uchun maxfiylik isboti — **ko'rinadigan qator SONI**:

```bash
flutter test test/integration/private_tables_anon_isolation_live_test.dart --dart-define-from-file=env/prod.json --dart-define=LEXHUB_LIVE_WRITE_TESTS=true --reporter expanded
```

Kutilgan: shaxsiy jadvalda `count=0`, ochiq ma'lumotnomada 200 va qatorlar bor.
`RAISE NOTICE` Supabase SQL Editor'da KO'RINMAYDI — migratsiya natijasini
COMMIT'dan keyingi `SELECT` bilan qaytar.
