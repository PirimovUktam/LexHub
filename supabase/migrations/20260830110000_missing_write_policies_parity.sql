-- =============================================================================
-- LEXHUB — `supabase/migrations/` DA YETISHMAGAN YOZISH POLICY'LARI
-- Sana: 2026-08-30
-- Ishga tushirish: Supabase Dashboard -> SQL Editor -> BUTUN faylni RUN
-- =============================================================================
-- O'LCHANGAN NUQSON (2026-08-30, FAQAT REPO MATNIDAN — jonli bazadan EMAS):
--
--   jadval     migrations              schema.sql                   YETMAYDI
--   questions  DELETE,SELECT           DELETE,INSERT,SELECT,UPDATE  INSERT,UPDATE
--   reports    DELETE,SELECT,UPDATE    DELETE,INSERT,SELECT,UPDATE  INSERT
--   votes      SELECT                  ALL,SELECT                   ALL
--
--   (`bookmarks` ham farq qiladi, lekin u ATAYLAB torroq:
--    `20260830100000_rls_never_enabled_tables.sql` egaga SELECT/INSERT/DELETE
--    beradi, `UPDATE` esa policy'SIZ = DENY. Bu KAMCHILIK EMAS.)
--
-- NIMA UCHUN MUHIM: jonli bazaga qo'llanadigan ishonchli to'plam —
-- `supabase/migrations/` (buni `supabase/schema.sql:20-23` o'zi aytadi).
-- FAQAT migratsiyalardan qurilgan bazada `questions` da RLS YOQILGAN
-- (`20260828_mvp_blockers_p0_07_p1_05_p1_06.sql:256`), INSERT policy esa
-- YO'Q — PostgreSQL savol yaratishni `42501` bilan RAD ETADI. Ya'ni community
-- savol yaratish oqimi butunlay to'xtaydi.
--
-- JONLI HOLAT — O'LCHANDI (2026-08-30T17:31:33Z, `supabase db query --linked`,
-- to'liq isbot: `.runtime_evidence/write_policies_parity_facts.out.json`).
-- Bu fayl jonli bazaga HALI QO'LLANMAGAN, va o'lchov nima uchun ekanini
-- ko'rsatadi:
--
--   jadval/buyruq        jonli policy                              holat
--   questions/INSERT     "Authenticated users can create questions" BOR (EGA)
--   questions/DELETE     "owner_can_delete_own_question"            BOR (EGA)
--   questions/UPDATE     —                                          YO'Q
--   reports/UPDATE       "Moderators and Admins can update reports" BOR (ADMIN)
--   reports/DELETE       "Admins can delete reports"                BOR (ADMIN)
--   reports/INSERT       —                                          YO'Q
--   votes/ALL            "Users can manage their own votes"         BOR (EGA)
--
--   RLS uchtasida ham YOQILGAN; CHEKLOVSIZ (`true`) yozish policy'si YO'Q.
--
-- YA'NI: yuqoridagi "savol yaratish butunlay to'xtaydi" ehtimoli JONLI BAZADA
-- RO'Y BERMAGAN — `questions` INSERT policy'si BOR va u sessiyali jonli test
-- bilan XULQ darajasida ham isbotlangan
-- (`test/integration/community_write_session_rls_live_test.dart`, EVIDENCE 1).
-- Bu faylning QOLGAN NETTO ta'siri — FAQAT ikki policy: `questions/UPDATE`
-- (ega tahriri) va `reports/INSERT` (shikoyat yuborish). Ikkisi ham HOZIR
-- ILOVADA ISHLATILMAYDI: `lib/` da `db('reports')` YO'Q, `updateQuestion` /
-- `editQuestion` yo'li YO'Q (o'lchandi: 2026-08-30, `grep` repo bo'ylab).
-- Demak bu migratsiya BUZILGAN oqimni tiklamaydi — u KELAJAK feature'lari
-- uchun parity bo'shlig'ini yopadi. Shoshilinch EMAS, lekin qo'llanmasa
-- "shikoyat" feature'i yozilgan kunda `42501` bilan yiqiladi.
--
-- ESKI QAYD (endi noto'g'ri emas, lekin TO'LIQ EMAS): pastdagi "jonli isbot"
-- sifatida `real_supabase_community_e2e_test.dart` ko'rsatilgan — u sessiya
-- OCHMAYDI, ya'ni yozish policy'sini o'lchamaydi. Sessiyali isbot:
--   flutter test test/integration/community_write_session_rls_live_test.dart \
--     --dart-define-from-file=env/prod.json \
--     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
--
-- "FAQAT TO'LDIR, ALMASHTIRMA" QOIDASI — repo'ning odatiy
-- `DROP POLICY IF EXISTS` + `CREATE POLICY` uslubi bu yerda ATAYLAB
-- ishlatilmadi. Sabab: jonli policy'ning predikati repo'dagidan QATTIQROQ
-- bo'lishi mumkin (`schema.sql` production'dan farq qilishi HUJJATLASHTIRILGAN),
-- va uni repo nusxasiga almashtirish XAVFSIZLIKNI ZAIFLASHTIRARDI. Shuning
-- uchun: shu `cmd` uchun policy ALLAQACHON bo'lsa — TEGILMAYDI. Idempotentlik
-- shu shartning o'zidan keladi, `DROP` kerak emas.
--
-- PREDIKATLAR `supabase/schema.sql` dan AYNAN ko'chirildi — yangi qoida
-- O'YLAB TOPILMADI: `:891-892` (questions INSERT), `:895-896` (questions
-- UPDATE), `:1037-1038` (votes ALL), `:1056-1057` (reports INSERT).
--
-- XUSUSIYATLARI: idempotent; transaction-safe; schema (jadval/ustun/FK)
-- O'ZGARMAYDI; DROP/DELETE/TRUNCATE YO'Q; huquq faqat EGA doirasida beriladi.
--
-- QO'LLASH PAYTIDA ISBOTLANADI:
--   P1  uchta jadval BOR;
--   P2  `questions.user_id`, `reports.reporter_id`, `votes.user_id` BOR;
--   P3  o'zgartirishdan OLDINGI yozish qoplamasi o'lchanadi;
--   D1  kerakli buyruqlar (savol INSERT/UPDATE, shikoyat INSERT, ovoz
--       INSERT/DELETE) policy bilan QOPLANDI;
--   D2  bu jadvallarda CHEKLOVSIZ (`true`) yozish policy'si YO'Q;
--   D3  har bir yozish policy'si `auth.uid()` yoki admin tekshiruviga tayanadi.
--
-- BU FAYLNING MAVJUDLIGI DEPLOYMENT ISBOTI EMAS. Jonli isbot — sessiyali
-- (authenticated) yozish testi:
--   flutter test test/integration/real_supabase_community_e2e_test.dart \
--     --dart-define-from-file=env/prod.json \
--     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) OLDINGI HOLAT — o'lchanadi, taxmin qilinmaydi
-- -----------------------------------------------------------------------------
DO $pre$
DECLARE
    v_missing_tbl TEXT;
    v_missing_col TEXT;
    v_state       TEXT;
BEGIN
    SELECT string_agg(x, ', ' ORDER BY x) INTO v_missing_tbl
      FROM unnest(ARRAY['questions', 'reports', 'votes']) AS x
     WHERE to_regclass('public.' || x) IS NULL;
    IF v_missing_tbl IS NOT NULL THEN
        RAISE EXCEPTION 'P1 FAILED: jadval YO''Q: % — bu migratsiya bu bazaga '
            'mos kelmaydi, jim o''tib ketmaslik uchun to''xtatildi.',
            v_missing_tbl;
    END IF;

    SELECT string_agg(t || '.' || c, ', ' ORDER BY t || '.' || c)
      INTO v_missing_col
      FROM (VALUES ('questions', 'user_id'), ('reports', 'reporter_id'),
                   ('votes', 'user_id')) AS v(t, c)
     WHERE NOT EXISTS (
         SELECT 1 FROM pg_attribute
          WHERE attrelid = ('public.' || t)::regclass
            AND attname = c AND NOT attisdropped AND attnum > 0);
    IF v_missing_col IS NOT NULL THEN
        RAISE EXCEPTION 'P2 FAILED: ustun YO''Q: % — policy predikati AYNAN '
            'shu ustunga tayanadi, sxema o''rganilishi kerak.', v_missing_col;
    END IF;

    SELECT string_agg(format('%s=[%s]', t, coalesce(cmds, '-')), '  ' ORDER BY t)
      INTO v_state
      FROM (SELECT x AS t,
                   (SELECT string_agg(DISTINCT cmd, ',' ORDER BY cmd)
                      FROM pg_policies
                     WHERE schemaname = 'public' AND tablename = x
                       AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')) AS cmds
              FROM unnest(ARRAY['questions', 'reports', 'votes']) AS x) s;
    RAISE NOTICE 'P3 O''LCHOV (OLDIN) yozish policy''lari: %', v_state;
END
$pre$;

-- -----------------------------------------------------------------------------
-- 2) FAQAT YETISHMAGANI TO'LDIRILADI — mavjud policy TEGILMAYDI
-- -----------------------------------------------------------------------------
-- `blockers` — shu buyruq uchun "allaqachon qoplangan" deb hisoblanadigan
-- `cmd` lar. `ALL` policy INSERT/UPDATE/DELETE ni HAM boshqaradi, shuning
-- uchun u ham to'suvchi sifatida sanaladi.
DO $fill$
DECLARE
    v_row     record;
    v_created TEXT[] := '{}';
    v_kept    TEXT[] := '{}';
BEGIN
    FOR v_row IN
        SELECT * FROM (VALUES
            ('questions', 'INSERT', ARRAY['INSERT', 'ALL'],
             $ddl$CREATE POLICY "Authenticated users can create questions"
                  ON public.questions FOR INSERT
                  WITH CHECK (auth.role() = 'authenticated'
                              AND auth.uid() = user_id)$ddl$),
            ('questions', 'UPDATE', ARRAY['UPDATE', 'ALL'],
             $ddl$CREATE POLICY "Owners can update their questions"
                  ON public.questions FOR UPDATE
                  USING (auth.uid() = user_id)
                  WITH CHECK (auth.uid() = user_id)$ddl$),
            ('reports', 'INSERT', ARRAY['INSERT', 'ALL'],
             $ddl$CREATE POLICY "Users can report content"
                  ON public.reports FOR INSERT
                  WITH CHECK (auth.role() = 'authenticated'
                              AND auth.uid() = reporter_id)$ddl$),
            ('votes', 'YOZISH', ARRAY['INSERT', 'UPDATE', 'DELETE', 'ALL'],
             $ddl$CREATE POLICY "Users can manage their own votes"
                  ON public.votes FOR ALL
                  USING (auth.uid() = user_id)
                  WITH CHECK (auth.uid() = user_id)$ddl$)
        ) AS x(tbl, label, blockers, ddl)
    LOOP
        IF EXISTS (SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public' AND tablename = v_row.tbl
                      AND permissive = 'PERMISSIVE'
                      AND cmd = ANY (v_row.blockers)) THEN
            v_kept := v_kept || format('%s/%s', v_row.tbl, v_row.label);
        ELSE
            EXECUTE v_row.ddl;
            v_created := v_created || format('%s/%s', v_row.tbl, v_row.label);
        END IF;
    END LOOP;

    RAISE NOTICE 'YARATILDI: %',
        coalesce(nullif(array_to_string(v_created, ', '), ''), '-');
    RAISE NOTICE 'TEGILMADI (allaqachon bor): %',
        coalesce(nullif(array_to_string(v_kept, ', '), ''), '-');
END
$fill$;

-- -----------------------------------------------------------------------------
-- 3) TUZATISHDAN KEYINGI ISBOT (§20: jim o'tish yo'q)
-- -----------------------------------------------------------------------------
DO $post$
DECLARE
    v_bad TEXT;
BEGIN
    -- D1: FEATURE darajasidagi talab — parity emas, ILOVA yo'li qoplanganmi.
    SELECT string_agg(format('%s/%s', t, c), ', ' ORDER BY t, c) INTO v_bad
      FROM (VALUES ('questions', 'INSERT'), ('questions', 'UPDATE'),
                   ('reports', 'INSERT'), ('votes', 'INSERT'),
                   ('votes', 'DELETE')) AS v(t, c)
     WHERE NOT EXISTS (
         SELECT 1 FROM pg_policies
          WHERE schemaname = 'public' AND tablename = t
            AND permissive = 'PERMISSIVE' AND cmd IN (c, 'ALL'));
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D1 FAILED: yozish policy hamon YO''Q: % — RLS '
            'yoqilgan jadvalda policy''siz buyruq DENY, ya''ni bu oqim '
            '`42501` bilan yiqiladi.', v_bad;
    END IF;

    -- D2: cheklovsiz yozish policy'si YO'Q. Bu migratsiya bunday policy
    -- YARATMAYDI — demak topilsa, u ILGARIDAN bor va QO'LDA tekshirilishi
    -- shart (P0). Tranzaksiya qaytariladi, bironta qator o'zgarmaydi.
    SELECT string_agg(format('%s:%s(%s)', tablename, policyname, cmd), ', '
                      ORDER BY tablename, policyname) INTO v_bad
      FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename IN ('questions', 'reports', 'votes')
       AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
       AND permissive = 'PERMISSIVE'
       AND (btrim(lower(coalesce(qual, ''))) = 'true'
            OR btrim(lower(coalesce(with_check, ''))) = 'true');
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D2 FAILED: CHEKLOVSIZ yozish policy''si bor: % — '
            'bu fayl bunday policy yaratmaydi, ya''ni u ILGARIDAN mavjud.',
            v_bad;
    END IF;

    -- D3: har bir yozish policy'si EGA yoki ADMIN tekshiruviga tayanadi.
    SELECT string_agg(format('%s:%s', tablename, policyname), ', '
                      ORDER BY tablename, policyname) INTO v_bad
      FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename IN ('questions', 'reports', 'votes')
       AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
       AND permissive = 'PERMISSIVE'
       AND coalesce(qual, '') || coalesce(with_check, '') NOT LIKE '%auth.uid()%'
       AND coalesce(qual, '') || coalesce(with_check, '') NOT LIKE '%is_admin%';
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D3 FAILED: `auth.uid()` ham, admin tekshiruvi ham '
            'YO''Q yozish policy''si: %', v_bad;
    END IF;

    RAISE NOTICE 'D1-D3 OK: questions/reports/votes yozish yo''li EGA '
        'doirasida qoplangan.';
END
$post$;

COMMIT;

-- =============================================================================
-- DEPLOY'DAN KEYIN KO'RINADIGAN DIAGNOSTIKA
--
-- Supabase SQL Editor `RAISE NOTICE` ni KO'RSATMAYDI (o'lchangan: 219545f) —
-- shu sababli natija COMMIT'dan keyin JADVAL bo'lib qaytariladi. Himoya bu
-- SELECT'ga TAYANMAYDI: D1-D3 buzilsa migratsiyaning O'ZI yiqiladi va COMMIT
-- umuman bo'lmaydi.
--
-- Kutilgan javob: `questions` -> INSERT va UPDATE qatorlari bor; `reports` ->
-- INSERT bor; `votes` -> ALL bor. `cheklov` ustunida `EGA` yoki `ADMIN`
-- turishi shart; `CHEKLOVSIZ` chiqsa — bu P0 va qo'lda tekshirilishi kerak.
-- =============================================================================
SELECT tablename,
       cmd,
       policyname,
       CASE
           WHEN btrim(lower(coalesce(qual, ''))) = 'true'
             OR btrim(lower(coalesce(with_check, ''))) = 'true' THEN 'CHEKLOVSIZ'
           WHEN coalesce(qual, '') || coalesce(with_check, '')
                LIKE '%auth.uid()%' THEN 'EGA'
           WHEN coalesce(qual, '') || coalesce(with_check, '')
                LIKE '%is_admin%' THEN 'ADMIN'
           ELSE 'BOSHQA'
       END AS cheklov
  FROM pg_policies
 WHERE schemaname = 'public'
   AND tablename IN ('questions', 'reports', 'votes')
   AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
 ORDER BY tablename, cmd, policyname;
