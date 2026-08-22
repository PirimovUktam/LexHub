-- ==============================================================================
-- MIGRATION: 20260821_expert_verification_and_privacy.sql
-- LexHub Platform — Expert Verification, Lawyer System & Privacy Shield
-- Idempotent Migration with Complete Pre-Requisite Dependencies
-- Fully Resilient against 22P02 Enum Casting Issues
-- ==============================================================================

-- 1. EXTENSIONS & ENUMS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('citizen', 'lawyer', 'verified_expert', 'moderator', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'citizen';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'lawyer';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'verified_expert';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'moderator';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'admin';

-- 2. HELPER FUNCTION: is_admin_or_moderator (Text-safe)
CREATE OR REPLACE FUNCTION public.is_admin_or_moderator()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role::text IN ('moderator', 'admin')
  );
$$;

-- 3. ENSURE BASE TABLE: expert_profiles EXISTS
CREATE TABLE IF NOT EXISTS public.expert_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    license_number VARCHAR(64) UNIQUE,
    license_document_url TEXT,
    specialization VARCHAR(128) NOT NULL DEFAULT 'Umumiy huquq',
    experience_years INTEGER DEFAULT 1 NOT NULL CHECK (experience_years >= 0),
    education TEXT,
    workplace VARCHAR(255),
    rating NUMERIC(3, 2) DEFAULT 5.00 NOT NULL CHECK (rating >= 0.00 AND rating <= 5.00),
    reviews_count INTEGER DEFAULT 0 NOT NULL CHECK (reviews_count >= 0),
    consultation_fee NUMERIC(12, 2) DEFAULT 0.00 NOT NULL CHECK (consultation_fee >= 0.00), -- UZS
    is_available_for_booking BOOLEAN DEFAULT TRUE NOT NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS license_number VARCHAR(64);
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS license_document_url TEXT;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS specialization VARCHAR(128) NOT NULL DEFAULT 'Umumiy huquq';
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS experience_years INTEGER DEFAULT 1 NOT NULL;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS education TEXT;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS workplace VARCHAR(255);
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2) DEFAULT 5.00 NOT NULL;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS reviews_count INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(12, 2) DEFAULT 0.00 NOT NULL;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS is_available_for_booking BOOLEAN DEFAULT TRUE NOT NULL;
ALTER TABLE public.expert_profiles ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- Indices on expert_profiles
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'expert_profiles' AND column_name = 'user_id'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_expert_profiles_user_id ON public.expert_profiles(user_id);
    END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'expert_profiles' AND column_name = 'specialization'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_expert_profiles_specialization ON public.expert_profiles(specialization);
    END IF;
END $$;

-- 4. ANTI-TAMPERING TRIGGER ON expert_profiles
CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF (current_user != 'service_role' AND session_user != 'postgres') THEN
        IF NEW.rating IS DISTINCT FROM OLD.rating THEN
            RAISE EXCEPTION 'Rating Tampering Blocked: Ratings are computed automatically from verified reviews.';
        END IF;
        IF NEW.reviews_count IS DISTINCT FROM OLD.reviews_count THEN
            RAISE EXCEPTION 'Reviews Count Tampering Blocked.';
        END IF;
        IF NEW.verified_at IS DISTINCT FROM OLD.verified_at THEN
            RAISE EXCEPTION 'Expert verification date is managed by administrators.';
        END IF;
        IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
            RAISE EXCEPTION 'Expert user_id is immutable.';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'expert_profiles') THEN
        DROP TRIGGER IF EXISTS trg_protect_expert_profile_sensitive_fields ON public.expert_profiles;
        CREATE TRIGGER trg_protect_expert_profile_sensitive_fields
        BEFORE UPDATE ON public.expert_profiles
        FOR EACH ROW EXECUTE FUNCTION public.protect_expert_profile_sensitive_fields();
    END IF;
END $$;

-- 5. CREATE PUBLIC EXPERT PROFILES VIEW (Masks sensitive license document URLs)
CREATE OR REPLACE VIEW public.public_expert_profiles_view AS
SELECT
    ep.id AS expert_id,
    ep.user_id,
    p.full_name,
    p.avatar_url,
    p.phone,
    p.role,
    p.is_verified AS is_profile_verified,
    ep.specialization,
    ep.experience_years,
    ep.education,
    ep.workplace,
    ep.rating,
    ep.reviews_count,
    ep.consultation_fee,
    ep.is_available_for_booking,
    ep.verified_at,
    ep.created_at,
    ep.updated_at
FROM public.expert_profiles ep
JOIN public.profiles p ON ep.user_id = p.id
WHERE p.is_verified = TRUE AND p.role::text IN ('verified_expert', 'lawyer');

-- 6. HARDENED BASE TABLE RLS: Only Owner or Admin can read raw expert_profiles
ALTER TABLE public.expert_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Expert profiles viewable by everyone" ON public.expert_profiles;
DROP POLICY IF EXISTS "Expert profiles viewable by owner or admin" ON public.expert_profiles;
CREATE POLICY "Expert profiles viewable by owner or admin" ON public.expert_profiles 
FOR SELECT USING (
    auth.uid() = user_id 
    OR public.is_admin_or_moderator()
);

DROP POLICY IF EXISTS "Experts can create or apply for profile" ON public.expert_profiles;
CREATE POLICY "Experts can create or apply for profile" ON public.expert_profiles 
FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' 
    AND auth.uid() = user_id
);

DROP POLICY IF EXISTS "Experts can update their profile" ON public.expert_profiles;
CREATE POLICY "Experts can update their profile" ON public.expert_profiles 
FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 7. STORED PROCEDURE: Apply for Expert Verification (Citizen -> Lawyer Application)
CREATE OR REPLACE FUNCTION public.apply_for_expert_verification(
    p_specialization VARCHAR(128),
    p_experience_years INTEGER,
    p_license_number VARCHAR(64),
    p_license_document_url TEXT DEFAULT NULL,
    p_workplace VARCHAR(255) DEFAULT NULL,
    p_education TEXT DEFAULT NULL,
    p_consultation_fee NUMERIC(12, 2) DEFAULT 0.00
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_expert_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to apply for expert verification.';
    END IF;

    -- Upsert expert profile in pending verification state (verified_at remains NULL)
    INSERT INTO public.expert_profiles (
        user_id,
        specialization,
        experience_years,
        license_number,
        license_document_url,
        workplace,
        education,
        consultation_fee,
        verified_at,
        is_available_for_booking
    )
    VALUES (
        v_user_id,
        p_specialization,
        GREATEST(0, p_experience_years),
        p_license_number,
        p_license_document_url,
        p_workplace,
        p_education,
        p_consultation_fee,
        NULL, -- Pending approval
        TRUE
    )
    ON CONFLICT (user_id) DO UPDATE SET
        specialization = EXCLUDED.specialization,
        experience_years = EXCLUDED.experience_years,
        license_number = EXCLUDED.license_number,
        license_document_url = COALESCE(EXCLUDED.license_document_url, expert_profiles.license_document_url),
        workplace = EXCLUDED.workplace,
        education = EXCLUDED.education,
        consultation_fee = EXCLUDED.consultation_fee,
        updated_at = now()
    RETURNING id INTO v_expert_id;

    RETURN jsonb_build_object(
        'success', true,
        'expert_id', v_expert_id,
        'status', 'pending_verification',
        'message', 'Ariza muvaffaqiyatli topshirildi. Ma''muriyat tomonidan tekshirilgach tasdiqlanadi.'
    );
END;
$$;

-- 8. STORED PROCEDURE: Admin Verify / Approve Expert Application
CREATE OR REPLACE FUNCTION public.verify_expert_application(
    p_target_user_id UUID,
    p_approve BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only Admin or Moderator can verify applications
    IF NOT public.is_admin_or_moderator() AND current_user != 'service_role' THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can approve expert applications.';
    END IF;

    IF p_approve THEN
        -- Update Profile Role & Verification
        UPDATE public.profiles
        SET 
            role = 'verified_expert',
            is_verified = TRUE,
            updated_at = now()
        WHERE id = p_target_user_id;

        -- Update Expert Profile Verification timestamp
        UPDATE public.expert_profiles
        SET 
            verified_at = now(),
            updated_at = now()
        WHERE user_id = p_target_user_id;

        RETURN jsonb_build_object('success', true, 'status', 'approved');
    ELSE
        -- Reject application
        UPDATE public.expert_profiles
        SET 
            verified_at = NULL,
            updated_at = now()
        WHERE user_id = p_target_user_id;

        RETURN jsonb_build_object('success', true, 'status', 'rejected');
    END IF;
END;
$$;

-- 9. TRIGGER: Enforce that only verified experts can submit is_expert_answer = true
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'answers') THEN
        CREATE OR REPLACE FUNCTION public.enforce_expert_answer()
        RETURNS TRIGGER AS $func$
        DECLARE
            v_user_role text;
            v_is_verified BOOLEAN;
        BEGIN
            IF NEW.is_expert_answer = TRUE THEN
                SELECT role::text, is_verified INTO v_user_role, v_is_verified 
                FROM public.profiles 
                WHERE id = NEW.user_id;

                IF v_user_role NOT IN ('verified_expert', 'lawyer') OR v_is_verified IS NOT TRUE THEN
                    -- Non-verified user cannot claim is_expert_answer = true
                    NEW.is_expert_answer := FALSE;
                END IF;
            END IF;
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

        DROP TRIGGER IF EXISTS trg_enforce_expert_answer ON public.answers;
        CREATE TRIGGER trg_enforce_expert_answer
        BEFORE INSERT OR UPDATE OF is_expert_answer ON public.answers
        FOR EACH ROW EXECUTE FUNCTION public.enforce_expert_answer();
    END IF;
END $$;
