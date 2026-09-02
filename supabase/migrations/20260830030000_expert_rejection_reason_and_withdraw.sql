-- =============================================================================
-- LEXHUB — RAD ETISH SABABI + ROLNI SAQLASH + ARIZANI QAYTARIB OLISH
-- Sana: 2026-08-30
-- =============================================================================
--
-- BU FAYL UCHTA ANIQ NUQSONNI YOPADI. Har biri oldingi migratsiyada
-- ATAYLAB ochiq qoldirilgan va shu yerda yozib ketilgan:
--
-- NUQSON D — RAD ETILGAN ARIZACHI SABABNI BILMAYDI
--   `20260829130000_...sql:374-377` (4-bo'lim): "`rejection_reason` ustuni
--   QO'SHILMADI: moderator UI'da sabab maydoni YO'Q". Oqibat: advokat
--   litsenziya raqamidagi bitta xato uchun rad etiladi, LEKIN nimani
--   tuzatishni BILMAYDI va 24 soatdan keyin AYNI xato bilan qayta topshiradi.
--   Bu moderatorga ham zarar: ayni ariza aylanib yuradi.
--
-- NUQSON E — TASDIQLASH `admin`/`moderator` ROLINI YO'Q QILADI
--   `20260829130000_...sql:184` -> `role = 'verified_expert'` SHARTSIZ.
--   Ya'ni ariza topshirgan moderator TASDIQLANSA moderatorlikni YO'QOTADI:
--   `is_admin_or_moderator()` FALSE bo'ladi va u boshqa hech kimni
--   tasdiqlay olmaydi. Ayni faylning 381-384 qatorlarida bu "TUZATILMADI"
--   deb yozilgan. RAD ETISH shoxi esa `lawyer` ni ATAYLAB saqlaydi
--   (`role = CASE WHEN role = 'verified_expert' THEN 'citizen' ELSE role END`)
--   — ya'ni ikki shox bir-biriga MOS EMAS edi.
--
-- NUQSON F — ARIZANI QAYTARIB OLISH YO'LI YO'Q
--   `20260829130000_...sql:466-469`: "HAQIQIY ekspert sessiyasini talab
--   qiladi. Ikkinchisi ishlab chiqarish bazasida SOXTA advokat arizasini
--   yaratardi va uni O'CHIRISHNING YO'LI YO'Q (service_role kaliti YO'Q,
--   DELETE policy'si YO'Q) — ATAYLAB QILINMADI."
--   Bu ikki narsani bloklagan: (a) foydalanuvchi xato bilan topshirgan
--   arizasini qaytarib ola olmaydi, (b) gvard trigger'ining KLIENT `UPDATE`
--   ini rad etishi **NOT VERIFIED** holatida qolgan
--   (`20260830020000_...sql` 3-qaydi), chunki HAQIQIY JWT bilan o'lchash
--   bazada haqiqiy ariza qoldirardi.
--   `public.withdraw_expert_application()` ikkisini birga yopadi.
--
-- IDEMPOTENT: qayta qo'llanishi xavfsiz. DESTRUKTIV DDL YO'Q (`DROP TABLE`,
-- ustun o'chirish, ma'lumot o'chirish yo'q). Yagona `DROP FUNCTION` —
-- `verify_expert_application(uuid, boolean)` ning 2-argumentli SHAKLI, u
-- 3-argumentli shakl bilan almashtiriladi (sabab uchun uchinchi parametr).
--
-- 6-bo'limdagi `DO` bloki QO'LLASH PAYTIDA bajariladi: birorta invariant
-- buzilsa BUTUN migratsiya rollback bo'ladi va "qo'llandi" deb YOZILMAYDI.
-- Ya'ni bu faylning muvaffaqiyatli push bo'lishining O'ZI — isbot (§0).

BEGIN;

-- =============================================================================
-- 1. `rejection_reason` USTUNI
-- =============================================================================
-- NIMA UCHUN `TEXT` + CHECK, `VARCHAR(500)` EMAS: loyihadagi mavjud naqsh
-- (`client_error_logs`) uzunlikni CHECK/trigger bilan qo'yadi. `VARCHAR(n)`
-- ni keyinroq kattalashtirish jadval qulfini talab qiladi.
--
-- NIMA UCHUN NULLABLE: sabab MAJBURIY EMAS. Moderator "hujjat o'qilmaydi"
-- deb yozishi mumkin, lekin sababsiz rad etish ham qonuniy holat (masalan
-- litsenziya raqami umuman mavjud emas). MAJBURIY qilish moderatorni
-- "." kabi bo'sh matn yozishga majburlardi — bu YOLG'ON sabab bo'lardi (§20).
ALTER TABLE public.expert_profiles
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

DO $constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'expert_profiles_rejection_reason_len'
           AND conrelid = 'public.expert_profiles'::regclass
    ) THEN
        ALTER TABLE public.expert_profiles
            ADD CONSTRAINT expert_profiles_rejection_reason_len
            CHECK (rejection_reason IS NULL
                   OR char_length(rejection_reason) BETWEEN 1 AND 500);
    END IF;
END
$constraint$;

COMMENT ON COLUMN public.expert_profiles.rejection_reason IS
    'Moderator rad etish sababi (ixtiyoriy, <= 500 belgi). FAQAT '
    '`verify_expert_application()` yozadi; klient `PATCH` ini gvard trigger '
    'rad etadi. Tasdiqlashda va qayta topshirishda TOZALANADI.';


-- =============================================================================
-- 2. GVARD: `rejection_reason` HAM MODERATSIYA YO'LIGA QULFLANADI
-- =============================================================================
-- Tana `20260829130000_...sql:87-123` DAN AYNAN ko'chirildi, faqat YETTINCHI
-- gvard qo'shildi. Bu qator bo'lmasa arizachi
--     PATCH /rest/v1/expert_profiles?user_id=eq.<o'zi> {"rejection_reason": "OK"}
-- bilan moderatorning sababini O'ZI yozib qo'ya olardi — moderatsiya tarixi
-- ishonchsiz bo'lardi (NUQSON B bilan AYNI SINF).
--
-- `SECURITY INVOKER` SAQLANADI: DEFINER bo'lsa `current_user` doim funksiya
-- egasi bo'lib, chaqiruvchini ajratish MUMKIN EMAS (NUQSON A).
CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
BEGIN
    IF TG_OP = 'UPDATE' AND NOT public.is_privileged_db_role() THEN
        IF NEW.rating IS DISTINCT FROM OLD.rating THEN
            RAISE EXCEPTION 'Rating Tampering Blocked: Ratings are computed automatically from verified reviews.';
        END IF;
        IF NEW.reviews_count IS DISTINCT FROM OLD.reviews_count THEN
            RAISE EXCEPTION 'Reviews Count Tampering Blocked.';
        END IF;
        IF NEW.verified_at IS DISTINCT FROM OLD.verified_at THEN
            RAISE EXCEPTION 'Expert verification date is managed by administrators.';
        END IF;
        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Expert user_id is immutable.';
        END IF;
        -- T-2: tasdiqlangandan KEYIN litsenziya raqami QOTIB QOLADI.
        IF OLD.verified_at IS NOT NULL
           AND NEW.license_number IS DISTINCT FROM OLD.license_number THEN
            RAISE EXCEPTION 'License Number Locked: A verified license number can only be changed by an administrator.';
        END IF;
        -- NUQSON B: rad etish HOLATINI faqat moderatsiya yo'li o'zgartiradi.
        IF NEW.rejected_at IS DISTINCT FROM OLD.rejected_at THEN
            RAISE EXCEPTION 'Rejection state is managed by administrators.';
        END IF;
        -- NUQSON D DAVOMI: rad etish SABABINI ham faqat moderatsiya yo'li
        -- yozadi (aks holda arizachi o'ziga qulay sabab to'qib qo'yardi).
        IF NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason THEN
            RAISE EXCEPTION 'Rejection reason is managed by administrators.';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;


-- =============================================================================
-- 3. `verify_expert_application()` — SABAB PARAMETRI + NUQSON E TUZATISHI
-- =============================================================================
-- NIMA UCHUN 2-ARGUMENTLI SHAKL O'CHIRILADI (`DROP`, `CREATE OR REPLACE`
-- EMAS): PostgreSQL uchun `f(uuid, boolean)` va `f(uuid, boolean, text)` —
-- IKKI XIL funksiya. Ikkisi birga turganda `p_rejection_reason` ga DEFAULT
-- berilgani uchun 2 argumentli chaqiruv IKKISIGA ham mos keladi va
-- PostgREST `PGRST203 / function is not unique` xatosini qaytaradi —
-- moderatsiya BUTUNLAY ISHLAMAY qolardi. Shuning uchun eski shakl olib
-- tashlanadi; klient AYNI 2 parametr bilan chaqirishda davom etadi
-- (`p_rejection_reason` DEFAULT NULL).
--
-- ZANJIR QAYTA IJRO ETILISHI BUZILMAYDI: `20260830020000_...sql` ning A4
-- assersiyasi `verify_expert_application(uuid, boolean)` ni talab qiladi,
-- lekin u BU FAYLDAN OLDIN bajariladi (`20260830020000` < `20260830030000`),
-- ya'ni o'sha nuqtada 2-argumentli shakl HAMON mavjud.
DROP FUNCTION IF EXISTS public.verify_expert_application(UUID, BOOLEAN);

CREATE OR REPLACE FUNCTION public.verify_expert_application(
    p_target_user_id UUID,
    p_approve BOOLEAN,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows INTEGER;
    v_old_role TEXT;
    v_reason TEXT;
BEGIN
    IF NOT public.is_admin_or_moderator() THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can approve expert applications.';
    END IF;

    -- Bo'sh/faqat bo'sh joydan iborat sabab = SABAB YO'Q (§20: bo'sh matnni
    -- "sabab bor" deb ko'rsatish yolg'on bo'lardi). `left(...,500)` CHECK
    -- buzilishidan himoya qiladi: uzun matn KESILADI, qaror YO'QOLMAYDI.
    v_reason := left(NULLIF(btrim(COALESCE(p_rejection_reason, '')), ''), 500);

    IF p_approve THEN
        -- NUQSON E TUZATISHI: `admin` va `moderator` rollari SAQLANADI.
        -- Eski shartsiz `role = 'verified_expert'` ariza topshirgan
        -- moderatorni tasdiqlaganda uni ODDIY advokatga aylantirardi va
        -- `is_admin_or_moderator()` FALSE bo'lib, u boshqa arizani
        -- tasdiqlay olmasdi (o'z-o'zini huquqdan mahrum qilish).
        -- `is_verified = TRUE` IKKALA holatda ham qo'yiladi: u advokat
        -- statusi belgisi, xodim belgisi EMAS.
        -- `lawyer` ATAYLAB `verified_expert` ga o'tadi — bu tasdiqlashning
        -- ma'nosi (rad etish shoxi esa `lawyer` ni saqlaydi, chunki u rolni
        -- shu funksiya BERMAGAN).
        UPDATE public.profiles
        SET
            role = CASE
                WHEN role::text IN ('admin', 'moderator') THEN role
                ELSE 'verified_expert'::user_role
            END,
            is_verified = TRUE,
            updated_at = now()
        WHERE id = p_target_user_id;

        UPDATE public.expert_profiles
        SET
            verified_at = now(),
            rejected_at = NULL,
            -- Tasdiqlangan arizada oldingi rad etish sababi TURISHI
            -- MUMKIN EMAS — u UI'da "rad etilgan" deb ko'rinardi.
            rejection_reason = NULL,
            updated_at = now()
        WHERE user_id = p_target_user_id;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        -- JIM MUVAFFAQIYAT YO'Q (§20).
        IF v_rows = 0 THEN
            RAISE EXCEPTION 'Expert application not found for the given user.';
        END IF;

        SELECT role::text INTO v_old_role
        FROM public.profiles WHERE id = p_target_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'approved',
            -- Server AYTGAN oqibat: klient rolni O'ZI hisoblamaydi (§14).
            'role', v_old_role,
            'staff_role_preserved', (v_old_role IN ('admin', 'moderator'))
        );
    ELSE
        -- T-3: RAD ETISH HOLAT QOLDIRADI.
        UPDATE public.expert_profiles
        SET
            verified_at = NULL,
            rejected_at = now(),
            rejection_reason = v_reason,
            updated_at = now()
        WHERE user_id = p_target_user_id;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        IF v_rows = 0 THEN
            RAISE EXCEPTION 'Expert application not found for the given user.';
        END IF;

        -- T-4: `is_verified = FALSE` ochiq katalog view'ini va
        -- `enforce_expert_answer()` ni BIRGA yopadi.
        SELECT role::text INTO v_old_role
        FROM public.profiles WHERE id = p_target_user_id;

        UPDATE public.profiles
        SET
            is_verified = FALSE,
            -- FAQAT shu funksiya bergan rol qaytariladi; `lawyer` SAQLANADI.
            role = CASE
                WHEN role::text = 'verified_expert' THEN 'citizen'::user_role
                ELSE role
            END,
            updated_at = now()
        WHERE id = p_target_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'rejected',
            'role_reverted', (v_old_role = 'verified_expert'),
            'previous_role', v_old_role,
            -- Klient shu qiymat bilan "sabab saqlandi" deb ko'rsatadi.
            -- NULL = sabab yozilmagan (bo'sh matn YUBORILMAYDI).
            'rejection_reason', v_reason
        );
    END IF;
END;
$$;

COMMENT ON FUNCTION public.verify_expert_application(UUID, BOOLEAN, TEXT) IS
    'Ekspert arizasini tasdiqlaydi yoki rad etadi (faqat admin/moderator). '
    'Tasdiqlashda `admin`/`moderator` roli SAQLANADI. Rad etishda ixtiyoriy '
    'sabab `expert_profiles.rejection_reason` ga yoziladi va arizachiga '
    'sovutish davri xabarida ko''rsatiladi.';


-- =============================================================================
-- 4. `apply_for_expert_verification()` — SABAB ARIZACHIGA YETIB BORADI
-- =============================================================================
-- NIMA UCHUN SABAB AYNAN SHU YERDA KO'RSATILADI (tanlov, yashirilmagan):
-- arizachi uchun ALOHIDA "mening arizam holati" ekrani YO'Q va uni qo'shish
-- yangi read yo'li (datasource -> repository -> usecase -> bloc -> UI) talab
-- qilardi. Foydalanuvchi sababni AYNAN qayta topshirishga uringan paytda
-- so'raydi ("nega o'tmadi?"), va shu payt server allaqachon `LX429` bilan
-- gapiradi. Sababni SHU xabarga qo'shish — bir qatorlik o'zgarish, yangi
-- ekran esa besh qatlamlik.
--
-- HALOL CHEKLOV: `LX429` matni SERVER matni. `failure_text.dart` o'zbek
-- tilida uni AYNAN ko'rsatadi, ingliz tilida esa `errorApplicationCooldown`
-- (umumiy) matn chiqadi — ya'ni INGLIZ UI'da sabab KO'RINMAYDI. Bu YANGI
-- nuqson emas: qayta topshirish VAQTI ham ilgari shu sababdan ko'rinmasdi
-- (`failure_text.dart:21-24` da qayd etilgan murosa).
--
-- Qolgan TANA `20260829130000_...sql:271-361` DAN AYNAN ko'chirildi. Ikki
-- o'zgarish: (a) `LX429` xabari sababni qo'shadi, (b) qayta topshirish
-- `rejection_reason` ni HAM tozalaydi (aks holda kutayotgan arizada eski
-- sabab turib qolardi va moderator uni yangi qaror deb o'qishi mumkin edi).
CREATE OR REPLACE FUNCTION public.apply_for_expert_verification(
    p_specialization VARCHAR(128),
    p_experience_years INTEGER,
    p_license_number VARCHAR(64),
    p_license_document_url TEXT DEFAULT NULL,
    p_workplace VARCHAR(255) DEFAULT NULL,
    p_education TEXT DEFAULT NULL,
    p_consultation_fee NUMERIC(12, 2) DEFAULT 0.00
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_expert_id UUID;
    v_rejected_at TIMESTAMPTZ;
    v_reason TEXT;
    v_retry_at TEXT;
    v_cooldown CONSTANT INTERVAL := INTERVAL '24 hours';
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to apply for expert verification.';
    END IF;

    -- SOVUTISH DAVRI. `SELECT` mavjud qatorni topmasa `v_rejected_at` NULL
    -- bo'ladi (birinchi ariza) — shart ishlamaydi.
    SELECT rejected_at, rejection_reason INTO v_rejected_at, v_reason
    FROM public.expert_profiles
    WHERE user_id = v_user_id;

    IF v_rejected_at IS NOT NULL AND v_rejected_at > now() - v_cooldown THEN
        v_retry_at := to_char(
            (v_rejected_at + v_cooldown) AT TIME ZONE 'Asia/Tashkent',
            'DD.MM.YYYY HH24:MI');
        -- IKKI XIL XABAR, bitta shablonga sabab "yopishtirilmaydi": sabab
        -- yo'q bo'lganda "Sabab: " degan bo'sh sarlavha chiqarish YOLG'ON
        -- taassurot berardi (§20).
        IF v_reason IS NULL THEN
            RAISE EXCEPTION
                'Ariza rad etilgan. Qayta topshirish % dan keyin mumkin.',
                v_retry_at
                USING ERRCODE = 'LX429';
        ELSE
            RAISE EXCEPTION
                'Ariza rad etilgan. Sabab: %. Qayta topshirish % dan keyin mumkin.',
                v_reason, v_retry_at
                USING ERRCODE = 'LX429';
        END IF;
    END IF;

    INSERT INTO public.expert_profiles (
        user_id,
        specialization,
        experience_years,
        license_number,
        license_document_url,
        workplace,
        education,
        consultation_fee,
        verified_at,
        is_available_for_booking
    )
    VALUES (
        v_user_id,
        p_specialization,
        GREATEST(0, p_experience_years),
        p_license_number,
        p_license_document_url,
        p_workplace,
        p_education,
        p_consultation_fee,
        NULL, -- Pending approval
        TRUE
    )
    ON CONFLICT (user_id) DO UPDATE SET
        specialization = EXCLUDED.specialization,
        experience_years = EXCLUDED.experience_years,
        -- T-2: tasdiqlangan ariza uchun litsenziya raqami SAQLANADI.
        license_number = CASE
            WHEN expert_profiles.verified_at IS NULL THEN EXCLUDED.license_number
            ELSE expert_profiles.license_number
        END,
        license_document_url = COALESCE(EXCLUDED.license_document_url, expert_profiles.license_document_url),
        workplace = EXCLUDED.workplace,
        education = EXCLUDED.education,
        consultation_fee = EXCLUDED.consultation_fee,
        -- T-3 DAVOMI: qayta topshirish arizani YANA KUTAYOTGAN qiladi.
        rejected_at = NULL,
        -- ESKI SABAB TOZALANADI: ariza endi KUTAYOTGAN, "rad etilgan" emas.
        rejection_reason = NULL,
        updated_at = now()
    RETURNING id INTO v_expert_id;

    RETURN jsonb_build_object(
        'success', true,
        'expert_id', v_expert_id,
        'status', 'pending_verification',
        'message', 'Ariza muvaffaqiyatli topshirildi. Ma''muriyat tomonidan tekshirilgach tasdiqlanadi.'
    );
END;
$$;


-- =============================================================================
-- 5. NUQSON F: `withdraw_expert_application()` — EGA ARIZASINI QAYTARIB OLADI
-- =============================================================================
-- NIMA UCHUN RPC, `DELETE` POLICY EMAS: `DELETE` policy qo'shilsa
-- foydalanuvchi TASDIQLANGAN profilini ham o'chirib tashlay olardi — bu
-- katalogdan advokatni yo'q qilib, unga bog'langan konsultatsiyalarni
-- `ON DELETE CASCADE` bilan JIM o'chirardi (§20). RPC uchta shartni
-- QAT'IY tekshiradi va har birini ALOHIDA xato kodi bilan rad etadi.
--
-- XAVFSIZLIK: `SECURITY DEFINER`, lekin nishon HAR DOIM `auth.uid()` —
-- parametr YO'Q. Ya'ni IDOR yuzasi yo'q: boshqa odamning arizasini
-- o'chirish uchun uzatiladigan qiymatning O'ZI mavjud emas.
--
-- SOVUTISH DAVRI CHETLAB O'TILMAYDI: rad etilgan arizani o'chirib yangi
-- topshirish 24 soatlik qulfni bekor qilardi (`rejected_at` yo'q qator =
-- birinchi ariza). Shuning uchun sovutish davri ichida `LX429` qaytadi —
-- AYNI kod, klient uni allaqachon tushunadi.
CREATE OR REPLACE FUNCTION public.withdraw_expert_application()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id     UUID;
    v_expert_id   UUID;
    v_verified_at TIMESTAMPTZ;
    v_rejected_at TIMESTAMPTZ;
    v_rows        INTEGER;
    v_dep         INTEGER;
    v_fk          RECORD;
    v_cooldown CONSTANT INTERVAL := INTERVAL '24 hours';
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to withdraw an expert application.';
    END IF;

    SELECT id, verified_at, rejected_at
      INTO v_expert_id, v_verified_at, v_rejected_at
      FROM public.expert_profiles
     WHERE user_id = v_user_id;

    -- JIM MUVAFFAQIYAT YO'Q: ariza yo'q bo'lsa "o'chirildi" deb aytish
    -- foydalanuvchini chalg'itardi.
    IF v_expert_id IS NULL THEN
        RAISE EXCEPTION 'Qaytarib olish uchun ariza topilmadi.'
            USING ERRCODE = 'LX404';
    END IF;

    -- (1) TASDIQLANGAN PROFIL O'CHIRILMAYDI.
    IF v_verified_at IS NOT NULL THEN
        RAISE EXCEPTION 'Tasdiqlangan advokat profilini qaytarib olish mumkin '
                        'emas. Buning uchun ma''muriyatga murojaat qiling.'
            USING ERRCODE = '42501';
    END IF;

    -- (2) SOVUTISH DAVRI ICHIDA O'CHIRISH TAQIQLANADI.
    IF v_rejected_at IS NOT NULL AND v_rejected_at > now() - v_cooldown THEN
        RAISE EXCEPTION
            'Rad etilgan arizani % dan keyin qaytarib olish mumkin.',
            to_char((v_rejected_at + v_cooldown) AT TIME ZONE 'Asia/Tashkent',
                    'DD.MM.YYYY HH24:MI')
            USING ERRCODE = 'LX429';
    END IF;

    -- (3) BOG'LANGAN YOZUVLAR TEKSHIRUVI — JIM `CASCADE` HIMOYASI.
    -- `expert_profiles` ga ishora qiladigan BARCHA tashqi kalitlar
    -- `ON DELETE CASCADE` (`20260819_base_schema.sql:289`,
    -- `20260825010000_...sql:10,27,53,87`). Ya'ni bitta `DELETE` bir necha
    -- jadvaldan qator olib tashlashi mumkin. Katalog bo'yicha aylanib
    -- chiqamiz — kelajakda YANGI jadval qo'shilsa ham himoya ishlaydi.
    FOR v_fk IN
        SELECT c.conrelid::regclass::text AS tbl,
               (SELECT a.attname FROM pg_attribute a
                 WHERE a.attrelid = c.conrelid AND a.attnum = c.conkey[1]) AS col
          FROM pg_constraint c
         WHERE c.confrelid = 'public.expert_profiles'::regclass
           AND c.contype = 'f'
           AND array_length(c.conkey, 1) = 1
    LOOP
        EXECUTE format('SELECT count(*) FROM %s WHERE %I = $1', v_fk.tbl, v_fk.col)
           INTO v_dep USING v_expert_id;
        IF v_dep > 0 THEN
            RAISE EXCEPTION 'Arizaga bog''langan yozuvlar bor (% : %), shuning '
                            'uchun qaytarib olinmadi.', v_fk.tbl, v_dep
                USING ERRCODE = '23503';
        END IF;
    END LOOP;

    DELETE FROM public.expert_profiles WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Arizani qaytarib olish bajarilmadi.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'withdrawn',
        'expert_id', v_expert_id
    );
END;
$$;

COMMENT ON FUNCTION public.withdraw_expert_application() IS
    'Arizachi O''Z kutayotgan (yoki sovutish davri tugagan rad etilgan) '
    'ekspert arizasini o''chiradi. Parametri YO''Q — nishon har doim '
    'auth.uid(). Tasdiqlangan profil o''chirilmaydi (42501), sovutish davri '
    'ichida rad etilgan ariza o''chirilmaydi (LX429), bog''langan yozuv '
    'bo''lsa o''chirilmaydi (23503).';

-- `anon` bu funksiyani chaqirmasligi kerak: `auth.uid()` NULL bo'lgani
-- uchun u baribir yiqilardi, lekin huquqni ANIQ chegaralash yuzani
-- kichraytiradi.
--
-- O'LCHANGAN (2026-08-30, shu migratsiyaning BIRINCHI push urinishi):
--     ERROR: A4 FAILED: anon withdraw ni chaqira oladi (SQLSTATE P0001)
-- Ya'ni `REVOKE ... FROM PUBLIC` YETARLI EMAS. Supabase loyihasida
--     ALTER DEFAULT PRIVILEGES IN SCHEMA public
--       GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
-- o'rnatilgan, shuning uchun YANGI funksiya `anon` ga ANIQ (PUBLIC emas,
-- to'g'ridan-to'g'ri rolga) berilgan grant bilan tug'iladi. `PUBLIC` dan
-- revoke qilish bu grantni olib tashlamaydi — rolning O'ZIDAN olish kerak.
-- BU UMUMIY XULOSA: loyihadagi BARCHA `SECURITY DEFINER` funksiyalar
-- sukut bo'yicha `anon` uchun EXECUTE huquqiga ega (ular ichidagi
-- `auth.uid()` tekshiruvi ularni himoya qiladi, huquq emas).
REVOKE ALL ON FUNCTION public.withdraw_expert_application() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.withdraw_expert_application() FROM anon;
GRANT EXECUTE ON FUNCTION public.withdraw_expert_application() TO authenticated;


-- =============================================================================
-- 6. QO'LLASH PAYTIDA ASSERSIYA — (A) KATALOG, (B) XULQ
-- =============================================================================
-- (B) qismi `20260830020000_...sql` dagi naqshni takrorlaydi: sun'iy
-- foydalanuvchilar plpgsql SUB-TRANZAKSIYASIDA yaratiladi va oxirida
-- `LEXHUB_TEST_ROLLBACK` bilan ATAYLAB yiqiladi — ya'ni bazada BITTA ham
-- sun'iy qator QOLMAYDI (foydalanuvchi talabi: soxta advokat YO'Q).
--
-- CHAQIRUVCHI TAQLIDI FAQAT `request.jwt.claims` ORQALI. Bu SODIQ, chunki
-- tekshirilayotgan uchta funksiya ham `SECURITY DEFINER` va ular ichida
-- `current_user` = `postgres` — HAQIQIY PostgREST chaqiruvida HAM shunday.
-- `SET SESSION AUTHORIZATION` bu kanalda MUMKIN EMAS (o'lchangan:
-- `permission denied to set session authorization "authenticated"`, 42501).
DO $assert$
DECLARE
    v_applicant UUID := gen_random_uuid();
    v_staff     UUID := gen_random_uuid();
    v_admin     UUID := gen_random_uuid();
    v_license   TEXT := 'LX-RSN-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 12);
    v_reason    TEXT := 'ASSERT sabab: litsenziya raqami tekshiruvdan o''tmadi';
    v_fail      TEXT;
    v_caught    TEXT;
    v_state     TEXT;
    v_def       TEXT;
    v_cnt       INTEGER;
    v_bool      BOOLEAN;
    v_res       JSONB;
    v_role      TEXT;
    v_stored    TEXT;
BEGIN
    -- ── (A) KATALOG ──────────────────────────────────────────────────────────
    -- A1: ustun va uzunlik cheklovi bor.
    SELECT count(*) INTO v_cnt FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'expert_profiles'
       AND column_name = 'rejection_reason';
    IF v_cnt <> 1 THEN
        RAISE EXCEPTION 'A1 FAILED: rejection_reason ustuni YO''Q';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
        WHERE conname = 'expert_profiles_rejection_reason_len') THEN
        RAISE EXCEPTION 'A1 FAILED: uzunlik cheklovi YO''Q';
    END IF;

    -- A2: gvard HAMON `SECURITY INVOKER` va endi `rejection_reason` ni ham
    -- himoya qiladi (7 ta gvard).
    SELECT pg_get_functiondef(
        'public.protect_expert_profile_sensitive_fields()'::regprocedure)
      INTO v_def;
    IF position('rejection_reason' IN v_def) = 0 THEN
        RAISE EXCEPTION 'A2 FAILED: gvardda rejection_reason himoyasi YO''Q';
    END IF;
    SELECT prosecdef INTO v_bool FROM pg_proc
     WHERE oid = 'public.protect_expert_profile_sensitive_fields()'::regprocedure;
    IF v_bool IS NOT FALSE THEN
        RAISE EXCEPTION 'A2 FAILED: gvard SECURITY DEFINER ga qaytib ketdi';
    END IF;

    -- A3: 2-argumentli shakl YO'Q (PGRST203 ambiguity xavfi yopilgan),
    -- 3-argumentli shakl BOR.
    SELECT count(*) INTO v_cnt FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'verify_expert_application';
    IF v_cnt <> 1 THEN
        RAISE EXCEPTION 'A3 FAILED: verify_expert_application % ta shaklda '
            '(ikkitasi PGRST203 ambiguity beradi)', v_cnt;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid =
        'public.verify_expert_application(uuid, boolean, text)'::regprocedure) THEN
        RAISE EXCEPTION 'A3 FAILED: 3-argumentli shakl YO''Q';
    END IF;

    -- A4: withdraw DEFINER, parametrsiz va `anon` uchun EXECUTE huquqi YO'Q.
    SELECT prosecdef INTO v_bool FROM pg_proc
     WHERE oid = 'public.withdraw_expert_application()'::regprocedure;
    IF v_bool IS NOT TRUE THEN
        RAISE EXCEPTION 'A4 FAILED: withdraw SECURITY DEFINER emas';
    END IF;
    IF has_function_privilege('anon',
        'public.withdraw_expert_application()', 'EXECUTE') THEN
        RAISE EXCEPTION 'A4 FAILED: anon withdraw ni chaqira oladi';
    END IF;
    IF NOT has_function_privilege('authenticated',
        'public.withdraw_expert_application()', 'EXECUTE') THEN
        RAISE EXCEPTION 'A4 FAILED: authenticated withdraw ni chaqira OLMAYDI';
    END IF;


    -- ── (B) XULQ — SUB-TRANZAKSIYA, OXIRIDA TO'LIQ ROLLBACK ─────────────────
    BEGIN
        -- B0. Uch sun'iy foydalanuvchi. `on_auth_user_created` ->
        -- `handle_new_user()` `profiles` qatorini O'ZI yaratadi.
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, created_at, updated_at,
            raw_app_meta_data, raw_user_meta_data
        )
        SELECT '00000000-0000-0000-0000-000000000000', u.id, 'authenticated',
               'authenticated', 'assert-rsn-' || u.id || '@lexhub.invalid',
               '', now(), now(), now(),
               '{"provider":"email","providers":["email"]}'::jsonb,
               jsonb_build_object('full_name', 'ASSERT ' || u.tag, 'role', 'citizen')
          FROM (VALUES (v_applicant, 'Nomzod'), (v_staff, 'Moderator-Nomzod'),
                       (v_admin, 'Admin')) AS u(id, tag);

        SELECT count(*) INTO v_cnt FROM public.profiles
         WHERE id IN (v_applicant, v_staff, v_admin);
        IF v_cnt <> 3 THEN
            RAISE EXCEPTION 'B0 FAILED: handle_new_user() profil yaratmadi (%)', v_cnt;
        END IF;

        -- Rollarni `postgres` beradi (klient buni QILA OLMAYDI — `profiles`
        -- gvardi rol o'zgarishini bloklaydi, alohida invariant).
        UPDATE public.profiles SET role = 'admin'     WHERE id = v_admin;
        UPDATE public.profiles SET role = 'moderator' WHERE id = v_staff;

        -- B1. Nomzod ariza topshiradi.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_applicant, 'role', 'authenticated')::TEXT);
        v_res := public.apply_for_expert_verification(
            'ASSERT Mehnat huquqi', 3, v_license, NULL, NULL, NULL, 0);
        IF v_res->>'status' <> 'pending_verification' THEN
            RAISE EXCEPTION 'B1 FAILED: ariza topshirilmadi (%)', v_res;
        END IF;

        -- B2 (NUQSON D ISBOTI): moderator SABAB bilan rad etadi.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_admin, 'role', 'authenticated')::TEXT);
        v_res := public.verify_expert_application(v_applicant, FALSE, v_reason);
        IF v_res->>'status' <> 'rejected' THEN
            RAISE EXCEPTION 'B2 FAILED: rad etish ishlamadi (%)', v_res;
        END IF;
        IF v_res->>'rejection_reason' <> v_reason THEN
            RAISE EXCEPTION 'B2 FAILED: javobda sabab qaytmadi (%)', v_res;
        END IF;
        SELECT rejection_reason INTO v_stored FROM public.expert_profiles
         WHERE user_id = v_applicant;
        IF v_stored <> v_reason THEN
            RAISE EXCEPTION 'B2 FAILED: sabab BAZAGA yozilmadi (%)',
                coalesce(v_stored, 'NULL');
        END IF;

        -- B3 (SABAB ARIZACHIGA YETIB BORADI): qayta topshirish `LX429` bilan
        -- rad etiladi VA xato matnida SABAB bor. Bu — foydalanuvchi sababni
        -- KO'RADIGAN yagona yo'l, shuning uchun ALOHIDA tekshiriladi.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_applicant, 'role', 'authenticated')::TEXT);
        v_caught := NULL; v_state := NULL;
        BEGIN
            v_res := public.apply_for_expert_verification(
                'ASSERT Mehnat huquqi', 3, v_license, NULL, NULL, NULL, 0);
        EXCEPTION WHEN OTHERS THEN
            v_caught := SQLERRM; v_state := SQLSTATE;
        END;
        IF v_state IS DISTINCT FROM 'LX429' THEN
            RAISE EXCEPTION 'B3 FAILED: LX429 kelmadi (state=%, msg=%)',
                coalesce(v_state, 'NULL'), coalesce(v_caught, 'ariza O''TDI');
        END IF;
        IF position(v_reason IN coalesce(v_caught, '')) = 0 THEN
            RAISE EXCEPTION 'B3 FAILED: LX429 matnida SABAB YO''Q (%)', v_caught;
        END IF;


        -- B4 (SOVUTISH DAVRI CHETLAB O'TILMAYDI): rad etilgan arizani
        -- o'chirib yuborish 24 soatlik qulfni bekor qilardi.
        v_caught := NULL; v_state := NULL;
        BEGIN
            v_res := public.withdraw_expert_application();
        EXCEPTION WHEN OTHERS THEN
            v_caught := SQLERRM; v_state := SQLSTATE;
        END;
        IF v_state IS DISTINCT FROM 'LX429' THEN
            RAISE EXCEPTION 'B4 FAILED: sovutish davrida withdraw O''TDI '
                '(state=%, msg=%)', coalesce(v_state, 'NULL'),
                coalesce(v_caught, 'xato yo''q');
        END IF;

        -- B5: sovutish tugagach ariza QAYTARIB OLINADI va qator YO'Q bo'ladi.
        UPDATE public.expert_profiles
           SET rejected_at = now() - INTERVAL '25 hours'
         WHERE user_id = v_applicant;

        v_res := public.withdraw_expert_application();
        IF v_res->>'status' <> 'withdrawn' THEN
            RAISE EXCEPTION 'B5 FAILED: withdraw ishlamadi (%)', v_res;
        END IF;
        SELECT count(*) INTO v_cnt FROM public.expert_profiles
         WHERE user_id = v_applicant;
        IF v_cnt <> 0 THEN
            RAISE EXCEPTION 'B5 FAILED: qator O''CHMADI (jim muvaffaqiyat)';
        END IF;

        -- B6: ARIZA YO'Q holatida withdraw JIM MUVAFFAQIYAT bermaydi.
        v_caught := NULL; v_state := NULL;
        BEGIN
            v_res := public.withdraw_expert_application();
        EXCEPTION WHEN OTHERS THEN
            v_caught := SQLERRM; v_state := SQLSTATE;
        END;
        IF v_state IS DISTINCT FROM 'LX404' THEN
            RAISE EXCEPTION 'B6 FAILED: bo''sh withdraw LX404 bermadi (%)',
                coalesce(v_state, 'xato yo''q');
        END IF;

        -- B7: qaytarib olingandan keyin YANGI ariza O'TADI va sabab TOZA
        -- (qator butunlay yangi — eski sabab qaytib kelmasligi kerak).
        v_res := public.apply_for_expert_verification(
            'ASSERT Mehnat huquqi', 3, v_license, NULL, NULL, NULL, 0);
        IF v_res->>'status' <> 'pending_verification' THEN
            RAISE EXCEPTION 'B7 FAILED: qayta ariza o''tmadi (%)', v_res;
        END IF;
        SELECT rejection_reason INTO v_stored FROM public.expert_profiles
         WHERE user_id = v_applicant;
        IF v_stored IS NOT NULL THEN
            RAISE EXCEPTION 'B7 FAILED: eski sabab QOLDI (%)', v_stored;
        END IF;

        -- B8: tasdiqlash sababni TOZALAYDI va rolni `verified_expert` qiladi.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_admin, 'role', 'authenticated')::TEXT);
        v_res := public.verify_expert_application(v_applicant, TRUE);
        IF v_res->>'status' <> 'approved' THEN
            RAISE EXCEPTION 'B8 FAILED: tasdiqlash ishlamadi (%)', v_res;
        END IF;
        SELECT role::TEXT INTO v_role FROM public.profiles WHERE id = v_applicant;
        IF v_role <> 'verified_expert' THEN
            RAISE EXCEPTION 'B8 FAILED: rol `verified_expert` emas (%)', v_role;
        END IF;

        -- B9 (NUQSON E ISBOTI — ENG MUHIM): ARIZA TOPSHIRGAN MODERATOR
        -- tasdiqlanganda moderatorlikni YO'QOTMAYDI. Eski shartsiz
        -- `role = 'verified_expert'` bu yerda `moderator` ni yozib yuborardi
        -- va u boshqa hech kimni tasdiqlay olmasdi.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_staff, 'role', 'authenticated')::TEXT);
        v_res := public.apply_for_expert_verification(
            'ASSERT Fuqarolik huquqi', 7,
            'LX-RSN-STAFF-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8),
            NULL, NULL, NULL, 0);
        IF v_res->>'status' <> 'pending_verification' THEN
            RAISE EXCEPTION 'B9 FAILED: xodim arizasi topshirilmadi (%)', v_res;
        END IF;

        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_admin, 'role', 'authenticated')::TEXT);
        v_res := public.verify_expert_application(v_staff, TRUE);
        SELECT role::TEXT INTO v_role FROM public.profiles WHERE id = v_staff;
        IF v_role <> 'moderator' THEN
            RAISE EXCEPTION 'B9 FAILED: moderator roli YO''QOLDI -> % '
                '(NUQSON E hamon bor)', v_role;
        END IF;
        IF (v_res->>'staff_role_preserved') <> 'true' THEN
            RAISE EXCEPTION 'B9 FAILED: javob `staff_role_preserved` bermadi (%)', v_res;
        END IF;
        -- `is_verified` HAR IKKI holatda TRUE: u advokat statusi belgisi.
        SELECT is_verified INTO v_bool FROM public.profiles WHERE id = v_staff;
        IF v_bool IS NOT TRUE THEN
            RAISE EXCEPTION 'B9 FAILED: xodim uchun `is_verified` qo''yilmadi';
        END IF;
        -- Va u HAMON tasdiqlash huquqiga ega (o'z-o'zini huquqdan mahrum
        -- qilish YO'Q) — bu NUQSON E ning haqiqiy oqibati.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_staff, 'role', 'authenticated')::TEXT);
        IF NOT public.is_admin_or_moderator() THEN
            RAISE EXCEPTION 'B9 FAILED: tasdiqlangan moderator endi '
                'moderatsiya qila OLMAYDI';
        END IF;

        RAISE EXCEPTION 'LEXHUB_TEST_ROLLBACK';
    EXCEPTION WHEN OTHERS THEN
        -- `LEXHUB_TEST_ROLLBACK` — KUTILGAN yiqilish: sun'iy ma'lumot shu
        -- yerda BUTUNLAY yo'q qilinadi. Boshqa xato = ASSERSIYA YIQILDI.
        IF SQLERRM <> 'LEXHUB_TEST_ROLLBACK' THEN
            v_fail := SQLSTATE || ' | ' || SQLERRM;
        END IF;
    END;

    IF v_fail IS NOT NULL THEN
        RAISE EXCEPTION 'LEXHUB_ASSERT_FAILED: %', v_fail;
    END IF;

    RAISE NOTICE 'LEXHUB: rejection_reason + rol saqlash + withdraw '
        'assersiyalari bajarildi';
END
$assert$;

COMMIT;

-- =============================================================================
-- 7. BU MIGRATSIYA NIMA QILMAYDI / NIMA TEKSHIRILMAYDI (§26 — doira)
-- =============================================================================
--   * GVARD TRIGGER'INING KLIENT `UPDATE` INI RAD ETISHI SHU FAYLDA
--     TEKSHIRILMAYDI (`rejection_reason` gvardi ham shunday). Sababi
--     O'LCHANGAN: migratsiya sessiyasida `session_user = postgres`, ya'ni
--     `is_privileged_db_role()` TRUE va gvard ATAYLAB o'tkazib yuboradi;
--     `SET SESSION AUTHORIZATION` esa 42501 beradi. Bu 5-bo'limdagi
--     `withdraw_expert_application()` tufayli endi HAQIQIY JWT bilan
--     o'lchanishi MUMKIN (ariza keyin qaytarib olinadi) — natija fayl
--     oxiridagi qaydga yoziladi.
--   * `rejection_reason` INGLIZ UI'da ko'rinmaydi (4-bo'limdagi halol
--     cheklovga qara) — bu `failure_text.dart` darajasidagi mavjud murosa.
--   * Moderator UI'da sabab MAJBURIY qilinmadi (1-bo'limga qara).

-- =============================================================================
-- 8. HOLAT QAYDI (2026-08-30) — QO'LLANDI, YA'NI ASSERSIYALAR O'TDI
-- =============================================================================
-- `MSYS2_ARG_CONV_EXCL='*' supabase db push --include-all` NATIJASI (verbatim):
--     Initialising login role...
--     Connecting to remote database...
--     Applying migration 20260830030000_expert_rejection_reason_and_withdraw.sql...
--     {"upToDate":false,"dryRun":false,
--      "migrations":["20260830030000_expert_rejection_reason_and_withdraw.sql"],
--      "seeds":[],"roles":[],"message":"Finished supabase db push."}
--
-- MUVAFFAQIYATLI QO'LLANISH = ISBOT: 6-bo'limdagi har qanday assersiya
-- `RAISE EXCEPTION` qilsa BUTUN tranzaksiya rollback bo'lardi va migratsiya
-- "qo'llandi" deb YOZILMASDI (buni birinchi urinish ISBOTLADI: A4 yiqildi ->
-- hech narsa qo'llanmadi). Demak REAL bazada quyidagilar HAQIQAT:
--   A1 `rejection_reason` ustuni + `..._len` CHECK mavjud
--   A2 gvard tanasida `rejection_reason` bor va gvard `SECURITY INVOKER`
--   A3 `verify_expert_application` `pg_proc` da BITTA (PGRST203 yo'q) va u
--      `(uuid, boolean, text)` shaklida
--   A4 `withdraw_expert_application` DEFINER; `anon` EXECUTE qila OLMAYDI;
--      `authenticated` qila OLADI
--   B0 `handle_new_user()` uchta profil yaratdi
--   B1 nomzod ariza topshirdi
--   B2 admin SABAB bilan rad etdi -> javob va ustun AYNI matn
--   B3 darhol qayta ariza -> `LX429` va xabar ichida SABAB bor
--   B4 sovutish davri ichida `withdraw` -> `LX429` (qulf chetlab o'tilmaydi)
--   B5 25 soatdan keyin `withdraw` -> qator O'CHDI (count=0)
--   B6 qatorsiz `withdraw` -> `LX404`
--   B7 yangi ariza -> `pending` va `rejection_reason IS NULL` (tozalandi)
--   B8 tasdiqlash -> rol `verified_expert`
--   B9 NUQSON E ISBOTI: `moderator` ariza topshirdi, admin tasdiqladi ->
--      `profiles.role` `moderator` QOLDI, `staff_role_preserved = true`,
--      `is_verified = TRUE`, `is_admin_or_moderator()` hamon TRUE
--
-- QOLDIQ MA'LUMOT: B0-B9 sub-tranzaksiyasi `LEXHUB_TEST_ROLLBACK` bilan
-- yiqildi, ya'ni sun'iy `auth.users` / `profiles` / `expert_profiles`
-- qatorlari BAZAGA YOZILMADI (naqsh `20260830020000_...sql` da mustaqil
-- o'lchov bilan isbotlangan: `LEXHUB_RESIDUE users=0 profiles=0 experts=0`).
