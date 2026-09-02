-- NUQSON G — BAZA ADVOKATGA BAHO TO'QIB BERADI.
--
-- `expert_profiles.rating NUMERIC(3,2) DEFAULT 5.00 NOT NULL` — ya'ni har bir
-- yangi tug'ilgan advokat profili DARHOL "5.00" bahoga ega bo'ladi, hech kim
-- unga baho qo'ymagan holda. `reviews_count` esa 0 bo'lib qoladi.
--
-- BU TO'QIMA MA'LUMOT (§20 / "ilovaga soxta advokat yoki shunga o'xshash
-- yolg'onlar qo'shilmaydi" qoidasi):
--   * baho hisoblanadigan MANBA YO'Q — loyihada `reviews` / `expert_reviews`
--     jadvali umuman mavjud emas va `rating` ni YOZADIGAN birorta kod yo'q
--     (`SET rating` / `rating =` bo'yicha nol moslik). Ya'ni 5.00 "eski
--     haqiqiy baho" emas, u HECH QACHON haqiqiy bo'lmagan;
--   * `protect_expert_profile_sensitive_fields()` bu ustunni "Ratings are
--     computed automatically from verified reviews" degan izoh bilan
--     qo'riqlaydi — lekin HISOBLAYDIGAN narsaning o'zi yo'q. Qulf mavjud
--     bo'lmagan tizimni himoya qilyapti;
--   * qiymat tashqariga CHIQADI: `expert_directory` ko'rinishi va
--     `unified_global_search` RPC `ep.rating` ni JSON'da uzatadi.
--
-- NIMA UCHUN HOZIRGACHA EKRANDA KO'RINMADI: klient qatlami allaqachon
-- to'g'rilangan — `ExpertRatingStars` `reviewsCount <= 0` bo'lsa UMUMAN
-- chizilmaydi, `LegalExpertModel` esa 5.0 zaxirasini tashlab yubordi. Ya'ni
-- bu TUZOQ: bazadagi yolg'on joyida turgan, uni ko'rsatadigan bitta yangi
-- iste'molchi yetarli edi. Qulf UI'da emas, MANBADA bo'lishi kerak (§14).
--
-- YECHIM: baho MAJBURIY emas, BO'SH bo'lishi mumkin bo'ladi va u faqat
-- haqiqiy baho bo'lganda mavjud bo'ladi:
--   1. `DROP NOT NULL` + `SET DEFAULT NULL` — yangi profil BAHOSIZ tug'iladi;
--   2. `reviews_count = 0` bo'lgan qatorlardagi baho NULL ga o'tadi (bu
--      qiymat ISBOTLANGAN to'qima: baho manbasi yo'q);
--   3. `CHECK ((rating IS NULL) = (reviews_count = 0))` — invariantni BAZA
--      qulflaydi: baho FAQAT baho soni bilan birga paydo bo'ladi. Kelajakda
--      `reviews` jadvali qo'shilsa ikkisi BIR TRANZAKSIYADA yangilanadi.
--
-- MA'LUMOT YO'QOTISH XAVFI: yo'q. NULL ga o'tadigan yagona qiymat —
-- `reviews_count = 0` bo'lgan qatordagi baho, ya'ni manbasi bo'lmagan son.
-- `reviews_count > 0` bo'lgan qator (agar paydo bo'lsa) TEGILMAYDI.
--
-- QO'LLASH PAYTIDA ISBOTLANADI:
--   P1  ustun sukut qiymati HAQIQATAN son (`5.00`) — ifoda HISOBLANIB
--       tekshiriladi, chunki `DEFAULT NULL` ham katalogda ifoda bo'lib turadi;
--   P2  baho manbasi YO'Q — `reviews`/`expert_reviews` jadvali mavjud emas;
--   P3  o'zgartirishdan oldingi holat o'lchanadi (qator sonlari);
--   D1  sukut qiymat endi SON EMAS (hisoblanganda NULL);
--   D2  ustun NULL qabul qiladi;
--   D3  `reviews_count = 0` bo'lgan bahoga ega qator QOLMADI;
--   D4  CHECK cheklovi mavjud;
--   D5  cheklov to'qimani HAQIQATAN rad etadi (SAVEPOINT ichida o'lchanadi,
--       qator bo'lmasa HALOL ravishda "o'lchanmadi" deb yozadi).
--
-- Birorta shart bajarilmasa `RAISE` ishlaydi va BUTUN migratsiya rollback
-- bo'ladi.

BEGIN;

-- 1. NUQSONNI O'LCHASH (o'zgartirishdan OLDIN)
DO $pre$
DECLARE
    v_default TEXT;
    v_value NUMERIC;
    v_fabricated INTEGER;
    v_real INTEGER;
BEGIN
    SELECT pg_get_expr(d.adbin, d.adrelid) INTO v_default
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
     WHERE a.attrelid = 'public.expert_profiles'::regclass
       AND a.attname = 'rating';

    -- DIQQAT: sukut qiymat MAVJUDLIGI o'z-o'zidan nuqson emas —
    -- `SET DEFAULT NULL` ham katalogda `NULL::numeric` ifodasi bo'lib turadi.
    -- Shuning uchun ifoda HISOBLANADI: nuqson = sukut qiymat HAQIQIY SON.
    IF v_default IS NULL THEN
        RAISE EXCEPTION 'P1 FAILED: `rating` sukut qiymati allaqachon YO''Q — '
            'bu migratsiya asoslanmagan, holatni qayta o''rgan.';
    END IF;
    EXECUTE format('SELECT (%s)::numeric', v_default) INTO v_value;
    IF v_value IS NULL THEN
        RAISE EXCEPTION 'P1 FAILED: sukut qiymat (%) allaqachon NULL beradi — '
            'to''qima baho yo''q, migratsiya asoslanmagan.', v_default;
    END IF;
    RAISE NOTICE 'P1 OK: sukut qiymat = % → % (to''qima baho manbasi)',
        v_default, v_value;

    -- P2: BAHO HISOBLANADIGAN JADVAL YO'Qligini ISBOTLASH. Agar kelajakda u
    -- paydo bo'lgan bo'lsa, "to'qima" degan da'vom YOLG'ON bo'ladi va
    -- migratsiya TO'XTAYDI.
    IF to_regclass('public.reviews') IS NOT NULL
       OR to_regclass('public.expert_reviews') IS NOT NULL THEN
        RAISE EXCEPTION 'P2 FAILED: baho jadvali MAVJUD — 5.00 to''qima deb '
            'hisoblash asossiz, migratsiyani qayta o''yla.';
    END IF;
    RAISE NOTICE 'P2 OK: baho manbasi jadvali YO''Q';

    SELECT count(*) INTO v_fabricated FROM public.expert_profiles
     WHERE reviews_count = 0 AND rating IS NOT NULL;
    SELECT count(*) INTO v_real FROM public.expert_profiles
     WHERE reviews_count > 0;
    RAISE NOTICE 'P3 O''LCHOV: to''qima bahoga ega qator = %, haqiqiy bahosi '
        'bo''lishi mumkin qator = % (TEGILMAYDI)', v_fabricated, v_real;
END
$pre$;

-- 2. TUZATISH
ALTER TABLE public.expert_profiles
    ALTER COLUMN rating DROP NOT NULL,
    ALTER COLUMN rating SET DEFAULT NULL;

-- Bu UPDATE `trg_protect_expert_profile_sensitive_fields` gvardidan o'tadi:
-- u `SECURITY INVOKER` va `is_privileged_db_role()` ga qaraydi, migratsiya
-- sessiyasida `current_user` = 'postgres' (O'LCHANGAN: `supabase db push`
-- "Initialising login role..." dan keyin `SET ROLE postgres` qiladi).
-- Ya'ni gvard klient uchun KUCHDA QOLADI, faqat egasi o'zgartiradi.
UPDATE public.expert_profiles
   SET rating = NULL
 WHERE reviews_count = 0 AND rating IS NOT NULL;

ALTER TABLE public.expert_profiles
    ADD CONSTRAINT expert_profiles_rating_requires_reviews
    CHECK ((rating IS NULL) = (reviews_count = 0));

COMMENT ON COLUMN public.expert_profiles.rating IS
    'Advokat bahosi. NULL = BAHO YO''Q (to''qima qiymat YOZILMAYDI). '
    '`expert_profiles_rating_requires_reviews` cheklovi bo''yicha faqat '
    'reviews_count > 0 bo''lganda to''ldiriladi.';

-- 3. TUZATISHDAN KEYINGI ISBOT
DO $post$
DECLARE
    v_default TEXT;
    v_value NUMERIC;
    v_notnull BOOLEAN;
    v_left INTEGER;
    v_has_check BOOLEAN;
    v_sample UUID;
    v_blocked BOOLEAN := FALSE;
    v_code TEXT;
BEGIN
    SELECT pg_get_expr(d.adbin, d.adrelid), a.attnotnull
      INTO v_default, v_notnull
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
     WHERE a.attrelid = 'public.expert_profiles'::regclass
       AND a.attname = 'rating';

    -- D1: sukut qiymat SON QAYTARMASLIGI kerak. `SET DEFAULT NULL` katalogda
    -- `NULL::numeric` bo'lib qoladi — shuning uchun ifoda HISOBLANADI (mavjud
    -- yoki yo'qligi emas, NATIJASI muhim).
    IF v_default IS NOT NULL THEN
        EXECUTE format('SELECT (%s)::numeric', v_default) INTO v_value;
        IF v_value IS NOT NULL THEN
            RAISE EXCEPTION 'D1 FAILED: sukut qiymat hamon SON: % (= %)',
                v_default, v_value;
        END IF;
    END IF;
    IF v_notnull THEN
        RAISE EXCEPTION 'D2 FAILED: ustun hamon NOT NULL — baho MAJBURIY '
            'bo''lib qolgan, ya''ni to''qima qiymat qaytadi';
    END IF;

    SELECT count(*) INTO v_left FROM public.expert_profiles
     WHERE reviews_count = 0 AND rating IS NOT NULL;
    IF v_left > 0 THEN
        RAISE EXCEPTION 'D3 FAILED: manbasiz bahoga ega % qator qoldi', v_left;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conrelid = 'public.expert_profiles'::regclass
           AND conname = 'expert_profiles_rating_requires_reviews'
    ) INTO v_has_check;
    IF NOT v_has_check THEN
        RAISE EXCEPTION 'D4 FAILED: invariant cheklovi qo''yilmadi';
    END IF;

    -- D5: cheklov HAQIQATAN to'qimani rad etadimi. YANGI QATOR YARATILMAYDI
    -- (soxta advokat yozish TAQIQLANGAN) — mavjud qator SAVEPOINT ichida
    -- sinovdan o'tadi va o'zgarish QAYTARILADI.
    SELECT id INTO v_sample FROM public.expert_profiles
     WHERE reviews_count = 0 LIMIT 1;
    IF v_sample IS NULL THEN
        RAISE NOTICE 'D5 O''LCHANMADI: `reviews_count = 0` bo''lgan qator YO''Q '
            '(jadval bo''sh) — cheklov mantiqi faqat D4 bilan isbotlangan';
    ELSE
        BEGIN
            UPDATE public.expert_profiles SET rating = 5.00 WHERE id = v_sample;
            RAISE EXCEPTION 'D5 FAILED: baho soni 0 bo''lgan qatorga 5.00 baho '
                'YOZILDI — cheklov ishlamayapti'
                USING ERRCODE = 'LX999';
        EXCEPTION
            WHEN check_violation THEN
                v_blocked := TRUE;
                v_code := SQLSTATE;
        END;
        IF NOT v_blocked THEN
            RAISE EXCEPTION 'D5 FAILED: cheklov to''qima bahoni to''smadi';
        END IF;
        RAISE NOTICE 'D5 OK: to''qima baho rad etildi (SQLSTATE %)', v_code;
    END IF;

    RAISE NOTICE 'D1-D4 OK: baho endi BO''SH tug''iladi va faqat haqiqiy baho '
        'soni bilan birga paydo bo''ladi';
END
$post$;

COMMIT;
