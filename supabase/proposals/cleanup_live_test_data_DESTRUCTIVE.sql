-- =============================================================================
-- LEXHUB — §18 LIVE TEST DATA CLEANUP  ***DESTRUCTIVE***
-- Sana: 2026-08-23
-- Ishga tushirish: Supabase SQL Editor. FAQAT `20260828_mvp_blockers_...sql`
--                  MUVAFFAQIYATLI qo'llanganidan KEYIN.
-- =============================================================================
-- ⚠️  DIQQAT — BU FAYL MA'LUMOTNI O'CHIRADI (qaytarib bo'lmaydi):
--     * `public.answers`   — probe savollarga kelgan javoblar
--     * `public.questions` — sarlavhasida "probe" bo'lgan savollar
--     * `auth.users`       — `%_probe_%@lexhub.uz` hisoblar (cascade bilan
--                            ularning `profiles` qatori ham ketadi)
--
-- NEGA KERAK: §18 live write testlar production'da HAQIQIY qatorlar yaratdi.
--   Ularni qoldirish ikki sababdan xato: (1) hamjamiyat feed'ida begona
--   "probe" savollari ko'rinadi; (2) keyingi auditda bu qatorlar haqiqiy
--   foydalanuvchi ma'lumoti bilan aralashib ketadi.
--
-- NEGA CLIENT'DAN QILINMADI: DELETE policy yo'q edi (P1-06). Policy
--   qo'shilgandan KEYIN `test/integration/cleanup_live_test_data_test.dart`
--   o'z-o'zidan tozalay oladi — lekin `auth.users` uchun har holda
--   `service_role` kerak, ya'ni bu fayl `auth.users` uchun MAJBURIY.
--
-- QOLDIQ RO'YXATI (2026-08-23 holatiga):
--   savollar:   'Answer probe savoli 1787385405015'
--               'Answer probe savoli 1787389699140'
--               'Invariant probe savoli 1787428875317'
--               'Answer probe savoli 1787428900824'
--   auth.users: 4724e7aa…1637, 8818a417…88b6, 547e7794…91b0
-- =============================================================================

-- QADAM 0 — AVVAL SHUNI RUN QILING (nima o'chishini KO'RISH uchun):
--   SELECT id, title, created_at FROM public.questions WHERE title ILIKE '%probe%';
--   SELECT id, email FROM auth.users WHERE email LIKE '%\_probe\_%@lexhub.uz';

BEGIN;

-- Tartib MUHIM: avval bolalar, keyin ota qator.
DELETE FROM public.answers
  WHERE question_id IN (
    SELECT id FROM public.questions WHERE title ILIKE '%probe%'
  );

DELETE FROM public.questions
  WHERE title ILIKE '%probe%';

-- `auth.users` — faqat `service_role`/`postgres` bajaradi.
-- `profiles.id -> auth.users(id)` cascade bo'lsa profil ham ketadi.
DELETE FROM auth.users
  WHERE email LIKE '%\_probe\_%@lexhub.uz';

COMMIT;

-- TEKSHIRUV — ikkalasi ham 0 qaytarishi kerak:
--   SELECT count(*) FROM public.questions WHERE title ILIKE '%probe%';
--   SELECT count(*) FROM auth.users WHERE email LIKE '%\_probe\_%@lexhub.uz';
