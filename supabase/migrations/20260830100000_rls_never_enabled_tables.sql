-- NUQSON — MIGRATSIYALARDA TO'RT JADVALGA RLS HECH QACHON YOQILMAGAN.
--
-- O'LCHANGAN HOLAT (2026-08-30, MIGRATSIYA FAYLLARIDAN — jonli baza ALOHIDA
-- o'lchandi, pastdagi "JONLI HOLAT ENDI O'LCHANDI" bo'limiga qara):
--   * Barcha migratsiyalar bo'ylab `ENABLE ROW LEVEL SECURITY` 21 marta
--     uchraydi, lekin quyidagi 4 jadval uchun BIRON MARTA ham yo'q:
--       public.bookmarks             (`20260819_base_schema.sql:317`)
--       public.question_categories   (`20260819_base_schema.sql:124`)
--       public.question_tags         (`20260819_base_schema.sql:134`)
--       public.question_tag_mappings (`20260819_base_schema.sql:195`)
--   * Bu 4 jadval uchun `CREATE POLICY` ham migratsiyalarda YO'Q.
--
-- KEYINROQ O'LCHANDI — `supabase/schema.sql` BOSHQACHA GAPIRADI (2026-08-30):
--   * `schema.sql:822-833` TO'RTTASIDA HAM RLS ni YOQADI;
--   * `bookmarks` uchun egaga-xos policy BOR: `schema.sql:1042-1043`
--     `FOR ALL USING (auth.uid() = user_id) WITH CHECK (...)`;
--   * `question_categories` uchun `FOR SELECT USING (true)` BOR (`:866`);
--   * `question_tags` va `question_tag_mappings` uchun POLICY YO'Q — ya'ni
--     `schema.sql` qo'llangan bazada bu ikki jadval DENY-ALL bo'ladi va
--     ochiq ma'lumotnoma O'QILMAY qoladi (o'lchandi: schema.sql da RLS 19
--     jadvalga yoqiladi, shu ikkitasida policy yo'q).
--
-- JONLI HOLAT ENDI O'LCHANDI — IKKI SHOX HAM XATO CHIQDI (2026-08-30,
-- `supabase db query --linked`; isbot:
-- `.runtime_evidence/before_rls_state.out.json`):
--   jadval                  rls_yoqilgan  policy_soni  cmdlar  qatorlar
--   bookmarks               true          0            -       0
--   question_categories     true          0            -       5
--   question_tags           true          0            -       0
--   question_tag_mappings   true          0            -       0
-- Ya'ni jonli bazada RLS ALLAQACHON YOQILGAN, POLICY esa BITTA HAM YO'Q.
-- PostgreSQL bunday jadvalni `anon`/`authenticated` uchun DENY-ALL qiladi
-- (PostgREST xato bermaydi — HTTP 200 va BO'SH massiv qaytaradi). Shu sababli
-- yuqoridagi (A) shox ("TO'LIQ OCHIQ") ham, (B) shox ("bookmarks yopiq,
-- ma'lumotnoma DENY-ALL") ham jonli holatni TO'G'RI TASVIRLAMAYDI: to'rttasi
-- ham yopiq. `schema.sql` ning o'zi jonli bazaga mos kelmasligini
-- hujjatlashtirgan (`schema.sql:7-23`) — o'lchov aynan shuni ko'rsatdi.
--
-- QAROR: PRODUCTION'GA QO'LLANMADI (2026-08-30). SABABLARI:
--   1. Bu fayl DENY-ALL holatni BO'SHASHTIRADI: uchta ma'lumotnomaga
--      `FOR SELECT USING (true)` (mehmon uchun O'QISH ochiladi) va
--      `bookmarks` ga egaga-xos CRUD beradi.
--   2. Bitta ham O'LCHANGAN jonli muammoni yechmaydi: `lib/` bu to'rt
--      jadvalning BIRONTASIGA tegmaydi (grep, 2026-08-30). Kategoriya o'qish
--      yo'li `public.categories` orqali ketadi
--      (`question_category_resolver.dart`, `kCategoriesTable`), va 2026-08-22
--      da `GET /rest/v1/question_categories?select=*` jonli bazada `[]`
--      qaytargani o'lchangan — ya'ni "ochiq ma'lumotnoma o'qilmay qoldi"
--      degan regressiya feature darajasida HOZIR ham yo'q.
--   3. Ya'ni foyda NOL, huquq kengayishi esa REAL. Qaytarish uchun qo'lda
--      `DROP POLICY` kerak bo'lardi.
--
-- FAYL NIMA UCHUN O'CHIRILMADI: (a) FAQAT `supabase/migrations/` dan qurilgan
-- bazada RLS bu to'rt jadvalda hech qachon yoqilmaydi (fayl boshidagi o'lchov)
-- — u yerda bu fayl HAQIQIY himoya beradi; (b) uning kontrakti
-- `test/core/security/rls_enabled_for_all_tables_test.dart` (B guruh) da
-- qulflangan. Fayl REPO uchun kerak, JONLI baza uchun kerak emas. Agar
-- kelajakda `bookmarks` yoki `question_categories` ILOVADA ishlatilsa —
-- o'shanda qo'llanadi va D1-D4 gate'lari isbot beradi.

--   * Supabase `public` sxemasida `anon` va `authenticated` rollariga sukut
--     bo'yicha to'liq huquq beradi (`ALTER DEFAULT PRIVILEGES`). Ya'ni RLS
--     yoqilmagan jadval — TO'LIQ OCHIQ: har qanday mehmon o'qiydi, YOZADI
--     va O'CHIRADI. Grant'lar jonli bazada o'lchanmagan (NOT VERIFIED),
--     lekin repo'da bu rollardan huquq QAYTARIB OLINGAN joy ham yo'q
--     (yagona `REVOKE ... FROM anon` — `profiles`, `20260829120000`).
--
-- TA'SIR IKKI XIL, shuning uchun yechim ham ikki xil:
--   1. `bookmarks` — SHAXSIY ma'lumot (`user_id NOT NULL`, saqlangan
--      element sarlavhasi). Kimning qanday huquqiy muammosi borligini
--      oshkor qiladi. Yechim: EGASIGA-XOS policy.
--      DIQQAT: `lib/` ichida `bookmarks` HECH QAYERDA ishlatilmaydi
--      (grep, 2026-08-30) — ya'ni hozir jadval bo'sh bo'lishi mumkin va
--      o'g'irlanadigan qator yo'q. Bu himoyani KEYINGA qoldirish uchun
--      sabab EMAS: jadval bo'shligi tekshirilmagan, va yozish huquqi
--      allaqachon ochiq (istalgan mehmon qator kiritadi).
--   2. `question_categories` / `question_tags` / `question_tag_mappings` —
--      OCHIQ ma'lumotnoma. O'qish MUAMMO EMAS, YOZISH muammo: mehmon
--      kategoriyani o'zgartirsa yoki o'chirsa, `questions.category_id` va
--      `citizen_services.category_id` FK'lari `ON DELETE SET NULL` bilan
--      HAQIQIY savollarning kategoriyasini NULL qiladi
--      (`20260819_base_schema.sql:162`, `20260822...sql:23`). Yechim:
--      o'qish OCHIQ qoladi (`USING (true)`), yozish — admin/moderator.
--
-- MA'LUMOT YO'QOTISH XAVFI: YO'Q. Birorta qator o'qilmaydi, yozilmaydi,
-- o'chirilmaydi. Faqat policy va `relrowsecurity` o'zgaradi.
--
-- REGRESSIYA XAVFI VA UNI YOPISH: RLS yoqilib POLICY berilmasa jadval
-- DENY-ALL bo'ladi va ochiq ma'lumotnoma o'qilmay qoladi. Shu sababli D2/D3
-- gate'lari har bir jadvalda kamida bitta policy borligini VA ma'lumotnoma
-- jadvallarida `USING (true)` SELECT policy'si borligini isbotlaydi.
--
-- QO'LLASH PAYTIDA ISBOTLANADI:
--   P1  `public.is_admin_or_moderator()` funksiyasi BOR (policy shunga
--       tayanadi; yo'q bo'lsa yozish himoyasi yaratilmaydi);
--   P2  `bookmarks.user_id` ustuni BOR (egasiga-xos policy shunga tayanadi);
--   P3  o'zgartirishdan OLDINGI holat o'lchanadi (qaysi jadvalda RLS yoq);
--   D1  4 jadvalda ham `relrowsecurity = true`;
--   D2  har bir jadvalda kamida bitta policy bor (DENY-ALL emas);
--   D3  ma'lumotnoma jadvallarida `USING (true)` SELECT policy bor (o'qish
--       O'ZGARMADI);
--   D4  `bookmarks` da `USING (true)` policy YO'Q (ya'ni haqiqatan yopiq).
--
-- BU FAYLNING MAVJUDLIGI DEPLOYMENT ISBOTI EMAS. Jonli isbot:
-- `test/integration/private_tables_anon_isolation_live_test.dart`
-- (anon kalit bilan `bookmarks` dan NOL qator ko'rinishini o'lchaydi).

BEGIN;

-- 1. NUQSONNI O'LCHASH (o'zgartirishdan OLDIN)
DO $pre$
DECLARE
    v_tables TEXT[] := ARRAY['bookmarks', 'question_categories',
                             'question_tags', 'question_tag_mappings'];
    v_open TEXT;
    v_nopolicy TEXT;
BEGIN
    IF to_regprocedure('public.is_admin_or_moderator()') IS NULL THEN
        RAISE EXCEPTION 'P1 FAILED: `public.is_admin_or_moderator()` YO''Q — '
            'ma''lumotnoma jadvallarining YOZISH himoyasi shunga tayanadi. '
            'Funksiya `20260820_p0_security_remediation.sql` da yaratiladi.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_attribute
         WHERE attrelid = 'public.bookmarks'::regclass
           AND attname = 'user_id' AND NOT attisdropped
    ) THEN
        RAISE EXCEPTION 'P2 FAILED: `bookmarks.user_id` YO''Q — egasiga-xos '
            'policy yaratib bo''lmaydi, sxema o''rganilishi kerak.';
    END IF;

    SELECT string_agg(x, ', ' ORDER BY x) INTO v_open
      FROM unnest(v_tables) AS x
     WHERE NOT (SELECT relrowsecurity
                  FROM pg_class WHERE oid = ('public.' || x)::regclass);

    SELECT string_agg(x, ', ' ORDER BY x) INTO v_nopolicy
      FROM unnest(v_tables) AS x
     WHERE NOT EXISTS (SELECT 1 FROM pg_policies
                        WHERE schemaname = 'public' AND tablename = x);

    RAISE NOTICE 'P3 O''LCHOV: RLS O''CHIQ = [%], POLICY YO''Q = [%]',
        coalesce(v_open, '-'), coalesce(v_nopolicy, '-');
END
$pre$;

-- 2. SHAXSIY JADVAL — FAQAT EGASI
--
-- `UPDATE` uchun policy ATAYLAB berilmadi: xatcho'p yaratiladi va
-- o'chiriladi, tahrirlanmaydi (`UNIQUE (user_id, item_type, item_id)`).
-- Policy'siz `UPDATE` — DENY, ya'ni eng kam huquq.
--
-- DIQQAT: agar bazada `schema.sql:1042` dagi egaga-xos `FOR ALL` policy
-- ALLAQACHON bo'lsa, u bu fayl bilan O'CHIRILMAYDI (faqat quyidagi uchta NOM
-- almashtiriladi) — u holda EGA `UPDATE` ham qila oladi. Bu XAVFSIZLIK
-- muammosi emas (predikat baribir `auth.uid() = user_id`), lekin "UPDATE =
-- DENY" da'vosi faqat shu policy YO'Q bazada to'g'ri. Jonli holat — NOT
-- VERIFIED (§0).
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own bookmarks" ON public.bookmarks;
CREATE POLICY "Users can view own bookmarks" ON public.bookmarks
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own bookmarks" ON public.bookmarks;
CREATE POLICY "Users can create own bookmarks" ON public.bookmarks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own bookmarks" ON public.bookmarks;
CREATE POLICY "Users can delete own bookmarks" ON public.bookmarks
    FOR DELETE USING (auth.uid() = user_id);

-- 3. OCHIQ MA'LUMOTNOMALAR — O'QISH HAMMAGA, YOZISH ADMIN/MODERATORGA
--
-- `USING (true)` SELECT policy'si ataylab: bu jadvallar RLS'siz ham
-- o'qilardi, ya'ni O'QISH XULQI O'ZGARMAYDI (D3 shuni isbotlaydi).
-- O'zgaradigan narsa faqat YOZISH: ilgari mehmon kategoriyani o'chirib
-- haqiqiy savollarning `category_id` sini NULL qila olardi.
ALTER TABLE public.question_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Categories are readable by everyone"
    ON public.question_categories;
CREATE POLICY "Categories are readable by everyone"
    ON public.question_categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage categories"
    ON public.question_categories;
CREATE POLICY "Admins can manage categories"
    ON public.question_categories FOR ALL
    USING (public.is_admin_or_moderator())
    WITH CHECK (public.is_admin_or_moderator());

ALTER TABLE public.question_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tags are readable by everyone" ON public.question_tags;
CREATE POLICY "Tags are readable by everyone"
    ON public.question_tags FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage tags" ON public.question_tags;
CREATE POLICY "Admins can manage tags"
    ON public.question_tags FOR ALL
    USING (public.is_admin_or_moderator())
    WITH CHECK (public.is_admin_or_moderator());

ALTER TABLE public.question_tag_mappings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tag mappings are readable by everyone"
    ON public.question_tag_mappings;
CREATE POLICY "Tag mappings are readable by everyone"
    ON public.question_tag_mappings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage tag mappings"
    ON public.question_tag_mappings;
CREATE POLICY "Admins can manage tag mappings"
    ON public.question_tag_mappings FOR ALL
    USING (public.is_admin_or_moderator())
    WITH CHECK (public.is_admin_or_moderator());

-- 4. TUZATISHDAN KEYINGI ISBOT
DO $post$
DECLARE
    v_all TEXT[] := ARRAY['bookmarks', 'question_categories',
                          'question_tags', 'question_tag_mappings'];
    v_ref TEXT[] := ARRAY['question_categories', 'question_tags',
                          'question_tag_mappings'];
    v_bad TEXT;
BEGIN
    SELECT string_agg(x, ', ' ORDER BY x) INTO v_bad
      FROM unnest(v_all) AS x
     WHERE NOT (SELECT relrowsecurity
                  FROM pg_class WHERE oid = ('public.' || x)::regclass);
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D1 FAILED: RLS hamon o''chiq: %', v_bad;
    END IF;

    -- RLS yoqilib policy berilmasa jadval DENY-ALL bo'ladi va OCHIQ
    -- ma'lumotnoma o'qilmay qoladi — ya'ni himoya nomidan feature buziladi.
    SELECT string_agg(x, ', ' ORDER BY x) INTO v_bad
      FROM unnest(v_all) AS x
     WHERE NOT EXISTS (SELECT 1 FROM pg_policies
                        WHERE schemaname = 'public' AND tablename = x);
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D2 FAILED: RLS yoqilgan, POLICY yo''q (DENY-ALL): %',
            v_bad;
    END IF;

    SELECT string_agg(x, ', ' ORDER BY x) INTO v_bad
      FROM unnest(v_ref) AS x
     WHERE NOT EXISTS (
         SELECT 1 FROM pg_policies
          WHERE schemaname = 'public' AND tablename = x
            AND cmd = 'SELECT' AND btrim(lower(qual)) = 'true');
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D3 FAILED: ochiq ma''lumotnomaning o''qish xulqi '
            'O''ZGARDI (cheklovsiz SELECT policy yo''q): %', v_bad;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_policies
                WHERE schemaname = 'public' AND tablename = 'bookmarks'
                  AND btrim(lower(coalesce(qual, 'true'))) = 'true') THEN
        RAISE EXCEPTION 'D4 FAILED: `bookmarks` da cheklovsiz policy bor — '
            'shaxsiy xatcho''plar hamon ochiq.';
    END IF;

    RAISE NOTICE 'D1-D4 OK: 4 jadvalda RLS yoqildi, ochiq ma''lumotnoma '
        'o''qilishi saqlandi, `bookmarks` egasiga yopildi';
END
$post$;

-- 5. SXEMADA QOLADIGAN IZOH (keyingi o'quvchi uchun)
COMMENT ON TABLE public.bookmarks IS
    'SHAXSIY. RLS: faqat EGASI (auth.uid() = user_id) SELECT/INSERT/DELETE '
    'qiladi. Bu migratsiya tahrirlash uchun policy BERMAYDI. Agar '
    'schema.sql''dagi egaga-xos ALL policy bazada bo''lsa, ega tahrirlay '
    'oladi. 2026-08-30 ga qadar migratsiyalarda bu jadvalda RLS HECH QACHON '
    'yoqilmagan edi (20260830100000_rls_never_enabled_tables.sql).';

COMMENT ON TABLE public.question_categories IS
    'OCHIQ ma''lumotnoma. O''qish hammaga (USING (true)), YOZISH faqat '
    'admin/moderator. Sabab: FK ON DELETE SET NULL tufayli o''chirilgan '
    'kategoriya HAQIQIY savollarning category_id sini NULL qiladi.';

COMMENT ON TABLE public.question_tags IS
    'OCHIQ ma''lumotnoma. O''qish hammaga, yozish admin/moderator '
    '(20260830100000_rls_never_enabled_tables.sql).';

COMMENT ON TABLE public.question_tag_mappings IS
    'OCHIQ ma''lumotnoma (savol <-> teg). O''qish hammaga, yozish '
    'admin/moderator (20260830100000_rls_never_enabled_tables.sql).';

COMMIT;

-- 6. INSON KO'ZI BILAN O'QILADIGAN DIAGNOSTIKA (COMMIT'DAN KEYIN)
--
-- Supabase SQL Editor `RAISE NOTICE` ni KO'RSATMAYDI (o'lchangan: 219545f).
-- Himoya shu SELECT'ga TAYANMAYDI — D1-D4 buzilsa migratsiyaning O'ZI
-- yiqiladi. Bu faqat natijani KO'RISH uchun jadval. Kutilgan javob: 4 qator,
-- `rls_yoqilgan = true`, `bookmarks` -> 3 policy (DELETE,INSERT,SELECT),
-- qolgan uchtasi -> 2 policy (ALL,SELECT).
SELECT t.tablename,
       c.relrowsecurity AS rls_yoqilgan,
       count(p.policyname) AS policy_soni,
       coalesce(string_agg(DISTINCT p.cmd, ',' ORDER BY p.cmd), '-') AS cmdlar
  FROM (VALUES ('bookmarks'), ('question_categories'),
               ('question_tags'), ('question_tag_mappings')) AS t(tablename)
  JOIN pg_class c ON c.oid = ('public.' || t.tablename)::regclass
  LEFT JOIN pg_policies p
         ON p.schemaname = 'public' AND p.tablename = t.tablename
 GROUP BY t.tablename, c.relrowsecurity
 ORDER BY t.tablename;


