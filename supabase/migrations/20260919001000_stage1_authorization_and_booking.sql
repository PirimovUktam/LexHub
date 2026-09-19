-- Stage 1: P1-06 answer authorship; P1-07 expert INSERT; P1-09 booking fee.
-- Prepared after READ-ONLY production MCP inspection on 2026-09-19.
-- NOT APPLIED TO PRODUCTION. Runbook: docs/STAGE1_DATABASE.md.
BEGIN;

DO $$
BEGIN
    IF to_regclass('public.answers') IS NULL
       OR to_regclass('public.expert_profiles') IS NULL
       OR to_regclass('public.consultations') IS NULL
       OR to_regprocedure('public.is_admin_or_moderator()') IS NULL THEN
        RAISE EXCEPTION 'Stage 1 prerequisites missing; inspect schema before applying';
    END IF;
END;
$$;

-- Function privileges are finalized after all definitions below.

-- Keep the current client PATCH {is_accepted: true} contract. The question
-- author may accept an answer, but may not edit it under someone else's name.
-- INVOKER is essential: DEFINER would treat every caller as the table owner.
CREATE OR REPLACE FUNCTION public.guard_answer_write()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_actor UUID := auth.uid();
    v_staff BOOLEAN := public.is_admin_or_moderator();
    v_question_owner UUID;
BEGIN
    -- Existing trusted counter/acceptance functions execute as their owner.
    IF current_user IN ('postgres', 'supabase_admin', 'service_role') THEN
        RETURN NEW;
    END IF;
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authentication required to write an answer'
            USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.user_id IS DISTINCT FROM v_actor
           OR NEW.is_accepted IS DISTINCT FROM false
           OR NEW.upvotes_count IS DISTINCT FROM 0 THEN
            RAISE EXCEPTION 'Answer author and initial state are server controlled'
                USING ERRCODE = '42501';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.question_id IS DISTINCT FROM OLD.question_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Answer identity and authorship are immutable'
            USING ERRCODE = '42501';
    END IF;

    SELECT user_id INTO v_question_owner FROM public.questions
        WHERE id = OLD.question_id;
    IF NOT v_staff AND v_actor IS DISTINCT FROM OLD.user_id THEN
        IF v_actor IS DISTINCT FROM v_question_owner
           OR (to_jsonb(NEW) - ARRAY['is_accepted', 'updated_at'])
              IS DISTINCT FROM
              (to_jsonb(OLD) - ARRAY['is_accepted', 'updated_at']) THEN
            RAISE EXCEPTION 'Only the answer author may edit answer content'
                USING ERRCODE = '42501';
        END IF;
    ELSIF NOT v_staff THEN
        -- Authors edit their text/references, not reputation or source badges.
        IF (to_jsonb(NEW) - ARRAY['body', 'content', 'legal_references',
                'is_expert_answer', 'is_accepted', 'updated_at'])
           IS DISTINCT FROM
           (to_jsonb(OLD) - ARRAY['body', 'content', 'legal_references',
                'is_expert_answer', 'is_accepted', 'updated_at']) THEN
            RAISE EXCEPTION 'Answer metadata is server controlled'
                USING ERRCODE = '42501';
        END IF;
    END IF;
    IF NEW.is_accepted IS DISTINCT FROM OLD.is_accepted
       AND NOT v_staff AND v_actor IS DISTINCT FROM v_question_owner THEN
        RAISE EXCEPTION 'Only the question author may accept an answer'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_00_guard_answer_write ON public.answers;
CREATE TRIGGER trg_00_guard_answer_write BEFORE INSERT OR UPDATE ON public.answers
    FOR EACH ROW EXECUTE FUNCTION public.guard_answer_write();

-- Restrictive policies intersect any older permissive policy, including the
-- additional legacy INSERT policy found in production. Do not widen RLS.
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stage1_answer_insert_identity ON public.answers;
CREATE POLICY stage1_answer_insert_identity ON public.answers AS RESTRICTIVE
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS stage1_answer_update_actor ON public.answers;
CREATE POLICY stage1_answer_update_actor ON public.answers AS RESTRICTIVE
    FOR UPDATE TO authenticated USING (
        auth.uid() = user_id OR public.is_admin_or_moderator()
        OR EXISTS (SELECT 1 FROM public.questions q
                   WHERE q.id = answers.question_id AND q.user_id = auth.uid())
    ) WITH CHECK (
        auth.uid() = user_id OR public.is_admin_or_moderator()
        OR EXISTS (SELECT 1 FROM public.questions q
                   WHERE q.id = answers.question_id AND q.user_id = auth.uid())
    );

CREATE OR REPLACE FUNCTION public.handle_answer_acceptance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_question_owner UUID;
BEGIN
    IF NEW.is_accepted IS DISTINCT FROM OLD.is_accepted THEN
        SELECT user_id INTO v_question_owner FROM public.questions
            WHERE id = OLD.question_id FOR UPDATE;
        IF (auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM v_question_owner)
           AND NOT public.is_admin_or_moderator()
           AND coalesce(auth.role(), '') <> 'service_role' THEN
            RAISE EXCEPTION 'Only the question author may accept an answer'
                USING ERRCODE = '42501';
        END IF;
        IF NEW.is_accepted THEN
            UPDATE public.answers SET is_accepted = false
                WHERE question_id = OLD.question_id AND id <> OLD.id
                  AND is_accepted;
            UPDATE public.questions SET status = 'answered', updated_at = now()
                WHERE id = OLD.question_id;
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- Keep the application/moderation RPCs and their cooldown logic unchanged.
-- Direct client INSERT must start pending, unrated and owned by the caller.
CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF current_user NOT IN ('postgres', 'supabase_admin', 'service_role',
                            'supabase_auth_admin') THEN
        IF TG_OP = 'INSERT' THEN
            IF auth.uid() IS NULL OR NEW.user_id IS DISTINCT FROM auth.uid()
               OR NEW.verified_at IS NOT NULL OR NEW.rating IS NOT NULL
               OR NEW.reviews_count IS DISTINCT FROM 0
               OR NEW.rejected_at IS NOT NULL OR NEW.rejection_reason IS NOT NULL THEN
                RAISE EXCEPTION 'Expert application must start pending and unrated'
                    USING ERRCODE = '42501';
            END IF;
        ELSIF NEW.user_id IS DISTINCT FROM OLD.user_id
           OR NEW.id IS DISTINCT FROM OLD.id
           OR NEW.created_at IS DISTINCT FROM OLD.created_at
           OR NEW.rating IS DISTINCT FROM OLD.rating
           OR NEW.reviews_count IS DISTINCT FROM OLD.reviews_count
           OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
           OR NEW.rejected_at IS DISTINCT FROM OLD.rejected_at
           OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
           OR (OLD.verified_at IS NOT NULL
               AND NEW.license_number IS DISTINCT FROM OLD.license_number) THEN
            RAISE EXCEPTION 'Expert identity, verification and rating are server controlled'
                USING ERRCODE = '42501';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_protect_expert_profile_sensitive_fields ON public.expert_profiles;
CREATE TRIGGER trg_protect_expert_profile_sensitive_fields
    BEFORE INSERT OR UPDATE ON public.expert_profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_expert_profile_sensitive_fields();

-- booking RPC follows, with its existing signature and response preserved.

CREATE OR REPLACE FUNCTION public.book_consultation(
    p_expert_id UUID,
    p_scheduled_at TIMESTAMPTZ,
    p_meeting_type TEXT DEFAULT 'online',
    p_notes TEXT DEFAULT NULL,
    p_question_id UUID DEFAULT NULL,
    p_provider TEXT DEFAULT 'payme'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_citizen_id UUID;
    v_expert_record RECORD;
    v_price_uzs NUMERIC(12, 2);
    v_price_tiyin BIGINT;
    v_commission_tiyin BIGINT;
    v_payout_tiyin BIGINT;
    v_duration INT := 45;
    v_consultation_id UUID;
    v_payment_id UUID;
    v_idempotency_key TEXT;
    v_provider_enum payment_provider;
BEGIN
    v_citizen_id := auth.uid();
    IF v_citizen_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required: Fuqaro tizimga kirgan bo''lishi shart.';
    END IF;

    -- Validate provider
    BEGIN
        v_provider_enum := p_provider::payment_provider;
    EXCEPTION WHEN OTHERS THEN
        v_provider_enum := 'payme';
    END;

    -- Lock expert profile row for transactional price snapshotting
    SELECT ep.id, ep.user_id, ep.consultation_fee, p.full_name
    INTO v_expert_record
    FROM public.expert_profiles ep
    JOIN public.profiles p ON ep.user_id = p.id
    WHERE ep.id = p_expert_id AND ep.verified_at IS NOT NULL
      AND ep.rejected_at IS NULL AND p.is_verified = TRUE
      AND p.role::text IN ('verified_expert', 'lawyer', 'moderator', 'admin')
    FOR SHARE;

    IF v_expert_record.id IS NULL THEN
        RAISE EXCEPTION 'Expert not found or not verified: Advokat profili tasdiqlanmagan.';
    END IF;

    -- Cannot book consultation with self
    IF v_expert_record.user_id = v_citizen_id THEN
        RAISE EXCEPTION 'Self-booking blocked: Advokat o''ziga konsultatsiya bron qila olmaydi.';
    END IF;

    -- Validate scheduled_at is in future
    IF p_scheduled_at <= now() THEN
        RAISE EXCEPTION 'Invalid date: Konsultatsiya vaqti kelajakda bo''lishi shart.';
    END IF;

    -- Double Booking Check with Advisory Lock
    IF NOT pg_try_advisory_xact_lock(hashtext('consultation_lock_' || p_expert_id::text || '_' || p_scheduled_at::text)) THEN
        RAISE EXCEPTION 'Slot is currently being booked by another citizen. Please try another time.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.consultations
        WHERE expert_id = p_expert_id
          AND scheduled_at = p_scheduled_at
          AND status IN ('pending', 'awaiting_payment', 'confirmed', 'in_progress')
    ) THEN
        RAISE EXCEPTION 'Slot already booked: Ushbu vaqt oralig''i allaqachon band qilingan.';
    END IF;

    -- Price Snapshot & Commission Calculation (Tiyin safe)
    v_price_uzs := v_expert_record.consultation_fee;
    IF v_price_uzs IS NULL THEN
        RAISE EXCEPTION 'Expert consultation fee is missing';
    END IF;
    v_price_tiyin := (v_price_uzs * 100)::BIGINT;
    v_commission_tiyin := ROUND(v_price_tiyin * 0.10)::BIGINT; -- 10% platform commission
    v_payout_tiyin := v_price_tiyin - v_commission_tiyin;

    -- Generate IDs
    v_consultation_id := gen_random_uuid();
    v_payment_id := gen_random_uuid();
    v_idempotency_key := 'pay_' || v_consultation_id::text || '_' || EXTRACT(EPOCH FROM now())::BIGINT;

    -- Insert Consultation record
    INSERT INTO public.consultations (
        id,
        citizen_id,
        expert_id,
        question_id,
        scheduled_at,
        duration_minutes,
        fee,
        price_amount_tiyin,
        currency,
        commission_rate,
        commission_amount_tiyin,
        expert_payout_amount_tiyin,
        status,
        payment_status,
        payout_status,
        payment_id,
        meeting_type,
        notes
    ) VALUES (
        v_consultation_id,
        v_citizen_id,
        p_expert_id,
        p_question_id,
        p_scheduled_at,
        v_duration,
        v_price_uzs,
        v_price_tiyin,
        'UZS',
        0.1000,
        v_commission_tiyin,
        v_payout_tiyin,
        'awaiting_payment',
        'pending',
        'pending',
        v_payment_id,
        p_meeting_type,
        p_notes
    );

    -- Insert Payment record
    INSERT INTO public.payments (
        id,
        consultation_id,
        citizen_id,
        expert_id,
        provider,
        idempotency_key,
        amount_tiyin,
        currency,
        status
    ) VALUES (
        v_payment_id,
        v_consultation_id,
        v_citizen_id,
        p_expert_id,
        v_provider_enum,
        v_idempotency_key,
        v_price_tiyin,
        'UZS',
        'pending'
    );

    -- Insert Audit Log
    INSERT INTO public.payment_audit_logs (
        payment_id,
        consultation_id,
        actor_id,
        action,
        new_state,
        notes
    ) VALUES (
        v_payment_id,
        v_consultation_id,
        v_citizen_id,
        'CONSULTATION_BOOKED',
        jsonb_build_object(
            'status', 'awaiting_payment',
            'price_amount_tiyin', v_price_tiyin,
            'commission_amount_tiyin', v_commission_tiyin,
            'expert_payout_amount_tiyin', v_payout_tiyin
        ),
        'Booking initiated awaiting payment checkout.'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'consultation_id', v_consultation_id,
        'payment_id', v_payment_id,
        'idempotency_key', v_idempotency_key,
        'price_amount_uzs', v_price_uzs,
        'price_amount_tiyin', v_price_tiyin,
        'commission_amount_uzs', (v_commission_tiyin / 100.0),
        'expert_name', v_expert_record.full_name,
        'scheduled_at', p_scheduled_at,
        'status', 'awaiting_payment',
        'provider', v_provider_enum
    );
END;
$$;

DO $acl$
DECLARE
    v_function RECORD;
BEGIN
    IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'book_consultation') <> 1 THEN
        RAISE EXCEPTION 'Unexpected book_consultation overload; inspect before applying';
    END IF;
    FOR v_function IN
        SELECT p.oid::regprocedure AS signature, p.proname
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname IN (
            'guard_answer_write', 'handle_answer_acceptance',
            'protect_expert_profile_sensitive_fields', 'book_consultation')
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',
                       v_function.signature);
        IF v_function.proname = 'book_consultation' THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role',
                           v_function.signature);
        END IF;
    END LOOP;
END;
$acl$;

DO $assert$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger
                   WHERE tgrelid = 'public.expert_profiles'::regclass
                     AND tgname = 'trg_protect_expert_profile_sensitive_fields'
                     AND tgtype = 23 AND tgenabled = 'O')
       OR NOT EXISTS (SELECT 1 FROM pg_trigger
                      WHERE tgrelid = 'public.answers'::regclass
                        AND tgname = 'trg_00_guard_answer_write'
                        AND tgtype = 23 AND tgenabled = 'O')
       OR NOT EXISTS (SELECT 1 FROM pg_trigger
                      WHERE tgrelid = 'public.answers'::regclass
                        AND tgname = 'trg_handle_answer_acceptance'
                        AND tgenabled = 'O') THEN
        RAISE EXCEPTION 'Stage 1 write guards not attached';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc WHERE oid IN (
        'public.guard_answer_write()'::regprocedure,
        'public.protect_expert_profile_sensitive_fields()'::regprocedure)
        AND prosecdef) THEN
        RAISE EXCEPTION 'Stage 1 write guards must be SECURITY INVOKER';
    END IF;
END;
$assert$;
COMMIT;

-- Read-only post-apply check (does not prove authenticated runtime behavior):
-- SELECT tgname, pg_get_triggerdef(oid) FROM pg_trigger
-- WHERE tgrelid IN ('public.answers'::regclass, 'public.expert_profiles'::regclass)
--   AND NOT tgisinternal;
-- SELECT policyname, permissive, cmd, qual, with_check FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'answers';
-- SELECT has_function_privilege('anon',
--   'public.book_consultation(uuid,timestamptz,text,text,uuid,text)', 'EXECUTE');
-- Expected false. Use the runbook for isolated authenticated tests.
