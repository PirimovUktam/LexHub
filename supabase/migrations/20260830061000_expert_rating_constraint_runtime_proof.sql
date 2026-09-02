-- NUQSON G — D5 BO'SHLIG'INI YOPADIGAN RUNTIME ISBOT.
--
-- `20260830060000_expert_rating_no_fabrication.sql` COMMIT bo'ldi (push JSON
-- pastda), ya'ni uning D1-D4 tekshiruvlari SERVERDA bajarildi. Lekin D5 —
-- "cheklov to'qima bahoni HAQIQATAN rad etadimi" — O'LCHANMADI, chunki
-- `expert_profiles` jadvali BO'SH (mustaqil kanal bilan o'lchandi: REST
-- `GET /rest/v1/expert_profiles?select=rating,reviews_count` →
-- `Content-Range: */0`). Soxta advokat qatori YARATILMAYDI (§20 / "feyk
-- advokat qo'shmaslik" sharti), shuning uchun D5 boshqa yo'l bilan olinadi:
--
--   cheklov ifodasi KATALOGDAN o'qiladi va AYNI shu ifoda bilan TEMP jadval
--   quriladi. TEMP jadval sessiya tugashi bilan yo'qoladi, `expert_profiles`
--   ga TEGMAYDI va hech qanday "advokat" yaratmaydi. Rad etish/qabul qilish
--   xatti-harakati DEPLOY QILINGAN ifodada o'lchanadi.
--
-- ISBOTLANADIGAN SHARTLAR:
--   A1  cheklov mavjud va ifodasi KUTILGAN matnga teng;
--   A2  ustun NULL qabul qiladi va sukut qiymati hisoblanganda NULL;
--   A3  deploy qilingan ifoda: (5.00, 0) RAD ETILADI  — to'qima baho;
--       (NULL, 0) QABUL  — bahosiz advokat;
--       (4.50, 3) QABUL  — haqiqiy baho + haqiqiy baho soni;
--       (NULL, 3) RAD ETILADI — baho soni bor, baho yo'q (nomuvofiqlik).
--
-- Bu migratsiya SXEMANI O'ZGARTIRMAYDI — faqat o'lchaydi va shart buzilsa
-- `RAISE` bilan yiqiladi.

BEGIN;

DO $proof$
DECLARE
    v_def TEXT;
    v_notnull BOOLEAN;
    v_default TEXT;
    v_value NUMERIC;
    v_rows INTEGER;
    v_case TEXT;
    v_expect_ok BOOLEAN;
    v_ok BOOLEAN;
BEGIN
    SELECT pg_get_constraintdef(oid) INTO v_def
      FROM pg_constraint
     WHERE conrelid = 'public.expert_profiles'::regclass
       AND conname = 'expert_profiles_rating_requires_reviews';
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'A1 FAILED: cheklov yo''q — 20260830060000 qo''llanmagan';
    END IF;
    IF v_def != 'CHECK (((rating IS NULL) = (reviews_count = 0)))' THEN
        RAISE EXCEPTION 'A1 FAILED: cheklov ifodasi kutilmagan: %', v_def;
    END IF;
    RAISE NOTICE 'A1 OK: %', v_def;

    SELECT a.attnotnull, pg_get_expr(d.adbin, d.adrelid)
      INTO v_notnull, v_default
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
     WHERE a.attrelid = 'public.expert_profiles'::regclass
       AND a.attname = 'rating';
    IF v_notnull THEN
        RAISE EXCEPTION 'A2 FAILED: ustun hamon NOT NULL';
    END IF;
    IF v_default IS NOT NULL THEN
        EXECUTE format('SELECT (%s)::numeric', v_default) INTO v_value;
        IF v_value IS NOT NULL THEN
            RAISE EXCEPTION 'A2 FAILED: sukut qiymat SON: %', v_default;
        END IF;
    END IF;
    RAISE NOTICE 'A2 OK: NULL qabul qiladi, sukut qiymat NULL beradi';

    SELECT count(*) INTO v_rows FROM public.expert_profiles;
    RAISE NOTICE 'O''LCHOV: `expert_profiles` da % qator (haqiqiy qatorda D5 '
        'o''lchash uchun jadval bo''sh — soxta qator YARATILMAYDI)', v_rows;

    -- A3: DEPLOY QILINGAN ifoda TEMP jadvalda sinaladi.
    EXECUTE format(
        'CREATE TEMP TABLE lx_rating_probe ('
        '  rating NUMERIC(3,2), reviews_count INTEGER NOT NULL, '
        '  CONSTRAINT lx_probe_chk %s) ON COMMIT DROP', v_def);

    FOR v_case, v_expect_ok IN
        SELECT * FROM (VALUES
            ('5.00, 0', FALSE),
            ('NULL, 0', TRUE),
            ('4.50, 3', TRUE),
            ('NULL, 3', FALSE)
        ) AS t(c, ok)
    LOOP
        v_ok := TRUE;
        BEGIN
            EXECUTE format(
                'INSERT INTO lx_rating_probe (rating, reviews_count) '
                'VALUES (%s)', v_case);
        EXCEPTION
            WHEN check_violation THEN
                v_ok := FALSE;
        END;
        IF v_ok != v_expect_ok THEN
            RAISE EXCEPTION 'A3 FAILED: (%) uchun kutilgan %, olingan %',
                v_case, v_expect_ok, v_ok;
        END IF;
        RAISE NOTICE 'A3 OK: (%) → % (kutilgan)', v_case, v_ok;
    END LOOP;

    RAISE NOTICE 'A1-A3 OK: to''qima baho (5.00 + 0 sharh) BAZA DARAJASIDA '
        'rad etiladi, bahosiz advokat esa QABUL qilinadi';
END
$proof$;

COMMIT;

-- =============================================================================
-- QO'LLASH NATIJASI (verbatim, `supabase db push --include-all`)
-- =============================================================================
-- 20260830060000:
--   {"upToDate":false,"dryRun":false,
--    "migrations":["20260830060000_expert_rating_no_fabrication.sql"],
--    "seeds":[],"roles":[],"message":"Finished supabase db push."}
-- 20260830061000 (shu fayl):
--   {"upToDate":false,"dryRun":false,
--    "migrations":["20260830061000_expert_rating_constraint_runtime_proof.sql"],
--    "seeds":[],"roles":[],"message":"Finished supabase db push."}
--
-- Bu assertionlar BEZAK EMAS — o'lchangan: 20260830060000 ning BIRINCHI
-- urinishi AYNI shu mexanizm bilan yiqilgan edi ("D1 FAILED: sukut qiymat
-- hamon bor: NULL::numeric", SQLSTATE P0001) va butun migratsiya rollback
-- bo'ldi. Ya'ni shart buzilsa push HAQIQATAN to'xtaydi.
--
-- NOT VERIFIED (halol qoldiriladi):
--   * haqiqiy advokat qatorida cheklov o'lchanmadi — jadval BO'SH;
--   * `expert_directory` ko'rinishi live PostgREST sxema keshida YO'Q
--     (`PGRST205`) — bu ALOHIDA masala, shu migratsiyaga tegishli emas.
