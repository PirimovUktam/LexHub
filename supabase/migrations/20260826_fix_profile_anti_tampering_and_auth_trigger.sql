-- ==============================================================================
-- MIGRATION: 20260826_fix_profile_anti_tampering_and_auth_trigger.sql
-- LexHub Platform — Fix Profile Anti-Tampering Trigger & Auth SignUp Trigger
-- ==============================================================================

-- 1. Ensure user_role enum exists
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

-- 2. Fix Anti-Tampering Trigger Function on Profiles
-- Must whitelist supabase_auth_admin and ONLY run on UPDATE where OLD is NOT NULL
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Only evaluate on UPDATE operations and skip for internal administrative roles
    IF (TG_OP = 'UPDATE' 
        AND current_user NOT IN ('service_role', 'postgres', 'supabase_auth_admin', 'supabase_admin') 
        AND session_user NOT IN ('postgres', 'supabase_auth_admin', 'supabase_admin')) THEN
        
        IF OLD IS NOT NULL AND NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Privilege Escalation Blocked: Role can only be modified by system administrators.';
        END IF;
        IF OLD IS NOT NULL AND NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
            RAISE EXCEPTION 'Verification Escalation Blocked: Verification status can only be granted by administrators.';
        END IF;
        IF OLD IS NOT NULL AND NEW.reputation_points IS DISTINCT FROM OLD.reputation_points THEN
            RAISE EXCEPTION 'Reputation Points Tampering Blocked.';
        END IF;
        IF OLD IS NOT NULL AND NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Profile ID is immutable.';
        END IF;
        IF OLD IS NOT NULL AND NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            NEW.created_at := OLD.created_at;
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Re-attach trg_protect_profile_sensitive_fields ONLY to BEFORE UPDATE
DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_sensitive_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_sensitive_fields();

-- 3. Fix Anti-Tampering Trigger Function on Expert Profiles
CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE' 
        AND current_user NOT IN ('service_role', 'postgres', 'supabase_auth_admin', 'supabase_admin') 
        AND session_user NOT IN ('postgres', 'supabase_auth_admin', 'supabase_admin')) THEN
        
        IF OLD IS NOT NULL AND NEW.rating IS DISTINCT FROM OLD.rating THEN
            RAISE EXCEPTION 'Rating Tampering Blocked: Ratings are computed automatically from verified reviews.';
        END IF;
        IF OLD IS NOT NULL AND NEW.reviews_count IS DISTINCT FROM OLD.reviews_count THEN
            RAISE EXCEPTION 'Reviews Count Tampering Blocked.';
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_protect_expert_profile_sensitive_fields ON public.expert_profiles;
CREATE TRIGGER trg_protect_expert_profile_sensitive_fields
BEFORE UPDATE ON public.expert_profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_expert_profile_sensitive_fields();

-- 4. Clean and Resilient handle_new_user() Trigger on auth.users
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
        'citizen'::user_role,
        10,
        FALSE
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
        updated_at = now();
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    BEGIN
        INSERT INTO public.profiles (id, full_name, role, reputation_points, is_verified)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Foydalanuvchi'), 'citizen'::user_role, 10, FALSE)
        ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Profiles RLS Policies Verification
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);
