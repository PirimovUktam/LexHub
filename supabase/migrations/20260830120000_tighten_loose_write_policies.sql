-- =============================================================================
-- LEXHUB — BO'SH YOZISH POLICY'LARINI EGA DOIRASIGA TORAYTIRISH
-- Sana: 2026-08-30
-- Ishga tushirish: Supabase Dashboard -> SQL Editor -> BUTUN faylni RUN
--   yoki: supabase db query --linked -f <shu fayl>
-- =============================================================================
-- O'LCHANGAN NUQSON — JONLI BAZADAN (2026-08-30T16:18:36Z,
-- `supabase db query --linked`, to'liq isbot:
-- `.runtime_evidence/before_tighten_write_policies.out.json`):
--
--   questions / INSERT  "Autentifikatsiya qilganlar savol yaratadi"
--       WITH CHECK (auth.role() = 'authenticated')   <- EGA TEKSHIRUVI YO'Q
--   votes / ALL         "Ovozlar autentifikatsiya qilganlar uchun"
--       USING (auth.role() = 'authenticated'), with_check = NULL
--                                                    <- EGA TEKSHIRUVI YO'Q
--
-- TA'SIRI — uchtasi ham AUTENTIFIKATSIYA QILGAN har qanday foydalanuvchi
-- uchun ochiq (mehmon uchun emas):
--   1. IMPERSONATION: `questions` ga BOSHQA odamning `user_id` si bilan savol
--      kiritiladi. `is_anonymous` bilan birga bu tuhmat vositasi — savol
--      boshqa fuqaro nomidan yozilib, u hech qachon ko'rmasligi mumkin.
--   2. OVOZ BUZISH: `FOR ALL` da `with_check IS NULL` bo'lsa PostgreSQL
--      INSERT tekshiruvini `USING` dan oladi. Ya'ni istalgan foydalanuvchi
--      BOSHQANING `user_id` si bilan ovoz qo'shadi, tahrirlaydi va O'CHIRADI.
--   3. OVOZ MAXFIYLIGI: shu `FOR ALL` policy SELECT ni HAM qoplaydi va
--      egaga-xos "Users can view own votes" bilan RUXSAT sifatida OR
--      qilinadi -> har bir autentifikatsiya qilgan foydalanuvchi HAMMANING
--      ovozini o'qiydi.
--
-- YECHIM: AYNAN shu ikki policy EGA doirasiga toraytiriladi. Boshqa hech
-- narsa o'zgarmaydi — jadval, ustun, FK, qolgan policy'lar, qatorlar.
--
-- NIMA UCHUN `DROP` + `CREATE` (`20260830110000` dagi "FAQAT TO'LDIR,
-- ALMASHTIRMA" qoidasidan FARQLI): u fayl jonli predikatni KO'RMAGAN va
-- "jonlisi repo'dagidan QATTIQROQ bo'lishi mumkin" deb ehtiyot bo'lgan.
-- HOZIR predikat O'LCHANDI: jonlisi qattiqroq EMAS, BO'SHROQ. Shu sababli
-- almashtirish ZAIFLASHTIRISH emas, TORAYTIRISH.
--
-- MA'LUMOT YO'QOTISH XAVFI: YO'Q. Bironta qator o'qilmaydi, yozilmaydi,
-- o'chirilmaydi. Faqat policy ta'riflari o'zgaradi.
--
-- QAYTARISH AVTOMATIK EMAS (§: xavfli amal). Qaytarish yozuvi:
-- `.runtime_evidence/before_tighten_write_policies.out.json` -> `B_policy` ->
-- `qayta_tiklash_ddl` — har bir policy'ni AYNAN tiklaydigan `CREATE POLICY`
-- matni (avval yangi policy `DROP POLICY` bilan olib tashlanadi).
--
-- QO'LLASH PAYTIDA ISBOTLANADI:
--   P1  `questions`/`votes` jadvallari va `user_id` ustunlari BOR;
--   P2  `user_id IS NULL` qator YO'Q (bo'lsa toraytirish o'sha qatorlarni
--       EGASIZ qilardi -> to'xtatiladi, o'lchov bilan);
--   P3  o'zgartirishdan OLDINGI predikatlar o'lchanadi;
--   D1  ilova yo'llari qoplangan: savol INSERT, ovoz INSERT/DELETE/SELECT;
--   D2  bu jadvallarda CHEKLOVSIZ (`true`) yozish policy'si YO'Q;
--   D3  har bir yozish policy'si `auth.uid()` yoki admin tekshiruviga
--       tayanadi — AYNAN `20260830110000` ni to'sgan gate;
--   D4  ikki BO'SH policy nomi endi YO'Q, yangi ikkitasi `user_id` ga tayanadi.
--
-- BU FAYLNING MAVJUDLIGI DEPLOYMENT ISBOTI EMAS. Qo'llash va XULQ o'lchandi
-- (2026-08-30, `supabase db query --linked`):
--   * katalog holati: `.runtime_evidence/mig_120000_apply.out.json`
--     (`questions/INSERT` -> EGA, `votes/ALL` -> EGA, BO'SH nomlar YO'Q);
--   * HAQIQIY XULQ: `.runtime_evidence/rls_behavior_probe.out.json` —
--     `set_config('role','authenticated')` + haqiqiy JWT claim bilan 6
--     urinish: o'zining `user_id` si bilan savol/ovoz O'TDI; boshqaning
--     `user_id` si bilan IKKISI ham `42501` bilan RAD ETILDI; boshqaning
--     ovozi SELECT'da 0 qator; boshqaning ovozini DELETE 0 qator. Barcha
--     yozuvlar BITTA subtranzaksiyada bajarilib QAYTARILDI, qoldiq qator
--     YO'Q (`.runtime_evidence/probe_cleanliness.out.json`).
--
-- ILOVA (Flutter) DARAJASIDA ENDI O'LCHANDI — 2026-08-30, jonli production:
-- `test/integration/community_write_session_rls_live_test.dart` (gated,
-- IKKI haqiqiy sessiya A va B, yozish `CommunityForumDataSourceImpl` orqali):
--   EVIDENCE 1  `questions` INSERT (ega, ilova yo'li) O'TDI, `user_id` sessiya
--               egasiga TENG;
--   EVIDENCE 2  boshqaning `user_id` si bilan savol — `42501`;
--   EVIDENCE 3  `answers` INSERT (ega, ilova yo'li) O'TDI;
--   EVIDENCE 4  `votes` INSERT (ega) O'TDI;
--   EVIDENCE 5  boshqaning `user_id` si bilan ovoz — `42501`;
--   EVIDENCE 6  begonaning ovozi: SELECT 0 qator, DELETE 0 qator, qator
--               EGASIDA SAQLANDI;
--   TOZALASH    ega o'z savol/javob/ovozini O'CHIRDI (1/1/1+1) — qoldiq YO'Q.
-- Ya'ni SQL darajasidagi probe endi PostgREST + `supabase_flutter` zanjiri
-- bilan ham TASDIQLANDI. (Eslatma: `real_supabase_community_e2e_test.dart`
-- hamon sessiya OCHMAYDI — u faqat MEHMON rad etilishini o'lchaydi.)
--
-- SHU YUGURTIRISHDA TOPILGAN ALOHIDA NUQSON (bu migratsiyaga TEGISHLI EMAS,
-- lekin jim qoldirilmaydi): ilovaning ovoz berish yo'li `votePost` /
-- `voteAnswer` `votes` ga `answer_id` YUBORMAYDI, u esa NOT NULL va
-- DEFAULT'siz -> `23502`. EVIDENCE 7: `statusCode=23502 message=null value in
-- column "answer_id" of relation "votes" violates not-null constraint`.
-- Ya'ni ovoz berish RLS'ga YETIB BORMAYDI, undan OLDIN yiqiladi.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) OLDINGI HOLAT — o'lchanadi, taxmin qilinmaydi
-- -----------------------------------------------------------------------------
DO $pre$
DECLARE
    v_missing TEXT;
    v_orphan  TEXT;
    v_state   TEXT;
BEGIN
    SELECT string_agg(t || '.' || c, ', ' ORDER BY t || '.' || c) INTO v_missing
      FROM (VALUES ('questions', 'user_id'), ('votes', 'user_id')) AS v(t, c)
     WHERE to_regclass('public.' || t) IS NULL
        OR NOT EXISTS (
            SELECT 1 FROM pg_attribute
             WHERE attrelid = ('public.' || t)::regclass
               AND attname = c AND NOT attisdropped AND attnum > 0);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'P1 FAILED: jadval yoki ustun YO''Q: % — yangi policy '
            'predikati AYNAN shu ustunga tayanadi, sxema o''rganilishi kerak.',
            v_missing;
    END IF;

    -- P2: `user_id IS NULL` qator BO'LSA, `auth.uid() = user_id` predikati
    -- o'sha qatorlarni EGASIZ qiladi: egasi ham o'chira olmaydi, faqat
    -- `service_role` ko'radi. Bunday holatda TO'XTAYMIZ — qatorlar avval
    -- ko'rib chiqilishi kerak.
    SELECT string_agg(format('%s=%s', t, n), ', ' ORDER BY t) INTO v_orphan
      FROM (
        SELECT 'questions' AS t, count(*) AS n FROM public.questions
         WHERE user_id IS NULL
        UNION ALL
        SELECT 'votes', count(*) FROM public.votes WHERE user_id IS NULL
      ) s
     WHERE n > 0;
    IF v_orphan IS NOT NULL THEN
        RAISE EXCEPTION 'P2 FAILED: `user_id IS NULL` qator bor (%) — '
            'toraytirish ularni EGASIZ qilib qo''yardi.', v_orphan;
    END IF;

    SELECT string_agg(
               format('%s/%s:%s[qual=%s; check=%s]', tablename, cmd,
                      policyname, coalesce(qual, '-'),
                      coalesce(with_check, '-')),
               '  ' ORDER BY tablename, cmd, policyname)
      INTO v_state
      FROM pg_policies
     WHERE schemaname = 'public' AND tablename IN ('questions', 'votes')
       AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL');
    RAISE NOTICE 'P3 O''LCHOV (OLDIN): %', coalesce(v_state, '-');
END
$pre$;

-- -----------------------------------------------------------------------------
-- 2) TORAYTIRISH — BO'SH policy olib tashlanadi, EGAGA-XOS policy qo'yiladi
-- -----------------------------------------------------------------------------
-- NOM TANLOVI ATAYLAB: yangi policy nomlari `20260830110000` dagi nomlar bilan
-- AYNAN BIR XIL. Sabab — ikki xil muhitda BIR XIL natija:
--   * FAQAT migratsiyalardan qurilgan bazada `110000` bu nomlarni allaqachon
--     yaratgan bo'ladi (egaga-xos predikat bilan); shu fayl ularni tashlab
--     AYNAN o'sha ta'rifni qayta yaratadi -> holat o'zgarmaydi.
--   * jonli bazada `110000` qo'llanmagan; shu fayl BO'SH nomlarni tashlaydi
--     va egaga-xos policy'ni yaratadi.
-- Ya'ni ikki muhitda ham OXIRIDA bitta nom va bitta ta'rif qoladi. Nomni
-- boshqacha tanlash IKKI RUXSAT policy'sini yonma-yon qoldirardi (PERMISSIVE
-- policy'lar OR qilinadi, ya'ni huquq KENGAYARDI).
--
-- `TO authenticated` — jonli BO'SH policy'lar `TO public` edi. Bu ham
-- toraytirish: `anon` rolida `auth.uid()` NULL, ya'ni predikat allaqachon
-- FALSE berardi; roldan cheklash NIYATNI OSHKOR qiladi.
DROP POLICY IF EXISTS "Autentifikatsiya qilganlar savol yaratadi"
    ON public.questions;
DROP POLICY IF EXISTS "Authenticated users can create questions"
    ON public.questions;
CREATE POLICY "Authenticated users can create questions"
    ON public.questions FOR INSERT
    TO authenticated
    WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Ovozlar autentifikatsiya qilganlar uchun"
    ON public.votes;
DROP POLICY IF EXISTS "Users can manage their own votes"
    ON public.votes;
CREATE POLICY "Users can manage their own votes"
    ON public.votes FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 3) TORAYTIRISHDAN KEYINGI ISBOT (jim o'tish yo'q)
-- -----------------------------------------------------------------------------
DO $post$
DECLARE
    v_bad TEXT;
BEGIN
    -- D1: ILOVA yo'llari qoplanganmi (parity emas, FEATURE talabi).
    -- `questions` INSERT — savol yaratish; `votes` INSERT/DELETE — ovoz
    -- berish va qaytarish; `votes` SELECT — "men ovoz berdim" belgisi.
    SELECT string_agg(format('%s/%s', t, c), ', ' ORDER BY t, c) INTO v_bad
      FROM (VALUES ('questions', 'INSERT'), ('votes', 'INSERT'),
                   ('votes', 'DELETE'), ('votes', 'SELECT')) AS v(t, c)
     WHERE NOT EXISTS (
         SELECT 1 FROM pg_policies
          WHERE schemaname = 'public' AND tablename = t
            AND permissive = 'PERMISSIVE' AND cmd IN (c, 'ALL'));
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D1 FAILED: policy YO''Q: % — RLS yoqilgan jadvalda '
            'policy''siz buyruq DENY, ya''ni bu oqim `42501` bilan yiqiladi.',
            v_bad;
    END IF;

    -- D2: CHEKLOVSIZ (`true`) yozish policy'si YO'Q.
    SELECT string_agg(format('%s:%s(%s)', tablename, policyname, cmd), ', '
                      ORDER BY tablename, policyname) INTO v_bad
      FROM pg_policies
     WHERE schemaname = 'public' AND tablename IN ('questions', 'votes')
       AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
       AND permissive = 'PERMISSIVE'
       AND (btrim(lower(coalesce(qual, ''))) = 'true'
            OR btrim(lower(coalesce(with_check, ''))) = 'true');
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D2 FAILED: CHEKLOVSIZ yozish policy''si bor: %',
            v_bad;
    END IF;

    -- D3: AYNAN `20260830110000` ni to'sgan gate. U `questions`/`reports`/
    -- `votes` ni tekshirardi; bu yerda `reports` ATAYLAB yo'q — uning yozish
    -- policy'lari allaqachon `is_admin_or_moderator()` ga tayanadi (o'lchandi)
    -- va bu fayl unga TEGMAYDI.
    SELECT string_agg(format('%s:%s', tablename, policyname), ', '
                      ORDER BY tablename, policyname) INTO v_bad
      FROM pg_policies
     WHERE schemaname = 'public' AND tablename IN ('questions', 'votes')
       AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
       AND permissive = 'PERMISSIVE'
       AND coalesce(qual, '') || coalesce(with_check, '') NOT LIKE '%auth.uid()%'
       AND coalesce(qual, '') || coalesce(with_check, '') NOT LIKE '%is_admin%';
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D3 FAILED: `auth.uid()` ham, admin tekshiruvi ham '
            'YO''Q yozish policy''si: %', v_bad;
    END IF;

    -- D4: BO'SH nomlar YO'Q va yangi policy'lar `user_id` ga tayanadi.
    SELECT string_agg(format('%s:%s', tablename, policyname), ', '
                      ORDER BY tablename) INTO v_bad
      FROM pg_policies
     WHERE schemaname = 'public'
       AND policyname IN ('Autentifikatsiya qilganlar savol yaratadi',
                          'Ovozlar autentifikatsiya qilganlar uchun');
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D4 FAILED: BO''SH policy hamon bor: % — `DROP` '
            'ishlamagan (nom o''zgargan bo''lishi mumkin).', v_bad;
    END IF;

    SELECT string_agg(format('%s:%s', tablename, policyname), ', '
                      ORDER BY tablename) INTO v_bad
      FROM pg_policies
     WHERE schemaname = 'public'
       AND policyname IN ('Authenticated users can create questions',
                          'Users can manage their own votes')
       AND coalesce(qual, '') || coalesce(with_check, '')
           NOT LIKE '%auth.uid() = user_id%';
    IF v_bad IS NOT NULL THEN
        RAISE EXCEPTION 'D4 FAILED: yangi policy `auth.uid() = user_id` ga '
            'tayanmaydi: %', v_bad;
    END IF;

    RAISE NOTICE 'D1-D4 OK: questions INSERT va votes yozish/o''qish yo''li '
        'EGA doirasiga toraytirildi.';
END
$post$;

COMMIT;

-- =============================================================================
-- DEPLOY'DAN KEYIN KO'RINADIGAN DIAGNOSTIKA
--
-- Supabase SQL Editor `RAISE NOTICE` ni KO'RSATMAYDI (o'lchangan: 219545f) —
-- shu sababli natija COMMIT'dan keyin JADVAL bo'lib qaytariladi. Himoya bu
-- SELECT'ga TAYANMAYDI: D1-D4 buzilsa migratsiyaning O'ZI yiqiladi va COMMIT
-- umuman bo'lmaydi.
--
-- `reports` ATAYLAB ro'yxatda: bu fayl unga TEGMAYDI, lekin `20260830110000`
-- ning D3 gate'i UCHALASINI tekshiradi. Ya'ni pastdagi javobda `cheklov`
-- ustunida `BOSHQA` yoki `CHEKLOVSIZ` QOLMASA — `110000` ni to'sgan sabab
-- yo'qolgan bo'ladi (u fayl jonli bazaga ATAYLAB qo'llanmagan; sababi
-- `20260830100000` sarlavhasidagi qarorda).
--
-- Kutilgan javob: `questions/INSERT` -> EGA; `votes/ALL` -> EGA;
-- `reports/UPDATE`, `reports/DELETE` -> ADMIN. `reports/INSERT` qatori YO'Q
-- (policy yo'q = DENY) — bu KAMCHILIK EMAS: `lib/` da `reports` ga yozish
-- yo'li YO'Q (grep, 2026-08-30).
-- =============================================================================
SELECT tablename,
       cmd,
       policyname,
       roles::text AS rollar,
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
