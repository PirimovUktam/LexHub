-- =============================================================================
-- LEXHUB — ANONIM SAVOL EGASINI FOSH QILISH TESHIGI (P0, maxfiylik)
-- Sana: 2026-08-30
-- Ishga tushirish: Supabase Dashboard -> SQL Editor -> BUTUN faylni RUN
-- =============================================================================
-- O'LCHANGAN DALIL (production, ANON kalit, sessiyasiz, 2026-08-30):
--
--   GET /rest/v1/questions?select=id,is_anonymous,user_id&is_anonymous=eq.true
--   -> 200
--   [{"id":"134fe461-...","is_anonymous":true,
--     "user_id":"9c409345-0ec2-4e87-8cef-ba37e6229ad2"}]
--
--   GET /rest/v1/profiles?select=id,full_name,role&id=eq.9c409345-...
--   -> 200  [{"full_name":"<haqiqiy ism>","role":"citizen"}]
--
--   Ya'ni: TIZIMGA KIRMAGAN har qanday odam anonim savolning EGASINI topib,
--   uning ISMINI o'qiy oladi. Anonimlik ILLUZIYA.
--
--   Solishtirish uchun (AYNI so'rov, AYNI kalit):
--   GET /rest/v1/public_questions_view?select=id,is_anonymous,user_id,author_name
--   -> [{"is_anonymous":true,"user_id":null,"author_name":"Anonim fuqaro"}]
--   View TO'G'RI ishlaydi — teshik XOM JADVALDA.
--
-- KUTILGAN HOLAT (repo shu holatni DA'VO qiladi):
--   `supabase/schema.sql:880` izohi:
--     "anonymous questions readable ONLY by owner/moderators on base table"
--   `20260820_p0_security_remediation.sql:225-230` policy'si:
--     USING (is_anonymous = false OR auth.uid() = user_id
--            OR public.is_admin_or_moderator())
--   Anon uchun bu predikat FALSE bo'lishi kerak. O'lchov esa qator
--   QAYTGANINI ko'rsatdi.
--
-- ANIQ SABAB PRODUCTION'DA O'LCHANMAGAN (§0): `pg_policies` anon kalit bilan
-- o'qilmaydi. Ikki ehtimol bor va IKKISI HAM shu fayl bilan yopiladi:
--   (E1) `questions` da RLS o'chirilgan yoki policy hech qachon qo'llanmagan;
--   (E2) qo'shimcha RUXSAT BERUVCHI (`USING (true)`) SELECT policy bor —
--        PostgreSQL policy'larni OR qiladi, ya'ni bitta `true` policy
--        qolganda to'g'ri policy HECH NARSA qilmaydi.
-- 1-BLOK sababni `RAISE NOTICE` bilan yozadi — LEKIN SUPABASE SQL EDITOR
-- `NOTICE` NI KO'RSATMAYDI (o'lchangan: 219545f). Ya'ni bu fayl 2026-08-30
-- da qo'llangan bo'lsa ham (8ba78c1), qaysi shox — E1 yoki E2 — ishlaganini
-- HECH KIM KO'RMAGAN: bu farq HAMON O'LCHANMAGAN (§0). Sababni ko'rish
-- uchun fayl OXIRIDAGI diagnostika `SELECT` i ishga tushirilsin — u natijani
-- NOTICE emas, JADVAL bo'lib qaytaradi.
--
-- XUSUSIYATLARI:
--   * IDEMPOTENT — qayta ishga tushirilsa natija bir xil;
--   * TRANSACTION-SAFE — bitta BEGIN/COMMIT;
--   * DESTRUKTIV OPERATSIYA YO'Q — DROP TABLE / DROP COLUMN / DELETE yo'q.
--     Faqat RLS yoqiladi va SELECT policy'lari qayta tartiblanadi;
--   * Schema (jadval/ustun/enum/FK) O'ZGARMAYDI;
--   * XAVFSIZLIK KUCHAYADI, hech qanday huquq KENGAYMAYDI.
--
-- ILOVAGA TA'SIRI: YO'Q (kod o'qildi). Feed va savol sahifasi ASOSIY
-- so'rovni `public_questions_view` ga qiladi
-- (`community_forum_remote_datasource.dart:214` va `:337`), view esa
-- `security_invoker` EMAS — u egasi (postgres) nomidan ishlaydi, ya'ni
-- bu RLS o'zgarishi view'ga TEGMAYDI. Xom jadval faqat view yiqilganda
-- zaxira yo'l sifatida ishlatiladi va u yo'lda anonim savol ko'rinmasligi
-- KUTILGAN xatti-harakat.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) DIAGNOSTIKA — sababni DEPLOY paytida o'lchab chiqar (jim o'tmaydi)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_rls    boolean;
    v_pol    record;
    v_count  int := 0;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'questions'
    ) THEN
        RAISE EXCEPTION
            'public.questions jadvali YO''Q — bu migration mos kelmaydi. '
            'Jim o''tib ketmaslik uchun to''xtatildi.';
    END IF;

    SELECT relrowsecurity INTO v_rls
      FROM pg_class WHERE oid = 'public.questions'::regclass;
    RAISE NOTICE 'DIAGNOSTIKA: questions.relrowsecurity = %', v_rls;

    FOR v_pol IN
        SELECT policyname, cmd, permissive, roles, qual
          FROM pg_policies
         WHERE schemaname = 'public' AND tablename = 'questions'
         ORDER BY cmd, policyname
    LOOP
        v_count := v_count + 1;
        RAISE NOTICE 'DIAGNOSTIKA: policy % | cmd=% | permissive=% | roles=% | USING=%',
            v_pol.policyname, v_pol.cmd, v_pol.permissive, v_pol.roles,
            coalesce(v_pol.qual, '<yo''q>');
    END LOOP;

    IF v_count = 0 THEN
        RAISE NOTICE 'DIAGNOSTIKA: questions uchun BIRORTA policy YO''Q (E1 shoxi).';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2) RLS YOQILADI (E1 shoxi yopiladi)
-- -----------------------------------------------------------------------------
-- `ENABLE ROW LEVEL SECURITY` idempotent: allaqachon yoqilgan bo'lsa NO-OP.
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 3) RUXSAT BERUVCHI `true` SELECT POLICY'LARI OLIB TASHLANADI (E2 shoxi)
-- -----------------------------------------------------------------------------
-- NOMGA bog'lanmaydi: production'dagi policy nomi repo'dagidan farq qilishi
-- mumkin (bu loyihada `schema.sql` production'dan ALLAQACHON farq qiladi).
-- Shuning uchun MEZON — predikatning O'ZI: `qual IS NULL` (ya'ni cheklovsiz)
-- yoki `qual = 'true'`.
--
-- DIQQAT — ILGARI BU YERDA NOTO'G'RI YOZILGAN EDI ("INSERT/UPDATE/DELETE
-- policy'lari QO'LGA TEGMAYDI"). Filtr `cmd IN ('SELECT', 'ALL')` bo'lgani
-- uchun `FOR ALL` policy HAM olib tashlanadi, `ALL` policy esa INSERT /
-- UPDATE / DELETE ni HAM boshqaradi. Ya'ni production'da cheklovsiz `ALL`
-- policy bo'lgan bo'lsa, u bilan birga MEHMONNING YOZISH yo'li ham yopilgan.
-- Bu QATTIQLASHTIRISH, regressiya emas — haqiqiy yozish yo'li alohida
-- nomlangan policy'lar orqali beriladi (`supabase/schema.sql:890-899`:
-- "Authenticated users can create questions" / "Owners can update their
-- questions" / "Owners can delete their questions") va ular TEGILMAYDI.
-- LEKIN: cheklovsiz `ALL` policy HAQIQATAN bor edimi — O'LCHANMAGAN,
-- chunki yuqoridagi `NOTICE` lar SQL Editor'da ko'rinmagan.
-- Nomlangan `FOR SELECT` / `FOR INSERT` / `FOR UPDATE` / `FOR DELETE`
-- policy'lari esa bu blok tomonidan HECH QACHON tegilmaydi.
DO $$
DECLARE
    v_pol      record;
    v_dropped  int := 0;
BEGIN
    FOR v_pol IN
        SELECT policyname, cmd, qual
          FROM pg_policies
         WHERE schemaname = 'public'
           AND tablename  = 'questions'
           AND cmd IN ('SELECT', 'ALL')
           AND permissive = 'PERMISSIVE'
           AND (qual IS NULL OR btrim(lower(qual)) = 'true')
    LOOP
        RAISE NOTICE 'OLIB TASHLANDI: cheklovsiz % policy "%" (USING=%)',
            v_pol.cmd, v_pol.policyname, coalesce(v_pol.qual, '<yo''q>');
        EXECUTE format('DROP POLICY %I ON public.questions', v_pol.policyname);
        v_dropped := v_dropped + 1;
    END LOOP;

    RAISE NOTICE 'JAMI olib tashlangan cheklovsiz SELECT/ALL policy: %', v_dropped;
END $$;

-- -----------------------------------------------------------------------------
-- 4) TO'G'RI POLICY QAYTA O'RNATILADI
-- -----------------------------------------------------------------------------
-- Predikat `20260820_p0_security_remediation.sql` dagi bilan AYNI —
-- yangi qoida O'YLAB TOPILMAYDI, faqat HAQIQATAN kuchga kiritiladi.
--
-- `TO anon, authenticated` ATAYLAB yozilmagan: `public.is_admin_or_moderator()`
-- va `auth.uid()` ikki rol uchun ham to'g'ri javob beradi, `postgres`/
-- `service_role` esa RLS'ni chetlab o'tadi (BYPASSRLS) — ya'ni rol ro'yxati
-- hech narsa qo'shmaydi, faqat kelgusida yangi rol qo'shilsa jim
-- fail-open xatariga yo'l ochadi.
DROP POLICY IF EXISTS "Questions are viewable by everyone"        ON public.questions;
DROP POLICY IF EXISTS "Public questions are viewable by everyone" ON public.questions;
CREATE POLICY "Public questions are viewable by everyone" ON public.questions
FOR SELECT USING (
    is_anonymous = false
    OR auth.uid() = user_id
    OR public.is_admin_or_moderator()
);

-- -----------------------------------------------------------------------------
-- 5) POST-DEPLOY ASSERTION — "muvaffaqiyatli, lekin hech narsa o'zgarmadi"
--    holatini IMKONSIZ qiladi (§20: jim o'tish yo'q)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_rls        boolean;
    v_open       int;
    v_correct    int;
    v_total_anon      int;
    v_visible_to_anon int;
BEGIN
    SELECT relrowsecurity INTO v_rls
      FROM pg_class WHERE oid = 'public.questions'::regclass;
    IF NOT v_rls THEN
        RAISE EXCEPTION 'ASSERTION: questions da RLS hamon O''CHIQ.';
    END IF;

    SELECT count(*) INTO v_open
      FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'questions'
       AND cmd IN ('SELECT', 'ALL') AND permissive = 'PERMISSIVE'
       AND (qual IS NULL OR btrim(lower(qual)) = 'true');
    IF v_open > 0 THEN
        RAISE EXCEPTION
            'ASSERTION: hamon % ta cheklovsiz SELECT/ALL policy bor — '
            'policy''lar OR qilinadi, ya''ni teshik YOPILMAGAN.', v_open;
    END IF;

    SELECT count(*) INTO v_correct
      FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'questions'
       AND cmd = 'SELECT'
       AND qual LIKE '%is_anonymous%'
       AND qual LIKE '%auth.uid()%';
    IF v_correct < 1 THEN
        RAISE EXCEPTION
            'ASSERTION: `is_anonymous` + `auth.uid()` tekshiradigan SELECT '
            'policy topilmadi.';
    END IF;

    -- ENG MUHIM O'LCHOV.
    --
    -- ILGARI BU YERDA policy predikati QO'LDA QAYTA YOZILGAN edi. Ikki
    -- jihatdan soxta o'lchov edi:
    --   (1) u REPO'dagi matnni tekshirardi, HAQIQATDA qo'llanadigan
    --       policy'ni EMAS — production policy'si boshqacha bo'lsa ham
    --       assertion YASHIL qolardi;
    --   (2) migration `postgres` roli ostida ishlaydi, u esa RLS'ni
    --       CHETLAB O'TADI — ya'ni rol almashtirilmasa "RLS ishlayaptimi"
    --       degan savol umuman berilmagan bo'ladi.
    -- Endi o'lchovni PostgreSQL O'ZI qiladi: `anon` roli nomidan oddiy
    -- `SELECT`, policy avtomatik qo'llanadi, `auth.uid()` NULL — aynan
    -- tizimga KIRMAGAN mehmon holati.
    SELECT count(*) INTO v_total_anon
      FROM public.questions WHERE is_anonymous = TRUE;

    BEGIN
        EXECUTE 'SET LOCAL ROLE anon';
        SELECT count(*) INTO v_visible_to_anon
          FROM public.questions WHERE is_anonymous = TRUE;
        EXECUTE 'RESET ROLE';
    EXCEPTION
        WHEN insufficient_privilege THEN
            -- `anon` ga jadval/funksiya huquqi berilmagan: bu izolyatsiyadan
            -- KUCHLIROQ himoya (klient ham xato oladi, ma'lumot chiqmaydi).
            -- Sub-tranzaksiya qaytarilgani uchun rol allaqachon tiklangan.
            v_visible_to_anon := 0;
    END;

    IF v_visible_to_anon > 0 THEN
        RAISE EXCEPTION
            'ASSERTION: `anon` roli hamon % ta ANONIM savolni KO''RADI '
            '(bazada jami % ta anonim savol bor).',
            v_visible_to_anon, v_total_anon;
    END IF;

    IF v_total_anon = 0 THEN
        -- HALOL CHEKLOV (§0): bazada anonim savol bo'lmasa, yuqoridagi 0
        -- himoyani ISBOTLAMAYDI — u BO'SH TO'PLAM natijasi. Fayl oxiridagi
        -- diagnostika `SELECT` i ikki sonni yonma-yon ko'rsatadi.
        RAISE NOTICE 'DIQQAT: bazada anonim savol YO''Q — anon o''lchovi '
            'BO''SH TO''PLAMDA bajarildi, ya''ni hech narsa isbotlanmadi.';
    END IF;

    RAISE NOTICE 'OK: RLS yoqilgan, cheklovsiz SELECT policy yo''q, '
                 'anonim savollar sessiyasiz KO''RINMAYDI.';
END $$;

COMMIT;

-- =============================================================================
-- DEPLOY'DAN KEYIN KO'RINADIGAN DIAGNOSTIKA
--
-- Yuqoridagi `RAISE NOTICE` lar SUPABASE SQL EDITOR'DA KO'RINMAYDI
-- (o'lchangan: 219545f) — shu sababli natija COMMIT'dan keyin JADVAL bo'lib
-- qaytariladi. Himoya bu SELECT'ga TAYANMAYDI: assertion buzilsa migration
-- yiqiladi va COMMIT umuman bo'lmaydi.
-- =============================================================================

-- 1) Umumiy holat. Kutilgan: rls_yoqilgan = true, cheklovsiz_policy = 0.
--    `anonim_savol_soni = 0` bo'lsa — anon o'lchovi BO'SH TO'PLAMDA
--    bajarilgan, ya'ni himoya HALI ISBOTLANMAGAN (§0).
SELECT (SELECT relrowsecurity FROM pg_class
         WHERE oid = 'public.questions'::regclass)        AS rls_yoqilgan,
       (SELECT count(*) FROM pg_policies
         WHERE schemaname = 'public' AND tablename = 'questions'
           AND cmd IN ('SELECT', 'ALL') AND permissive = 'PERMISSIVE'
           AND (qual IS NULL OR btrim(lower(qual)) = 'true')) AS cheklovsiz_policy,
       (SELECT count(*) FROM public.questions
         WHERE is_anonymous = TRUE)                       AS anonim_savol_soni;

-- 2) Policy'larning AYNAN qaysi biri qolgani (E1/E2 shoxini shu ko'rsatadi).
SELECT policyname, cmd, permissive, roles, qual
  FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'questions'
 ORDER BY cmd, policyname;

-- 3) ANON NOMIDAN o'lchash (ixtiyoriy, QO'LDA). DIQQAT: uchta gapni BIRGA
--    ishga tushiring — `RESET ROLE` tushib qolsa sessiya `anon` bo'lib
--    qoladi va keyingi so'rovlaringiz huquqsiz bajariladi:
--
--      SET ROLE anon;
--      SELECT count(*) FROM public.questions WHERE is_anonymous = TRUE;
--      RESET ROLE;
--
--    Kutilgan natija: 0.

-- KLIENT TOMONDAN LIVE ISBOT (anon kalit, sessiyasiz) — kutilgan natija
-- BO'SH massiv:
--
--   GET /rest/v1/questions?select=id,is_anonymous,user_id&is_anonymous=eq.true
--   -> 200 []
--
-- va view HAMON ishlashi kerak (regressiya yo'qligi isboti):
--
--   GET /rest/v1/public_questions_view?select=id,is_anonymous,user_id,author_name
--   -> 200 [{"is_anonymous":true,"user_id":null,"author_name":"Anonim fuqaro"}]
--
-- Gated live test:
--   flutter test test/integration/questions_anonymity_live_test.dart \
--     --dart-define-from-file=env/prod.json --reporter expanded
-- =============================================================================
