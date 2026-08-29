-- LEXHUB — KLIENT XATOLARI UCHUN SINK: `public.client_error_logs`
--
-- MUAMMO (o'lchangan): `lib/main.dart` da `FlutterError.onError` va
-- `PlatformDispatcher.instance.onError` FAQAT `debugPrint` qiladi. Release
-- build'da `debugPrint` hech qayerga bormaydi — ya'ni foydalanuvchi
-- qurilmasidagi har bir crash JIMGINA yo'qoladi. Loyihada `sentry` yoki
-- boshqa telemetriya paketi YO'Q (`pubspec.yaml` bo'yicha), shuning uchun
-- sink loyihaning o'z Supabase'ida quriladi — yangi dependency qo'shilmaydi.
--
-- XAVFSIZLIK MODELI (bu jadval INTERNETGA OCHIQ yozuv yuzasi):
--   * `user_id` NI KLIENT YUBORMAYDI: DEFAULT `auth.uid()`, RLS `WITH CHECK`
--     esa `user_id IS NOT DISTINCT FROM auth.uid()` — boshqa odam nomidan
--     yozib bo'lmaydi (anon uchun ikki tomon ham NULL, ya'ni ruxsat).
--   * KLIENT O'QIMAYDI: `anon`/`authenticated` uchun SELECT policy YO'Q,
--     faqat admin/moderator (`public.is_admin_or_moderator()`) ko'radi.
--     Stack trace'lar boshqa foydalanuvchilarga ko'rinmasligi shart.
--   * UPDATE/DELETE policy YO'Q — audit yozuvini klient o'zgartira olmaydi.
--   * O'LCHAM: BEFORE INSERT trigger matnni KESADI (rad etmaydi) — crash
--     hisoboti CHECK buzilishi tufayli butunlay yo'qolmasin.
--   * TEZLIK CHEGARASI: bir foydalanuvchi 20/min, anon oqim 60/min.
--     Cheklov `LX429` SQLSTATE bilan qaytadi (loyiha konvensiyasi).
--
-- IDEMPOTENT: qayta ishga tushirilsa hech narsa buzilmaydi. DESTRUKTIV
-- OPERATSIYA YO'Q (`DROP TABLE`, `DELETE`, ustun o'chirish — yo'q).

BEGIN;

-- 1. JADVAL
CREATE TABLE IF NOT EXISTS public.client_error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- `ON DELETE SET NULL`: foydalanuvchi hisobi o'chsa xato yozuvi qoladi,
    -- lekin kimga tegishli ekani anonimlashadi (PII minimizatsiya).
    user_id UUID DEFAULT auth.uid() REFERENCES public.profiles(id) ON DELETE SET NULL,
    kind TEXT NOT NULL DEFAULT 'flutter_error',
    message TEXT NOT NULL,
    stack TEXT,
    context TEXT,
    platform TEXT,
    build_mode TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mavjud bazada jadval allaqachon bo'lsa — ustunlar tekshiriladi.
ALTER TABLE public.client_error_logs ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'flutter_error';
ALTER TABLE public.client_error_logs ADD COLUMN IF NOT EXISTS stack TEXT;
ALTER TABLE public.client_error_logs ADD COLUMN IF NOT EXISTS context TEXT;
ALTER TABLE public.client_error_logs ADD COLUMN IF NOT EXISTS platform TEXT;
ALTER TABLE public.client_error_logs ADD COLUMN IF NOT EXISTS build_mode TEXT;

COMMENT ON TABLE public.client_error_logs IS
    'Klient (Flutter) tutilmagan xatolari. Klient faqat INSERT qiladi; '
    'o''qish faqat admin/moderator uchun. `user_id` DEFAULT auth.uid().';

-- 2. INDEKSLAR
-- Admin paneli "eng yangi xatolar" ni o'qiydi.
CREATE INDEX IF NOT EXISTS idx_client_error_logs_created_at
    ON public.client_error_logs (created_at DESC);
-- Tezlik chegarasi triggeri AYNI shu shaklda so'raydi.
CREATE INDEX IF NOT EXISTS idx_client_error_logs_user_recent
    ON public.client_error_logs (user_id, created_at DESC);

-- 3. SANITIZATSIYA + TEZLIK CHEGARASI
--
-- `SECURITY DEFINER` ATAYLAB: funksiya o'z jadvalini SANAB ko'rishi kerak,
-- lekin klient rollari uchun SELECT policy YO'Q — `SECURITY INVOKER` bo'lsa
-- `count(*)` HAR DOIM 0 qaytarib chegara mavjud bo'lsa ham ISHLAMASDI
-- (jim yolg'on himoya). Egasi (`postgres`) RLS'dan o'tadi, shuning uchun
-- sanoq haqiqiy.
CREATE OR REPLACE FUNCTION public.client_error_logs_sanitize()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_recent INTEGER;
BEGIN
    -- KESISH, rad etish EMAS: uzun stack trace butun hisobotni yo'qotmasin.
    NEW.message    := left(coalesce(NEW.message, ''), 2000);
    NEW.stack      := left(NEW.stack, 8000);
    NEW.context    := left(NEW.context, 200);
    NEW.platform   := left(NEW.platform, 32);
    NEW.build_mode := left(NEW.build_mode, 16);
    NEW.kind       := left(coalesce(NEW.kind, 'flutter_error'), 32);
    -- Vaqtni KLIENT belgilamaydi (qurilma soati noto'g'ri yoki to'qilgan
    -- bo'lishi mumkin) — server vaqti yoziladi.
    NEW.created_at := now();

    IF NEW.user_id IS NULL THEN
        SELECT count(*) INTO v_recent
          FROM public.client_error_logs
         WHERE user_id IS NULL
           AND created_at > now() - INTERVAL '1 minute';
        IF v_recent >= 60 THEN
            RAISE EXCEPTION 'client_error_logs: anon yozuv chegarasi (60/min) oshdi'
                USING ERRCODE = 'LX429';
        END IF;
    ELSE
        SELECT count(*) INTO v_recent
          FROM public.client_error_logs
         WHERE user_id = NEW.user_id
           AND created_at > now() - INTERVAL '1 minute';
        IF v_recent >= 20 THEN
            RAISE EXCEPTION 'client_error_logs: yozuv chegarasi (20/min) oshdi'
                USING ERRCODE = 'LX429';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_client_error_logs_sanitize ON public.client_error_logs;
CREATE TRIGGER trg_client_error_logs_sanitize
    BEFORE INSERT ON public.client_error_logs
    FOR EACH ROW EXECUTE FUNCTION public.client_error_logs_sanitize();

-- 4. RLS
ALTER TABLE public.client_error_logs ENABLE ROW LEVEL SECURITY;

-- Klient FAQAT o'z nomidan yozadi. `IS NOT DISTINCT FROM` — anon holatida
-- ikki tomon ham NULL bo'lgani uchun ruxsat beradi (login'gacha bo'lgan
-- crash'lar ham yig'iladi), lekin boshqa `user_id` ni QO'YIB BO'LMAYDI.
DROP POLICY IF EXISTS "client_error_logs_insert_self" ON public.client_error_logs;
CREATE POLICY "client_error_logs_insert_self"
    ON public.client_error_logs
    FOR INSERT TO anon, authenticated
    WITH CHECK (user_id IS NOT DISTINCT FROM auth.uid());

-- O'qish faqat xodimlarga. Klient uchun SELECT policy ATAYLAB YO'Q:
-- stack trace boshqa foydalanuvchining ma'lumotini oshkor qilishi mumkin.
DROP POLICY IF EXISTS "client_error_logs_select_staff" ON public.client_error_logs;
CREATE POLICY "client_error_logs_select_staff"
    ON public.client_error_logs
    FOR SELECT TO authenticated
    USING (public.is_admin_or_moderator());

-- UPDATE / DELETE policy YO'Q — yozuv o'zgartirilmaydi (audit izi).

GRANT INSERT ON public.client_error_logs TO anon, authenticated;
GRANT SELECT ON public.client_error_logs TO authenticated;

-- 5. SAQLASH MUDDATI
-- Internetga ochiq yozuv yuzasi cheksiz o'smasligi kerak. `pg_cron` mavjud
-- deb TAXMIN QILINMAYDI — tozalash admin tomonidan chaqiriladigan funksiya.
CREATE OR REPLACE FUNCTION public.purge_client_error_logs(p_days INTEGER DEFAULT 30)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    IF NOT public.is_privileged_db_role() AND NOT public.is_admin_or_moderator() THEN
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

REVOKE ALL ON FUNCTION public.purge_client_error_logs(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_client_error_logs(INTEGER) TO authenticated;

-- 6. O'Z-O'ZINI TEKSHIRISH (metadata darajasi)
--
-- Bu blok QO'LLASH PAYTIDA bajariladi: birorta invariant buzilgan bo'lsa
-- `RAISE` ishlaydi va BUTUN migratsiya rollback bo'ladi. Ya'ni "qo'llandi"
-- degan yozuv faqat quyidagilar HAQIQATAN bazada bo'lsa paydo bo'ladi.
DO $verify$
DECLARE
    v_rls BOOLEAN;
    v_insert_policy INTEGER;
    v_select_policy INTEGER;
    v_write_policy INTEGER;
    v_trigger INTEGER;
    v_definer BOOLEAN;
BEGIN
    SELECT relrowsecurity INTO v_rls
      FROM pg_class WHERE oid = 'public.client_error_logs'::regclass;
    IF v_rls IS NOT TRUE THEN
        RAISE EXCEPTION 'client_error_logs: RLS YOQILMAGAN';
    END IF;

    SELECT count(*) INTO v_insert_policy FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'client_error_logs'
       AND cmd = 'INSERT' AND with_check LIKE '%auth.uid()%';
    IF v_insert_policy < 1 THEN
        RAISE EXCEPTION 'client_error_logs: INSERT policy auth.uid() ga bog''lanmagan';
    END IF;

    SELECT count(*) INTO v_select_policy FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'client_error_logs'
       AND cmd = 'SELECT' AND qual LIKE '%is_admin_or_moderator%';
    IF v_select_policy < 1 THEN
        RAISE EXCEPTION 'client_error_logs: SELECT policy xodim tekshiruvisiz';
    END IF;

    -- UPDATE/DELETE/ALL policy paydo bo'lib qolmaganini QULFLAYDI.
    SELECT count(*) INTO v_write_policy FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'client_error_logs'
       AND cmd IN ('UPDATE', 'DELETE', 'ALL');
    IF v_write_policy > 0 THEN
        RAISE EXCEPTION 'client_error_logs: audit izini o''zgartiradigan policy topildi (%)', v_write_policy;
    END IF;

    SELECT count(*) INTO v_trigger FROM pg_trigger
     WHERE tgrelid = 'public.client_error_logs'::regclass
       AND tgname = 'trg_client_error_logs_sanitize'
       AND tgenabled <> 'D';
    IF v_trigger < 1 THEN
        RAISE EXCEPTION 'client_error_logs: sanitizatsiya trigger yo''q yoki o''chirilgan';
    END IF;

    SELECT prosecdef INTO v_definer FROM pg_proc
     WHERE oid = 'public.client_error_logs_sanitize()'::regprocedure;
    IF v_definer IS NOT TRUE THEN
        RAISE EXCEPTION 'client_error_logs_sanitize SECURITY DEFINER emas — '
            'tezlik chegarasi RLS tufayli JIM ishlamay qoladi';
    END IF;

    RAISE NOTICE 'client_error_logs: metadata invariantlari OK';
END
$verify$;

-- 7. HOLAT QAYDI (2026-08-30) — QO'LLANGAN VA RUNTIME TEKSHIRILGAN
--
-- (a) QO'LLANGAN. `supabase db push --include-all`:
--     Applying migration 20260830010000_client_error_logs.sql...
--     {"upToDate":false,"dryRun":false,
--      "migrations":["20260830010000_client_error_logs.sql"],
--      "message":"Finished supabase db push."}
--     6-bo'limdagi `DO` bloki qo'llash paytida bajarildi — u yiqilsa BUTUN
--     migratsiya rollback bo'lardi, ya'ni "qo'llandi" yozuvining o'zi
--     metadata invariantlari (RLS yoqilgan, INSERT policy `auth.uid()` ga
--     bog'langan, SELECT policy xodim tekshiruvi bilan, UPDATE/DELETE policy
--     YO'Q, trigger yoqilgan, sanitize `SECURITY DEFINER`) bazada
--     HAQIQATAN borligini isbotlaydi.
--
-- (b) ANON REST PROBE'lar (prod anon kalit, `curl`):
--     1. POST /rest/v1/client_error_logs (user_id YUBORILMADI,
--        message 2100+ belgi, created_at="2000-01-01T00:00:00Z")
--        -> HTTP 201. Ya'ni login'gacha bo'lgan crash ham yig'iladi.
--     2. GET  /rest/v1/client_error_logs?select=id,message  -> HTTP 200 []
--        QATOR MAVJUD BO'LGAN HOLATDA bo'sh — klient o'z yozuvini ham
--        o'qiy olmaydi (SELECT policy faqat admin/moderator uchun).
--     3. POST + "user_id":"00000000-...-0001" -> HTTP 401,
--        {"code":"42501","message":"new row violates row-level security
--        policy for table \"client_error_logs\""} — SOXTA MUALLIF RAD ETILDI.
--     4. PATCH ?kind=eq.verification_probe -> HTTP 204
--     5. DELETE ?kind=eq.verification_probe -> HTTP 204
--        204 O'ZI isbot EMAS (policy yo'q -> 0 qator mos keldi). Isbot (c) da.
--
-- (c) `postgres` huquqi bilan O'LCHOV (vaqtinchalik, ataylab yiqiladigan
--     `DO` bloki orqali; bazaga hech narsa qo'llanmadi, fayl o'chirildi):
--     LEXHUB_MEASUREMENT total=1 tampered=0 msg_len=2000 stack_len=51
--       user_id=NULL created_at=2026-08-29 19:22:22.560349+00
--       head=[LEXHUB VERIFICATION PROBE 2026-08-30 ano]
--     Bundan KELIB CHIQADI:
--       * total=1  -> (b.5) DELETE qatorni O'CHIRMADI.
--       * tampered=0 -> (b.4) PATCH matnni O'ZGARTIRMADI.
--       * msg_len=2000 -> 2100+ belgi SERVERDA kesildi (CHECK yiqilishi
--         emas, kesish — hisobot yo'qolmadi).
--       * created_at 2026-08-29 19:22 UTC -> klientning "2000-01-01" qiymati
--         RAD ETILDI, server vaqti yozildi.
--       * user_id=NULL -> anon yozuv (DEFAULT auth.uid()).
--
-- (d) QOLDIQ MA'LUMOT: `kind='verification_probe'` bo'lgan 1 (bitta) qator
--     bazada QOLDI — u ATAYLAB "LEXHUB VERIFICATION PROBE" deb belgilangan,
--     soxta foydalanuvchi/soxta crash EMAS, balki yuqoridagi o'lchovning
--     o'zi. Anon kalit uni o'chira olmaydi (DELETE policy yo'q — bu himoya
--     ishlayotganining isboti). 30 kundan keyin
--     `SELECT public.purge_client_error_logs(30);` (admin) uni tozalaydi.
--
-- (e) TEKSHIRILMAGAN (NOT VERIFIED): tezlik chegarasi (20/min, 60/min) real
--     yuklama bilan sinalmadi — 60+ so'rov yuborish prod bazaga ataylab
--     spam bo'lardi. Chegara mavjudligi (a) da metadata darajasida
--     isbotlangan, XULQI emas.
COMMIT;
