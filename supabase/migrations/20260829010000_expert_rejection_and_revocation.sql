-- =============================================================================
-- LEXHUB — RAD ETISH HOLATI (T-3) va BEKOR QILISH YARIM-HOLATI (T-4)
-- Sana: 2026-08-29
-- Asos: `20260821_expert_verification_and_privacy.sql`
--       `20260829_expert_license_visibility_and_lock.sql` (BU FAYLDAN KEYIN)
-- Bu migratsiya sxemani QAYTA LOYIHALAMAYDI: bitta nullable ustun qo'shadi va
-- bitta funksiyaning `ELSE` shoxini to'g'rilaydi.
-- =============================================================================
--
-- MUAMMO T-3 — RAD ETISH JIM NO-OP
-- -----------------------------------------------------------------------------
-- O'LCHANGAN (`20260821_...sql:268-276`): `verify_expert_application(
-- p_approve => FALSE)` FAQAT quyidagini bajaradi:
--     UPDATE public.expert_profiles SET verified_at = NULL, updated_at = now()
--      WHERE user_id = p_target_user_id;
-- va `{'success': true, 'status': 'rejected'}` qaytaradi.
--
-- Kutayotgan arizada `verified_at` ALLAQACHON NULL. Ya'ni UPDATE hech narsani
-- o'zgartirmaydi va ariza moderatsiya ro'yxatining `verified_at IS NULL`
-- filtriga QAYTA tushadi. Bazada "rad etilgan" holati YO'Q edi — moderator
-- "Rad etish" bosadi, RPC `success: true` qaytaradi, ariza esa joyida qoladi.
-- Bu SOXTA MUVAFFAQIYAT (§20).
--
-- MUAMMO T-4 — BEKOR QILISH YARIM-HOLAT QOLDIRADI
-- -----------------------------------------------------------------------------
-- Ayni `ELSE` shoxi TASDIQLANGAN advokat uchun ishlatilsa (huquqni bekor
-- qilish), u `expert_profiles.verified_at` ni tozalaydi, LEKIN
-- `profiles.role` / `profiles.is_verified` ga TEGMAYDI. Natijada:
--
--   * `public_expert_profiles_view` predikati `p.is_verified = TRUE AND
--     p.role::text IN ('verified_expert','lawyer')` — u `verified_at` ni
--     TEKSHIRMAYDI, ya'ni bekor qilingan advokat OCHIQ KATALOGDA QOLADI;
--   * `enforce_expert_answer()` `profiles.role` + `is_verified` bo'yicha
--     qaraydi (`20260821_...sql:288-296`), ya'ni u EKSPERT JAVOBI yozishda
--     DAVOM ETADI.
--
-- Ikki yuza ham `profiles.is_verified` orqali yopiladi.
--
-- ROL BO'YICHA QASDDAN QILINMAGAN NARSA
-- -----------------------------------------------------------------------------
-- `role` FAQAT `verified_expert` bo'lganda `citizen` ga qaytariladi — chunki
-- shu qiymatni AYNI shu funksiyaning `IF` shoxi beradi, ya'ni bu taxmin emas,
-- teskari amal. `lawyer` roli boshqa yo'l bilan (runbook, `service_role`)
-- beriladi va unga TEGILMAYDI: uni `citizen` ga tushirish MENING taxminim
-- bo'lardi va boshqa jarayonni buzardi. `is_verified = FALSE` esa har ikki
-- holatda ham qo'yiladi — katalog va ekspert javobi yuzalari shu bilan
-- yopiladi.
--
-- SHU QARORNING OCHIQ QOLGAN OQIBATI (yashirmayman): `lawyer` roli bilan
-- ishlaydigan advokat rad etilsa `role = 'lawyer'`, `is_verified = FALSE`
-- bo'ladi (ikki yuza yopiq). Moderator KEYIN xatosini tuzatib TASDIQLASA,
-- MAVJUD `IF` shoxi `role = 'verified_expert'` yozadi — ya'ni `lawyer`
-- belgisi YO'QOLADI. Bu men kiritgan defekt EMAS (`IF` shoxi 2026-08-21 dan
-- shunday), lekin rad etish endi ishlaydigan bo'lgani uchun bu yo'l ochildi.
-- To'g'ri yechim — `IF` shoxida ham `CASE WHEN role = 'lawyer' THEN role`
-- ishlatish, LEKIN u tasdiqlash invariantini o'zgartiradi
-- (`expert_verification_invariant_test.dart`, 2-guruh) va bu migratsiyaning
-- doirasidan tashqari. REPORT'da SHOULD FIX sifatida qoladi.

--
-- TRIGGER GVARDI TO'G'RISIDA (statik tahlil, runtime dalil EMAS)
-- -----------------------------------------------------------------------------
-- `protect_profile_sensitive_fields()` (`20260827_...sql:335`) `role` va
-- `is_verified` o'zgarishini bloklaydi, LEKIN `NOT public.
-- is_privileged_db_role()` sharti bilan. Bu funksiya `current_user IN
-- ('postgres', ...)` ni tekshiradi, `verify_expert_application` esa SECURITY
-- DEFINER — uning ichida `current_user` = funksiya EGASI, ya'ni gvard
-- O'TKAZADI. Shu sababli mavjud `IF` shoxi (`role = 'verified_expert'`)
-- ishlayotgan bo'lsa, yangi `ELSE` shoxi ham ayni yo'ldan o'tadi. BU FARAZ
-- REAL BAZADA TEKSHIRILISHI SHART (pastdagi 4-bo'lim).
-- =============================================================================


-- =============================================================================
-- 1. T-3: `rejected_at` USTUNI (additive, nullable)
-- =============================================================================
-- Nima uchun alohida ustun, `status` enum EMAS: mavjud kod (`getPendingApplications`
-- va `public_expert_profiles_view`) `verified_at` bo'yicha ishlaydi. Enum
-- kiritish har bir o'quvchini qayta yozishni talab qilardi — bu §12 taqiqlagan
-- "database redesign". Bitta nullable timestamp esa kengaytirish.
--
-- `rejection_reason` ATAYLAB QO'SHILMADI: moderatorda sabab kiritish maydoni
-- YO'Q, ya'ni ustun DOIM bo'sh bo'lardi. Bo'sh ustun "sabab bor" degan soxta
-- taassurot berardi (§20). Maydon UI'da paydo bo'lganda qo'shiladi.
ALTER TABLE public.expert_profiles
    ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;

COMMENT ON COLUMN public.expert_profiles.rejected_at IS
    'Ariza rad etilgan yoki ekspert huquqi bekor qilingan vaqt. NULL = rad '
    'etilmagan. `verified_at` bilan BIRGA NULL bo''lsa — ariza KUTILAYOTGAN. '
    'Faqat `verify_expert_application()` yozadi.';

-- Kutayotgan arizalarni tez topish uchun (moderatsiya ro'yxati shu ikki
-- ustun bo'yicha filtrlaydi).
CREATE INDEX IF NOT EXISTS idx_expert_profiles_pending
    ON public.expert_profiles (created_at DESC)
    WHERE verified_at IS NULL AND rejected_at IS NULL;


-- =============================================================================
-- 2. T-3 + T-4: `verify_expert_application()` — `ELSE` SHOXI TO'G'RILANADI
-- =============================================================================
-- `IF` (tasdiqlash) shoxi O'ZGARMAYDI: u `role` + `is_verified` +
-- `verified_at` ni BIRGA qo'yadi va bu invariant test bilan qulflangan
-- (`expert_verification_invariant_test.dart`, 2-guruh). Faqat `rejected_at`
-- tozalanishi qo'shildi — qayta tasdiqlangan ariza "rad etilgan" bo'lib
-- qolmasligi kerak.
CREATE OR REPLACE FUNCTION public.verify_expert_application(
    p_target_user_id UUID,
    p_approve BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows INTEGER;
    v_old_role TEXT;
BEGIN
    -- Only Admin or Moderator can verify applications
    IF NOT public.is_admin_or_moderator() AND current_user != 'service_role' THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can approve expert applications.';
    END IF;

    IF p_approve THEN
        -- Update Profile Role & Verification
        UPDATE public.profiles
        SET
            role = 'verified_expert',
            is_verified = TRUE,
            updated_at = now()
        WHERE id = p_target_user_id;

        -- Update Expert Profile Verification timestamp
        UPDATE public.expert_profiles
        SET
            verified_at = now(),
            rejected_at = NULL,
            updated_at = now()
        WHERE user_id = p_target_user_id;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        -- JIM MUVAFFAQIYAT YO'Q: ariza qatori bo'lmasa `success: true`
        -- qaytarish moderatorga tasdiqlangan advokat borligini ko'rsatardi.
        IF v_rows = 0 THEN
            RAISE EXCEPTION 'Expert application not found for the given user.';
        END IF;

        RETURN jsonb_build_object('success', true, 'status', 'approved');
    ELSE
        -- T-3: RAD ETISH endi HOLAT QOLDIRADI. `verified_at` NULL bo'lib
        -- qoladi (tasdiq YO'Q), `rejected_at` esa YOZILADI — ya'ni ariza
        -- kutayotganlar ro'yxatidan CHIQADI va amal takrorlanmaydi.
        UPDATE public.expert_profiles
        SET
            verified_at = NULL,
            rejected_at = now(),
            updated_at = now()
        WHERE user_id = p_target_user_id;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        IF v_rows = 0 THEN
            RAISE EXCEPTION 'Expert application not found for the given user.';
        END IF;

        -- T-4: BEKOR QILISH YUZALARINI YOPISH. `is_verified = FALSE` ikkisini
        -- birga yopadi: ochiq katalog view predikati va `enforce_expert_answer()`.
        SELECT role::text INTO v_old_role
        FROM public.profiles WHERE id = p_target_user_id;

        UPDATE public.profiles
        SET
            is_verified = FALSE,
            -- FAQAT shu funksiya bergan rol qaytariladi. `lawyer` (runbook
            -- orqali beriladi) va boshqa rollar SAQLANADI — izohga qarang.
            role = CASE
                WHEN role::text = 'verified_expert' THEN 'citizen'::user_role
                ELSE role
            END,
            updated_at = now()
        WHERE id = p_target_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'rejected',
            -- DIAGNOSTIKA MAYDONLARI — UI'DA HOZIR KO'RINMAYDI.
            -- `legal_experts_remote_datasource.dart:275-281` faqat `success`
            -- ni tekshiradi va Map'ni o'zgarishsiz bloc'ga uzatadi; moderatsiya
            -- ekrani esa undan hech narsa O'QIMAYDI. Ya'ni bu ikki maydon
            -- hozircha FAQAT Studio'dan qo'lda chaqirganda ko'rinadi.
            -- Ularni UI'ga chiqarish migratsiya QO'LLANGANDAN keyingi qadam:
            -- hozir qo'shilsa, eski RPC bu kalitlarni qaytarmagani uchun
            -- maydon DOIM null bo'lardi — ya'ni soxta struktura (§20).
            --
            -- `role_reverted = FALSE` ma'nosi: rol tegilmagan (masalan
            -- `lawyer`), `is_verified` esa FALSE qilingan.
            'role_reverted', (v_old_role = 'verified_expert'),
            'previous_role', v_old_role
        );
    END IF;
END;
$$;

-- =============================================================================
-- 3. `apply_for_expert_verification()` — QAYTA TOPSHIRISH `rejected_at` NI
--    TOZALAYDI
-- =============================================================================
-- NIMA UCHUN SHART: 2-bo'lim rad etilgan arizaga `rejected_at` yozadi va u
-- kutayotganlar ro'yxatidan chiqadi. Agar qayta topshirish bu ustunni
-- tozalamasa, advokat nuqsonni tuzatib qayta yuborsa ham ariza MODERATORGA
-- KO'RINMAY qolardi — ya'ni T-3 ni tuzatish yangi JIM YO'QOLISH yaratardi
-- (§20).
--
-- BU TA'RIF `20260829_expert_license_visibility_and_lock.sql:132-202` DAN
-- AYNAN KO'CHIRILDI, faqat `rejected_at = NULL` qo'shildi. T-2 ning
-- `license_number = CASE ...` qulfi SAQLANGAN — u yo'qolsa tasdiqlangan
-- advokat litsenziya raqamini qayta yozib olardi.
--
-- HAL QILINMAGAN, ATAYLAB: rad etilgan foydalanuvchi cheksiz qayta topshirib
-- moderatsiya ro'yxatini to'ldirib tashlashi mumkin. Rate-limit bu
-- migratsiyaning vazifasi EMAS (§26 scope) va uni "yopildi" deb yozish yolg'on
-- bo'lardi. Muammo REPORT'da SHOULD FIX sifatida qoladi.
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
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to apply for expert verification.';
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
        -- Tasdiqlanmagan ariza (verified_at IS NULL) tahrirlanadi.
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
-- 4. QO'LDA TEKSHIRISH (bu migratsiya BAJARMAYDI — Studio SQL Editor'da)
-- =============================================================================
-- Quyidagilar RUNTIME DALIL to'plash uchun. Ular bajarilmaguncha bu fayldagi
-- hech narsa "ishlaydi" deb yozilmaydi.
--
-- 4.1. GVARD FARAZINI TEKSHIRISH (eng muhim, 3-4 qatorli izohga qarang).
--      Admin sessiyasida TASDIQLANGAN advokat uchun rad etish chaqiriladi:
--        SELECT public.verify_expert_application('<TASDIQLANGAN-UUID>', FALSE);
--      -> `role_reverted: true`, `previous_role: "verified_expert"` KUTILADI.
--      Agar `Profile Tampering Blocked` xatosi chiqsa — FARAZ NOTO'G'RI va
--      `is_verified` yozuvi trigger bilan bloklangan. O'sha holatda yechim
--      trigger'ni bo'shatish EMAS (§14 xavfsizlikni pasaytirish), balki
--      `verify_expert_application` egasini tekshirish.
--
-- 4.2. T-3 — rad etilgan ariza ro'yxatdan CHIQADI:
--        SELECT user_id, verified_at, rejected_at FROM public.expert_profiles
--         WHERE verified_at IS NULL AND rejected_at IS NULL;
--      -> rad etilgan qator bu natijada BO'LMASLIGI kerak.
--
-- 4.3. T-4 — bekor qilingan advokat OCHIQ KATALOGDAN chiqadi:
--        SELECT count(*) FROM public.public_expert_profiles_view
--         WHERE user_id = '<TASDIQLANGAN-UUID>';
--      -> 0 KUTILADI (migratsiyadan OLDIN 1 qaytardi).
--
-- 4.4. T-4 — ekspert javobi yuzasi yopildi:
--      Bekor qilingan foydalanuvchi sessiyasida `answers` ga INSERT qilinsa,
--      `enforce_expert_answer()` `is_expert_answer` ni FALSE ga tushirishi
--      SHART.
--
-- 4.5. QAYTA TOPSHIRISH (3-bo'lim):
--        SELECT public.apply_for_expert_verification('Mehnat', 5, 'ADV-123');
--        SELECT verified_at, rejected_at FROM public.expert_profiles
--         WHERE user_id = auth.uid();
--      -> ikkisi ham NULL (yana kutayotgan).
--
-- 4.6. T-2 REGRESSIYA TEKSHIRUVI (3-bo'lim funksiyani qayta yozdi):
--      TASDIQLANGAN advokat sessiyasida:
--        SELECT public.apply_for_expert_verification('Mehnat', 5, 'BOSHQA');
--        SELECT license_number FROM public.expert_profiles WHERE user_id = auth.uid();
--      -> ESKI raqam qaytishi SHART. Yangi raqam qaytsa — T-2 qulfi SINDI.
--
--
-- KLIENT TOMONI — QO'SHILDI (2026-08-29)
-- -----------------------------------------------------------------------------
-- `legal_experts_remote_datasource.dart` endi IKKI ustun bo'yicha filtrlaydi:
-- `.isFilter('verified_at', null).isFilter('rejected_at', null)`. Bu qadam
-- ilgari ATAYLAB kechiktirilgan edi (ustun bo'lmasa so'rov `42703` bilan
-- yiqilib, moderatsiya ekrani butunlay ishlamas bo'lardi); `rejected_at`
-- ustuni jonli bazada mavjudligi `information_schema.columns` orqali
-- tasdiqlangandan KEYIN qo'shildi. Filtr yuqoridagi partial index'ga aynan mos.
-- Qulf: `test/features/legal_experts/expert_moderation_honesty_test.dart`.
--
-- HOLAT — RUNTIME'DA O'LCHANGAN (2026-08-29)
-- -----------------------------------------------------------------------------
-- Migratsiya jonli bazaga QO'LLANDI va 4.1-4.6 dan quyidagilari Studio'da,
-- o'zini QAYTARADIGAN (`RAISE EXCEPTION` bilan rollback qilinadigan)
-- tranzaksiya ichida o'lchandi:
--
--   4.1 VERIFIED — tasdiqlash `role=verified_expert`, `is_verified=t`,
--       `verified_at` yozdi; `protect_profile_sensitive_fields()` RPC ichida
--       to'sib qo'ymadi (SECURITY DEFINER ichida `current_user = postgres`).
--   4.2 VERIFIED (T-3) — rad etishdan keyin `rejected_at` yozildi va
--       kutayotganlar 1 -> 0.
--   4.3 VERIFIED (T-4) — bekor qilingan advokat ochiq katalogdan chiqdi
--       (1 -> 0). View `verified_at` ni tekshirmaydi, ya'ni bu aynan
--       `is_verified = FALSE` yozuvini izolyatsiya qiladi.
--   4.4 VERIFIED — `enforce_expert_answer()` yuzasi yopilgan. IKKI TOMONLI
--       o'lchov: TASDIQLANGAN advokat `answers` ga `is_expert_answer = TRUE`
--       yozganda belgi SAQLANDI (`t`), BEKOR QILINGANDAN keyin ayni INSERT
--       belgini TUSHIRDI (`f`). Ya'ni `is_verified = FALSE` yozuvi ekspert
--       javobi yuzasini ham qulflaydi.
--   4.5 VERIFIED — qayta topshirish `rejected_at` ni tozaladi, kutayotganlar
--       0 -> 1.
--   4.6 VERIFIED (T-2 regressiya) — 3-bo'lim funksiyani qayta yozgan bo'lsa
--       ham tasdiqlangan advokatning `license_number` qulfi saqlandi
--       (`LIC-BBB` qoldi), `specialization` esa yangilandi.
--
-- EVIDENCE CHEGARASI — OVERCLAIM QILINMAYDI: o'lchovlar `postgres` Studio
-- sessiyasida, `auth.uid()` `set_config('request.jwt.claims', ...)` bilan
-- SIMULYATSIYA qilingan holda olindi. ILOVA -> PostgREST -> RPC yo'li va
-- HAQIQIY admin JWT hali sinalmagan; bazada admin/moderator rolli hisob YO'Q
-- (barcha profillar `citizen`), shuning uchun moderatsiya ekrani qurilmada
-- ochilmaydi. Bu holat qurilmada alohida o'lchanishi kerak.
-- =============================================================================
