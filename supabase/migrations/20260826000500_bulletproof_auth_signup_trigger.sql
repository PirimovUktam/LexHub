-- ==============================================================================
-- MIGRATION: 20260826_bulletproof_auth_signup_trigger.sql
-- LexHub Platform — Safe Auth User Signup Trigger Reconciliation
-- Prevents "Database error saving new user" 500 error on client registration
-- ==============================================================================

-- 1. Ensure user_role enum and all values exist
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

-- 2. Resilient handle_new_user() trigger function
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
        full_name = EXCLUDED.full_name,
        updated_at = now();
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Fallback insertion with minimal parameters to ensure auth user creation never fails
    BEGIN
        INSERT INTO public.profiles (id, full_name, role, reputation_points, is_verified)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Foydalanuvchi'), 'citizen'::user_role, 10, FALSE)
        ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Re-attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Enable Profiles RLS & ensure INSERT policy exists
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
