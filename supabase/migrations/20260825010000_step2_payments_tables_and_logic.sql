-- ==============================================================================
-- MIGRATION STEP 2: 20260825_step2_payments_tables_and_logic.sql
-- LexHub Platform — Tables, Double-Booking Protection, RLS & Financial RPC Engine
-- MUST BE EXECUTED AFTER 20260825_step1_payments_enums.sql IS COMMITTED
-- ==============================================================================

-- 1. EXPERT SCHEDULES TABLE
CREATE TABLE IF NOT EXISTS public.expert_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expert_id UUID NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1: Monday ... 7: Sunday
    start_time TIME NOT NULL DEFAULT '09:00:00',
    end_time TIME NOT NULL DEFAULT '18:00:00',
    slot_duration_minutes INTEGER DEFAULT 45 NOT NULL CHECK (slot_duration_minutes > 0),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (expert_id, day_of_week)
);

CREATE INDEX IF NOT EXISTS idx_expert_schedules_expert_id ON public.expert_schedules(expert_id);


-- 2. RECONCILE CONSULTATIONS TABLE
CREATE TABLE IF NOT EXISTS public.consultations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citizen_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    expert_id UUID NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.questions(id) ON DELETE SET NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER DEFAULT 45 NOT NULL CHECK (duration_minutes > 0),
    price_amount_tiyin BIGINT NOT NULL DEFAULT 0 CHECK (price_amount_tiyin >= 0),
    currency VARCHAR(8) DEFAULT 'UZS' NOT NULL,
    commission_rate NUMERIC(5, 4) DEFAULT 0.1000 NOT NULL,
    commission_amount_tiyin BIGINT NOT NULL DEFAULT 0 CHECK (commission_amount_tiyin >= 0),
    expert_payout_amount_tiyin BIGINT NOT NULL DEFAULT 0 CHECK (expert_payout_amount_tiyin >= 0),
    status consultation_status DEFAULT 'pending' NOT NULL,
    payment_status payment_status DEFAULT 'pending' NOT NULL,
    payout_status payout_status DEFAULT 'pending' NOT NULL,
    payment_id UUID,
    cancelled_by UUID REFERENCES public.profiles(id),
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    refund_amount_tiyin BIGINT DEFAULT 0 NOT NULL,
    meeting_link TEXT,
    meeting_type VARCHAR(32) DEFAULT 'online' NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Idempotent column reconciliations on consultations
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS citizen_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS expert_id UUID REFERENCES public.expert_profiles(id) ON DELETE CASCADE;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS question_id UUID REFERENCES public.questions(id) ON DELETE SET NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 45 NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS price_amount_tiyin BIGINT DEFAULT 0 NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS currency VARCHAR(8) DEFAULT 'UZS' NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS commission_rate NUMERIC(5, 4) DEFAULT 0.1000 NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS commission_amount_tiyin BIGINT DEFAULT 0 NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS expert_payout_amount_tiyin BIGINT DEFAULT 0 NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS status consultation_status DEFAULT 'pending' NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS payment_status payment_status DEFAULT 'pending' NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS payout_status payout_status DEFAULT 'pending' NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS payment_id UUID;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES public.profiles(id);
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS refund_amount_tiyin BIGINT DEFAULT 0 NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS meeting_link TEXT;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS meeting_type VARCHAR(32) DEFAULT 'online' NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.consultations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- 3. DOUBLE BOOKING PROTECTION INDEX
CREATE UNIQUE INDEX IF NOT EXISTS idx_active_consultation_slot 
ON public.consultations (expert_id, scheduled_at) 
WHERE status IN ('pending', 'awaiting_payment', 'confirmed', 'in_progress');


-- 4. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consultation_id UUID NOT NULL REFERENCES public.consultations(id) ON DELETE CASCADE,
    citizen_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    expert_id UUID NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
    provider payment_provider NOT NULL DEFAULT 'payme',
    provider_transaction_id VARCHAR(128),
    idempotency_key VARCHAR(128) UNIQUE NOT NULL,
    amount_tiyin BIGINT NOT NULL CHECK (amount_tiyin >= 0),
    currency VARCHAR(8) DEFAULT 'UZS' NOT NULL,
    status payment_status DEFAULT 'pending' NOT NULL,
    provider_payload JSONB DEFAULT '{}'::jsonb,
    error_message TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_payments_consultation_id ON public.payments(consultation_id);
CREATE INDEX IF NOT EXISTS idx_payments_citizen_id ON public.payments(citizen_id);
CREATE INDEX IF NOT EXISTS idx_payments_expert_id ON public.payments(expert_id);
CREATE INDEX IF NOT EXISTS idx_payments_idempotency_key ON public.payments(idempotency_key);


-- 5. PAYMENT AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.payment_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
    consultation_id UUID REFERENCES public.consultations(id) ON DELETE SET NULL,
    actor_id UUID REFERENCES public.profiles(id),
    action VARCHAR(64) NOT NULL,
    old_state JSONB,
    new_state JSONB,
    provider_reference VARCHAR(128),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_consultation_id ON public.payment_audit_logs(consultation_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_payment_id ON public.payment_audit_logs(payment_id);


-- 6. USER NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(64) NOT NULL DEFAULT 'consultation',
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON public.user_notifications(user_id);


-- 7. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.expert_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

-- Schedules: Public can view active schedules; Expert can manage own
DROP POLICY IF EXISTS "Public can view active expert schedules" ON public.expert_schedules;
CREATE POLICY "Public can view active expert schedules" ON public.expert_schedules 
FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS "Experts can manage own schedule" ON public.expert_schedules;
CREATE POLICY "Experts can manage own schedule" ON public.expert_schedules 
FOR ALL USING (
    expert_id IN (SELECT id FROM public.expert_profiles WHERE user_id = auth.uid())
);

-- Consultations: Only citizen and assigned expert can view
DROP POLICY IF EXISTS "Consultation participants can view" ON public.consultations;
CREATE POLICY "Consultation participants can view" ON public.consultations 
FOR SELECT USING (
    auth.uid() = citizen_id OR 
    expert_id IN (SELECT id FROM public.expert_profiles WHERE user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Deny raw INSERT/UPDATE/DELETE on consultations (Must use RPC)
DROP POLICY IF EXISTS "Citizens can book consultations" ON public.consultations;
DROP POLICY IF EXISTS "Deny direct consultation inserts" ON public.consultations;
CREATE POLICY "Deny direct consultation inserts" ON public.consultations 
FOR INSERT WITH CHECK (
    current_user = 'service_role' OR session_user = 'postgres'
);

DROP POLICY IF EXISTS "Deny direct consultation updates" ON public.consultations;
CREATE POLICY "Deny direct consultation updates" ON public.consultations 
FOR UPDATE USING (
    current_user = 'service_role' OR session_user = 'postgres'
);

-- Payments: Only citizen, assigned expert and admin can view
DROP POLICY IF EXISTS "Payment participants can view" ON public.payments;
CREATE POLICY "Payment participants can view" ON public.payments 
FOR SELECT USING (
    auth.uid() = citizen_id OR 
    expert_id IN (SELECT id FROM public.expert_profiles WHERE user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "Deny direct payment mutations" ON public.payments;
CREATE POLICY "Deny direct payment mutations" ON public.payments 
FOR ALL USING (
    current_user = 'service_role' OR session_user = 'postgres'
);

-- Audit logs: Only admin can view
DROP POLICY IF EXISTS "Admins can view payment audit logs" ON public.payment_audit_logs;
CREATE POLICY "Admins can view payment audit logs" ON public.payment_audit_logs 
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Notifications: User can view and mark read on own
DROP POLICY IF EXISTS "Users can view own notifications" ON public.user_notifications;
CREATE POLICY "Users can view own notifications" ON public.user_notifications 
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.user_notifications;
CREATE POLICY "Users can update own notifications" ON public.user_notifications 
FOR UPDATE USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);


-- 8. RPC: GET EXPERT AVAILABLE SLOTS
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

    -- Get expert consultation fee
    SELECT COALESCE(consultation_fee, 150000.00) INTO v_fee
    FROM public.expert_profiles
    WHERE id = p_expert_id AND verified_at IS NOT NULL;

    IF v_fee IS NULL THEN
        v_fee := 150000.00;
    END IF;

    -- Get expert schedule or use default (09:00 - 18:00, 45 min slots)
    SELECT 
        COALESCE(start_time, '09:00:00'::TIME),
        COALESCE(end_time, '18:00:00'::TIME),
        COALESCE(slot_duration_minutes, 45)
    INTO v_start_time, v_end_time, v_duration
    FROM public.expert_schedules
    WHERE expert_id = p_expert_id AND day_of_week = v_day_of_week AND is_active = TRUE;

    IF v_start_time IS NULL THEN
        v_start_time := '09:00:00'::TIME;
        v_end_time := '18:00:00'::TIME;
        v_duration := 45;
    END IF;

    v_current_slot := p_date + v_start_time;
    v_end_slot := p_date + v_end_time;

    -- Generate slots
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


-- 9. RPC: BOOK CONSULTATION (Zero-Trust Snapshot & Locking)
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
    v_price_uzs := COALESCE(v_expert_record.consultation_fee, 150000.00);
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


-- 10. RPC: PROCESS PAYMENT WEBHOOK (Idempotent Backend Verification)
CREATE OR REPLACE FUNCTION public.process_payment_webhook(
    p_payment_id UUID,
    p_provider TEXT,
    p_provider_transaction_id TEXT,
    p_paid_amount_tiyin BIGINT,
    p_status TEXT DEFAULT 'paid',
    p_error_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_payment RECORD;
    v_consultation RECORD;
    v_citizen_name TEXT;
    v_expert_user_id UUID;
    v_meeting_link TEXT;
BEGIN
    -- Fetch payment with row lock
    SELECT * INTO v_payment
    FROM public.payments
    WHERE id = p_payment_id
    FOR UPDATE;

    IF v_payment.id IS NULL THEN
        RAISE EXCEPTION 'Payment record not found: To''lov topilmadi.';
    END IF;

    -- Fetch consultation
    SELECT c.*, ep.user_id AS expert_user_id, p.full_name AS citizen_name
    INTO v_consultation
    FROM public.consultations c
    JOIN public.expert_profiles ep ON c.expert_id = ep.id
    JOIN public.profiles p ON c.citizen_id = p.id
    WHERE c.id = v_payment.consultation_id;

    -- Idempotency check: if already paid, return success without duplicate side-effects
    IF v_payment.status = 'paid' THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'is_duplicate', TRUE,
            'message', 'Payment already processed successfully.',
            'consultation_id', v_payment.consultation_id,
            'status', 'paid'
        );
    END IF;

    -- Handle Failed Payment
    IF p_status = 'failed' THEN
        UPDATE public.payments SET
            status = 'failed',
            error_message = p_error_message,
            updated_at = now()
        WHERE id = p_payment_id;

        UPDATE public.consultations SET
            payment_status = 'failed',
            status = 'expired',
            updated_at = now()
        WHERE id = v_payment.consultation_id;

        INSERT INTO public.payment_audit_logs (
            payment_id, consultation_id, action, notes
        ) VALUES (
            p_payment_id, v_payment.consultation_id, 'PAYMENT_FAILED', p_error_message
        );

        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'failed',
            'error', p_error_message
        );
    END IF;

    -- Verify amount matches expected tiyin exactly
    IF p_paid_amount_tiyin != v_payment.amount_tiyin THEN
        UPDATE public.payments SET
            status = 'failed',
            error_message = 'Amount mismatch: expected ' || v_payment.amount_tiyin || ' got ' || p_paid_amount_tiyin,
            updated_at = now()
        WHERE id = p_payment_id;

        UPDATE public.consultations SET
            status = 'disputed',
            payment_status = 'failed',
            updated_at = now()
        WHERE id = v_payment.consultation_id;

        RAISE EXCEPTION 'Amount Mismatch: To''lov summasi mos kelmadi.';
    END IF;

    -- Generate meeting link
    v_meeting_link := 'https://meet.lexhub.uz/room/' || v_consultation.id::text;

    -- Update Payment to PAID
    UPDATE public.payments SET
        status = 'paid',
        provider_transaction_id = p_provider_transaction_id,
        paid_at = now(),
        updated_at = now()
    WHERE id = p_payment_id;

    -- Update Consultation to CONFIRMED
    UPDATE public.consultations SET
        status = 'confirmed',
        payment_status = 'paid',
        meeting_link = v_meeting_link,
        updated_at = now()
    WHERE id = v_payment.consultation_id;

    -- Record Audit Log
    INSERT INTO public.payment_audit_logs (
        payment_id,
        consultation_id,
        action,
        old_state,
        new_state,
        provider_reference,
        notes
    ) VALUES (
        p_payment_id,
        v_payment.consultation_id,
        'PAYMENT_CAPTURED',
        jsonb_build_object('payment_status', 'pending', 'consultation_status', 'awaiting_payment'),
        jsonb_build_object('payment_status', 'paid', 'consultation_status', 'confirmed'),
        p_provider_transaction_id,
        'Payment captured and consultation confirmed.'
    );

    -- Notify Citizen
    INSERT INTO public.user_notifications (
        user_id,
        title,
        message,
        type,
        data
    ) VALUES (
        v_consultation.citizen_id,
        'Konsultatsiya tasdiqlandi!',
        'Advokat bilan uchrashuv muvaffaqiyatli band qilindi. Xona havolasi tayyor.',
        'consultation_confirmed',
        jsonb_build_object('consultation_id', v_consultation.id, 'meeting_link', v_meeting_link)
    );

    -- Notify Expert
    INSERT INTO public.user_notifications (
        user_id,
        title,
        message,
        type,
        data
    ) VALUES (
        v_consultation.expert_user_id,
        'Yangi konsultatsiya buyurtmasi!',
        v_consultation.citizen_name || ' siz bilan konsultatsiya band qildi.',
        'consultation_booked',
        jsonb_build_object('consultation_id', v_consultation.id, 'meeting_link', v_meeting_link)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'consultation_id', v_consultation.id,
        'payment_id', p_payment_id,
        'status', 'confirmed',
        'payment_status', 'paid',
        'meeting_link', v_meeting_link
    );
END;
$$;


-- 11. RPC: CANCEL CONSULTATION (Policy-Grounded Refund Calculator)
CREATE OR REPLACE FUNCTION public.cancel_consultation(
    p_consultation_id UUID,
    p_reason TEXT DEFAULT 'Foydalanuvchi tomonidan bekor qilindi'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_consultation RECORD;
    v_hours_until_start NUMERIC;
    v_refund_percent NUMERIC := 0.0;
    v_refund_tiyin BIGINT := 0;
    v_is_expert BOOLEAN := FALSE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- Fetch consultation
    SELECT c.*, ep.user_id AS expert_user_id
    INTO v_consultation
    FROM public.consultations c
    JOIN public.expert_profiles ep ON c.expert_id = ep.id
    WHERE c.id = p_consultation_id
    FOR UPDATE;

    IF v_consultation.id IS NULL THEN
        RAISE EXCEPTION 'Consultation not found.';
    END IF;

    -- Authorization check
    IF v_user_id = v_consultation.expert_user_id THEN
        v_is_expert := TRUE;
    ELSIF v_user_id != v_consultation.citizen_id AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Faqat fuqaro yoki advokat bekor qila oladi.';
    END IF;

    -- State check
    IF v_consultation.status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN
        RAISE EXCEPTION 'Invalid state transition: Ushbu holatdagi konsultatsiyani bekor qilib bo''lmaydi.';
    END IF;

    -- Refund Policy Calculation
    IF v_consultation.payment_status = 'paid' THEN
        IF v_is_expert THEN
            -- Expert cancelled: 100% full refund
            v_refund_percent := 1.00;
        ELSE
            -- Citizen cancelled: time-tiered refund
            v_hours_until_start := EXTRACT(EPOCH FROM (v_consultation.scheduled_at - now())) / 3600.0;
            
            IF v_hours_until_start > 24.0 THEN
                v_refund_percent := 1.00; -- > 24h: 100%
            ELSIF v_hours_until_start >= 2.0 THEN
                v_refund_percent := 0.80; -- 2-24h: 80%
            ELSE
                v_refund_percent := 0.00; -- < 2h: 0%
            END IF;
        END IF;

        v_refund_tiyin := ROUND(v_consultation.price_amount_tiyin * v_refund_percent)::BIGINT;
    END IF;

    -- Update consultation
    UPDATE public.consultations SET
        status = 'cancelled',
        payment_status = CASE 
            WHEN v_refund_percent = 1.00 THEN 'refunded'::payment_status
            WHEN v_refund_percent > 0.00 THEN 'partially_refunded'::payment_status
            ELSE payment_status
        END,
        cancelled_by = v_user_id,
        cancelled_at = now(),
        cancellation_reason = p_reason,
        refund_amount_tiyin = v_refund_tiyin,
        updated_at = now()
    WHERE id = p_consultation_id;

    -- Record Audit Log
    INSERT INTO public.payment_audit_logs (
        consultation_id,
        actor_id,
        action,
        old_state,
        new_state,
        notes
    ) VALUES (
        p_consultation_id,
        v_user_id,
        'CONSULTATION_CANCELLED',
        jsonb_build_object('status', v_consultation.status, 'payment_status', v_consultation.payment_status),
        jsonb_build_object('status', 'cancelled', 'refund_amount_tiyin', v_refund_tiyin, 'refund_percent', (v_refund_percent * 100)),
        p_reason
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'consultation_id', p_consultation_id,
        'status', 'cancelled',
        'refund_percent', (v_refund_percent * 100),
        'refund_amount_uzs', (v_refund_tiyin / 100.0),
        'refund_amount_tiyin', v_refund_tiyin
    );
END;
$$;
