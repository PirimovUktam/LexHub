-- NUQSON F — `purge_client_error_logs()` GVARDI O'LIK (audit izini har qanday
-- tizimga kirgan foydalanuvchi o'chira olardi).
--
-- `20260830010000_client_error_logs.sql:155` dagi shart:
--
--     IF NOT public.is_privileged_db_role()
--        AND NOT public.is_admin_or_moderator() THEN RAISE ...
--
-- `is_privileged_db_role()` — `SECURITY INVOKER` funksiya, tanasi
-- `current_user IN ('postgres', ...) OR session_user IN (...)`. Lekin
-- `purge_client_error_logs()` O'ZI `SECURITY DEFINER` va egasi `postgres`:
-- uning ICHIDA `current_user` = 'postgres', ya'ni shart HAR DOIM TRUE va
-- `NOT TRUE` = FALSE — gvard HECH KIMNI to'smaydi.
--
-- Bu AYNI `20260829130000_...:10` da "NUQSON A" deb tuzatilgan naqsh, lekin
-- o'sha tuzatish trigger gvardiga tegdi; bu funksiya O'TKAZIB YUBORILGAN.
-- Loyihadagi `is_privileged_db_role()` chaqiruvlarini sanab chiqdim: qolgan
-- 3 tasi (`protect_profile_privileged_columns_on_insert`,
-- `protect_profile_sensitive_fields`, `protect_expert_profile_sensitive_fields`)
-- `SECURITY INVOKER` — ular TO'G'RI. Yuza = FAQAT shu funksiya.
--
-- TA'SIRI: `EXECUTE` `authenticated` ga berilgan (va Supabase'ning
-- `ALTER DEFAULT PRIVILEGES` sozlamasi tufayli `anon` ga ham), ya'ni oddiy
-- fuqaro `rpc('purge_client_error_logs', {p_days: 1})` bilan crash
-- jurnalining deyarli hammasini o'chirib tashlab, o'z xatosining izini
-- yo'qotishi mumkin edi. Jadvalda UPDATE/DELETE policy ATAYLAB yo'q edi
-- ("audit izi"), bu funksiya esa o'sha qarorni chetlab o'tardi.
--
-- QO'LLASH PAYTIDA ISBOTLANADI (`;` bilan yopilgan DO bloklari):
--   PRE-1  tuzatishdan OLDIN: `SET LOCAL ROLE authenticated` (JWT yo'q,
--          ya'ni `auth.uid()` NULL, `is_admin_or_moderator()` FALSE) ostida
--          chaqiruv MUVAFFAQIYATLI o'tadi — nuqson HAQIQATAN bor.
--          Chaqiruv `p_days = 36500` bilan: 100 yildan eski yozuv yo'q,
--          shuning uchun MA'LUMOT O'CHMAYDI, faqat RUXSAT o'lchanadi.
--          O'LCHANGAN (2-push urinishi, ataylab RAISE bilan):
--              passed=t deleted=0 session_user=cli_login_postgres
--              current_user=postgres
--   C1     tuzatishdan KEYIN ayni chaqiruv 42501 bilan RAD ETILADI.
--   C2     migratsiya sessiyasining O'ZI ham 42501 oladi — rol bo'yicha orqa
--          eshik YO'Q (jadval egasi kerak bo'lsa to'g'ridan-to'g'ri DELETE
--          qiladi).
--   C3     `anon` da `EXECUTE` huquqi YO'Q.
--   C4     `authenticated` da `EXECUTE` huquqi BOR (xodim UI'si uchun).
--   C5     funksiya tanasida `is_privileged_db_role` YO'Q (naqsh qaytmaydi).
--
-- Birorta shart bajarilmasa `RAISE` ishlaydi va BUTUN migratsiya rollback
-- bo'ladi — "qo'llandi" yozuvi faqat yuqoridagilar HAQIQATAN shunday bo'lsa
-- paydo bo'ladi.

BEGIN;

-- 1. NUQSONNI O'LCHASH (tuzatishdan OLDIN)
DO $pre$
DECLARE
    v_passed BOOLEAN := FALSE;
    v_deleted INTEGER;
    -- `RESET ROLE` ISHLATILMAYDI: `supabase db push` kanali login roli bilan
    -- kirib, keyin `SET ROLE postgres` qiladi ("Initialising login role...").
    -- `RESET ROLE` o'sha `SET ROLE` ni ham bekor qilib, keyingi operatorni
    -- login roli nomidan bajarardi — O'LCHANGAN: birinchi push urinishi
    -- "permission denied for schema public (42501)" bilan yiqildi.
    v_prev TEXT := current_user;
BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
        SELECT public.purge_client_error_logs(36500) INTO v_deleted;
        v_passed := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_passed := FALSE;
    END;
    EXECUTE format('SET LOCAL ROLE %I', v_prev);

    IF NOT v_passed THEN
        RAISE EXCEPTION 'PRE-1 FAILED: kutilgan nuqson TOPILMADI — xodim '
            'bo''lmagan `authenticated` allaqachon to''silgan. Bu migratsiya '
            'asoslanmagan, tuzatishdan oldin sababni qayta o''rgan.';
    END IF;
    RAISE NOTICE 'PRE-1 OK: gvard o''lik edi (o''chirilgan qator: %)', v_deleted;
END
$pre$;

-- 2. TUZATISH
CREATE OR REPLACE FUNCTION public.purge_client_error_logs(p_days INTEGER DEFAULT 30)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    -- `is_privileged_db_role()` BU YERDA ISHLATILMAYDI: u `current_user` ga
    -- qaraydi, `SECURITY DEFINER` ichida esa u DOIM funksiya egasi
    -- (`postgres`) — ya'ni shart chaqiruvchini AJRATMAYDI (NUQSON F).
    --
    -- `session_user` BO'YICHA OQ RO'YXAT HAM RAD ETILDI. O'LCHANGAN
    -- (2026-08-30, shu migratsiyaning 2-push urinishi):
    --     session_user=cli_login_postgres current_user=postgres
    -- Ya'ni `supabase db push` kanali `postgres` NOMIDAN EMAS, alohida login
    -- roli bilan keladi. PostgREST'da esa u `authenticator`. Bu ro'yxat
    -- Supabase infratuzilmasi o'zgarsa JIM ravishda YOLG'ON javob berardi —
    -- va xato yo'nalishda: ro'yxatda yo'q rol "klient" deb hisoblanib, gvard
    -- HAMMAGA ochilib qolishi mumkin edi.
    --
    -- SHUNING UCHUN YAGONA SHART: JWT'da xodim bo'lish. Fail-closed.
    --
    -- OQIBATI (ATAYLAB): migratsiya/psql sessiyasi ham bu funksiyani chaqira
    -- OLMAYDI (`auth.uid()` NULL). Bu cheklov EMAS — jadval egasi kerak bo'lsa
    -- `DELETE FROM public.client_error_logs ...` ni to'g'ridan-to'g'ri bajaradi.
    -- Kelajakda `pg_cron` qo'shilsa u ham shu DELETE'ni ishlatadi yoki ANIQ
    -- yozilgan alohida shart qo'shiladi — mavjud bo'lmagan chaqiruvchi uchun
    -- ruxsat oldindan kengaytirilmaydi.
    IF NOT public.is_admin_or_moderator() THEN
        RAISE EXCEPTION 'Bu amal uchun ruxsat yo''q.' USING ERRCODE = '42501';
    END IF;
    IF p_days IS NULL OR p_days < 1 THEN
        RAISE EXCEPTION 'p_days kamida 1 bo''lishi kerak.' USING ERRCODE = '22023';
    END IF;

    DELETE FROM public.client_error_logs
     WHERE created_at < now() - make_interval(days => p_days);
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

-- Supabase loyihasida `ALTER DEFAULT PRIVILEGES ... GRANT ALL ON FUNCTIONS TO
-- postgres, anon, authenticated, service_role` o'rnatilgan, shuning uchun
-- `REVOKE ... FROM PUBLIC` YETARLI EMAS — `anon` dan ANIQ olib tashlanadi
-- (O'LCHANGAN: `20260830030000_...` ning birinchi push urinishi "A4 FAILED").
REVOKE ALL ON FUNCTION public.purge_client_error_logs(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purge_client_error_logs(INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION public.purge_client_error_logs(INTEGER) TO authenticated;

COMMENT ON FUNCTION public.purge_client_error_logs(INTEGER) IS
    'Klient xato jurnalini tozalaydi. Faqat admin/moderator (JWT) yoki '
    'privileged DB sessiyasi. `is_privileged_db_role()` ATAYLAB '
    'ishlatilmaydi — SECURITY DEFINER ichida u chaqiruvchini ajratmaydi.';

-- 3. TUZATISHDAN KEYINGI ISBOT
DO $post$
DECLARE
    v_blocked BOOLEAN := FALSE;
    v_code TEXT;
    v_deleted INTEGER;
    v_prev TEXT := current_user;
BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
        SELECT public.purge_client_error_logs(36500) INTO v_deleted;
    EXCEPTION WHEN OTHERS THEN
        v_blocked := TRUE;
        v_code := SQLSTATE;
    END;
    EXECUTE format('SET LOCAL ROLE %I', v_prev);

    IF NOT v_blocked THEN
        RAISE EXCEPTION 'C1 FAILED: xodim bo''lmagan `authenticated` hamon '
            'jurnalni tozalay oladi';
    END IF;
    IF v_code IS DISTINCT FROM '42501' THEN
        RAISE EXCEPTION 'C1 FAILED: kutilgan SQLSTATE 42501 emas: %', v_code;
    END IF;

    -- C2: PRIVILEGED MIGRATSIYA SESSIYASI HAM to'siladi (`auth.uid()` NULL).
    -- Bu ATAYLAB — yuqoridagi izohga qara. Qulf `current_user`/`session_user`
    -- bo'yicha "orqa eshik" QAYTIB kelmasligi uchun.
    v_blocked := FALSE;
    v_code := NULL;
    BEGIN
        SELECT public.purge_client_error_logs(36500) INTO v_deleted;
    EXCEPTION WHEN OTHERS THEN
        v_blocked := TRUE;
        v_code := SQLSTATE;
    END;
    IF NOT v_blocked OR v_code IS DISTINCT FROM '42501' THEN
        RAISE EXCEPTION 'C2 FAILED: DB sessiyasi uchun orqa eshik bor '
            '(blocked=% code=%) — gvard yana chaqiruvchi ROLIGA qarayapti',
            v_blocked, v_code;
    END IF;

    IF has_function_privilege('anon',
            'public.purge_client_error_logs(integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'C3 FAILED: `anon` tozalash funksiyasini chaqira oladi';
    END IF;
    IF NOT has_function_privilege('authenticated',
            'public.purge_client_error_logs(integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'C4 FAILED: xodim UI''si funksiyani chaqira olmaydi';
    END IF;

    -- C5: NUQSON F NAQSHI QAYTMAYDI — funksiya tanasida `is_privileged_db_role`
    -- BO'LMASLIGI SHART. Bu qulf bazaning O'ZIDAN o'qiladi (fayl matnidan
    -- emas), ya'ni keyingi `CREATE OR REPLACE` uni tiklab qo'ysa ushlanadi.
    --
    -- `--` izohlari OLIB TASHLANADI: yuqoridagi tushuntirish izohi nomni
    -- MATN sifatida o'z ichiga oladi va tekshiruv o'z izohiga ilinardi
    -- (O'LCHANGAN: shu migratsiyaning 3-push urinishi "C5 FAILED").
    IF position('is_privileged_db_role' IN
            regexp_replace(
                pg_get_functiondef('public.purge_client_error_logs(integer)'
                    ::regprocedure),
                '--[^' || chr(10) || ']*', '', 'g')) > 0 THEN
        RAISE EXCEPTION 'C5 FAILED: o''lik `is_privileged_db_role()` sharti '
            'qaytib keldi (SECURITY DEFINER ichida u DOIM TRUE)';
    END IF;

    RAISE NOTICE 'C1-C5 OK: gvard endi FAQAT JWT xodimini o''tkazadi';
END
$post$;

COMMIT;

-- ==========================================================================
-- HOLAT QAYDI (2026-08-30) — QO'LLANDI
--
-- `supabase db push --include-all` javobi (AYNAN):
--   {"upToDate":false,"dryRun":false,
--    "migrations":["20260830050000_purge_logs_guard_fix.sql"],
--    "seeds":[],"roles":[],"message":"Finished supabase db push."}
--
-- Ya'ni PRE-1 va C1-C5 HAMMASI bazada BAJARILDI va o'tdi:
--   PRE-1  nuqson HAQIQATAN bor edi — xodim bo'lmagan `authenticated`
--          `purge_client_error_logs(36500)` ni MUVAFFAQIYATLI chaqirdi
--          (o'chirilgan qator 0 — probe DESTRUKTIV EMAS edi).
--   C1     endi 42501 "Bu amal uchun ruxsat yo'q."
--   C2     migratsiya sessiyasi ham 42501 — rol bo'yicha orqa eshik YO'Q.
--   C3     `anon` da EXECUTE YO'Q.
--   C4     `authenticated` da EXECUTE BOR.
--   C5     funksiya tanasida (izohlar olib tashlangach) `is_privileged_db_role`
--          YO'Q.
--
-- YO'LDA O'LCHANGAN 3 FAKT (har biri yiqilgan push bilan isbotlangan):
--   1. `RESET ROLE` migratsiya kanalini BUZADI: push `cli_login_postgres`
--      bilan kirib `SET ROLE postgres` qiladi, `RESET ROLE` esa uni bekor
--      qilib "permission denied for schema public (42501)" beradi. Yechim —
--      `current_user` ni saqlab, `SET LOCAL ROLE %I` bilan tiklash.
--   2. `session_user` = `cli_login_postgres` (`postgres` EMAS). Shuning uchun
--      "privileged rol oq ro'yxati" g'oyasi TASHLANDI — u infratuzilma
--      o'zgarsa fail-open bo'lardi.
--   3. `pg_get_functiondef()` IZOHLARNI ham qaytaradi, shuning uchun manba
--      matnidagi qulf o'z izohiga ilinishi mumkin.
--
-- HALI ISBOTLANMAGAN (NOT VERIFIED): HAQIQIY admin JWT bilan chaqiruv
-- (C1 faqat "xodim EMAS" yo'lini o'lchadi). Buni xodim hisobi bilan
-- qurilmada yoki `tool/probe_expert_guard.py` naqshida o'lchash kerak.
-- ==========================================================================
