-- LEXHUB — `public.profiles` MAXFIY USTUNLARINI `anon` DAN YOPISH
--
-- O'LCHANGAN (2026-08-29, PRODUCTION, publishable/anon kalit, sessiyasiz):
--   GET /rest/v1/profiles?select=*&limit=1  -> HTTP 200
--   Qaytgan ustunlar (12): avatar_url, bio, created_at, full_name, id,
--   is_verified, license_number, phone, reputation_points, role,
--   specialization, updated_at
--
-- Ya'ni TIZIMGA KIRMAGAN har qanday odam (kalit APK ichida, ya'ni kalit
-- hammada bor) BARCHA foydalanuvchilarning `phone`, `bio` va
-- `license_number` qiymatini o'qiy oladi.
--
-- NIMA UCHUN RLS bu yerda YETARLI EMAS: `20260826_bulletproof_auth_signup_
-- trigger.sql:69` da siyosat `FOR SELECT USING (true)` — ya'ni QATOR
-- darajasida hech qanday cheklov yo'q va bo'lishi ham kerak emas (jamoat
-- forumida muallif ismi ko'rinishi shart). PostgreSQL RLS esa USTUN
-- darajasida filtrlay OLMAYDI. Shuning uchun yagona to'g'ri mexanizm —
-- ustun darajasidagi GRANT.
--
-- MUHIM MEXANIKA: jadval darajasidagi `GRANT SELECT` ustun darajasidagi
-- `REVOKE SELECT (col)` ni BEKOR QILADI (jadval grant'i kuchliroq). Shuning
-- uchun avval jadval grant'i olib tashlanadi, keyin FAQAT xavfsiz ustunlar
-- qaytariladi. Boshqa yo'l yo'q.
--
-- HOZIRGI HOLAT (o'lchangan, 2026-08-29): `phone`, `bio`, `license_number`
-- barcha qatorlarda NULL (`service_role` bilan ham 0 ta non-null). Ya'ni
-- bugun bu LATENT tashqi oqim — foydalanuvchi telefon raqamini kiritishi
-- bilan FAOL bo'ladi. Shu sababli tuzatish profil tahrirlash oqimi
-- ishlatilishidan OLDIN kiritiladi.

BEGIN;

-- 1) ANON: jadval darajasidagi SELECT olib tashlanadi.
REVOKE SELECT ON TABLE public.profiles FROM anon;

-- 2) ANON: faqat JAMOAT UI'ga kerak bo'lgan ustunlar qaytariladi.
--
-- Ro'yxat klient kodidan O'LCHAB olindi, taxmin qilinmadi:
--   community_forum_remote_datasource.dart:226,249,349,371,577,661
--     -> `select('*, profiles(full_name, role, is_verified, avatar_url)')`
--   question_answer_model.dart:47-49 -> profile['full_name'], profile['role']
--   `id` — FK/embedding identifikatori.
-- `specialization`, `reputation_points`, `created_at`, `updated_at` maxfiy
-- emas (kasbiy/gamifikatsiya ma'lumoti) va kelajakdagi jamoat profil
-- kartasi uchun qoldiriladi.
GRANT SELECT (
    id,
    role,
    full_name,
    specialization,
    is_verified,
    created_at,
    updated_at,
    avatar_url,
    reputation_points
) ON TABLE public.profiles TO anon;

-- 3) `authenticated` ATAYLAB TEGILMAYDI.
--
-- Sabab: `auth_remote_datasource.dart:143` foydalanuvchining O'Z profilini
-- `select()` (yulduzcha) bilan o'qiydi. Ustun grant'i ROL bo'yicha ishlaydi,
-- QATOR bo'yicha emas — ya'ni "o'z qatorini to'liq, boshqalarni qisman"
-- deyishning grant bilan imkoni YO'Q.
--
-- QOLGAN OCHIQ MASALA (bu migratsiya YOPMAYDI, alohida ish talab qiladi):
-- tizimga kirgan HAR QANDAY foydalanuvchi hamon boshqalarning `phone`,
-- `bio`, `license_number` qiymatini o'qiy oladi (`USING (true)`). To'g'ri
-- yechim — `profiles` siyosatini o'z qatoriga qisqartirib, jamoat uchun
-- xavfsiz ustunlardan `public_profiles_view` ochish (loyihada shu naqsh
-- allaqachon bor: `public_questions_view`, `public_expert_profiles_view`).
-- Bu O'QISH YO'LINI qayta qurish, shuning uchun bu faylga qo'shilmadi.

COMMIT;

-- ==========================================================================
-- TEKSHIRISH (qo'llangandan keyin, anon kalit bilan):
--
--   1) Maxfiy ustun YOPILGANI:
--      GET /rest/v1/profiles?select=phone&limit=1
--      KUTILADI: HTTP 401/403, code 42501,
--                "permission denied for table profiles"
--                (P0-07 da o'lchangani kabi PostgREST 42501 ni 401 qilib
--                 ko'rsatishi mumkin — kod muhim, status emas)
--
--   2) JAMOAT UI SINMAGANI:
--      GET /rest/v1/questions?select=id,title,profiles(full_name,role,is_verified,avatar_url)&limit=3
--      KUTILADI: HTTP 200 va `profiles` obyekti to'ldirilgan
--
--   3) `select=*` endi ANON uchun ISHLAMAYDI (kutilgan xatti-harakat):
--      GET /rest/v1/profiles?select=*&limit=1 -> 42501
--      Klientda anon `profiles` dan yulduzcha bilan o'qiydigan joy YO'Q
--      (tekshirilgan: `auth_remote_datasource.dart:143` sessiya talab
--      qiladi, ya'ni `authenticated` roli).
--
-- HOLATI: QO'LLANGAN va JONLI BAZADA TEKSHIRILGAN (2026-08-29,
-- `supabase db push --include-all`, `schema_migrations.version = 20260829120000`).
-- Yuqoridagi 3 tekshiruv anon kalit bilan RUNTIME'da bajarildi:
--   1) `?select=phone` -> 42501 "permission denied for table profiles" (HTTP 401);
--      `?select=bio` va `?select=license_number` ham AYNI xato.
--   2) `questions?select=id,title,profiles(full_name,role,is_verified,avatar_url)`
--      -> HTTP 200, `profiles` obyekti to'ldirilgan (jamoat UI sinmagan).
--   3) `?select=*` -> 42501 (kutilgan). Ruxsat berilgan 7 ustunni ochiq
--      o'qish -> HTTP 200.
-- Qo'shimcha 2 tekshiruv: `public_expert_profiles_view` -> 200 va
-- `public_questions_view` -> 200 — bu view'lar `security_invoker` EMAS, ya'ni
-- egasining huquqi bilan ishlaydi va anon'ning bazaviy jadval grant'i
-- olinishi ularni buzmaydi (o'lchangan, taxmin emas).
--
-- `authenticated` roli ATAYLAB tegilmagan: o'z profilini tahrirlash va
-- sessiya talab qiladigan o'qishlar shu rol orqali ketadi.
-- ==========================================================================
