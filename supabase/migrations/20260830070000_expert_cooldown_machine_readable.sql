-- NUQSON H — RAD ETISH SABABI INGLIZ UI'DA KO'RINMAYDI.
--
-- O'LCHANGAN HOLAT: `apply_for_expert_verification()` sovutish davrida
-- `LX429` bilan yiqiladi va sabab + qayta topshirish vaqtini FAQAT xato
-- MATNI ichida beradi ("Ariza rad etilgan. Sabab: %. Qayta topshirish % dan
-- keyin mumkin."). Klientda `failure_text.dart` o'zbek tilida server matnini
-- AYNAN ko'rsatadi, boshqa tilda esa `code` bo'yicha umumiy ARB matnini
-- oladi — ya'ni INGLIZ UI'da sabab HAM, vaqt HAM YO'Q. Bu
-- `20260830030000_...sql:286-290` da halol qayd etilgan cheklov edi.
--
-- YECHIM YO'NALISHI (§14 — chegara serverda, §16 — xom qiymat tarjima
-- qilinmaydi): matn tarjima qilinmaydi, MA'LUMOT mashina o'qiy oladigan
-- shaklda beriladi. `RAISE ... USING DETAIL` PostgREST javobida `details`
-- maydoni bo'lib chiqadi (`PostgrestException.details`), shuning uchun
-- klient sababni va vaqtni AJRATIB oladi va matnni O'Z TILIDA quradi.
--
-- XABAR MATNI O'ZGARMAYDI: o'zbek UI hozirgidek server matnini ko'rsatadi
-- (regressiya yo'q), ingliz UI esa `details` dan quriladi.
--
-- NIMA UCHUN `DETAIL`, `HINT` EMAS: `HINT` — odam o'qishi uchun tavsiya;
-- `DETAIL` xato haqidagi QO'SHIMCHA MA'LUMOT uchun, ayni holatga mos.
--
-- MAXFIYLIK: `DETAIL` ichidagi ikki qiymat ham AYNI foydalanuvchiga
-- tegishli (o'z arizasi rad etilgani sababi va o'z sovutish vaqti) va
-- allaqachon xato MATNIDA ochiq yuboriladi — ya'ni yangi oshkorlik YO'Q.
--
-- TANA `20260830030000_expert_rejection_reason_and_withdraw.sql:296-395` DAN
-- AYNAN ko'chirildi. YAGONA o'zgarish — ikki `RAISE` ga `DETAIL` qo'shildi.
--
-- ISBOT:
--   P1  hozirgi ta'rifda `DETAIL` YO'Q (nuqson bor) — izohlar OLIB
--       TASHLANGAN matnda tekshiriladi;
--   D1  yangi ta'rifda `DETAIL` ikki marta (sababli va sababsiz shox);
--   D2  `DETAIL` JSON'i klient KUTGAN shaklda: `retry_at` ISO 8601
--       (`DateTime.parse` o'qiy oladi) va `reason` kaliti mavjud;
--   D3  eski xatti-harakat SAQLANDI — xabar matni va SQLSTATE o'zgarmadi.
--
-- NOT VERIFIED (halol): HAQIQIY arizachi JWT bilan chaqiruv o'lchanmadi —
-- `auth.uid()` migratsiya sessiyasida NULL, ya'ni funksiya birinchi shartda
-- "Authentication required" bilan to'xtaydi. Sovutish shoxi faqat rad
-- etilgan arizasi bor foydalanuvchi tokeni bilan o'lchanadi.

BEGIN;

DO $pre$
DECLARE
    v_def TEXT;
BEGIN
    v_def := regexp_replace(
        pg_get_functiondef(
            'public.apply_for_expert_verification(character varying,integer,'
            'character varying,text,character varying,text,numeric)'
            ::regprocedure),
        '--[^' || chr(10) || ']*', '', 'g');
    IF position('DETAIL' IN v_def) > 0 THEN
        RAISE EXCEPTION 'P1 FAILED: `DETAIL` allaqachon bor — migratsiya '
            'asoslanmagan, holatni qayta o''rgan.';
    END IF;
    IF position('LX429' IN v_def) = 0 THEN
        RAISE EXCEPTION 'P1 FAILED: `LX429` yo''q — bu boshqa versiya, '
            'nusxa olinayotgan tana MOS EMAS.';
    END IF;
    RAISE NOTICE 'P1 OK: sovutish xabari faqat MATN, mashina o''qiy oladigan '
        'kanal yo''q';
END
$pre$;

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
    v_detail TEXT;
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
        -- MASHINA O'QIY OLADIGAN KANAL: `DETAIL` PostgREST javobida
        -- `details` bo'lib chiqadi. `to_jsonb(timestamptz)` ISO 8601 beradi
        -- (`DateTime.parse` o'qiydi), `reason` NULL bo'lsa JSON `null`.
        -- Klient shu ikki qiymatdan matnni O'Z TILIDA quradi.
        v_detail := jsonb_build_object(
            'lx', 'application_cooldown',
            'retry_at', to_jsonb(v_rejected_at + v_cooldown),
            'reason', v_reason
        )::text;
        -- IKKI XIL XABAR, bitta shablonga sabab "yopishtirilmaydi": sabab
        -- yo'q bo'lganda "Sabab: " degan bo'sh sarlavha chiqarish YOLG'ON
        -- taassurot berardi (§20).
        IF v_reason IS NULL THEN
            RAISE EXCEPTION
                'Ariza rad etilgan. Qayta topshirish % dan keyin mumkin.',
                v_retry_at
                USING ERRCODE = 'LX429', DETAIL = v_detail;
        ELSE
            RAISE EXCEPTION
                'Ariza rad etilgan. Sabab: %. Qayta topshirish % dan keyin mumkin.',
                v_reason, v_retry_at
                USING ERRCODE = 'LX429', DETAIL = v_detail;
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

DO $post$
DECLARE
    v_def TEXT;
    v_detail_count INTEGER;
    v_probe JSONB;
BEGIN
    v_def := regexp_replace(
        pg_get_functiondef(
            'public.apply_for_expert_verification(character varying,integer,'
            'character varying,text,character varying,text,numeric)'
            ::regprocedure),
        '--[^' || chr(10) || ']*', '', 'g');

    SELECT count(*) INTO v_detail_count
      FROM regexp_matches(v_def, 'ERRCODE = ''LX429'', DETAIL = v_detail', 'g');
    IF v_detail_count != 2 THEN
        RAISE EXCEPTION 'D1 FAILED: `DETAIL` ikki shoxda ham yo''q (topildi: %)',
            v_detail_count;
    END IF;

    -- D2: klient KUTGAN JSON shakli. AYNI ifoda hisoblanadi.
    v_probe := jsonb_build_object(
        'lx', 'application_cooldown',
        'retry_at', to_jsonb(now() + INTERVAL '24 hours'),
        'reason', 'sinov sababi'
    );
    IF v_probe->>'retry_at' !~
        '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?([+-]\d{2}:\d{2}|Z)$' THEN
        RAISE EXCEPTION 'D2 FAILED: `retry_at` ISO 8601 emas: %',
            v_probe->>'retry_at';
    END IF;
    IF NOT (v_probe ? 'reason') OR v_probe->>'lx' != 'application_cooldown' THEN
        RAISE EXCEPTION 'D2 FAILED: JSON kalitlari kutilmagan: %', v_probe;
    END IF;

    -- D3: xatti-harakat SAQLANDI — matn va kod o'zgarmadi.
    IF position('Ariza rad etilgan. Sabab: %. Qayta topshirish % dan keyin '
            'mumkin.' IN v_def) = 0 THEN
        RAISE EXCEPTION 'D3 FAILED: o''zbek xabari o''zgargan — o''zbek UI '
            'regressiyasi';
    END IF;
    IF position('rejection_reason = NULL' IN v_def) = 0 THEN
        RAISE EXCEPTION 'D3 FAILED: qayta topshirishda eski sabab '
            'tozalanmaydi (T-3 regressiyasi)';
    END IF;

    RAISE NOTICE 'D1-D3 OK: sabab va qayta topshirish vaqti `details` orqali '
        'MASHINA O''QIY OLADIGAN shaklda ketadi, o''zbek matni o''zgarmadi. '
        'Namuna: %', v_probe;
END
$post$;

COMMIT;
