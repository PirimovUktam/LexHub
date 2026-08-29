-- LEXHUB — EKSPERT MODERATSIYASI INVARIANTLARINING RUNTIME ASSERSIYASI
--
-- NIMA UCHUN BU FAYL BOR (CLAUDE.md §0: CLAIM != EVIDENCE):
-- `20260829130000_expert_moderation_guard_fix_and_apply_cooldown.sql` uch
-- nuqsonni tuzatdi (A: gvard `SECURITY DEFINER` bo'lgani uchun chaqiruvchini
-- ajratmasdi; B: `rejected_at` gvardi yo'q edi; C: sovutish davri yo'q edi),
-- LEKIN uning §5 bo'limi "bu migratsiya hech narsani tekshirmaydi" deb yozib
-- qo'ygan edi. Ya'ni tuzatishlar **NOT VERIFIED** holatida turgan.
--
-- BU FAYL O'ZI TEKSHIRUVDIR. Ikki qatlam:
--   (A) KATALOG ASSERSIYALARI — `pg_proc` / `pg_trigger` / `pg_get_functiondef`
--       bo'yicha haqiqiy holat.
--   (B) XULQ TESTLARI — sun'iy foydalanuvchi va sun'iy ariza bilan HAQIQIY
--       `UPDATE` / RPC chaqiruvlari, `authenticated` roli va soxta JWT
--       da'volari ostida (ya'ni PostgREST chaqiruvi taqlid qilinadi).
--
-- QOLDIQ MA'LUMOT YO'Q — SOXTA ADVOKAT YO'Q:
-- (B) qismi plpgsql SUB-TRANZAKSIYASI ichida bajariladi va OXIRIDA
-- `LEXHUB_TEST_ROLLBACK` bilan ATAYLAB yiqiladi. Ya'ni sun'iy `auth.users`,
-- `profiles`, `expert_profiles` qatorlari BAZAGA YOZILMAYDI. Foydalanuvchi
-- talabi: ilovaga soxta advokat/yolg'on ma'lumot QO'SHILMASIN — shuning uchun
-- tekshiruv ma'lumotining bir zarrasi ham qolmaydi.
--
-- ASSERSIYA YIQILSA: `RAISE EXCEPTION` -> BUTUN migratsiya rollback ->
-- `supabase db push` XATO qaytaradi va migratsiya "qo'llangan" deb
-- YOZILMAYDI. Ya'ni bu faylning muvaffaqiyatli qo'llanishi = isbot.
--
-- IDEMPOTENT: hech qanday DDL/DML qoldirmaydi, faqat o'qiydi va tekshiradi.

BEGIN;

DO $assert$
DECLARE
    v_applicant   UUID := gen_random_uuid();
    v_admin       UUID := gen_random_uuid();
    v_license     TEXT := 'LX-ASSERT-' || substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 12);
    v_fail        TEXT;
    v_caught      TEXT;
    v_state       TEXT;
    v_definer     BOOLEAN;
    v_def         TEXT;
    v_cnt         INTEGER;
    v_res         JSONB;
    v_verified_at TIMESTAMPTZ;
    v_role        TEXT;
BEGIN
    -- =========================================================================
    -- (A) KATALOG ASSERSIYALARI
    -- =========================================================================

    -- A1 (NUQSON A ning o'zagi): gvard `SECURITY INVOKER` bo'lishi SHART.
    -- `SECURITY DEFINER` bo'lsa funksiya ichida `current_user` = egasi
    -- (`postgres`), ya'ni chaqiruvchini ajratish MUMKIN EMAS.
    SELECT prosecdef INTO v_definer FROM pg_proc
     WHERE oid = 'public.protect_expert_profile_sensitive_fields()'::regprocedure;
    IF v_definer IS NOT FALSE THEN
        RAISE EXCEPTION 'A1 FAILED: protect_expert_profile_sensitive_fields '
            'hali ham SECURITY DEFINER (prosecdef=%)', v_definer;
    END IF;

    -- A2: gvard trigger ULANGAN va O'CHIRILMAGAN.
    SELECT count(*) INTO v_cnt FROM pg_trigger
     WHERE tgrelid = 'public.expert_profiles'::regclass
       AND tgname = 'trg_protect_expert_profile_sensitive_fields'
       AND tgenabled <> 'D';
    IF v_cnt < 1 THEN
        RAISE EXCEPTION 'A2 FAILED: gvard trigger yo''q yoki DISABLED';
    END IF;

    -- A3 (NUQSON B): gvard tanasi `is_privileged_db_role()` bilan qaraydi va
    -- `rejected_at` ni himoya qiladi; o'lik `current_user != ''service_role''`
    -- sharti QAYTIB KELMASLIGI kerak.
    SELECT pg_get_functiondef(
        'public.protect_expert_profile_sensitive_fields()'::regprocedure)
      INTO v_def;
    IF position('is_privileged_db_role' IN v_def) = 0 THEN
        RAISE EXCEPTION 'A3 FAILED: gvard is_privileged_db_role() ni ishlatmaydi';
    END IF;
    IF position('rejected_at' IN v_def) = 0 THEN
        RAISE EXCEPTION 'A3 FAILED: gvardda rejected_at himoyasi YO''Q';
    END IF;
    IF position('service_role' IN v_def) > 0 THEN
        RAISE EXCEPTION 'A3 FAILED: o''lik current_user != service_role sharti qaytgan';
    END IF;

    -- A4: moderatsiya RPC'si `SECURITY DEFINER` va xodim tekshiruvi bilan.
    SELECT prosecdef, pg_get_functiondef(oid) INTO v_definer, v_def
      FROM pg_proc
     WHERE oid = 'public.verify_expert_application(uuid, boolean)'::regprocedure;
    IF v_definer IS NOT TRUE
       OR position('is_admin_or_moderator' IN v_def) = 0 THEN
        RAISE EXCEPTION 'A4 FAILED: verify_expert_application xavfsizlik konteksti buzilgan';
    END IF;

    -- A5 (NUQSON C): sovutish davri `LX429` SQLSTATE bilan qaytadi (klient
    -- xato MATNI bo'yicha emas, KOD bo'yicha ajratadi).
    SELECT pg_get_functiondef(oid) INTO v_def FROM pg_proc
     WHERE oid = 'public.apply_for_expert_verification(character varying, integer, '
                 'character varying, text, character varying, text, numeric)'::regprocedure;
    IF position('LX429' IN v_def) = 0 THEN
        RAISE EXCEPTION 'A5 FAILED: apply_for_expert_verification LX429 qaytarmaydi';
    END IF;

    -- =========================================================================
    -- (B) XULQ TESTLARI — SUB-TRANZAKSIYA, OXIRIDA TO'LIQ ROLLBACK
    -- =========================================================================
    BEGIN
        -- B0. Sun'iy foydalanuvchilar. `on_auth_user_created` ->
        -- `handle_new_user()` `profiles` qatorini O'ZI yaratadi.
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, created_at, updated_at,
            raw_app_meta_data, raw_user_meta_data
        ) VALUES
        ('00000000-0000-0000-0000-000000000000', v_applicant, 'authenticated',
         'authenticated', 'assert-applicant-' || v_applicant || '@lexhub.invalid',
         '', now(), now(), now(),
         '{"provider":"email","providers":["email"]}'::jsonb,
         jsonb_build_object('full_name', 'ASSERT Nomzod', 'role', 'citizen')),
        ('00000000-0000-0000-0000-000000000000', v_admin, 'authenticated',
         'authenticated', 'assert-admin-' || v_admin || '@lexhub.invalid',
         '', now(), now(), now(),
         '{"provider":"email","providers":["email"]}'::jsonb,
         jsonb_build_object('full_name', 'ASSERT Moderator', 'role', 'citizen'));

        SELECT count(*) INTO v_cnt FROM public.profiles
         WHERE id IN (v_applicant, v_admin);
        IF v_cnt <> 2 THEN
            RAISE EXCEPTION 'B0 FAILED: handle_new_user() profil yaratmadi (topildi=%)', v_cnt;
        END IF;

        -- Admin rolini `postgres` beradi. KLIENT buni qila OLMAYDI —
        -- `profiles` gvardi rol o'zgarishini bloklaydi (alohida invariant).
        UPDATE public.profiles SET role = 'admin' WHERE id = v_admin;

        -- B1. CHAQIRUVCHI TAQLIDI — FAQAT JWT DA'VOLARI ORQALI.
        --
        -- O'LCHANGAN CHEGARA (2026-08-30, `supabase db push` xatosi):
        --   ERROR: permission denied to set session authorization
        --   "authenticated" (SQLSTATE 42501)
        -- Supabase'ning `postgres` roli SUPERUSER EMAS — bu kanaldan
        -- `session_user` ni o'zgartirib bo'lmaydi. `SET ROLE authenticated`
        -- esa YETARLI EMAS: `is_privileged_db_role()` `session_user` ni HAM
        -- ko'radi (u `postgres` bo'lib qoladi), ya'ni gvard chetlab o'tilardi
        -- va test YOLG'ON natija berardi.
        --
        -- SHU SABABLI faqat `request.jwt.claims` qo'yiladi. Bu `auth.uid()`
        -- va `is_admin_or_moderator()` uchun YETARLI, ya'ni `SECURITY DEFINER`
        -- RPC'lari (`apply_for_expert_verification`, `verify_expert_application`)
        -- REAL chaqiruv bilan AYNI kontekstda ishlaydi: ular ichida
        -- `current_user` = `postgres` — real PostgREST chaqiruvida HAM shunday
        -- (funksiya egasi `postgres`). Demak RPC testlari SODIQ.
        --
        -- NIMA TEKSHIRILMAYDI (halol chegara): gvard trigger'ining KLIENT
        -- `UPDATE`ini rad etishi. Buning uchun HAQIQIY JWT bilan PostgREST
        -- so'rovi kerak, u esa bazada HAQIQIY ekspert arizasi QOLDIRARDI
        -- (klient uchun DELETE yo'li YO'Q) — "soxta advokat qo'shmaslik"
        -- talabi buni TAQIQLAYDI. Holat: fayl oxiridagi qaydga qara.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_applicant, 'role', 'authenticated')::TEXT);

        IF auth.uid() IS DISTINCT FROM v_applicant THEN
            RAISE EXCEPTION 'B1 FAILED: auth.uid() da''volari ishlamadi (%)', auth.uid();
        END IF;

        v_res := public.apply_for_expert_verification(
            'ASSERT Fuqarolik huquqi', 3, v_license, NULL, NULL, NULL, 0);
        IF v_res->>'status' <> 'pending_verification' THEN
            RAISE EXCEPTION 'B1 FAILED: ariza topshirilmadi (%)', v_res;
        END IF;
        IF (v_res->>'expert_id') IS NULL THEN
            RAISE EXCEPTION 'B1 FAILED: `expert_id` qaytmadi (jim muvaffaqiyat)';
        END IF;

        -- (B2-B6 BO'LGAN JOY — ATAYLAB OLIB TASHLANDI, YASHIRILMADI.)
        --
        -- Bu yerda klientning `rating` / `reviews_count` / `verified_at` /
        -- `user_id` / `rejected_at` maydonlarini buzishga urinishi tekshirilardi.
        -- LEKIN bu sessiyada `session_user` = `postgres`, ya'ni
        -- `is_privileged_db_role()` TRUE qaytaradi va gvard trigger
        -- ATAYLAB o'tkazib yuboradi. Ya'ni `UPDATE` MUVAFFAQIYATLI bo'lardi va
        -- test "himoya YO'Q" degan YOLG'ON xulosaga olib kelardi.
        -- `SET SESSION AUTHORIZATION` bilan `session_user` ni almashtirish
        -- MUMKIN EMAS (yuqoridagi o'lchangan 42501 xatosi).
        -- Shuning uchun bu beshta invariant SHU FAYLDA TEKSHIRILMAYDI —
        -- ular A1/A3 (gvard `SECURITY INVOKER`, tanasida `rejected_at` bor)
        -- darajasida MANBA bo'yicha qulflangan, XULQI esa NOT VERIFIED.
        -- Batafsil: fayl oxiridagi "HOLAT QAYDI" bo'limi.

        -- B7 (NUQSON A ISBOTI — MODERATSIYA YO'LI TIRIK):
        -- Gvard `SECURITY INVOKER` bo'lgani uchun DEFINER RPC ichidagi yozuv
        -- `is_privileged_db_role()` bo'yicha O'TADI. Agar gvard noto'g'ri
        -- yozilgan bo'lsa, tasdiqlash "Expert verification date is managed by
        -- administrators" xatosi bilan yiqilardi — ya'ni ADMIN HAM
        -- tasdiqlay olmasdi.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_admin, 'role', 'authenticated')::TEXT);
        v_res := public.verify_expert_application(v_applicant, TRUE);
        IF v_res->>'status' <> 'approved' THEN
            RAISE EXCEPTION 'B7 FAILED: tasdiqlash yo''li ishlamadi (%)', v_res;
        END IF;

        SELECT verified_at INTO v_verified_at FROM public.expert_profiles
         WHERE user_id = v_applicant;
        IF v_verified_at IS NULL THEN
            RAISE EXCEPTION 'B7 FAILED: `verified_at` QO''YILMADI (jim muvaffaqiyat)';
        END IF;
        SELECT role::TEXT INTO v_role FROM public.profiles WHERE id = v_applicant;
        IF v_role <> 'verified_expert' THEN
            RAISE EXCEPTION 'B7 FAILED: rol `verified_expert` emas (%)', v_role;
        END IF;

        -- B8: NOMZOD O'ZINI TASDIQLAY OLMAYDI. Bu test SODIQ: gate
        -- `is_admin_or_moderator()` bo'lib, u `auth.uid()` -> `profiles.role`
        -- ni o'qiydi, ya'ni FAQAT JWT da'volariga bog'liq — DB roliga emas.
        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_applicant, 'role', 'authenticated')::TEXT);
        v_caught := NULL;
        BEGIN
            v_res := public.verify_expert_application(v_applicant, TRUE);
        EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM;
        END;
        IF v_caught IS NULL THEN
            RAISE EXCEPTION 'B8 FAILED: NOMZOD O''ZINI TASDIQLADI (privilege escalation)';
        END IF;

        -- B9 (NUQSON C ISBOTI): rad etilgandan keyin 24 soatlik sovutish.
        -- Rad etish holati `postgres` huquqi bilan qo'yiladi (fixture) —
        -- real hayotda buni moderator RPC'si qiladi.
        UPDATE public.expert_profiles
           SET verified_at = NULL, rejected_at = now()
         WHERE user_id = v_applicant;

        EXECUTE format('SET LOCAL request.jwt.claims = %L',
            json_build_object('sub', v_applicant, 'role', 'authenticated')::TEXT);
        v_caught := NULL;
        v_state := NULL;
        BEGIN
            v_res := public.apply_for_expert_verification(
                'ASSERT Fuqarolik huquqi', 3, v_license, NULL, NULL, NULL, 0);
        EXCEPTION WHEN OTHERS THEN
            v_caught := SQLERRM;
            v_state := SQLSTATE;
        END;
        IF v_state IS DISTINCT FROM 'LX429' THEN
            RAISE EXCEPTION 'B9 FAILED: sovutish davri LX429 bermadi (state=%, msg=%)',
                coalesce(v_state, 'NULL'), coalesce(v_caught, 'xato yo''q — ariza O''TDI');
        END IF;

        -- B10: 24 soatdan KEYIN qayta topshirish MUMKIN (qulf abadiy emas).
        UPDATE public.expert_profiles
           SET rejected_at = now() - INTERVAL '25 hours'
         WHERE user_id = v_applicant;

        v_res := public.apply_for_expert_verification(
            'ASSERT Fuqarolik huquqi', 3, v_license, NULL, NULL, NULL, 0);
        IF v_res->>'status' <> 'pending_verification' THEN
            RAISE EXCEPTION 'B10 FAILED: sovutish tugagach ariza o''tmadi (%)', v_res;
        END IF;

        SELECT rejected_at INTO v_verified_at FROM public.expert_profiles
         WHERE user_id = v_applicant;
        IF v_verified_at IS NOT NULL THEN
            RAISE EXCEPTION 'B10 FAILED: qayta topshirishda `rejected_at` tozalanmadi';
        END IF;

        RAISE EXCEPTION 'LEXHUB_TEST_ROLLBACK';
    EXCEPTION WHEN OTHERS THEN
        -- `LEXHUB_TEST_ROLLBACK` — KUTILGAN yiqilish: sun'iy ma'lumot
        -- shu yerda BUTUNLAY yo'q qilinadi. Boshqa har qanday xato =
        -- ASSERSIYA YIQILDI.
        IF SQLERRM <> 'LEXHUB_TEST_ROLLBACK' THEN
            v_fail := SQLSTATE || ' | ' || SQLERRM;
        END IF;
    END;

    IF v_fail IS NOT NULL THEN
        RAISE EXCEPTION 'LEXHUB_ASSERT_FAILED: %', v_fail;
    END IF;

    RAISE NOTICE 'LEXHUB: barcha assersiyalar bajarildi';
END
$assert$;

COMMIT;

-- =============================================================================
-- HOLAT QAYDI (2026-08-30) — QO'LLANDI, YA'NI ASSERSIYALAR O'TDI
-- =============================================================================
--
-- (1) `supabase db push --include-all` NATIJASI:
--     Applying migration 20260830020000_expert_moderation_runtime_assertions.sql...
--     {"upToDate":false,"dryRun":false,
--      "migrations":["20260830020000_expert_moderation_runtime_assertions.sql"],
--      "message":"Finished supabase db push."}
--     Bu faylning MUVAFFAQIYATLI qo'llanishi = ISBOT: har qanday assersiya
--     `RAISE EXCEPTION` qilsa BUTUN tranzaksiya rollback bo'lardi va migratsiya
--     "qo'llandi" deb YOZILMASDI. Demak REAL bazada quyidagilar HAQIQAT:
--       A1 gvard `SECURITY INVOKER` (prosecdef = false)
--       A2 `trg_protect_expert_profile_sensitive_fields` ULANGAN va yoqilgan
--       A3 gvard tanasi `is_privileged_db_role()` + `rejected_at`, o'lik
--          `service_role` sharti YO'Q
--       A4 `verify_expert_application` DEFINER + `is_admin_or_moderator`
--       A5 `apply_for_expert_verification` `LX429` qaytaradi
--       B0 `handle_new_user()` `auth.users` INSERT'ida profil YARATDI
--       B1 nomzod ariza topshirdi -> `pending_verification` + `expert_id`
--       B7 MODERATOR TASDIQLADI -> `verified_at` QO'YILDI, rol
--          `verified_expert` (ya'ni NUQSON A tuzatilgani XULQ bilan isbotlandi)
--       B8 nomzod O'ZINI tasdiqlay OLMADI (privilege escalation YO'Q)
--       B9 rad etilgandan keyin qayta ariza `LX429` bilan RAD ETILDI
--       B10 25 soatdan keyin ariza O'TDI va `rejected_at` TOZALANDI
--
-- (2) QOLDIQ MA'LUMOT YO'Q — MUSTAQIL O'LCHOV BILAN ISBOTLANDI.
--     Vaqtinchalik, ataylab yiqiladigan `DO` bloki (`postgres` huquqi,
--     hech narsa qo'llanmadi, fayl o'chirildi) quyidagini qaytardi:
--       ERROR: LEXHUB_RESIDUE users=0 profiles=0 experts=0 (SQLSTATE P0001)
--     Ya'ni `auth.users` (`assert-%@lexhub.invalid`), `profiles`
--     (`ASSERT %`) va `expert_profiles` (`LX-ASSERT-%`) da BITTA ham qator
--     QOLMADI. Foydalanuvchi talabi bajarildi: ilovada SOXTA ADVOKAT YO'Q.
--
-- (3) NOT VERIFIED (halol chegara, yashirilmadi): gvard trigger'ining KLIENT
--     `UPDATE`ini rad etishi (`rating`, `reviews_count`, `verified_at`,
--     `user_id`, `rejected_at`). Sababi O'LCHANGAN:
--       ERROR: permission denied to set session authorization "authenticated"
--       (SQLSTATE 42501)
--     Supabase migratsiya roli SUPERUSER emas, `session_user` ni almashtirib
--     bo'lmaydi; `SET ROLE` esa yolg'on natija berardi
--     (`is_privileged_db_role()` `session_user` ni HAM ko'radi). Yagona sodiq
--     yo'l — HAQIQIY JWT bilan PostgREST so'rovi, u esa bazada HAQIQIY ekspert
--     arizasi qoldirardi (klient uchun DELETE yo'li YO'Q) — bu TAQIQLANGAN.
--     Manba darajasidagi qulf: A1 + A3 (yuqorida) va
--     `test/features/legal_experts/expert_verification_invariant_test.dart` +
--     `test/features/legal_experts/expert_apply_cooldown_test.dart`.

