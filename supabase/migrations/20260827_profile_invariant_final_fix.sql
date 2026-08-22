-- ==============================================================================
-- MIGRATION: 20260827_profile_invariant_final_fix.sql
-- LexHub — AUTH PROFILE INVARIANT FINAL FIX
-- ==============================================================================
-- ROOT CAUSE (live Supabase'da tasdiqlangan, 2026-08-22):
--   public.profiles.phone : TEXT, is_nullable = NO, column_default = NULL
--   auth.users            : 10/10 foydalanuvchida phone = NULL
--                           (email/parol signup telefon raqam bermaydi)
--   public.handle_new_user() -> INSERT INTO public.profiles (..., phone, ...)
--                               VALUES (..., NEW.phone, ...)   -- NULL
--     => 23502  null value in column "phone" violates not-null constraint
--     => EXCEPTION WHEN OTHERS -> zaxira INSERT `phone`ni umuman yubormaydi,
--        lekin ustunda DEFAULT ham yo'q  => yana NULL  => yana 23502
--     => EXCEPTION WHEN OTHERS THEN NULL -> ikkinchi xato ham yutildi
--     => RETURN NEW -> signup "muvaffaqiyatli", profil qatori esa YO'Q
--     => keyin questions.user_id -> profiles.id FK 23503 bilan yiqildi.
--
-- SCHEMA DRIFT: repo'da `phone VARCHAR(32)` NULLABLE
--   (20260819_base_schema.sql:72,83). Live'dagi `TEXT NOT NULL` repo
--   migration'lari orqali KELMAGAN. Bu migration ikki muhitni ham bir xil
--   (NULLABLE) holatga keltiradi.
--
-- FAYL NOMI (20260827) TASODIFIY EMAS: repo migration prefikslari kalendardan
--   oldinda (eng kattasi 20260826_*), `supabase db push/reset` esa leksikografik
--   tartibda ishlatadi. Kichik prefiks bilan nomlansa, eski 20260826_* fayllar
--   xatoni yutuvchi handle_new_user()ni QAYTA o'rnatib qo'yadi.
--
-- IDEMPOTENT: bir necha marta ishga tushirish xavfsiz.
-- OLDINGI MIGRATION FAYLLARI O'ZGARTIRILMADI (faqat CREATE OR REPLACE bilan
--   ustidan yangi ta'rif beriladi).
-- ==============================================================================

BEGIN;

-- ─── 0. PRECONDITION ─────────────────────────────────────────────────────────
DO $$
BEGIN
    IF to_regclass('public.profiles') IS NULL THEN
        RAISE EXCEPTION 'public.profiles topilmadi — avval 20260819_base_schema.sql.';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'user_role' AND n.nspname = 'public'
    ) THEN
        RAISE EXCEPTION 'public.user_role enum topilmadi — avval base schema.';
    END IF;
END $$;

-- `phone` ustuni yo'q muhitda (toza `supabase db reset`) handle_new_user()
-- 42703 beradi. Idempotent qo'shiladi — live'da NO-OP.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;


-- ─── 1. FIX #1: profiles.phone NULL qabul qiladi ─────────────────────────────
-- DEFAULT ATAYLAB QO'SHILMAYDI (talab §1).
-- Mavjud data O'ZGARMAYDI: `DROP NOT NULL` faqat katalogdagi attnotnull
-- flagini o'chiradi — jadval qayta yozilmaydi, hech bir qiymat tegilmaydi.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_attribute
        WHERE attrelid = 'public.profiles'::regclass
          AND attname = 'phone'
          AND attnum > 0 AND NOT attisdropped
          AND attnotnull
    ) THEN
        ALTER TABLE public.profiles ALTER COLUMN phone DROP NOT NULL;
        RAISE NOTICE 'FIX #1: profiles.phone NOT NULL olib tashlandi (root cause).';
    ELSE
        RAISE NOTICE 'FIX #1: profiles.phone allaqachon NULLABLE — no-op.';
    END IF;
END $$;

-- ─── 2. FIX #2: handle_new_user() — production-safe, XATONI YUTMAYDI ─────────
-- O'zgarishlar:
--   * NEW.phone NULL bo'lishi VALID holat (FIX #1 dan keyin).
--   * `full_name` VARCHAR(128) NOT NULL — bo'sh/uzun qiymatlar oldindan
--     normallashtiriladi (22001 va 23502 sinfi yopiladi).
--   * `role` HARDCODED 'citizen' — client `raw_user_meta_data`sidan OLINMAYDI
--     (signUp payload'ida `role` bo'lsa ham e'tiborsiz qoldiriladi).
--   * `reputation_points = 10` -> CHECK (>= 0) buzilmaydi.
--   * ON CONFLICT (id) SAQLANDI, lekin role/is_verified/reputation_points
--     ATAYLAB yangilanmaydi: mavjud profil huquqlari signup orqali qayta
--     yozilmasligi kerak.
--   * SILENT FALLBACK OLIB TASHLANDI. Xato Postgres log'iga WARNING sifatida
--     yoziladi va AYNAN o'sha SQLSTATE bilan qayta ko'tariladi (`RAISE;`) —
--     profil yaratilmasa signup ham muvaffaqiyatli bo'lmaydi.
--   * SECURITY DEFINER + SET search_path saqlandi (search_path'dan `auth`
--     olib tashlandi: funksiya faqat NEW.* va public.* ga tegadi).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_full_name  text;
    v_avatar_url text;
BEGIN
    v_full_name  := NULLIF(btrim(COALESCE(NEW.raw_user_meta_data->>'full_name', '')), '');
    v_full_name  := left(COALESCE(v_full_name, 'Foydalanuvchi'), 128);
    v_avatar_url := NULLIF(btrim(COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')), '');

    INSERT INTO public.profiles (
        id, full_name, avatar_url, phone, role, reputation_points, is_verified
    )
    VALUES (
        NEW.id,
        v_full_name,
        v_avatar_url,
        NEW.phone,                      -- NULL = VALID
        'citizen'::public.user_role,    -- client metadata'dan OLINMAYDI
        10,
        FALSE
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name  = COALESCE(EXCLUDED.full_name,  profiles.full_name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        phone      = COALESCE(EXCLUDED.phone,      profiles.phone),
        updated_at = now();

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user FAILED: user_id=% sqlstate=% message=%',
                  NEW.id, SQLSTATE, SQLERRM;
    RAISE;  -- asl xato, asl SQLSTATE bilan
END;
$function$;

-- Trigger qayta ulanadi (nomi o'zgarmaydi — dublikat yaratilmaydi).
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Dublikat trigger diagnostikasi: `handle_new_user()`ni chaqiradigan boshqa
-- nomli trigger qolgan bo'lsa, u ham har INSERT'da ishlaydi. ON CONFLICT
-- borligi uchun bu buzmaydi, lekin bilib turish kerak.
DO $$
DECLARE
    v_names text;
    v_count int;
BEGIN
    SELECT count(*), string_agg(t.tgname, ', ' ORDER BY t.tgname)
      INTO v_count, v_names
    FROM pg_trigger t
    JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE t.tgrelid = 'auth.users'::regclass
      AND NOT t.tgisinternal
      AND p.proname = 'handle_new_user';

    IF v_count > 1 THEN
        RAISE WARNING 'auth.users: handle_new_user() % ta trigger bilan ulangan: %',
                      v_count, v_names;
    ELSE
        RAISE NOTICE 'FIX #2: auth.users triggeri OK (%).', COALESCE(v_names, 'yo''q');
    END IF;
END $$;

-- ─── 3. FIX #3: `auth.users.id = profiles.id` invarianti ─────────────────────
-- (a) profiles.id -> auth.users(id) FK. Bu bir tomonni DB darajasida
--     majburlaydi: auth user'siz profil MUMKIN EMAS.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND contype = 'f'
          AND confrelid = 'auth.users'::regclass
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_id_fkey
            FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
        RAISE NOTICE 'FIX #3a: profiles.id -> auth.users(id) FK qo''shildi.';
    ELSE
        RAISE NOTICE 'FIX #3a: profiles.id -> auth.users(id) FK allaqachon bor.';
    END IF;
END $$;

-- (b) BACKFILL — teskari tomon: profili YO'Q mavjud foydalanuvchilar.
--     Buni FK bilan majburlash mumkin emas (auth.users -> profiles FK
--     aylanma bog'lanish bo'lardi va `auth` sxemasiga tegishga majbur qilardi),
--     shuning uchun: (1) mavjud yetishmovchilik shu yerda to'ldiriladi,
--     (2) kelgusida FIX #2 (RAISE) yangi yetishmovchilikka yo'l bermaydi.
--
--     BU MIGRATION'DAGI YAGONA DATA YOZUVI.
--     Faqat YETISHMAYDIGAN qatorlar qo'shiladi (LEFT JOIN ... IS NULL +
--     ON CONFLICT DO NOTHING) — mavjud profillar TEGILMAYDI.
--     `role` har doim 'citizen': backfill hech kimga imtiyoz bermaydi.
INSERT INTO public.profiles (
    id, full_name, avatar_url, phone, role, reputation_points, is_verified, created_at
)
SELECT
    u.id,
    left(COALESCE(
        NULLIF(btrim(COALESCE(u.raw_user_meta_data->>'full_name', '')), ''),
        'Foydalanuvchi'), 128),
    NULLIF(btrim(COALESCE(u.raw_user_meta_data->>'avatar_url', '')), ''),
    u.phone,
    'citizen'::public.user_role,
    10,
    FALSE,
    COALESCE(u.created_at, now())
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ─── 4. FIX #4: client role='admin' bera OLMAYDI ─────────────────────────────
-- Imtiyozli DB rollarini aniqlash uchun yagona joy.
-- MUHIM: bu funksiya SECURITY INVOKER — chaqiruvchining haqiqiy roli
-- ko'rinishi kerak. SECURITY DEFINER bo'lsa `current_user` DOIM funksiya
-- egasi bo'lib qoladi va tekshiruv ma'nosini yo'qotadi.
CREATE OR REPLACE FUNCTION public.is_privileged_db_role()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
    SELECT current_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin', 'service_role')
        OR session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin');
$function$;

-- SECURITY INVOKER trigger guard'lari chaqiruvchi rol nomidan ishlaydi,
-- shuning uchun EXECUTE huquqi ochiq bo'lishi kerak (bu PostgreSQL'ning
-- standart holati — aniq yozib qo'yildi, "permission denied for function"
-- xatosi profil tahrirlashni buzmasligi uchun).
GRANT EXECUTE ON FUNCTION public.is_privileged_db_role() TO PUBLIC;

-- (a) Client'dan profil yaratish yo'li YOPILADI.
--     Eski policy: FOR INSERT WITH CHECK (auth.uid() = id) — `role` va
--     `is_verified` uchun HECH QANDAY cheklov yo'q edi (P0 escalation yuzasi:
--     profili yo'q har qanday authenticated user o'ziga role='admin' bilan
--     profil INSERT qila olardi). RLS'da INSERT policy bo'lmasa INSERT
--     taqiqlanadi, profil yaratish esa faqat SECURITY DEFINER
--     handle_new_user() orqali qoladi (u jadval egasi nomidan ishlaydi va
--     RLS'ga tushmaydi).
--     Client kodida `from('profiles').insert/upsert` YO'Q — bu test bilan
--     qo'riqlanadi (question_category_resolver_test.dart).
--     Policy nomi live'da boshqacha bo'lishi mumkin, shuning uchun nom bo'yicha
--     emas, `cmd = 'INSERT'` bo'yicha hammasi olib tashlanadi.
DO $$
DECLARE
    v_policy text;
BEGIN
    FOR v_policy IN
        SELECT policyname FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'INSERT'
    LOOP
        EXECUTE format('DROP POLICY %I ON public.profiles', v_policy);
        RAISE NOTICE 'FIX #4a: INSERT policy olib tashlandi: %', v_policy;
    END LOOP;

    -- `FOR ALL` policy ham INSERT huquqini beradi — o'chirilmaydi (SELECT/UPDATE
    -- ni buzishi mumkin), lekin ochiq ogohlantiriladi.
    FOR v_policy IN
        SELECT policyname FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'ALL'
    LOOP
        RAISE WARNING 'DIQQAT: "%" policy FOR ALL — u INSERT huquqini ham beradi.', v_policy;
    END LOOP;
END $$;

-- Grant qatlami: RLS policy holatidan qat'i nazar, client rollari uchun
-- `profiles` ga INSERT huquqi olib tashlanadi. SECURITY DEFINER
-- handle_new_user() jadval egasi nomidan ishlaganligi uchun bunga tegmaydi.
DO $$
DECLARE
    v_role text;
BEGIN
    FOR v_role IN SELECT * FROM unnest(ARRAY['anon', 'authenticated']::text[]) LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role) THEN
            EXECUTE format('REVOKE INSERT ON TABLE public.profiles FROM %I', v_role);
            RAISE NOTICE 'FIX #4a: % rolidan profiles INSERT grant olib tashlandi.', v_role;
        END IF;
    END LOOP;
END $$;

-- (b) Defense-in-depth: agar kelajakda INSERT policy qayta qo'shilsa ham,
--     imtiyozli ustunlarni client O'ZI bera olmasin.
--     ALOHIDA funksiya, chunki INSERT triggerida `OLD` tayinlanmagan —
--     mavjud UPDATE guard'ining OLD'ga tayanadigan mantig'ini INSERT'ga
--     ulash 55000 (`record "old" is not assigned yet`) xatosini beradi.
CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
BEGIN
    IF NOT public.is_privileged_db_role() THEN
        IF NEW.role IS DISTINCT FROM 'citizen'::public.user_role THEN
            RAISE EXCEPTION
                'Privilege Escalation Blocked: role=% cannot be self-assigned on INSERT.',
                NEW.role;
        END IF;
        IF COALESCE(NEW.is_verified, FALSE) THEN
            RAISE EXCEPTION
                'Verification Escalation Blocked: is_verified cannot be self-assigned on INSERT.';
        END IF;
        IF COALESCE(NEW.reputation_points, 0) > 10 THEN
            RAISE EXCEPTION
                'Reputation Tampering Blocked: reputation_points=% on INSERT.',
                NEW.reputation_points;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_protect_profile_privileged_columns_on_insert ON public.profiles;
CREATE TRIGGER trg_protect_profile_privileged_columns_on_insert
BEFORE INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privileged_columns_on_insert();

GRANT EXECUTE ON FUNCTION public.protect_profile_privileged_columns_on_insert() TO PUBLIC;

-- (c) UPDATE yo'li: mavjud anti-tampering guard AMALDA ISHLAMAGAN.
--     20260826_fix_profile_anti_tampering_and_auth_trigger.sql:21-48 dagi
--     funksiya SECURITY DEFINER, shuning uchun uning ichida `current_user`
--     DOIM funksiya egasi ('postgres') bo'ladi. Shart esa
--     `current_user NOT IN ('service_role','postgres',...)` — ya'ni HAR DOIM
--     FALSE, va butun tekshiruv bloki HAR QANDAY chaqiruvchi uchun
--     tashlab ketilgan. Natijada `FOR UPDATE USING (auth.uid() = id)` policy
--     bilan birgalikda: foydalanuvchi O'Z profilida `role='admin'` qilib
--     qo'yishi mumkin bo'lgan (P0).
--     Yechim: SECURITY INVOKER + is_privileged_db_role(). Funksiya faqat
--     NEW/OLD bilan ishlaydi, elevated huquq talab qilmaydi.
--     Client `toUpdatePayload()` faqat full_name/avatar_url/phone/bio/
--     updated_at yuboradi (user_profile_model.dart:59-67), shuning uchun
--     qonuniy profil tahrirlash bloklanmaydi.
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $function$
BEGIN
    IF TG_OP = 'UPDATE' AND NOT public.is_privileged_db_role() THEN
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Privilege Escalation Blocked: Role can only be modified by system administrators.';
        END IF;
        IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
            RAISE EXCEPTION 'Verification Escalation Blocked: Verification status can only be granted by administrators.';
        END IF;
        IF NEW.reputation_points IS DISTINCT FROM OLD.reputation_points THEN
            RAISE EXCEPTION 'Reputation Points Tampering Blocked.';
        END IF;
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Profile ID is immutable.';
        END IF;
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            NEW.created_at := OLD.created_at;
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_sensitive_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_sensitive_fields();

GRANT EXECUTE ON FUNCTION public.protect_profile_sensitive_fields() TO PUBLIC;

-- ─── 5. REGRESSION DETECTOR + YAKUNIY TEKSHIRUV ──────────────────────────────
-- Bu bug'ning BUTUN SINFI: `profiles` ichida NOT NULL bo'lgan, DEFAULT'i
-- YO'Q va handle_new_user() yubormaydigan ustun bo'lsa — signup yana
-- 23502 bilan yiqiladi. Shu holat aniqlansa ochiq WARNING beriladi.
DO $$
DECLARE
    v_col     text;
    v_bad     int := 0;
    v_orphans int;
    v_profiles int;
    v_users    int;
BEGIN
    FOR v_col IN
        SELECT a.attname
        FROM pg_attribute a
        WHERE a.attrelid = 'public.profiles'::regclass
          AND a.attnum > 0 AND NOT a.attisdropped
          AND a.attnotnull
          AND a.attgenerated = ''
          AND NOT EXISTS (
              SELECT 1 FROM pg_attrdef d
              WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum
          )
          AND a.attname <> ALL (ARRAY[
              'id', 'full_name', 'avatar_url', 'phone',
              'role', 'reputation_points', 'is_verified'
          ])
        ORDER BY a.attnum
    LOOP
        v_bad := v_bad + 1;
        RAISE WARNING 'SCHEMA DRIFT: profiles.% NOT NULL, DEFAULT yo''q va handle_new_user() uni yubormaydi — signup 23502 beradi.', v_col;
    END LOOP;

    SELECT count(*) INTO v_users    FROM auth.users;
    SELECT count(*) INTO v_profiles FROM public.profiles;
    SELECT count(*) INTO v_orphans
    FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id
    WHERE p.id IS NULL;

    RAISE NOTICE 'YAKUN: auth.users=%, profiles=%, profili yo''q=%, drift ustun=%',
                 v_users, v_profiles, v_orphans, v_bad;

    IF v_orphans > 0 THEN
        RAISE EXCEPTION 'INVARIANT BUZILGAN: % foydalanuvchida hamon profil yo''q — migration qabul qilinmadi.', v_orphans;
    END IF;
END $$;

COMMIT;

