-- =============================================================================
-- LEXHUB — FINAL MVP BLOCKER CLOSURE (P0-07, P1-05, P1-06)
-- Sana: 2026-08-23
-- Ishga tushirish: Supabase Dashboard -> SQL Editor -> butun faylni RUN
-- =============================================================================
-- XUSUSIYATLARI:
--   * IDEMPOTENT — bir necha marta ishga tushirilsa ham natija bir xil;
--   * TRANSACTION-SAFE — hammasi bitta BEGIN/COMMIT ichida, xato bo'lsa
--     hech narsa qo'llanmaydi;
--   * DESTRUCTIVE OPERATSIYA YO'Q — birorta DROP TABLE, DROP COLUMN yoki
--     DELETE FROM yo'q. Faqat GRANT/REVOKE, bitta funksiya tanasi va
--     ikkita yangi RLS policy.
--   * Schema (jadval/ustun/enum/FK) O'ZGARMAYDI.
--
-- QAMROV:
--   1) P0-07  process_payment_webhook — client (anon/authenticated) EXECUTE
--             huquqi olib tashlanadi -> to'g'ridan-to'g'ri chaqiruv 403.
--   2) P1-05  get_expert_available_slots — mavjud/tasdiqlanmagan advokat
--             uchun to'qima 12 slot va 150 000 UZS narx OLIB TASHLANADI.
--   3) P1-06  questions/answers uchun EGA DELETE policy'si (hozir YO'Q).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) P0-07 — process_payment_webhook: CALLER AUTHORIZATION
-- -----------------------------------------------------------------------------
-- DALIL (2026-08-22, production, anon key, sessiyasiz):
--   rpc('process_payment_webhook', {...}) ->
--   PostgrestException(code: P0001, message: 'Payment record not found')
--   Ya'ni funksiya ANON tomonidan BAJARILDI — "permission denied" EMAS.
--
-- SABAB: `20260825_step2_payments_tables_and_logic.sql` da bu funksiya uchun
--   birorta GRANT/REVOKE yo'q. PostgreSQL default'i bo'yicha yangi funksiyaga
--   EXECUTE huquqi PUBLIC ga beriladi, `anon` va `authenticated` esa PUBLIC
--   a'zosi. SECURITY DEFINER tanasida `auth.uid()` tekshiruvi ham yo'q.
--
-- TA'SIR: (a) o'z bronini pul to'lamasdan `paid`/`confirmed` qilish;
--         (b) `p_status := 'failed'` bilan BOSHQA odamning bronini `expired`
--             qilish (sabotaj) — yagona to'siq `payment_id` UUID'ini bilish.
--
-- YECHIM: webhook — SERVER tomon vazifasi. To'lov provayderi -> Edge Function
--   (`service_role`) -> RPC. Client umuman chaqirmasligi kerak.
--
-- KUTILGAN NATIJA: anon/authenticated chaqiruvi ->
--   PostgreSQL 42501 (insufficient_privilege) -> PostgREST HTTP 403.
--
-- ESLATMA: funksiya TANASI o'zgarmaydi (production'dagi mantiqni ko'r-ko'rona
--   qayta yozish xavfli). Faqat EXECUTE huquqi qayta taqsimlanadi — bu
--   PostgreSQL'ning ASOSIY (authoritative) ruxsat mexanizmi.

-- Imzoga BOG'LIQ BO'LMAGAN usul: `pg_proc` dan barcha overload'lar topiladi.
-- Sabab — production'dagi imzo migration faylidagidan farq qilishi mumkin
-- (bu loyihada `schema.sql` production'dan ALLAQACHON farq qiladi: u
-- `answers.content NOT NULL` deydi, production esa `column does not exist`).
DO $$
DECLARE
    v_fn      record;
    v_role    text;
    v_found   int := 0;
BEGIN
    FOR v_fn IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'process_payment_webhook'
    LOOP
        v_found := v_found + 1;

        -- PUBLIC dan butunlay olinadi (default EXECUTE huquqi shu yerdan keladi)
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', v_fn.sig);

        -- Client rollari: aniq nomlab olib tashlanadi (agar mavjud bo'lsa)
        FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role) THEN
                EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %I', v_fn.sig, v_role);
            END IF;
        END LOOP;

        -- Faqat ishonchli server tomon: Edge Function / backend
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', v_fn.sig);
        END IF;

        RAISE NOTICE 'P0-07: EXECUTE qayta taqsimlandi -> %', v_fn.sig;
    END LOOP;

    IF v_found = 0 THEN
        RAISE EXCEPTION 'P0-07 BAJARILMADI: public.process_payment_webhook topilmadi. '
                        'Funksiya nomi yoki schema tekshirilsin.';
    END IF;
END $$;


-- -----------------------------------------------------------------------------
-- 2) P1-05 — get_expert_available_slots: TO'QIMA SLOT VA NARX OLIB TASHLANADI
-- -----------------------------------------------------------------------------
-- DALIL (2026-08-22, production, anon):
--   `expert_profiles` anon uchun ko'rinadigan qator: 0
--   get_expert_available_slots('00000000-...-0001', <ertaga>)
--     -> 12 qator, is_available: true, price_amount_uzs: 150000.0
--
-- SABAB: `IF v_fee IS NULL THEN v_fee := 150000.00; END IF;` — advokat
--   TOPILMASA ham funksiya davom etadi va default jadval (09:00-18:00,
--   45 daqiqa) bo'yicha 12 ta "bo'sh" slot generatsiya qiladi.
--
--   Diqqat: `expert_profiles.consultation_fee` — `NUMERIC(12,2) NOT NULL
--   DEFAULT 0.00`. Ya'ni MAVJUD qator uchun `v_fee` HECH QACHON NULL
--   bo'lmaydi. Demak 150 000 qiymati FAQAT "qator topilmadi" holatida
--   paydo bo'lgan — bu sof to'qima ma'lumot.
--
-- TA'SIR: UI mavjud bo'lmagan/tasdiqlanmagan advokat uchun to'liq bron
--   kalendarini va 150 000 UZS narxni ko'rsatadi, keyin `book_consultation`
--   'Expert not found or not verified' bilan rad etadi -> foydalanuvchi
--   boshi berk oqimga tushadi.
--
-- TUZATISH: advokat MAVJUD va TASDIQLANGAN bo'lmasa -> BO'SH natija.
--   Narx endi faqat DB'dan olinadi, fallback konstanta YO'Q.
--   Imzo, qaytish turi va volatility (STABLE) O'ZGARMAYDI.
--
-- REGRESSIYA XAVFI: tasdiqlangan advokat uchun mantiq AVVALGIDEK — jadval
--   bo'lsa jadval bo'yicha, bo'lmasa 09:00-18:00/45 daqiqa default'i.
--   Ya'ni ishlaydigan oqim buzilmaydi.
CREATE OR REPLACE FUNCTION public.get_expert_available_slots(
    p_expert_id UUID,
    p_date DATE
)
RETURNS TABLE (
    slot_time TIMESTAMPTZ,
    is_available BOOLEAN,
    duration_minutes INT,
    price_amount_uzs NUMERIC(12, 2)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    v_day_of_week INT;
    v_fee NUMERIC(12, 2);
    v_start_time TIME;
    v_end_time TIME;
    v_duration INT;
    v_current_slot TIMESTAMPTZ;
    v_end_slot TIMESTAMPTZ;
BEGIN
    -- Day of week: 1=Monday ... 7=Sunday
    v_day_of_week := EXTRACT(ISODOW FROM p_date);

    -- P1-05 GUARD: advokat MAVJUD va TASDIQLANGAN bo'lishi SHART.
    -- `RETURN` bo'sh natija qaytaradi — client tomonda bu "bo'sh vaqt yo'q"
    -- holatiga tushadi (soxta slot EMAS, xato ham EMAS).
    SELECT ep.consultation_fee
    INTO v_fee
    FROM public.expert_profiles ep
    WHERE ep.id = p_expert_id
      AND ep.verified_at IS NOT NULL;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Narx faqat DB'dan. `consultation_fee` NOT NULL, lekin himoya sifatida:
    -- qiymat aniqlanmagan bo'lsa to'qima narx ko'rsatilmaydi.
    IF v_fee IS NULL THEN
        RETURN;
    END IF;

    -- Expert schedule, aks holda default (09:00-18:00, 45 daqiqa)
    SELECT
        COALESCE(start_time, '09:00:00'::TIME),
        COALESCE(end_time, '18:00:00'::TIME),
        COALESCE(slot_duration_minutes, 45)
    INTO v_start_time, v_end_time, v_duration
    FROM public.expert_schedules
    WHERE expert_id = p_expert_id
      AND day_of_week = v_day_of_week
      AND is_active = TRUE;

    IF v_start_time IS NULL THEN
        v_start_time := '09:00:00'::TIME;
        v_end_time := '18:00:00'::TIME;
        v_duration := 45;
    END IF;

    v_current_slot := p_date + v_start_time;
    v_end_slot := p_date + v_end_time;

    WHILE v_current_slot + (v_duration * INTERVAL '1 minute') <= v_end_slot LOOP
        RETURN QUERY
        SELECT
            v_current_slot AS slot_time,
            NOT EXISTS (
                SELECT 1 FROM public.consultations c
                WHERE c.expert_id = p_expert_id
                  AND c.scheduled_at = v_current_slot
                  AND c.status IN ('pending', 'awaiting_payment', 'confirmed', 'in_progress')
            ) AS is_available,
            v_duration AS duration_minutes,
            v_fee AS price_amount_uzs;

        v_current_slot := v_current_slot + (v_duration * INTERVAL '1 minute');
    END LOOP;
END;
$$;


-- -----------------------------------------------------------------------------
-- 3) P1-06 — EGA O'Z KONTENTINI O'CHIRA OLMAYDI (DELETE policy YO'Q)
-- -----------------------------------------------------------------------------
-- DALIL (2026-08-23, production, 3 xil authenticated sessiya):
--   test/integration/cleanup_live_test_data_test.dart
--     invariant_probe_1787428875317: DELETE 0 qator, keyingi SELECT 1 qator
--     answer_probe_1787428900824:    DELETE 0 qator, keyingi SELECT 1 qator
--     answer_probe_1787389699140:    DELETE 0 qator, keyingi SELECT 1 qator
--   Qator KO'RINADI (SELECT policy bor), lekin O'CHMAYDI.
--
-- SABAB (fayl darajasida aniqlangan): `supabase/migrations/` ICHIDA
--   `questions`/`answers` uchun birorta `FOR DELETE` policy YO'Q —
--   migration'larda faqat `reports` va `user_documents` uchun DELETE bor.
--   `questions` uchun DELETE policy FAQAT `supabase/schema.sql:866-868` da
--   mavjud, u esa `migrations/` da emas va production'ga QO'LLANMAGAN
--   (mustaqil isbot: `schema.sql` `answers.content NOT NULL` deydi,
--   production esa `42703 column answers.content does not exist` qaytaradi).
--   RLS yoqilgan + DELETE policy yo'q => PostgREST xato QAYTARMAYDI,
--   shunchaki 0 qator ta'sir qiladi. Shu sababli nuqson UI'da ham,
--   log'da ham ko'rinmaydi.
--
-- TA'SIR: foydalanuvchi hamjamiyatga shaxsiy huquqiy holatini yozgach
--   (ishdan bo'shatish, ajrashish, qarz) uni QAYTA OLIB TASHLAY OLMAYDI.
--   Yuridik maslahat platformasi uchun bu maxfiylik/"data subject rights"
--   masalasi. Ruxsatsiz KIRISH yo'q, shuning uchun P1 (P0 emas).
--
-- QAROR IZOHI:
--   * `TO authenticated` — ANONIM foydalanuvchi uchun policy UMUMAN
--     qo'llanmaydi va boshqa DELETE policy yo'q => anon DELETE fail-closed.
--   * `auth.uid() = user_id` — faqat O'Z qatori. Boshqa odamning qatori
--     policy'ga tushmaydi => 0 qator (ma'lumot oshkor bo'lmaydi).
--   * `is_admin_or_moderator()` — loyihadagi MAVJUD funksiya
--     (`20260821_expert_verification_and_privacy.sql:24`), SELECT/UPDATE
--     policy'larida allaqachon ishlatilgan. Moderatsiya imkoni saqlanadi.
--     DIQQAT: `public.is_admin(uuid)` loyihada MAVJUD EMAS — ataylab
--     ishlatilmadi, aks holda migration yiqilardi.
--
-- FK / CASCADE TEKSHIRILDI:
--   answers.question_id          -> questions(id) ON DELETE CASCADE
--   consultations.question_id    -> questions(id) ON DELETE SET NULL
--   question_tag_mappings        -> questions(id) ON DELETE CASCADE
--   Ya'ni savol o'chirilsa javoblari ham ketadi (forum semantikasi) va
--   konsultatsiya qatori YO'QOLMAYDI — faqat bog'lanish uziladi.
--   `trg_handle_answer_counter` (AFTER DELETE) `GREATEST(0, ...)` bilan
--   himoyalangan, cascade paytida xato bermaydi.

-- RLS yoqilganini kafolatlash (idempotent, allaqachon yoqilgan bo'lsa no-op)
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.answers   ENABLE ROW LEVEL SECURITY;

-- `schema.sql` dagi nom bilan to'qnashmasligi uchun eski nom ham tozalanadi
DROP POLICY IF EXISTS "Owners can delete their questions" ON public.questions;
DROP POLICY IF EXISTS "owner_can_delete_own_question"    ON public.questions;
CREATE POLICY "owner_can_delete_own_question"
  ON public.questions
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR public.is_admin_or_moderator()
  );

DROP POLICY IF EXISTS "Owners can delete their answers" ON public.answers;
DROP POLICY IF EXISTS "owner_can_delete_own_answer"     ON public.answers;
CREATE POLICY "owner_can_delete_own_answer"
  ON public.answers
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR public.is_admin_or_moderator()
  );

COMMIT;


-- =============================================================================
-- DEPLOYDAN KEYIN TEKSHIRUV (SQL Editor'da alohida RUN)
-- =============================================================================
-- 1) P0-07: client rollarida EXECUTE QOLMAGANINI ko'rsatish (3 qator: false)
--    SELECT r.rolname,
--           has_function_privilege(r.rolname, p.oid, 'EXECUTE') AS can_execute
--    FROM pg_proc p
--    JOIN pg_namespace n ON n.oid = p.pronamespace
--    CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) AS r(rolname)
--    WHERE n.nspname = 'public' AND p.proname = 'process_payment_webhook';
--    KUTILGAN: anon=false, authenticated=false, service_role=true
--
-- 2) P1-05: mavjud bo'lmagan advokat -> 0 qator
--    SELECT count(*) FROM public.get_expert_available_slots(
--      '00000000-0000-0000-0000-000000000001', current_date + 1);
--    KUTILGAN: 0
--
-- 3) P1-06: policy'lar mavjudligi (2 qator)
--    SELECT tablename, policyname, cmd, roles
--    FROM pg_policies
--    WHERE schemaname = 'public' AND cmd = 'DELETE'
--      AND tablename IN ('questions','answers');
-- =============================================================================
