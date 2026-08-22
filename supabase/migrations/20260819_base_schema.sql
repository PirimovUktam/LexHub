-- ==============================================================================
-- MIGRATION: 20260819_base_schema.sql
-- LexHub Platform — Initial Base Database Schema
-- Fully Self-Healing, Resilient Enum & Column Reconciliation
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. ENUMS & RESILIENT TYPE EXPANSION
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

DO $$ BEGIN
    CREATE TYPE question_status AS ENUM ('open', 'answered', 'resolved', 'closed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE question_status ADD VALUE IF NOT EXISTS 'open';
ALTER TYPE question_status ADD VALUE IF NOT EXISTS 'answered';
ALTER TYPE question_status ADD VALUE IF NOT EXISTS 'resolved';
ALTER TYPE question_status ADD VALUE IF NOT EXISTS 'closed';

DO $$ BEGIN
    CREATE TYPE vote_target_type AS ENUM ('question', 'answer');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE vote_target_type ADD VALUE IF NOT EXISTS 'question';
ALTER TYPE vote_target_type ADD VALUE IF NOT EXISTS 'answer';

DO $$ BEGIN
    CREATE TYPE consultation_status AS ENUM ('pending', 'confirmed', 'completed', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'confirmed';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'completed';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'cancelled';

DO $$ BEGIN
    CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved', 'dismissed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'reviewed';
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'resolved';
ALTER TYPE report_status ADD VALUE IF NOT EXISTS 'dismissed';

-- 3. PROFILES TABLE & COLUMN RECONCILIATION
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(128) NOT NULL DEFAULT 'Foydalanuvchi',
    avatar_url TEXT,
    phone VARCHAR(32),
    role user_role DEFAULT 'citizen' NOT NULL,
    reputation_points INTEGER DEFAULT 0 NOT NULL CHECK (reputation_points >= 0),
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name VARCHAR(128) NOT NULL DEFAULT 'Foydalanuvchi';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone VARCHAR(32);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role user_role DEFAULT 'citizen' NOT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reputation_points INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- 4. EXPERT PROFILES TABLE & COLUMN RECONCILIATION
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
    consultation_fee NUMERIC(12, 2) DEFAULT 0.00 NOT NULL CHECK (consultation_fee >= 0.00),
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

-- 5. QUESTION CATEGORIES & TAGS
CREATE TABLE IF NOT EXISTS public.question_categories (
    id VARCHAR(64) PRIMARY KEY,
    name_uz VARCHAR(128) NOT NULL,
    name_ru VARCHAR(128) NOT NULL,
    description TEXT,
    icon_name VARCHAR(64) DEFAULT 'help_outline' NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.question_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) UNIQUE NOT NULL,
    slug VARCHAR(64) UNIQUE NOT NULL,
    usage_count INTEGER DEFAULT 0 NOT NULL CHECK (usage_count >= 0)
);

-- 6. QUESTIONS TABLE & COLUMN RECONCILIATION
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    category_id VARCHAR(64) REFERENCES public.question_categories(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    is_anonymous BOOLEAN DEFAULT FALSE NOT NULL,
    status question_status DEFAULT 'open' NOT NULL,
    views_count INTEGER DEFAULT 0 NOT NULL CHECK (views_count >= 0),
    upvotes_count INTEGER DEFAULT 0 NOT NULL CHECK (upvotes_count >= 0),
    answers_count INTEGER DEFAULT 0 NOT NULL CHECK (answers_count >= 0),
    is_ai_analyzed BOOLEAN DEFAULT FALSE NOT NULL,
    ai_summary TEXT,
    ai_clarifications JSONB,
    search_vector tsvector,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS category_id VARCHAR(64) REFERENCES public.question_categories(id) ON DELETE SET NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS content TEXT;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS anonymized_question TEXT;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS status question_status DEFAULT 'open' NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS upvotes_count INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS answers_count INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS is_ai_analyzed BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS ai_summary TEXT;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS ai_clarifications JSONB;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS search_vector tsvector;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- Backfill description if existing table used alternative column names
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'questions' AND column_name = 'content'
    ) THEN
        UPDATE public.questions SET description = content WHERE (description IS NULL OR description = '') AND content IS NOT NULL;
    END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'questions' AND column_name = 'anonymized_question'
    ) THEN
        UPDATE public.questions SET description = anonymized_question WHERE (description IS NULL OR description = '') AND anonymized_question IS NOT NULL;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.question_tag_mappings (
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.question_tags(id) ON DELETE CASCADE,
    PRIMARY KEY (question_id, tag_id)
);

-- 7. ANSWERS TABLE & COLUMN RECONCILIATION
CREATE TABLE IF NOT EXISTS public.answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL DEFAULT '',
    is_expert_answer BOOLEAN DEFAULT FALSE NOT NULL,
    is_accepted BOOLEAN DEFAULT FALSE NOT NULL,
    upvotes_count INTEGER DEFAULT 0 NOT NULL CHECK (upvotes_count >= 0),
    legal_references JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.answers ADD COLUMN IF NOT EXISTS content TEXT;
ALTER TABLE public.answers ADD COLUMN IF NOT EXISTS body TEXT;
ALTER TABLE public.answers ADD COLUMN IF NOT EXISTS is_expert_answer BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.answers ADD COLUMN IF NOT EXISTS is_accepted BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.answers ADD COLUMN IF NOT EXISTS upvotes_count INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE public.answers ADD COLUMN IF NOT EXISTS legal_references JSONB;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'answers' AND column_name = 'body'
    ) THEN
        UPDATE public.answers SET content = body WHERE (content IS NULL OR content = '') AND body IS NOT NULL;
    END IF;
END $$;

-- 8. VOTES TABLE & COLUMN RECONCILIATION
CREATE TABLE IF NOT EXISTS public.votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type vote_target_type NOT NULL,
    target_id UUID NOT NULL,
    vote_value SMALLINT NOT NULL CHECK (vote_value IN (-1, 1)),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (user_id, target_type, target_id)
);

ALTER TABLE public.votes ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.votes ADD COLUMN IF NOT EXISTS target_type vote_target_type;
ALTER TABLE public.votes ADD COLUMN IF NOT EXISTS target_id UUID;
ALTER TABLE public.votes ADD COLUMN IF NOT EXISTS vote_value SMALLINT DEFAULT 1;

-- 9. CITIZEN SERVICES & SERVICE STEPS
CREATE TABLE IF NOT EXISTS public.citizen_services (
    id VARCHAR(64) PRIMARY KEY,
    category_id VARCHAR(64) REFERENCES public.question_categories(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    department VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    cost_bhm_percent NUMERIC(5, 2) DEFAULT 0.00 NOT NULL CHECK (cost_bhm_percent >= 0.00),
    is_free BOOLEAN DEFAULT FALSE NOT NULL,
    processing_days INTEGER DEFAULT 1 NOT NULL CHECK (processing_days >= 0),
    required_documents TEXT[] DEFAULT '{}',
    online_url TEXT,
    deadline_law_reference TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.service_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id VARCHAR(64) NOT NULL REFERENCES public.citizen_services(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL CHECK (step_number > 0),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    warning_note TEXT,
    UNIQUE (service_id, step_number)
);

-- 10. DOCUMENT TEMPLATES
CREATE TABLE IF NOT EXISTS public.document_templates (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    target_authority VARCHAR(255) NOT NULL,
    required_fields JSONB NOT NULL,
    body_template TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 11. CONSULTATIONS
CREATE TABLE IF NOT EXISTS public.consultations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citizen_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    expert_id UUID NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.questions(id) ON DELETE SET NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    status consultation_status DEFAULT 'pending' NOT NULL,
    fee NUMERIC(12, 2) NOT NULL CHECK (fee >= 0.00),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 12. REPORTS TABLE & COLUMN RECONCILIATION
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type VARCHAR(32) NOT NULL DEFAULT 'question',
    target_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status report_status DEFAULT 'pending' NOT NULL,
    reviewed_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS target_type VARCHAR(32) NOT NULL DEFAULT 'question';
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS target_id UUID;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS status report_status DEFAULT 'pending' NOT NULL;
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id);

-- 13. BOOKMARKS TABLE & COLUMN RECONCILIATION
CREATE TABLE IF NOT EXISTS public.bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_type VARCHAR(32) NOT NULL CHECK (item_type IN ('question', 'service', 'document', 'law')),
    item_id VARCHAR(128) NOT NULL,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (user_id, item_type, item_id)
);

ALTER TABLE public.bookmarks ADD COLUMN IF NOT EXISTS item_type VARCHAR(32);
ALTER TABLE public.bookmarks ADD COLUMN IF NOT EXISTS item_id VARCHAR(128);

-- 14. LAW ARTICLE CHUNKS (PGVECTOR)
CREATE TABLE IF NOT EXISTS public.law_article_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id VARCHAR(128) UNIQUE NOT NULL,
    document_name VARCHAR(255) NOT NULL,
    document_id VARCHAR(64) NOT NULL,
    article_number INTEGER NOT NULL CHECK (article_number > 0),
    article_title VARCHAR(512) NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(32) DEFAULT 'active' NOT NULL CHECK (status IN ('active', 'repealed', 'amended')),
    jurisdiction VARCHAR(128) NOT NULL,
    last_updated DATE NOT NULL,
    lex_url TEXT NOT NULL,
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.law_article_chunks ADD COLUMN IF NOT EXISTS chunk_id VARCHAR(128);
ALTER TABLE public.law_article_chunks ADD COLUMN IF NOT EXISTS embedding vector(1536);

-- 15. BASE INDICES (Conditional on Column Existence)
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'expert_profiles' AND column_name = 'user_id'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_expert_profiles_user_id ON public.expert_profiles(user_id);
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'questions' AND column_name = 'user_id'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_questions_user_id ON public.questions(user_id);
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'questions' AND column_name = 'category_id'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_questions_category_id ON public.questions(category_id);
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'answers' AND column_name = 'question_id'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_answers_question_id ON public.answers(question_id);
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'votes' AND column_name = 'target_type'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_votes_target ON public.votes(target_type, target_id);
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'law_article_chunks' AND column_name = 'status'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_law_chunks_status ON public.law_article_chunks(status);
    END IF;
END $$;

-- 16. BASIC AUTH TRIGGER
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
