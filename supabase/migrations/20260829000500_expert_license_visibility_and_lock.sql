-- =============================================================================
-- LEXHUB — LITSENZIYA RAQAMI: KO'RINISH (T-1) va TASDIQDAN KEYIN QULF (T-2)
-- Sana: 2026-08-29
-- Asos: `20260821_expert_verification_and_privacy.sql`
-- Bu migratsiya YANGI JADVAL yaratmaydi va mavjud sxemani QAYTA LOYIHALAMAYDI —
-- faqat bitta ustunni ochiq view'ga qo'shadi va bitta yozuv yo'lini qulflaydi.
-- =============================================================================
--
-- MUAMMO T-1 — DA'VO ISBOTSIZ
-- -----------------------------------------------------------------------------
-- Ekranda yozilgan: "Rasmiy Litsenziyaga Ega Advokatlar — Barcha mutaxassislar
-- O'zbekiston Advokatlar palatasi ro'yxatidan tekshirilgan"
-- (`legal_experts_page.dart`). Lekin `public_expert_profiles_view` SELECT
-- ro'yxatida `license_number` YO'Q (`20260821_...sql:118-140`), ya'ni
-- `LegalExpertModel.licenseNumber` DOIM `''`. Foydalanuvchi da'voni
-- TEKSHIRA OLMAYDI. Litsenziya RAQAMI ochiq ma'lumot (advokatlar palatasi
-- ro'yxatidan izlash mumkin), `license_document_url` esa PII bo'lib QOLADI.
--
-- MUAMMO T-2 — TEKSHIRILGAN RAQAMNI ALMASHTIRISH
-- -----------------------------------------------------------------------------
-- Tasdiqlangan advokat tekshirilgan litsenziya raqamini BOSHQASIGA o'zgartira
-- oladi, `verified_at` esa SAQLANADI. IKKI yo'l bilan:
--
--   Yo'l 1 — RPC: `apply_for_expert_verification()` ON CONFLICT bloki
--     `license_number = EXCLUDED.license_number` yozadi (`:216`) va
--     `verified_at` ga TEGMAYDI. Funksiya SECURITY DEFINER, ya'ni uning
--     ichida `current_user` = funksiya EGASI (`postgres`) → trigger gvardi
--     shartini (`current_user != 'service_role' AND session_user != 'postgres'`)
--     BAJARMAYDI va gvard umuman ISHLAMAYDI. Shu sababli T-2 ni FAQAT
--     trigger bilan yopish MUMKIN EMAS — funksiyaning O'ZI tuzatiladi.
--
--   Yo'l 2 — TO'G'RIDAN-TO'G'RI UPDATE: `"Experts can update their profile"`
--     policy'si `FOR UPDATE USING (auth.uid() = user_id)` (`:161-162`), ya'ni
--     advokat o'z qatorini REST orqali to'g'ridan-to'g'ri UPDATE qila oladi.
--     Bu yo'lda `current_user` = `authenticated` → gvard ISHLAYDI, lekin
--     `protect_expert_profile_sensitive_fields()` faqat `rating`,
--     `reviews_count`, `verified_at`, `user_id` ni qulflaydi (`:86-104`) —
--     `license_number` RO'YXATDA YO'Q.
--
-- Ya'ni to'liq qulf uchun IKKI o'zgarish SHART. Bittasi qolib ketsa ishonch
-- oynasi ochiq qoladi.
--
-- QASDDAN QILINMAGAN NARSA: tasdiqlanmagan ariza TAHRIRLANADIGAN bo'lib
-- qoladi (`verified_at IS NULL`). Advokat xato raqam yozsa, uni tuzatib qayta
-- topshira oladi. Qulf faqat TASDIQ MOMENTIDAN keyin yopiladi.
-- =============================================================================


-- =============================================================================
-- 1. T-1: VIEW'GA `license_number` — HUJJAT URL'i OCHILMAYDI
-- =============================================================================
-- DIQQAT: `CREATE OR REPLACE VIEW` mavjud ustunlarni O'ZGARTIRISHGA ruxsat
-- bermaydi (nom/tur/tartib), faqat OXIRIGA qo'shishga ruxsat beradi. Shuning
-- uchun `license_number` ENG OXIRIDA. `DROP VIEW` QILINMAYDI — u mavjud
-- GRANT'larni va view'ning ownership orqali RLS'ni chetlab o'tish xususiyatini
-- yo'q qilardi.
CREATE OR REPLACE VIEW public.public_expert_profiles_view AS
SELECT
    ep.id AS expert_id,
    ep.user_id,
    p.full_name,
    p.avatar_url,
    p.phone,
    p.role,
    p.is_verified AS is_profile_verified,
    ep.specialization,
    ep.experience_years,
    ep.education,
    ep.workplace,
    ep.rating,
    ep.reviews_count,
    ep.consultation_fee,
    ep.is_available_for_booking,
    ep.verified_at,
    ep.created_at,
    ep.updated_at,
    -- T-1: litsenziya RAQAMI (ochiq ma'lumot). `license_document_url` ATAYLAB
    -- BERILMAYDI — u PII (skanerlangan hujjatda F.I.SH., manzil, imzo bo'ladi).
    ep.license_number
FROM public.expert_profiles ep
JOIN public.profiles p ON ep.user_id = p.id
WHERE p.is_verified = TRUE AND p.role::text IN ('verified_expert', 'lawyer');

-- GRANT'lar `CREATE OR REPLACE` da saqlanadi; quyidagisi idempotent kafolat.
GRANT SELECT ON public.public_expert_profiles_view TO anon, authenticated;


-- =============================================================================
-- 2. T-2 / Yo'l 2: TRIGGER GVARDI — TO'G'RIDAN-TO'G'RI UPDATE
-- =============================================================================
-- `20260821_...sql:86-104` dagi funksiya SAQLANADI, ustiga `license_number`
-- sharti QO'SHILADI. Mavjud to'rt gvard (`rating`, `reviews_count`,
-- `verified_at`, `user_id`) O'ZGARMAYDI — ular alohida invariant.
CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF (current_user != 'service_role' AND session_user != 'postgres') THEN
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
        -- T-2: tasdiqlangandan KEYIN litsenziya raqami QOTIB QOLADI. Aks holda
        -- tekshirilgan raqam ekranda ko'rinib turib (T-1), ostidan boshqasiga
        -- almashtirilishi mumkin edi.
        IF OLD.verified_at IS NOT NULL
           AND NEW.license_number IS DISTINCT FROM OLD.license_number THEN
            RAISE EXCEPTION 'License Number Locked: A verified license number can only be changed by an administrator.';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- =============================================================================
-- 3. T-2 / Yo'l 1: RPC — ARIZA QAYTA TOPSHIRISH
-- =============================================================================
-- Faqat ON CONFLICT blokidagi `license_number` qatori o'zgaradi. Qolgan
-- maydonlar (`specialization`, `workplace`, `education`, `experience_years`,
-- `consultation_fee`) TAHRIRLANADIGAN bo'lib qoladi — ular tekshirilgan
-- litsenziya da'vosining o'zagi emas va advokat ish joyini almashtirsa
-- yangilanishi KERAK.
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
-- 4. QO'LDA TEKSHIRISH (bu migratsiya bajarmaydi — SQL Editor'da)
-- =============================================================================
-- 4.1. View endi ustunni beradi (migratsiyadan OLDIN xato berardi):
--      SELECT expert_id, full_name, license_number
--      FROM public.public_expert_profiles_view LIMIT 5;
--
-- 4.2. Hujjat URL'i ochilmaganini tasdiqlash — bu so'rov XATO BERISHI SHART:
--      SELECT license_document_url FROM public.public_expert_profiles_view;
--      -> ERROR: column "license_document_url" does not exist
--
-- 4.3. T-2 gvardi (advokat sessiyasida, `authenticated` roli ostida):
--      UPDATE public.expert_profiles SET license_number = 'XXX'
--       WHERE user_id = auth.uid();
--      -> tasdiqlangan bo'lsa: ERROR "License Number Locked: ..."
--      -> tasdiqlanmagan bo'lsa: muvaffaqiyatli (kutilgan xatti-harakat)
--
-- 4.4. T-2 RPC yo'li (tasdiqlangan advokat arizani QAYTA yuboradi):
--      SELECT public.apply_for_expert_verification('Mehnat', 5, 'BOSHQA-RAQAM');
--      -> `success: true`, LEKIN:
--      SELECT license_number FROM public.expert_profiles WHERE user_id = auth.uid();
--      -> ESKI (tekshirilgan) raqam qaytishi SHART.
--
-- HOLAT: bu fayl `supabase db push` qilinmagan (`SUPABASE_ACCESS_TOKEN` yo'q,
-- `psql` o'rnatilmagan) — ya'ni QO'LLANMAGAN. Fayl mavjudligi "deployed"
-- DEGANI EMAS.
-- =============================================================================
