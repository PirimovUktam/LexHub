-- ============================================================================
-- LexHub — AUTH PROFILE INVARIANT: PRE/POST CHECK (READ-ONLY)
-- ============================================================================
-- BU MIGRATION EMAS. Supabase SQL Editor'da qo'lda ishlatiladi.
-- BARCHA bloklar TOZA READ-ONLY: hech narsa o'zgartirmaydi, hech narsa
-- yozmaydi. `20260827_profile_invariant_final_fix.sql` dan OLDIN va KEYIN
-- bir xil ishlatiladi — ikki natijani solishtirish evidence beradi.
--
-- TARTIB:
--   1) A-BLOK (PRE)  -> natijani saqlab qo'ying
--   2) migration'ni to'liq bir marta run qiling
--   3) A-BLOK (POST) -> KUTILGAN ustunda yozilgan holat bo'lishi shart
-- ============================================================================

-- ── A1. ROOT CAUSE ustuni: phone hamon NOT NULL mi? ─────────────────────────
-- KUTILGAN (PRE):  is_nullable = NO,  column_default = NULL
-- KUTILGAN (POST): is_nullable = YES, column_default = NULL  (DEFAULT QO'SHILMAYDI)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'phone';


-- ── A2. INVARIANT: profili yo'q auth foydalanuvchilar ──────────────────────
-- KUTILGAN (PRE):  profili_yoq_userlar > 0
-- KUTILGAN (POST): profili_yoq_userlar = 0   <-- ASOSIY MEZON
--
-- `auth_useri_yoq_profillar` — MIGRATIONDAN OLDIN MAJBURIY TEKSHIRUV:
-- agar u > 0 bo'lsa, `profiles.id -> auth.users(id)` FK'ni QO'SHIB BO'LMAYDI
-- (23503) va butun migration rollback bo'ladi. Bu holatda avval o'sha
-- qatorlarni ko'rib chiqish kerak (A2b), migration'ni run QILMANG.
SELECT
    (SELECT count(*) FROM auth.users)      AS auth_users,
    (SELECT count(*) FROM public.profiles) AS profiles,
    (SELECT count(*) FROM auth.users u
       LEFT JOIN public.profiles p ON p.id = u.id
     WHERE p.id IS NULL)                   AS profili_yoq_userlar,
    (SELECT count(*) FROM public.profiles p
       LEFT JOIN auth.users u ON u.id = p.id
     WHERE u.id IS NULL)                   AS auth_useri_yoq_profillar;


-- ── A2b. FK bloklovchi qatorlar (yuqoridagi oxirgi ustun > 0 bo'lsa) ───────
-- Bu qatorlar nima ekanini AVVAL aniqlang. Ularni o'chirish DATA YO'QOTISH
-- demakdir — qaror sizniki, migration ularga TEGMAYDI.
SELECT p.id, p.full_name, p.role, p.created_at
FROM public.profiles p
LEFT JOIN auth.users u ON u.id = p.id
WHERE u.id IS NULL
ORDER BY p.created_at
LIMIT 50;


-- ── A3. Foydalanuvchi bergan tekshiruv so'rovi ─────────────────────────────
-- KUTILGAN (POST): har bir qatorda profile_id NOT NULL, role = 'citizen',
--                  is_verified = false, phone = NULL (email signup)
SELECT u.id AS auth_user_id, p.id AS profile_id, p.phone, p.role, p.is_verified
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
ORDER BY u.created_at DESC
LIMIT 10;


-- ── A4. handle_new_user(): xatoni yutuvchi handler qoldimi? ────────────────
-- KUTILGAN (PRE):  yutadi_mi = true   (EXCEPTION ... THEN NULL / RETURN NEW)
-- KUTILGAN (POST): yutadi_mi = false  VA  qayta_kotaradi_mi = true
SELECT
    p.proname,
    p.prosecdef                                   AS security_definer,
    p.proconfig                                   AS search_path_config,
    pg_get_functiondef(p.oid) ILIKE '%EXCEPTION%THEN%NULL%'
      OR pg_get_functiondef(p.oid) ILIKE '%WHEN OTHERS%RETURN NEW%'
                                                  AS yutadi_mi,
    pg_get_functiondef(p.oid) ~* E'RAISE\\s*;'    AS qayta_kotaradi_mi
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'handle_new_user';
-- Bir nechta qator qaytsa: dublikat/overload funksiya — drift.


-- ── A5. P0: anti-tampering guard'lar chaqiruvchini KO'RA oladimi? ──────────
-- SECURITY DEFINER ichida `current_user` DOIM funksiya egasi bo'ladi, ya'ni
-- `current_user NOT IN (...)` sharti HAR DOIM false — guard o'lik kod.
-- KUTILGAN (PRE):  protect_profile_sensitive_fields -> security_definer = true (BUG)
-- KUTILGAN (POST): uchala guard uchun ham security_definer = false
SELECT p.proname, p.prosecdef AS security_definer, p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'is_privileged_db_role',
      'protect_profile_sensitive_fields',
      'protect_profile_privileged_columns_on_insert')
ORDER BY p.proname;


-- ── A6. profiles RLS policy'lari va grant'lari ─────────────────────────────
-- KUTILGAN (POST): cmd = 'INSERT' policy YO'Q; cmd = 'ALL' policy ham
--                  bo'lmasligi ma'qul (bo'lsa migration WARNING beradi).
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profiles'
ORDER BY cmd, policyname;

-- KUTILGAN (POST): anon/authenticated uchun INSERT qatori YO'Q.
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'profiles'
  AND grantee IN ('anon', 'authenticated')
ORDER BY grantee, privilege_type;


-- ── A7. Triggerlar ─────────────────────────────────────────────────────────
-- KUTILGAN (POST): auth.users da handle_new_user() bilan AYNAN 1 trigger.
SELECT t.tgname, t.tgenabled,
       CASE t.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
       p.proname
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'auth.users'::regclass AND NOT t.tgisinternal
ORDER BY t.tgname;

-- KUTILGAN (POST): profiles da INSERT guard + UPDATE guard.
SELECT t.tgname, t.tgenabled,
       CASE t.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
       CASE WHEN t.tgtype & 4  = 4  THEN 'INSERT' ELSE '' END
       || CASE WHEN t.tgtype & 16 = 16 THEN ' UPDATE' ELSE '' END AS events,
       p.proname
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgrelid = 'public.profiles'::regclass AND NOT t.tgisinternal
ORDER BY t.tgname;


-- ── A8. FK: profiles.id -> auth.users(id) ──────────────────────────────────
-- KUTILGAN (POST): kamida bitta qator, confrelid = auth.users
SELECT c.conname, c.confrelid::regclass AS parent_table,
       pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.conrelid = 'public.profiles'::regclass AND c.contype = 'f';


-- ── A9. BUG SINFINING QOLGAN QISMI: NOT NULL + DEFAULT yo'q ustunlar ───────
-- Migration ichidagi detektor shu ro'yxatni WARNING sifatida chiqaradi.
-- KUTILGAN (POST): faqat handle_new_user() to'ldiradigan ustunlar qoladi
--                  (id, full_name, role, reputation_points, is_verified).
-- Boshqa ism chiqsa — signup yana 23502 beradi, o'sha ustunni ham hal qilish kerak.
SELECT a.attname AS notnull_default_yoq_ustun
FROM pg_attribute a
WHERE a.attrelid = 'public.profiles'::regclass
  AND a.attnum > 0 AND NOT a.attisdropped
  AND a.attnotnull
  AND a.attgenerated = ''
  AND NOT EXISTS (SELECT 1 FROM pg_attrdef d
                  WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum)
ORDER BY a.attnum;


-- ── A10. questions.user_id FK: 23503 manbasi ───────────────────────────────
-- KUTILGAN: questions_user_id_fkey -> public.profiles(id)
SELECT c.conname, c.confrelid::regclass AS parent_table,
       pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c
WHERE c.conrelid = 'public.questions'::regclass AND c.contype = 'f'
ORDER BY c.conname;
