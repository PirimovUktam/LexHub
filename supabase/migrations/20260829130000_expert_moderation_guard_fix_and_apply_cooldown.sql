-- =============================================================================
-- LEXHUB — EKSPERT MODERATSIYA GVARDI + QAYTA TOPSHIRISH LIMITI
-- Sana: 2026-08-29
-- Asos: `20260827_profile_invariant_final_fix.sql` — AYNI SINF nuqsoni
--       `profiles` uchun 2026-08-27 da shu yo'l bilan tuzatilgan. Bu fayl shu
--       naqshni `expert_profiles` ga ko'chiradi, YANGI mexanizm o'ylab
--       TOPMAYDI (§12: database redesign yo'q).
-- =============================================================================
--
-- NUQSON A — `SECURITY DEFINER` TRIGGER GVARDI `current_user` NI FOYDASIZ QILADI
-- -----------------------------------------------------------------------------
-- Oxirgi ta'rif: `20260829000500_expert_license_visibility_and_lock.sql:95-98`
--     CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()
--     ... IF (current_user != 'service_role' AND session_user != 'postgres') THEN
--     ... $$ LANGUAGE plpgsql SECURITY DEFINER ...
--
-- `SECURITY DEFINER` funksiya ICHIDA `current_user` = funksiya EGASI
-- (migratsiya bilan yaratilgan, ya'ni `postgres`), CHAQIRUVCHI roli EMAS.
-- Ya'ni `current_user != 'service_role'` HAR DOIM TRUE — u hech kimni
-- ajratmaydi. Gvardning yagona haqiqiy sharti `session_user != 'postgres'`
-- bo'lib qoladi, PostgREST ulanish roli esa `postgres` EMAS.
--
-- OQIBAT (statik xulosa, quyida runtime dalil YO'Q deb belgilangan): gvard
-- KLIENT `PATCH` so'roviga ham, `verify_expert_application()` (SECURITY
-- DEFINER) ichidagi yozuvga ham BIR XIL kiradi:
--   * `p_approve => TRUE` -> `verified_at = now()` -> gvard
--     'Expert verification date is managed by administrators.' bilan yiqiladi
--     -> TASDIQLASH ISHLAMAYDI;
--   * TASDIQLANGAN advokatni bekor qilish -> `verified_at` NOT NULL -> NULL ->
--     AYNI xato -> BEKOR QILISH ISHLAMAYDI;
--   * KUTAYOTGAN arizani rad etish -> NULL -> NULL, `IS DISTINCT FROM` FALSE
--     -> gvard tegmaydi. Shuning uchun nuqson bir qarashda KO'RINMAYDI.
--
-- NIMA UCHUN `current_user NOT IN (...,'postgres',...)` YECHIM EMAS:
-- `20260826010000_fix_profile_anti_tampering_and_auth_trigger.sql:61-62` aynan
-- shunday qilgan. DEFINER ichida `current_user` DOIM `postgres` bo'lgani
-- uchun bunda gvard HAMMA UCHUN — klient `PATCH` uchun HAM — O'CHADI, ya'ni
-- `rating`/`verified_at`/`license_number` himoyasi butunlay yo'qoladi. Ikki
-- ta'rif bir-birini shu sababdan almashtirib kelgan: biri klientni himoya
-- qilib moderatsiyani buzadi, ikkinchisi moderatsiyani ishlatib himoyani
-- o'chiradi.
--
-- TO'G'RI YECHIM (`profiles` da allaqachon ishlatilgan): funksiyani
-- `SECURITY INVOKER` qilish + `public.is_privileged_db_role()`. INVOKER'da
-- `current_user` = HAQIQIY chaqiruvchi:
--   * klient `PATCH` -> `authenticated` -> gvard KIRADI;
--   * DEFINER RPC ichida -> `postgres` -> gvard O'TKAZADI;
--   * Studio SQL Editor / migratsiya -> `session_user = postgres` -> o'tkazadi.
-- Funksiya tanasi HECH QANDAY jadvalga tegmaydi (faqat NEW/OLD va RAISE),
-- shuning uchun DEFINER huquqi unga KERAK EMAS.
--
-- NUQSON B — RAD ETILGAN FOYDALANUVCHI `rejected_at` NI O'ZI TOZALAY OLADI
-- -----------------------------------------------------------------------------
-- `20260821010000_expert_verification_and_privacy.sql:193-195`:
--     CREATE POLICY "Experts can update their profile" ON public.expert_profiles
--     FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
-- Ya'ni ariza EGASI o'z qatorini to'g'ridan-to'g'ri `PATCH` qila oladi, gvard
-- ro'yxatida esa `rejected_at` YO'Q. Demak:
--     PATCH /rest/v1/expert_profiles?user_id=eq.<o'zi>   {"rejected_at": null}
-- rad etilgan arizani moderatsiya ro'yxatiga QAYTARADI — RPC ichidagi har
-- qanday limit shu yo'l bilan CHETLAB O'TILADI. Shu sababli A, B va C bitta
-- faylda: B yopilmasa C teatr bo'lardi.
--
-- NUQSON C — CHEKSIZ QAYTA TOPSHIRISH
-- -----------------------------------------------------------------------------
-- `20260829010000_expert_rejection_and_revocation.sql:285` — qayta topshirish
-- `rejected_at = NULL` yozadi va ariza yana KUTAYOTGAN bo'ladi. Chegara YO'Q:
-- moderator rad etadi, foydalanuvchi bir sekunddan keyin qayta yuboradi.
-- O'sha faylda bu ATAYLAB ochiq qoldirilgan va REPORT'da SHOULD FIX edi.
--
-- RUNTIME HOLATI (halol qayd): BU FAYLDAGI UCH NUQSONNING BIRI HAM
-- **NOT VERIFIED** — dalil STATIK (migratsiya matni + RLS siyosati matni).
-- Runtime tekshiruvi AUTENTIFIKATSIYALANGAN sessiya talab qiladi, u esa
-- ishlab chiqarish bazasida SOXTA ARIZA (soxta advokat) yaratishni talab
-- qilardi — bu ATAYLAB QILINMADI. Faylning oxiridagi 5-bo'limda `postgres`
-- huquqi bilan bajariladigan aniq tekshiruv skripti bor.
-- =============================================================================


-- =============================================================================
-- 1. NUQSON A + B: GVARD `SECURITY INVOKER` GA O'TADI, `rejected_at` QO'SHILADI
-- =============================================================================
-- Besh mavjud gvard (`rating`, `reviews_count`, `verified_at`, `user_id`,
-- `license_number`) AYNAN SAQLANADI — ular alohida invariant va bu fayl
-- ularni QAYTA LOYIHALAMAYDI. O'zgargani: xavfsizlik konteksti, chaqiruvchini
-- ajratish predikati va oltinchi gvard (`rejected_at`).
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
        -- Bu qator bo'lmasa `apply_for_expert_verification()` ichidagi
        -- sovutish davri (3-bo'lim) to'g'ridan-to'g'ri `PATCH` bilan
        -- chetlab o'tilardi.
        IF NEW.rejected_at IS DISTINCT FROM OLD.rejected_at THEN
            RAISE EXCEPTION 'Rejection state is managed by administrators.';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

-- Trigger QAYTA ULANMAYDI: `CREATE OR REPLACE FUNCTION` xavfsizlik
-- kontekstini ham almashtiradi, `trg_protect_expert_profile_sensitive_fields`
-- (`20260826010000_...sql:76-79`, `BEFORE UPDATE`) esa o'z joyida qoladi.


-- =============================================================================
-- 2. `verify_expert_application()` — O'LIK GVARD SHARTI OLIB TASHLANADI
-- =============================================================================
-- ESKI SHART (`20260829010000_...sql:121`):
--     IF NOT public.is_admin_or_moderator() AND current_user != 'service_role'
--
-- `verify_expert_application` O'ZI `SECURITY DEFINER`, ya'ni uning ichida
-- `current_user` = funksiya EGASI (`postgres`) — `service_role` HECH QACHON
-- emas. Shart HAR DOIM TRUE, ya'ni O'LIK KOD.
--
-- JONLI O'LCHOV (2026-08-29, `anon` publishable kalit, sessiyasiz,
-- tasodifiy UUID):
--     POST /rest/v1/rpc/verify_expert_application {p_approve: true}  -> HTTP 400
--     POST /rest/v1/rpc/verify_expert_application {p_approve: false} -> HTTP 400
--     ikkisida ham: code P0001,
--     "Access Denied: Only administrators can approve expert applications."
-- Ya'ni gvard anon'ni RAD ETADI va shart PRIVILEGE ESCALATION teshigi EMAS —
-- shunchaki o'lik. LEKIN funksiya egasi kelajakda `service_role` ga
-- o'tkazilsa shart teskarisiga aylanadi (gvard hech qachon ishlamaydi),
-- shuning uchun olib tashlanadi.
--
-- ALMASHTIRISH TAKLIF QILINMADI: `session_user` ni ishlatish uchun PostgREST
-- ulanish rolining ANIQ nomi kerak, uni o'lchash uchun esa mahalliy muhitda
-- YO'Q bo'lgan maxfiy kalit talab qilinadi (`env/prod.json` va `.env` da
-- faqat `sb_publishable_...` bor). Noto'g'ri taxmin gvardni ochib qo'yardi.
-- `is_admin_or_moderator()` esa `auth.uid()` bo'yicha ishlaydi va yetarli.
--
-- OQIBAT (yashirmayman): Studio SQL Editor'dan `SELECT public.
-- verify_expert_application(...)` chaqirilsa `auth.uid()` NULL bo'ladi va
-- gvard RAD ETADI. Bu O'ZGARISH EMAS — o'lik shart ham bunga yordam
-- bermagan. `supabase/proposals/onboard_verified_lawyers_RUNBOOK.sql` da
-- to'g'ridan-to'g'ri UPDATE varianti allaqachon bor.
--
-- Qolgan TANA `20260829010000_...sql:108-203` DAN AYNAN KO'CHIRILDI.
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
    IF NOT public.is_admin_or_moderator() THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can approve expert applications.';
    END IF;

    IF p_approve THEN
        UPDATE public.profiles
        SET
            role = 'verified_expert',
            is_verified = TRUE,
            updated_at = now()
        WHERE id = p_target_user_id;

        UPDATE public.expert_profiles
        SET
            verified_at = now(),
            rejected_at = NULL,
            updated_at = now()
        WHERE user_id = p_target_user_id;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        -- JIM MUVAFFAQIYAT YO'Q (§20).
        IF v_rows = 0 THEN
            RAISE EXCEPTION 'Expert application not found for the given user.';
        END IF;

        RETURN jsonb_build_object('success', true, 'status', 'approved');
    ELSE
        -- T-3: RAD ETISH HOLAT QOLDIRADI.
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
            'previous_role', v_old_role
        );
    END IF;
END;
$$;


-- =============================================================================
-- 3. NUQSON C: QAYTA TOPSHIRISH SOVUTISH DAVRI (24 SOAT)
-- =============================================================================
-- NIMA UCHUN VAQT, SANOQ EMAS: sanoq yangi ustun (`rejection_count`) talab
-- qiladi va uni faqat moderatsiya yo'li o'zgartirishi uchun gvardga yana
-- bitta shart kerak bo'lardi. Mavjud `rejected_at` bilan bir shartda
-- yopiladi — kengaytirish, sxema o'zgarishi EMAS.
--
-- NIMA UCHUN 24 SOAT (7 kun EMAS): `rejection_reason` ustuni ATAYLAB YO'Q
-- (`20260829010000_...sql:85-88` — moderatorda sabab maydoni yo'q), ya'ni
-- advokat NIMANI tuzatish kerakligini BILMAYDI. Bir haftalik qulf halol
-- xatoni (masalan litsenziya raqamidagi xato) jazoga aylantirardi. 24 soat
-- moderatsiya ro'yxatini bir foydalanuvchi uchun kuniga BITTA yozuvga
-- cheklaydi va shu bilan spam yo'lini yopadi.
--
-- SANOQ `rejected_at` DAN boshlanadi (arizadan emas): bu qiymatni FAQAT
-- `verify_expert_application()` yozadi va 1-bo'limdan keyin klient uni
-- o'zgartira OLMAYDI.
--
-- XATO KODI `LX429` — MASHINA O'QIY OLADIGAN. PostgreSQL foydalanuvchi
-- SQLSTATE'lari uchun `I`-`Z` bilan boshlanadigan sinflarni band QILMAYDI,
-- ya'ni bu kod kelajakdagi PostgreSQL kodi bilan TO'QNASHMAYDI. Klient
-- (`legal_experts_remote_datasource.dart`) shu kod bo'yicha `429`/
-- `FailureCode.applicationCooldown` beradi — matn bo'yicha TAXMIN QILMAYDI.
--
-- Qolgan TANA `20260829010000_...sql:224-296` DAN AYNAN KO'CHIRILDI (T-2
-- `license_number` qulfi va `rejected_at = NULL` SAQLANDI).
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
    v_cooldown CONSTANT INTERVAL := INTERVAL '24 hours';
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to apply for expert verification.';
    END IF;

    -- SOVUTISH DAVRI. `SELECT` mavjud qatorni topmasa `v_rejected_at` NULL
    -- bo'ladi (birinchi ariza) — shart ishlamaydi.
    SELECT rejected_at INTO v_rejected_at
    FROM public.expert_profiles
    WHERE user_id = v_user_id;

    IF v_rejected_at IS NOT NULL AND v_rejected_at > now() - v_cooldown THEN
        RAISE EXCEPTION
            'Ariza rad etilgan. Qayta topshirish % dan keyin mumkin.',
            to_char((v_rejected_at + v_cooldown) AT TIME ZONE 'Asia/Tashkent',
                    'DD.MM.YYYY HH24:MI')
            USING ERRCODE = 'LX429';
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
        -- Bu yozuv 1-bo'limdagi `rejected_at` gvardidan O'TADI, chunki
        -- funksiya `SECURITY DEFINER` (`current_user` = `postgres`) va gvard
        -- endi `is_privileged_db_role()` bo'yicha qaraydi.
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

COMMENT ON FUNCTION public.apply_for_expert_verification(
    VARCHAR, INTEGER, VARCHAR, TEXT, VARCHAR, TEXT, NUMERIC
) IS
    'Ekspert arizasini topshiradi yoki yangilaydi. Rad etilgandan keyin 24 '
    'soatlik sovutish davri bor (SQLSTATE LX429). `rejected_at` ni faqat shu '
    'funksiya va `verify_expert_application()` tozalay oladi.';


-- =============================================================================
-- 4. BU MIGRATSIYA NIMA QILMAYDI (§26 — doira)
-- =============================================================================
--   * `rejection_reason` ustuni QO'SHILMADI: moderator UI'da sabab maydoni
--     YO'Q, bo'sh ustun "sabab bor" degan soxta taassurot berardi (§20).
--     Sovutish davri xabari shu sababdan "nimani tuzatish kerak" demaydi —
--     faqat QACHON qayta topshirish mumkinligini aytadi.
--   * `20260821010000_...sql:90` dagi AYNI o'lik shart
--     (`current_user != 'service_role'`) `community_qa_triggers` da HAM bor;
--     u boshqa yuzaga tegadi va bu faylga QO'SHILMADI (REPORT'da qoladi).
--   * `verify_expert_application()` ning TASDIQLASH shoxi `lawyer` rolini
--     `verified_expert` ga yozib yuborishi (`20260829010000_...sql:49-56` da
--     tasvirlangan) TUZATILMADI — u tasdiqlash invariant testini
--     o'zgartiradi.


-- =============================================================================
-- 5. QO'LDA TEKSHIRISH — `postgres` HUQUQI BILAN (Studio SQL Editor)
-- =============================================================================
-- BU MIGRATSIYA HECH NARSANI TEKSHIRMAYDI. Quyidagilar bajarilmaguncha
-- yuqoridagi uch tuzatish **NOT VERIFIED** holatida qoladi.
--
-- 5.1. GVARD KONTEKSTI (NUQSON A ning o'zagi):
--        SELECT p.prosecdef AS is_definer
--          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--         WHERE n.nspname = 'public'
--           AND p.proname = 'protect_expert_profile_sensitive_fields';
--      KUTILADI: `is_definer = false`.
--
-- 5.2. TASDIQLASH YO'LI (A tuzatilgani):
--      Admin sessiyasida (`auth.uid()` admin bo'lgan JWT bilan, Studio'dan
--      EMAS — Studio'da `auth.uid()` NULL):
--        SELECT public.verify_expert_application('<KUTAYOTGAN-UUID>', TRUE);
--      KUTILADI: `{"success": true, "status": "approved"}` va
--        SELECT verified_at FROM public.expert_profiles WHERE user_id = '<UUID>';
--      -> NOT NULL. Agar 'Expert verification date is managed by
--      administrators.' chiqsa — NUQSON A HAMON BOR.
--
-- 5.3. NUQSON B YOPILGANI (eng muhim negativ test).
--      RAD ETILGAN foydalanuvchi SESSIYASIDA:
--        PATCH /rest/v1/expert_profiles?user_id=eq.<o'zi>
--        {"rejected_at": null}
--      KUTILADI: HTTP 4xx, 'Rejection state is managed by administrators.'
--      Agar HTTP 2xx qaytsa — sovutish davri CHETLAB O'TILADI.
--
-- 5.4. SOVUTISH DAVRI (NUQSON C):
--      AYNI sessiyada:
--        SELECT public.apply_for_expert_verification('Mehnat', 5, 'ADV-1');
--      KUTILADI: SQLSTATE `LX429`, "Ariza rad etilgan. Qayta topshirish
--      <DD.MM.YYYY HH24:MI> dan keyin mumkin."
--      So'ng `rejected_at` ni admin sessiyasida 25 soat oldinga surib
--      (`UPDATE ... SET rejected_at = now() - INTERVAL '25 hours'`) AYNI
--      chaqiruv `status: pending_verification` qaytarishi SHART.
--
-- 5.5. KLIENT HIMOYASI REGRESSIYASI (1-bo'lim gvardni O'CHIRMAGANI):
--      Oddiy foydalanuvchi sessiyasida:
--        PATCH /rest/v1/expert_profiles?user_id=eq.<o'zi>  {"rating": 5}
--      KUTILADI: 'Rating Tampering Blocked: ...'. HTTP 2xx qaytsa —
--      `SECURITY INVOKER` ga o'tish himoyani buzgan.
--
-- =============================================================================
-- 6. HOLAT QAYDI (2026-08-29) — QO'LLANGAN, LEKIN XULQI TEKSHIRILMAGAN
-- =============================================================================
-- QO'LLANGAN — HA. Dalil (ikki mustaqil o'lchov):
--   a) `supabase db push --include-all` ->
--      "Applying migration 20260829130000_expert_moderation_guard_fix_and_
--      apply_cooldown.sql..." va {"upToDate":false,"dryRun":false,
--      "migrations":["20260829130000_..."],"message":"Finished supabase db
--      push."}
--   b) `supabase migration list --linked` -> masofaviy
--      `supabase_migrations.schema_migrations` ichida
--      {"local":"20260829130000","remote":"20260829130000",
--       "time":"2026-08-29 13:00:00"} — ya'ni yozuv MASOFAVIY bazadan
--      o'qildi, push chiqishiga ishonib emas.
--
-- ANON KALIT BILAN O'LCHANGAN (ma'lumot YARATMAYDIGAN negativ testlar):
--   * POST /rest/v1/rpc/verify_expert_application
--     {p_target_user_id: <tasodifiy UUID>, p_approve: true}  -> HTTP 400,
--     {"code":"P0001","message":"Access Denied: Only administrators can
--      approve expert applications."}
--     AYNI natija `p_approve: false` bilan ham. ISBOTLAYDI: 2-bo'limdagi
--     o'lik `AND current_user != 'service_role'` shartini OLIB TASHLASH
--     funksiyani OCHIB QO'YMADI (gvard hamon yopiq).
--   * POST /rest/v1/rpc/apply_for_expert_verification (sessiyasiz) ->
--     HTTP 400, "Authentication required to apply for expert verification."
--     DIQQAT: bu matn 3-bo'limdan OLDIN ham mavjud edi, shuning uchun u
--     YANGI tanani (sovutish davrini) ISBOTLAMAYDI — faqat funksiya tirik
--     va anon'ni rad etayotganini ko'rsatadi.
--   * PATCH /rest/v1/expert_profiles?user_id=eq.<tasodifiy UUID>
--     {"rejected_at": null} (anon) -> HTTP 204. BU GVARD ISBOTI EMAS:
--     RLS `USING (auth.uid() = user_id)` NOL qator tanlagani uchun trigger
--     UMUMAN CHAQIRILMADI. Shu sababli 5.3 testi hamon kerak.
--
-- RUNTIME TEKSHIRILGAN — YO'Q. A, B, C nuqsonlarining tuzatilgani
-- **NOT VERIFIED** holatida qoladi: 5.1-5.5 testlari `postgres` huquqi yoki
-- HAQIQIY ekspert sessiyasini talab qiladi. Ikkinchisi ishlab chiqarish
-- bazasida SOXTA advokat arizasini yaratardi va uni o'chirishning yo'li
-- yo'q (service_role kaliti YO'Q, DELETE policy'si YO'Q) — ATAYLAB
-- QILINMADI.
-- =============================================================================


