-- ============================================================================
-- LexHub — `questions_user_id_fkey` (23503) ROOT CAUSE diagnostikasi
-- ============================================================================
-- BU MIGRATION EMAS. Faqat Supabase SQL Editor'da qo'lda ishga tushirish uchun.
-- 1-6 bloklar TOZA READ-ONLY. 7-blok BEGIN ... ROLLBACK ichida — hech narsa
-- saqlanmaydi, lekin `handle_new_user()` yutib yuborayotgan HAQIQIY PostgreSQL
-- xatosini ko'rsatadi.
--
-- Sabab: anon kalit bilan `information_schema` / `pg_catalog` 401 qaytaradi,
-- shuning uchun trigger va constraint holatini faqat shu yerdan ko'rish mumkin.
-- ============================================================================

-- ── 1. FK ta'rifi: questions.user_id qaysi jadvalga ishora qiladi? ─────────
SELECT
    c.conname                                   AS constraint_name,
    c.conrelid::regclass                        AS child_table,
    c.confrelid::regclass                       AS parent_table,
    pg_get_constraintdef(c.oid)                 AS definition
FROM pg_constraint c
WHERE c.conrelid = 'public.questions'::regclass
  AND c.contype = 'f'
ORDER BY c.conname;

-- KUTILGAN: questions_user_id_fkey -> public.profiles(id)
-- DIQQAT: agar `categories` uchun IKKITA FK chiqsa, bu PGRST201 sababi
-- (PostgREST embed qila olmaydi) — alohida risk.


-- ── 2. profiles.id -> auth.users(id) bog'lanishi ───────────────────────────
SELECT
    c.conname                                   AS constraint_name,
    c.confrelid::regclass                       AS parent_table,
    pg_get_constraintdef(c.oid)                 AS definition
FROM pg_constraint c
WHERE c.conrelid = 'public.profiles'::regclass
  AND c.contype = 'f';


-- ── 3. ENG MUHIM: profili YO'Q auth foydalanuvchilar (orphan users) ────────
SELECT
    u.id,
    u.email,
    u.created_at                                AS auth_created_at,
    u.email_confirmed_at,
    (p.id IS NOT NULL)                          AS profil_bor,
    p.full_name,
    p.role
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
ORDER BY u.created_at DESC
LIMIT 20;

-- Sanoq:
SELECT
    (SELECT count(*) FROM auth.users)           AS auth_users,
    (SELECT count(*) FROM public.profiles)      AS profiles,
    (SELECT count(*) FROM auth.users u
       LEFT JOIN public.profiles p ON p.id = u.id
     WHERE p.id IS NULL)                        AS profili_yoq_userlar;

-- Agar `profili_yoq_userlar` > 0 bo'lsa: ROOT CAUSE = A (profil yaratilmagan).


-- ── 4. auth.users triggerlari: mavjudmi, nechta, qaysi tartibda? ───────────
SELECT
    t.tgname                                    AS trigger_name,
    t.tgenabled                                 AS enabled_flag,  -- 'O' = ON
    CASE t.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
    p.proname                                   AS function_name,
    p.prosecdef                                 AS security_definer,
    pg_get_userbyid(p.proowner)                 AS function_owner,
    p.proconfig                                 AS search_path_config
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- KUTILGAN: on_auth_user_created / AFTER / handle_new_user / security_definer=t
-- Agar 0 qator qaytsa: ROOT CAUSE = D (trigger deploy qilinmagan).
-- Agar tgenabled <> 'O' bo'lsa: trigger o'chirilgan.


-- ── 5. handle_new_user() ning HAQIQIY deployed tanasi ─────────────────────
SELECT
    n.nspname || '.' || p.proname                AS function,
    pg_get_functiondef(p.oid)                    AS deployed_source
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'handle_new_user';

-- Tekshir: `EXCEPTION WHEN OTHERS` bormi? (repo'da BOR — xatoni yutadi)
-- Agar bir nechta qator qaytsa: dublikat funksiya (overload) — drift.


-- ── 6. profiles INSERT'ni buzishi mumkin bo'lgan cheklovlar ───────────────
SELECT t.tgname, t.tgenabled,
       CASE t.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
       CASE WHEN t.tgtype & 4 = 4 THEN 'INSERT' ELSE '' END
       || CASE WHEN t.tgtype & 16 = 16 THEN ' UPDATE' ELSE '' END AS events,
       p.proname
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'public.profiles'::regclass AND NOT t.tgisinternal;

-- Agar anti-tampering trigger INSERT'ga ham ulangan bo'lsa: ROOT CAUSE = G
-- (OLD NULL bo'lgani uchun `NEW.role IS DISTINCT FROM OLD.role` -> EXCEPTION).

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'public.profiles'::regclass;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

SELECT unnest(enum_range(NULL::user_role))::text AS user_role_values;


-- ── 7. YUTILGAN XATONI OCHIQ KO'RISH (BEGIN ... ROLLBACK — saqlanmaydi) ───
-- `handle_new_user()` ichidagi INSERT'ni AYNAN o'sha ustunlar bilan takrorlaydi.
-- Xato chiqsa — bu trigger jimgina yutayotgan HAQIQIY sabab.
-- MUHIM: ROLLBACK bilan birga, bitta blok sifatida ishga tushiring.
BEGIN;
INSERT INTO public.profiles (
    id, full_name, avatar_url, phone, role, reputation_points, is_verified
)
SELECT u.id, 'Diagnostika', NULL, u.phone, 'citizen'::user_role, 10, FALSE
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ORDER BY u.created_at DESC
LIMIT 1;
ROLLBACK;
-- Natija "ROLLBACK" bo'lsa: INSERT muvaffaqiyatli -> ROOT CAUSE = D yoki E
--   (trigger yo'q / ishga tushmagan), constraint muammosi YO'Q.
-- Natija xato bo'lsa: xato matnini to'liq yuboring -> ROOT CAUSE = F yoki G.
