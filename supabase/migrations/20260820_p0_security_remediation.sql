-- ==============================================================================
-- MIGRATION: 20260820_p0_security_remediation.sql
-- LexHub Platform — P0 Security Remediation & Hardening Migration
-- Dependencies: 20260819_base_schema.sql (profiles, expert_profiles, questions, reports, votes)
-- Fully Resilient against 22P02 Enum & 42703 Column Missing Issues
-- ==============================================================================

-- 0. Ensure Enum Values Exist
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'citizen';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'lawyer';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'verified_expert';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'moderator';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'admin';

-- 1. Anti-Escalation Trigger on Profiles
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF (current_user != 'service_role' AND session_user != 'postgres') THEN
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_fields ON public.profiles;
        CREATE TRIGGER trg_protect_profile_sensitive_fields
        BEFORE UPDATE ON public.profiles
        FOR EACH ROW EXECUTE FUNCTION public.protect_profile_sensitive_fields();
    END IF;
END $$;

-- 2. Anti-Tampering Trigger on Expert Profiles
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

-- 3. Is Moderator / Admin Helper Function (Text-safe to prevent 22P02)
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

-- 3.1. Auto-create Profile Trigger on New Auth User Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id, 
        full_name, 
        avatar_url, 
        phone, 
        role, 
        reputation_points, 
        is_verified
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Foydalanuvchi'),
        NEW.raw_user_meta_data->>'avatar_url',
        NEW.phone,
        'citizen',
        10,
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Anonymous Question Identity Shield View (With Safe Column Reconciliation)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'questions') THEN
        -- Reconcile columns to prevent 42703
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS title VARCHAR(255);
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS description TEXT;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS content TEXT;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS anonymized_question TEXT;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS category_id VARCHAR(64);
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS status question_status DEFAULT 'open';
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS upvotes_count INTEGER DEFAULT 0;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS answers_count INTEGER DEFAULT 0;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS is_ai_analyzed BOOLEAN DEFAULT FALSE;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS ai_summary TEXT;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS ai_clarifications JSONB;
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
        ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

        -- Reconcile description content
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'questions' AND column_name = 'content'
        ) THEN
            UPDATE public.questions SET description = content WHERE (description IS NULL OR description = '') AND content IS NOT NULL;
        END IF;

        CREATE OR REPLACE VIEW public.public_questions_view AS
        SELECT
            q.id,
            q.category_id,
            q.title,
            COALESCE(q.description, q.content, q.anonymized_question, '') AS description,
            COALESCE(q.description, q.content, q.anonymized_question, '') AS anonymized_question,
            q.is_anonymous,
            q.status,
            q.views_count,
            q.upvotes_count,
            q.answers_count,
            q.is_ai_analyzed,
            q.ai_summary,
            q.ai_clarifications,
            q.created_at,
            q.updated_at,
            CASE 
                WHEN q.is_anonymous THEN NULL 
                ELSE q.user_id 
            END AS user_id,
            CASE 
                WHEN q.is_anonymous THEN 'Anonim fuqaro' 
                ELSE p.full_name 
            END AS author_name,
            CASE 
                WHEN q.is_anonymous THEN NULL 
                ELSE p.avatar_url 
            END AS author_avatar_url,
            CASE 
                WHEN q.is_anonymous THEN FALSE 
                ELSE p.is_verified 
            END AS author_is_verified
        FROM public.questions q
        LEFT JOIN public.profiles p ON q.user_id = p.id;
    END IF;
END $$;

-- 5. Reports Table Security Hardening
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reports') THEN
        ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Moderators and Admins can view reports" ON public.reports;
        CREATE POLICY "Moderators and Admins can view reports" ON public.reports 
        FOR SELECT USING (public.is_admin_or_moderator());

        DROP POLICY IF EXISTS "Moderators and Admins can update reports" ON public.reports;
        CREATE POLICY "Moderators and Admins can update reports" ON public.reports 
        FOR UPDATE USING (public.is_admin_or_moderator()) WITH CHECK (public.is_admin_or_moderator());

        DROP POLICY IF EXISTS "Admins can delete reports" ON public.reports;
        CREATE POLICY "Admins can delete reports" ON public.reports 
        FOR DELETE USING (
          EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role::text = 'admin'
          )
        );
    END IF;
END $$;

-- 6. Base Questions Table Privacy Hardening
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'questions') THEN
        ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Questions are viewable by everyone" ON public.questions;
        DROP POLICY IF EXISTS "Public questions are viewable by everyone" ON public.questions;
        CREATE POLICY "Public questions are viewable by everyone" ON public.questions 
        FOR SELECT USING (
            is_anonymous = false 
            OR auth.uid() = user_id 
            OR public.is_admin_or_moderator()
        );
    END IF;
END $$;

-- 7. Votes Privacy Hardening
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'votes') THEN
        ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Votes readable by everyone" ON public.votes;
        DROP POLICY IF EXISTS "Users can view own votes" ON public.votes;
        CREATE POLICY "Users can view own votes" ON public.votes FOR SELECT USING (auth.uid() = user_id);
    END IF;
END $$;
