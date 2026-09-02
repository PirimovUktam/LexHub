---
name: lexhub-migration
description: LexHub uchun Supabase/PostgreSQL migration yozish, kontrakt testi bilan qulflash va live tekshirish tartibi. RLS policy, RPC funksiya huquqlari (GRANT/REVOKE), SECURITY DEFINER, trigger yoki jadval sxemasi o'zgartirilganda ishlatiladi. Agent migration'ni QO'LLAY OLMAYDI (privileged) — shuning uchun "migration fayli bor" degani "deployed" emas.
---

# LexHub — migration yozish va isbotlash

## Asosiy haqiqat

Agent Supabase SQL Editor'ga kira olmaydi. Ya'ni:

- `.sql` fayl yozilishi → **NOT DEPLOYED**
- kontrakt testi yashil → **PARTIALLY VERIFIED** (fayl mazmuni to'g'ri, xolos)
- live test kutilgan xato kodini qaytardi → **VERIFIED**

Hech qachon fayl mavjudligini "deployed" deb yozma.

## Yozish qoidalari

1. `BEGIN;` / `COMMIT;` — transaction-safe.
2. Idempotent: `DROP POLICY IF EXISTS`, `CREATE OR REPLACE FUNCTION`,
   `ADD COLUMN IF NOT EXISTS`.
3. **Jim o'tib ketmasin**: kutilgan obyekt topilmasa `RAISE EXCEPTION`.
   Aks holda migration "muvaffaqiyatli" bo'lib, hech narsa o'zgarmaydi.
4. Funksiya huquqlari signature'ga bog'liq bo'lmasin — barcha overload uchun
   `pg_proc` + `regprocedure` bo'yicha aylanib `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon, authenticated`
   va faqat kerakli rolga `GRANT EXECUTE`.
5. RLS: `FOR DELETE TO authenticated USING (auth.uid() = user_id OR public.is_admin_or_moderator())`.
   `TO authenticated` — anon'ning fail-closed bo'lishini ta'minlaydi.
   `public.is_admin(uuid)` bazada **YO'Q** — faqat `public.is_admin_or_moderator()`.
6. To'qima qiymat (hardcoded narx, soxta slot) qaytarma. Manba qator topilmasa
   `IF NOT FOUND THEN RETURN; END IF;` — bo'sh natija soxta ma'lumotdan yaxshiroq.
7. Secret (JWT, `sb_secret_`, service_role kaliti) `.sql` ichiga YOZILMAYDI —
   faqat rol NOMI.
8. Fayl oxirida post-deploy tekshiruv SQL'ini izoh sifatida qoldir
   (`has_function_privilege`, `pg_policies`).
9. **`RAISE NOTICE` DIAGNOSTIKA UCHUN ISHLATILMAYDI.** Supabase SQL Editor
   NOTICE chiqishini ko'rsatmaydi — foydalanuvchi faqat "Success. No rows
   returned" ni qaytaradi va o'lchov YO'QOLADI. Migration tuzatishdan oldingi
   holatni o'lchashi kerak bo'lsa (masalan qaysi policy ochiq edi), natijani
   `SELECT` bilan QAYTAR yoki `CREATE TEMP TABLE` ga yozib, oxirida `SELECT *`
   qil. Aks holda tuzatish qo'llangandan keyin SABAB qayta o'lchanmaydi.
   O'lchangan holat: `20260830080000_questions_anonymity_rls_enforcement.sql`
   deploy qilindi, teshik yopilgani isbotlandi, lekin ASL SABAB (RLS o'chiq
   edi yoki qo'shimcha `USING (true)` policy bor edi) MANGU noaniq qoldi.

## Kontrakt testi (regressiya qo'riqchisi)

`test/core/security/<nom>_migration_contract_test.dart` yoz. Namuna:
`test/core/security/mvp_blockers_migration_contract_test.dart`.

MUHIM: izoh qatorlarini AJRAT — izohlarda ataylab "ishlatilmagan" qiymatlar
eslatiladi, shuning uchun regressiya tekshiruvi izohda emas, KODDA qilinadi:

```dart
code = sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
expect(code.contains('150000'), isFalse);
```

Test header'ida "BU DEPLOYMENT ISBOTI EMAS" deb yoz.

## Live isbot

1. Foydalanuvchi `.sql`ni **Supabase SQL Editor**da ishga tushiradi (privileged).
2. Keyin gated live test:

```bash
flutter test test/integration/<nom>_live_test.dart --dart-define-from-file=env/prod.json --dart-define=LEXHUB_LIVE_WRITE_TESTS=true --reporter expanded
```

3. Kutilgan kodlarni AYNAN qulfla:
   - `42501` (insufficient_privilege → HTTP 403) = huquq yopilgan, **PASS**
   - `P0001` (funksiya tanasidagi `RAISE`) = funksiya TANASIGA kirgan, ya'ni
     REVOKE **QO'LLANMAGAN** → FAIL
   - RLS'da DELETE policy yo'q = **0 qator**, xato emas (jim rad)

Live test faylida `if (!liveSuiteEnabled('<suite>')) return;` bo'lishi SHART
(`test/support/live_gate.dart`) — aks holda default `flutter test` production'ga yozadi.

## Data yetishmasa

Testni ishlatish uchun sun'iy ma'lumot yaratib DB/RLS'ni **buzma** va service_role
ishlatma. `markTestSkipped('BLOCKED: <sabab>')` bilan oshkora BLOCKED qoldir.
