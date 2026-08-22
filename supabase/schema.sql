-- ==============================================================================
-- LEXHUB PLATFORM — PRODUCTION DATABASE SCHEMA & HARDENED SECURITY POLICIES
-- Uzbekistan Legal-Tech Architecture: AI + Community + Experts + Official Sources
-- SPRINT 1 P0 HARDENING: Anti-Escalation, Strict RLS, Anonymous Identity Shield
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ==============================================================================
-- 2. CORE ENUMS & TYPES
-- ==============================================================================
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

-- ==============================================================================
-- 3. PROFILES & USER ROLES (P0 HARDENED)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(128) NOT NULL,
    avatar_url TEXT,
    phone VARCHAR(32),
    role user_role DEFAULT 'citizen' NOT NULL,
    reputation_points INTEGER DEFAULT 0 NOT NULL CHECK (reputation_points >= 0),
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ==============================================================================
-- 4. EXPERT PROFILES & VERIFICATION (P0 HARDENED)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.expert_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    license_number VARCHAR(64) UNIQUE,
    license_document_url TEXT,
    specialization VARCHAR(128) NOT NULL,
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

-- ==============================================================================
-- 5. QUESTION CATEGORIES & TAGS
-- ==============================================================================
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

-- ==============================================================================
-- 6. QUESTIONS (COMMUNITY Q&A + AI INSIGHTS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    category_id VARCHAR(64) REFERENCES public.question_categories(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
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

CREATE TABLE IF NOT EXISTS public.question_tag_mappings (
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.question_tags(id) ON DELETE CASCADE,
    PRIMARY KEY (question_id, tag_id)
);

-- ==============================================================================
-- 7. ANSWERS (COMMUNITY & VERIFIED EXPERTS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_expert_answer BOOLEAN DEFAULT FALSE NOT NULL,
    is_accepted BOOLEAN DEFAULT FALSE NOT NULL,
    upvotes_count INTEGER DEFAULT 0 NOT NULL CHECK (upvotes_count >= 0),
    legal_references JSONB, -- list of Lex.uz article links and citations
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ==============================================================================
-- 8. VOTES (UPVOTE / DOWNVOTE)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type vote_target_type NOT NULL,
    target_id UUID NOT NULL,
    vote_value SMALLINT NOT NULL CHECK (vote_value IN (-1, 1)),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (user_id, target_type, target_id)
);

-- ==============================================================================
-- 9. CITIZEN SERVICES & GOVERNMENT GUIDES (MY.GOV.UZ & E-QAROR)
-- ==============================================================================
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
    source_url TEXT,
    legal_basis TEXT,
    last_verified_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    status VARCHAR(32) DEFAULT 'active' NOT NULL,
    is_popular BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.service_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id VARCHAR(64) NOT NULL REFERENCES public.citizen_services(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL CHECK (step_number > 0),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    warning_note TEXT,
    action_url TEXT,
    step_type VARCHAR(32) DEFAULT 'online' NOT NULL,
    UNIQUE (service_id, step_number)
);

-- ==============================================================================
-- 10. LEGAL DOCUMENT TEMPLATES & USER SAVED DOCUMENTS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.document_templates (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    target_authority VARCHAR(255) NOT NULL,
    required_fields JSONB NOT NULL,
    body_template TEXT NOT NULL,
    legal_basis TEXT,
    source_url TEXT,
    last_verified_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    status VARCHAR(32) DEFAULT 'active' NOT NULL,
    is_popular BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    template_id VARCHAR(64) REFERENCES public.document_templates(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(128) NOT NULL,
    form_values JSONB NOT NULL DEFAULT '{}'::jsonb,
    generated_text TEXT NOT NULL,
    legal_basis TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_documents_user_id ON public.user_documents(user_id);


-- ==============================================================================
-- 11. CONSULTATIONS & BOOKING
-- ==============================================================================
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

-- ==============================================================================
-- 12. REPORTS & CONTENT MODERATION (P0 HARDENED)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type VARCHAR(32) NOT NULL, -- 'question', 'answer', 'comment', 'user'
    target_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status report_status DEFAULT 'pending' NOT NULL,
    reviewed_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ==============================================================================
-- 13. BOOKMARKS & SAVED CASES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_type VARCHAR(32) NOT NULL CHECK (item_type IN ('question', 'service', 'document', 'law')),
    item_id VARCHAR(128) NOT NULL,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (user_id, item_type, item_id)
);

-- ==============================================================================
-- 14. LAW ARTICLE CHUNKS (PGVECTOR RAG REPOSITORY)
-- ==============================================================================
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

-- Indices for pgvector & Full-Text Search
CREATE INDEX IF NOT EXISTS idx_law_chunks_status ON public.law_article_chunks(status);
CREATE INDEX IF NOT EXISTS idx_law_chunks_jurisdiction ON public.law_article_chunks(jurisdiction);
CREATE INDEX IF NOT EXISTS idx_law_chunks_document ON public.law_article_chunks(document_id, article_number);
CREATE INDEX IF NOT EXISTS idx_law_chunks_embedding ON public.law_article_chunks 
USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- Vector Similarity Match Function for Legal RAG
CREATE OR REPLACE FUNCTION public.match_law_articles(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.5,
    match_count int DEFAULT 5,
    filter_jurisdiction text DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    chunk_id VARCHAR,
    document_name VARCHAR,
    document_id VARCHAR,
    article_number INTEGER,
    article_title VARCHAR,
    content TEXT,
    status VARCHAR,
    jurisdiction VARCHAR,
    last_updated DATE,
    lex_url TEXT,
    similarity float
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        lac.id,
        lac.chunk_id,
        lac.document_name,
        lac.document_id,
        lac.article_number,
        lac.article_title,
        lac.content,
        lac.status,
        lac.jurisdiction,
        lac.last_updated,
        lac.lex_url,
        (1 - (lac.embedding <=> query_embedding))::float AS similarity
    FROM public.law_article_chunks lac
    WHERE lac.status = 'active'
      AND (filter_jurisdiction IS NULL OR lac.jurisdiction = filter_jurisdiction)
      AND (1 - (lac.embedding <=> query_embedding)) > match_threshold
    ORDER BY lac.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Full text search index on questions
CREATE INDEX IF NOT EXISTS idx_questions_search ON public.questions USING gin(search_vector);

-- Trigger to maintain search_vector on questions
CREATE OR REPLACE FUNCTION public.update_question_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := setweight(to_tsvector('simple', COALESCE(NEW.title, '')), 'A') ||
                         setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_question_search_vector ON public.questions;
CREATE TRIGGER trg_update_question_search_vector
BEFORE INSERT OR UPDATE ON public.questions
FOR EACH ROW EXECUTE FUNCTION public.update_question_search_vector();

-- ==============================================================================
-- 15. P0 HARDENING: ANTI-ESCALATION TRIGGERS & FUNCTIONS
-- ==============================================================================

-- A. Protect Profiles Sensitive Fields (Role Escalation Defense)
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Only service_role or database superuser can modify role, is_verified, reputation_points
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

DROP TRIGGER IF EXISTS trg_protect_profile_sensitive_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_sensitive_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_sensitive_fields();

-- B. Protect Expert Profiles Sensitive Fields (Rating & Verification Defense)
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

DROP TRIGGER IF EXISTS trg_protect_expert_profile_sensitive_fields ON public.expert_profiles;
CREATE TRIGGER trg_protect_expert_profile_sensitive_fields
BEFORE UPDATE ON public.expert_profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_expert_profile_sensitive_fields();

-- Helper function: Is current user Moderator or Admin?
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

-- C. Auto-create Profile Trigger on New Auth User Signup
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
        10, -- 10 welcome reputation points
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 16. P0 HARDENING: ANONYMOUS QUESTION PRIVACY SHIELD (VIEW)
-- ==============================================================================
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
    -- Strict Privacy Shield: Author identity is completely redacted if is_anonymous = true
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

-- 16b. P0 HARDENING: PUBLIC EXPERT PROFILES VIEW (MASKS SENSITIVE LICENSE DOCUMENT URLS)
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
WHERE p.is_verified = TRUE AND p.role IN ('verified_expert', 'lawyer');

-- Stored Procedure: Apply for Expert Verification (Citizen -> Lawyer Application)
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
        NULL,
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

-- Stored Procedure: Admin Verify / Approve Expert Application
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
    IF NOT public.is_admin_or_moderator() AND current_user != 'service_role' THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can approve expert applications.';
    END IF;

    IF p_approve THEN
        UPDATE public.profiles
        SET 
            role = 'verified_expert',
            is_verified = TRUE,
            updated_at = now()
        WHERE id = p_target_user_id;

        UPDATE public.expert_profiles
        SET 
            verified_at = now(),
            updated_at = now()
        WHERE user_id = p_target_user_id;

        RETURN jsonb_build_object('success', true, 'status', 'approved');
    ELSE
        UPDATE public.expert_profiles
        SET 
            verified_at = NULL,
            updated_at = now()
        WHERE user_id = p_target_user_id;

        RETURN jsonb_build_object('success', true, 'status', 'rejected');
    END IF;
END;
$$;

-- Trigger: Enforce that only verified experts can submit is_expert_answer = true
CREATE OR REPLACE FUNCTION public.enforce_expert_answer()
RETURNS TRIGGER AS $$
DECLARE
    v_user_role user_role;
    v_is_verified BOOLEAN;
BEGIN
    IF NEW.is_expert_answer = TRUE THEN
        SELECT role, is_verified INTO v_user_role, v_is_verified 
        FROM public.profiles 
        WHERE id = NEW.user_id;

        IF v_user_role NOT IN ('verified_expert', 'lawyer') OR v_is_verified IS NOT TRUE THEN
            NEW.is_expert_answer := FALSE;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_enforce_expert_answer ON public.answers;
CREATE TRIGGER trg_enforce_expert_answer
BEFORE INSERT OR UPDATE OF is_expert_answer ON public.answers
FOR EACH ROW EXECUTE FUNCTION public.enforce_expert_answer();

-- ==============================================================================
-- 17. RAG & SEARCH FUNCTIONS (STRICT ACTIVE LAW FILTERING)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.search_law_articles(
    query_embedding vector(1536),
    match_threshold float DEFAULT 0.70,
    match_count int DEFAULT 5,
    filter_jurisdiction varchar DEFAULT NULL
)
RETURNS TABLE (
    chunk_id varchar,
    document_name varchar,
    document_id varchar,
    article_number int,
    article_title varchar,
    content text,
    status varchar,
    jurisdiction varchar,
    last_updated date,
    lex_url text,
    similarity float
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.chunk_id,
        c.document_name,
        c.document_id,
        c.article_number,
        c.article_title,
        c.content,
        c.status,
        c.jurisdiction,
        c.last_updated,
        c.lex_url,
        1 - (c.embedding <=> query_embedding) AS similarity
    FROM public.law_article_chunks c
    WHERE 
        c.status = 'active'
        AND (filter_jurisdiction IS NULL OR c.jurisdiction = filter_jurisdiction)
        AND 1 - (c.embedding <=> query_embedding) > match_threshold
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$;

-- Global full-text search across questions, citizen services, and document templates
CREATE OR REPLACE FUNCTION public.global_lexhub_search(query_text text, limit_count int DEFAULT 10)
RETURNS TABLE (
    result_type text,
    id text,
    title text,
    description text,
    category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    -- 1. Questions (Sanitized for Anonymous Posts)
    SELECT 'question'::text, q.id::text, q.title, q.description, COALESCE(q.category_id, 'Umumiy')
    FROM public.questions q
    WHERE q.search_vector @@ plainto_tsquery('simple', query_text)
    UNION ALL
    -- 2. Citizen Services
    SELECT 'service'::text, s.id, s.title, s.description, s.department
    FROM public.citizen_services s
    WHERE s.title ILIKE '%' || query_text || '%' OR s.description ILIKE '%' || query_text || '%'
    UNION ALL
    -- 3. Document Templates
    SELECT 'document'::text, d.id, d.title, d.description, d.category
    FROM public.document_templates d
    WHERE d.title ILIKE '%' || query_text || '%' OR d.description ILIKE '%' || query_text || '%'
    LIMIT limit_count;
END;
$$;

-- ==============================================================================
-- 18. ROW LEVEL SECURITY (RLS) POLICIES (P0 HARDENED)
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expert_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_tag_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.citizen_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.law_article_chunks ENABLE ROW LEVEL SECURITY;

-- 1. Profiles: Public read, owner update (restricted by trigger)
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles 
FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 2. Expert Profiles: Only owner or admin can read raw base table (Public queries use public_expert_profiles_view)
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

-- 3. Categories & Services & Templates & Laws: Public read-only, Admin modify
DROP POLICY IF EXISTS "Categories are readable by everyone" ON public.question_categories;
CREATE POLICY "Categories are readable by everyone" ON public.question_categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Services are readable by everyone" ON public.citizen_services;
CREATE POLICY "Services are readable by everyone" ON public.citizen_services FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service steps are readable by everyone" ON public.service_steps;
CREATE POLICY "Service steps are readable by everyone" ON public.service_steps FOR SELECT USING (true);

DROP POLICY IF EXISTS "Templates are readable by everyone" ON public.document_templates;
CREATE POLICY "Templates are readable by everyone" ON public.document_templates FOR SELECT USING (true);

DROP POLICY IF EXISTS "Active laws readable by everyone" ON public.law_article_chunks;
CREATE POLICY "Active laws readable by everyone" ON public.law_article_chunks FOR SELECT USING (status = 'active');

-- 4. Questions: Non-anonymous questions readable by public, anonymous questions readable ONLY by owner/moderators on base table (Public queries use public_questions_view)
DROP POLICY IF EXISTS "Questions are viewable by everyone" ON public.questions;
DROP POLICY IF EXISTS "Public questions are viewable by everyone" ON public.questions;
CREATE POLICY "Public questions are viewable by everyone" ON public.questions 
FOR SELECT USING (
    is_anonymous = false 
    OR auth.uid() = user_id 
    OR public.is_admin_or_moderator()
);

DROP POLICY IF EXISTS "Authenticated users can create questions" ON public.questions;
CREATE POLICY "Authenticated users can create questions" ON public.questions 
FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Owners can update their questions" ON public.questions;
CREATE POLICY "Owners can update their questions" ON public.questions 
FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Owners can delete their questions" ON public.questions;
CREATE POLICY "Owners can delete their questions" ON public.questions 
FOR DELETE USING (auth.uid() = user_id);

-- 5. Answers: Everyone can read, authenticated can create, owner or question owner (acceptance) can update
DROP POLICY IF EXISTS "Answers are viewable by everyone" ON public.answers;
CREATE POLICY "Answers are viewable by everyone" ON public.answers FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can post answers" ON public.answers;
CREATE POLICY "Authenticated users can post answers" ON public.answers 
FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Authors can update their answer" ON public.answers;
DROP POLICY IF EXISTS "Authors or Question owners can update answer" ON public.answers;
CREATE POLICY "Authors or Question owners can update answer" ON public.answers 
FOR UPDATE USING (
    auth.uid() = user_id 
    OR EXISTS (
        SELECT 1 FROM public.questions 
        WHERE id = answers.question_id AND user_id = auth.uid()
    )
    OR public.is_admin_or_moderator()
) WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
        SELECT 1 FROM public.questions 
        WHERE id = answers.question_id AND user_id = auth.uid()
    )
    OR public.is_admin_or_moderator()
);

-- ==============================================================================
-- 18. COMMUNITY Q&A COUNTERS & ACCEPTANCE TRIGGERS
-- ==============================================================================

-- A. Answers Counter Trigger
CREATE OR REPLACE FUNCTION public.handle_answer_counter()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.questions
        SET answers_count = answers_count + 1,
            updated_at = now()
        WHERE id = NEW.question_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.questions
        SET answers_count = GREATEST(0, answers_count - 1),
            updated_at = now()
        WHERE id = OLD.question_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_handle_answer_counter ON public.answers;
CREATE TRIGGER trg_handle_answer_counter
AFTER INSERT OR DELETE ON public.answers
FOR EACH ROW EXECUTE FUNCTION public.handle_answer_counter();

-- B. Votes Counter Trigger
CREATE OR REPLACE FUNCTION public.handle_vote_counter()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.target_type = 'question' THEN
            UPDATE public.questions
            SET upvotes_count = upvotes_count + 1
            WHERE id = NEW.target_id;
        ELSIF NEW.target_type = 'answer' THEN
            UPDATE public.answers
            SET upvotes_count = upvotes_count + 1
            WHERE id = NEW.target_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.target_type = 'question' THEN
            UPDATE public.questions
            SET upvotes_count = GREATEST(0, upvotes_count - 1)
            WHERE id = OLD.target_id;
        ELSIF OLD.target_type = 'answer' THEN
            UPDATE public.answers
            SET upvotes_count = GREATEST(0, upvotes_count - 1)
            WHERE id = OLD.target_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_handle_vote_counter ON public.votes;
CREATE TRIGGER trg_handle_vote_counter
AFTER INSERT OR DELETE ON public.votes
FOR EACH ROW EXECUTE FUNCTION public.handle_vote_counter();

-- C. Answer Acceptance Trigger
CREATE OR REPLACE FUNCTION public.handle_answer_acceptance()
RETURNS TRIGGER AS $$
DECLARE
    v_question_owner UUID;
BEGIN
    IF (NEW.is_accepted IS DISTINCT FROM OLD.is_accepted) THEN
        SELECT user_id INTO v_question_owner
        FROM public.questions
        WHERE id = NEW.question_id;

        IF (auth.uid() != v_question_owner AND NOT public.is_admin_or_moderator() AND current_user != 'service_role') THEN
            RAISE EXCEPTION 'Unauthorized: Only the question author can accept an answer.';
        END IF;

        IF NEW.is_accepted = TRUE THEN
            UPDATE public.answers
            SET is_accepted = FALSE
            WHERE question_id = NEW.question_id AND id != NEW.id AND is_accepted = TRUE;

            UPDATE public.questions
            SET status = 'answered',
                updated_at = now()
            WHERE id = NEW.question_id;
        END IF;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_handle_answer_acceptance ON public.answers;
CREATE TRIGGER trg_handle_answer_acceptance
BEFORE UPDATE ON public.answers
FOR EACH ROW EXECUTE FUNCTION public.handle_answer_acceptance();

-- 6. Votes: Authenticated users manage own votes, voting records are private to user
DROP POLICY IF EXISTS "Votes readable by everyone" ON public.votes;
DROP POLICY IF EXISTS "Users can view own votes" ON public.votes;
CREATE POLICY "Users can view own votes" ON public.votes FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage their own votes" ON public.votes;
CREATE POLICY "Users can manage their own votes" ON public.votes 
FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 7. Bookmarks: Private to user
DROP POLICY IF EXISTS "Users manage own bookmarks" ON public.bookmarks;
CREATE POLICY "Users manage own bookmarks" ON public.bookmarks 
FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 8. Consultations: Only citizen and assigned expert can view and update
DROP POLICY IF EXISTS "Consultation participants can view" ON public.consultations;
CREATE POLICY "Consultation participants can view" ON public.consultations FOR SELECT 
USING (auth.uid() = citizen_id OR auth.uid() IN (SELECT user_id FROM public.expert_profiles WHERE id = expert_id));

DROP POLICY IF EXISTS "Citizens can book consultations" ON public.consultations;
CREATE POLICY "Citizens can book consultations" ON public.consultations 
FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = citizen_id);

-- 9. Reports: P0 Hardened (Insert for authenticated, Select/Update for Moderators/Admins)
DROP POLICY IF EXISTS "Users can report content" ON public.reports;
CREATE POLICY "Users can report content" ON public.reports 
FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = reporter_id);

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
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ==============================================================================
-- 12. UNIFIED GLOBAL SEARCH RPC
-- ==============================================================================
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active';

ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active';

ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS has_expert_answer BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE FUNCTION public.global_search(
    query_text TEXT,
    filter_type TEXT DEFAULT 'all',
    match_limit INT DEFAULT 20,
    match_offset INT DEFAULT 0
)
RETURNS TABLE (
    id TEXT,
    result_type TEXT,
    title TEXT,
    subtitle TEXT,
    snippet TEXT,
    category TEXT,
    metadata JSONB,
    relevance_score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    clean_query TEXT;
    like_pattern TEXT;
BEGIN
    clean_query := trim(query_text);
    like_pattern := '%' || clean_query || '%';

    IF length(clean_query) = 0 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH combined_results AS (
        -- 1. LAW ARTICLES & RAG CHUNKS (type = 'law')
        SELECT
            lac.id::text AS id,
            'law'::text AS result_type,
            (lac.document_name || ' — ' || lac.article_number || '-modda')::text AS title,
            lac.article_title::text AS subtitle,
            substring(lac.content from 1 for 250)::text AS snippet,
            COALESCE(lac.jurisdiction::text, 'O''zbekiston')::text AS category,
            jsonb_build_object(
                'lex_url', lac.lex_url,
                'article_number', lac.article_number,
                'document_name', lac.document_name,
                'status', lac.status
            ) AS metadata,
            CASE
                WHEN lac.article_title ILIKE like_pattern THEN 1.0::float
                WHEN lac.content ILIKE like_pattern THEN 0.8::float
                ELSE 0.6::float
            END AS relevance_score
        FROM public.law_article_chunks lac
        WHERE (filter_type = 'all' OR filter_type = 'law')
          AND lac.status = 'active'
          AND (lac.article_title ILIKE like_pattern 
               OR lac.content ILIKE like_pattern 
               OR lac.document_name ILIKE like_pattern)

        UNION ALL

        -- 2. VERIFIED LEGAL EXPERTS & LAWYERS (type = 'expert')
        SELECT
            ep.id::text AS id,
            'expert'::text AS result_type,
            p.full_name::text AS title,
            (COALESCE(ep.specialization, 'Yurist') || ' • ' || COALESCE(ep.workplace, 'Toshkent sh.'))::text AS subtitle,
            substring(COALESCE(p.bio, 'Malakali yuridik maslahatchi') from 1 for 200)::text AS snippet,
            COALESCE(ep.specialization::text, 'Umumiy')::text AS category,
            jsonb_build_object(
                'is_verified', (ep.verified_at IS NOT NULL),
                'rating', ep.rating,
                'experience_years', ep.experience_years,
                'reviews_count', ep.reviews_count
            ) AS metadata,
            CASE
                WHEN p.full_name ILIKE like_pattern THEN 0.95::float
                WHEN ep.specialization ILIKE like_pattern THEN 0.85::float
                ELSE 0.7::float
            END AS relevance_score
        FROM public.expert_profiles ep
        JOIN public.profiles p ON ep.user_id = p.id
        WHERE (filter_type = 'all' OR filter_type = 'expert')
          AND ep.verified_at IS NOT NULL
          AND (p.full_name ILIKE like_pattern 
               OR ep.specialization ILIKE like_pattern 
               OR ep.workplace ILIKE like_pattern 
               OR p.bio ILIKE like_pattern)

        UNION ALL

        -- 3. CITIZEN SERVICES & GOVERNMENT GUIDES (type = 'service')
        SELECT
            cs.id::text AS id,
            'service'::text AS result_type,
            cs.title::text AS title,
            cs.department::text AS subtitle,
            substring(cs.description from 1 for 200)::text AS snippet,
            COALESCE(cs.category_id::text, 'Davlat xizmatlari')::text AS category,
            jsonb_build_object(
                'cost_bhm_percent', cs.cost_bhm_percent,
                'is_free', cs.is_free,
                'processing_days', cs.processing_days,
                'source_url', COALESCE(cs.source_url, cs.online_url),
                'online_url', cs.online_url
            ) AS metadata,
            CASE
                WHEN cs.title ILIKE like_pattern THEN 0.95::float
                WHEN COALESCE(cs.legal_basis, '') ILIKE like_pattern THEN 0.85::float
                ELSE 0.65::float
            END AS relevance_score
        FROM public.citizen_services cs
        WHERE (filter_type = 'all' OR filter_type = 'service')
          AND (cs.status IS NULL OR cs.status = 'active')
          AND (cs.title ILIKE like_pattern 
               OR cs.description ILIKE like_pattern 
               OR cs.department ILIKE like_pattern 
               OR COALESCE(cs.legal_basis, '') ILIKE like_pattern)

        UNION ALL

        -- 4. LEGAL DOCUMENT TEMPLATES (type = 'template')
        SELECT
            dt.id::text AS id,
            'template'::text AS result_type,
            dt.title::text AS title,
            dt.target_authority::text AS subtitle,
            substring(dt.description from 1 for 200)::text AS snippet,
            COALESCE(dt.category::text, 'Hujjatlar')::text AS category,
            jsonb_build_object(
                'legal_basis', dt.legal_basis,
                'source_url', dt.source_url,
                'is_popular', dt.is_popular
            ) AS metadata,
            CASE
                WHEN dt.title ILIKE like_pattern THEN 0.95::float
                WHEN COALESCE(dt.legal_basis, '') ILIKE like_pattern THEN 0.8::float
                ELSE 0.65::float
            END AS relevance_score
        FROM public.document_templates dt
        WHERE (filter_type = 'all' OR filter_type = 'template')
          AND (dt.status IS NULL OR dt.status = 'active')
          AND (dt.title ILIKE like_pattern 
               OR dt.description ILIKE like_pattern 
               OR COALESCE(dt.legal_basis, '') ILIKE like_pattern)

        UNION ALL

        -- 5. COMMUNITY FORUM QUESTIONS (type = 'question')
        SELECT
            q.id::text AS id,
            'question'::text AS result_type,
            q.title::text AS title,
            ('Hamjamiyat savoli • ' || q.answers_count || ' ta javob')::text AS subtitle,
            substring(COALESCE(q.description, q.title) from 1 for 200)::text AS snippet,
            COALESCE(q.category_id::text, 'Forum')::text AS category,
            jsonb_build_object(
                'answers_count', q.answers_count,
                'upvotes_count', q.upvotes_count,
                'is_ai_analyzed', q.is_ai_analyzed
            ) AS metadata,
            CASE
                WHEN q.title ILIKE like_pattern THEN 0.9::float
                ELSE 0.6::float
            END AS relevance_score
        FROM public.questions q
        WHERE (filter_type = 'all' OR filter_type = 'question')
          AND (q.is_anonymous = FALSE OR q.user_id = auth.uid())
          AND (q.title ILIKE like_pattern 
               OR q.description ILIKE like_pattern)
    )
    SELECT
        cr.id,
        cr.result_type,
        cr.title,
        cr.subtitle,
        cr.snippet,
        cr.category,
        cr.metadata,
        cr.relevance_score
    FROM combined_results cr
    ORDER BY cr.relevance_score DESC, cr.title ASC
    LIMIT match_limit
    OFFSET match_offset;
END;
$$;

-- ==============================================================================
-- 13. PAYMENTS, CONSULTATIONS, SCHEDULES & ZERO-TRUST FINANCIAL ENGINE
-- ==============================================================================

-- 1. ENUMS & EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

DO $$ BEGIN
    CREATE TYPE consultation_status AS ENUM ('pending', 'awaiting_payment', 'confirmed', 'in_progress', 'completed', 'cancelled', 'expired', 'disputed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'awaiting_payment';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'confirmed';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'in_progress';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'completed';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'expired';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'disputed';

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'paid', 'failed', 'refunding', 'refunded', 'partially_refunded');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'processing';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'paid';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'failed';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunding';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunded';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'partially_refunded';

DO $$ BEGIN
    CREATE TYPE payout_status AS ENUM ('pending', 'scheduled', 'paid', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'scheduled';
ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'paid';
ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'cancelled';

DO $$ BEGIN
    CREATE TYPE payment_provider AS ENUM ('payme', 'click', 'uzum', 'manual');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'payme';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'click';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'uzum';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'manual';

-- 2. EXPERT SCHEDULES TABLE
CREATE TABLE IF NOT EXISTS public.expert_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expert_id UUID NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time TIME NOT NULL DEFAULT '09:00:00',
    end_time TIME NOT NULL DEFAULT '18:00:00',
    slot_duration_minutes INTEGER DEFAULT 45 NOT NULL CHECK (slot_duration_minutes > 0),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE (expert_id, day_of_week)
);

CREATE INDEX IF NOT EXISTS idx_expert_schedules_expert_id ON public.expert_schedules(expert_id);

-- 3. RECONCILE CONSULTATIONS TABLE
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

-- 4. DOUBLE BOOKING PROTECTION INDEX
CREATE UNIQUE INDEX IF NOT EXISTS idx_active_consultation_slot 
ON public.consultations (expert_id, scheduled_at) 
WHERE status IN ('pending', 'awaiting_payment', 'confirmed', 'in_progress');

-- 5. PAYMENTS TABLE
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

-- 6. PAYMENT AUDIT LOGS
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

-- 7. USER NOTIFICATIONS TABLE
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

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.expert_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active expert schedules" ON public.expert_schedules;
CREATE POLICY "Public can view active expert schedules" ON public.expert_schedules FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS "Experts can manage own schedule" ON public.expert_schedules;
CREATE POLICY "Experts can manage own schedule" ON public.expert_schedules FOR ALL USING (
    expert_id IN (SELECT id FROM public.expert_profiles WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Consultation participants can view" ON public.consultations;
CREATE POLICY "Consultation participants can view" ON public.consultations FOR SELECT USING (
    auth.uid() = citizen_id OR 
    expert_id IN (SELECT id FROM public.expert_profiles WHERE user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "Deny direct consultation inserts" ON public.consultations;
CREATE POLICY "Deny direct consultation inserts" ON public.consultations FOR INSERT WITH CHECK (
    current_user = 'service_role' OR session_user = 'postgres'
);

DROP POLICY IF EXISTS "Deny direct consultation updates" ON public.consultations;
CREATE POLICY "Deny direct consultation updates" ON public.consultations FOR UPDATE USING (
    current_user = 'service_role' OR session_user = 'postgres'
);

DROP POLICY IF EXISTS "Payment participants can view" ON public.payments;
CREATE POLICY "Payment participants can view" ON public.payments FOR SELECT USING (
    auth.uid() = citizen_id OR 
    expert_id IN (SELECT id FROM public.expert_profiles WHERE user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "Deny direct payment mutations" ON public.payments;
CREATE POLICY "Deny direct payment mutations" ON public.payments FOR ALL USING (
    current_user = 'service_role' OR session_user = 'postgres'
);

DROP POLICY IF EXISTS "Admins can view payment audit logs" ON public.payment_audit_logs;
CREATE POLICY "Admins can view payment audit logs" ON public.payment_audit_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "Users can view own notifications" ON public.user_notifications;
CREATE POLICY "Users can view own notifications" ON public.user_notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.user_notifications;
CREATE POLICY "Users can update own notifications" ON public.user_notifications FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 9. RPC FUNCTIONS: get_expert_available_slots, book_consultation, process_payment_webhook, cancel_consultation
CREATE OR REPLACE FUNCTION public.get_expert_available_slots(p_expert_id UUID, p_date DATE)
RETURNS TABLE (slot_time TIMESTAMPTZ, is_available BOOLEAN, duration_minutes INT, price_amount_uzs NUMERIC(12, 2))
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE
    v_day_of_week INT;
    v_fee NUMERIC(12, 2);
    v_start_time TIME;
    v_end_time TIME;
    v_duration INT;
    v_current_slot TIMESTAMPTZ;
    v_end_slot TIMESTAMPTZ;
BEGIN
    v_day_of_week := EXTRACT(ISODOW FROM p_date);
    SELECT COALESCE(consultation_fee, 150000.00) INTO v_fee FROM public.expert_profiles WHERE id = p_expert_id AND verified_at IS NOT NULL;
    IF v_fee IS NULL THEN v_fee := 150000.00; END IF;

    SELECT COALESCE(start_time, '09:00:00'::TIME), COALESCE(end_time, '18:00:00'::TIME), COALESCE(slot_duration_minutes, 45)
    INTO v_start_time, v_end_time, v_duration
    FROM public.expert_schedules WHERE expert_id = p_expert_id AND day_of_week = v_day_of_week AND is_active = TRUE;

    IF v_start_time IS NULL THEN
        v_start_time := '09:00:00'::TIME;
        v_end_time := '18:00:00'::TIME;
        v_duration := 45;
    END IF;

    v_current_slot := p_date + v_start_time;
    v_end_slot := p_date + v_end_time;

    WHILE v_current_slot + (v_duration * INTERVAL '1 minute') <= v_end_slot LOOP
        RETURN QUERY
        SELECT v_current_slot AS slot_time,
               NOT EXISTS (
                   SELECT 1 FROM public.consultations c
                   WHERE c.expert_id = p_expert_id AND c.scheduled_at = v_current_slot
                     AND c.status IN ('pending', 'awaiting_payment', 'confirmed', 'in_progress')
               ) AS is_available,
               v_duration AS duration_minutes,
               v_fee AS price_amount_uzs;
        v_current_slot := v_current_slot + (v_duration * INTERVAL '1 minute');
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.book_consultation(
    p_expert_id UUID, p_scheduled_at TIMESTAMPTZ, p_meeting_type TEXT DEFAULT 'online',
    p_notes TEXT DEFAULT NULL, p_question_id UUID DEFAULT NULL, p_provider TEXT DEFAULT 'payme'
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
    IF v_citizen_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

    BEGIN v_provider_enum := p_provider::payment_provider; EXCEPTION WHEN OTHERS THEN v_provider_enum := 'payme'; END;

    SELECT ep.id, ep.user_id, ep.consultation_fee, p.full_name INTO v_expert_record
    FROM public.expert_profiles ep JOIN public.profiles p ON ep.user_id = p.id
    WHERE ep.id = p_expert_id AND ep.verified_at IS NOT NULL FOR SHARE;

    IF v_expert_record.id IS NULL THEN RAISE EXCEPTION 'Expert not found or not verified.'; END IF;
    IF v_expert_record.user_id = v_citizen_id THEN RAISE EXCEPTION 'Self-booking blocked.'; END IF;
    IF p_scheduled_at <= now() THEN RAISE EXCEPTION 'Invalid date: Must be in future.'; END IF;

    IF NOT pg_try_advisory_xact_lock(hashtext('consultation_lock_' || p_expert_id::text || '_' || p_scheduled_at::text)) THEN
        RAISE EXCEPTION 'Slot is currently being booked by another citizen.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.consultations WHERE expert_id = p_expert_id AND scheduled_at = p_scheduled_at
          AND status IN ('pending', 'awaiting_payment', 'confirmed', 'in_progress')
    ) THEN RAISE EXCEPTION 'Slot already booked.'; END IF;

    v_price_uzs := COALESCE(v_expert_record.consultation_fee, 150000.00);
    v_price_tiyin := (v_price_uzs * 100)::BIGINT;
    v_commission_tiyin := ROUND(v_price_tiyin * 0.10)::BIGINT;
    v_payout_tiyin := v_price_tiyin - v_commission_tiyin;

    v_consultation_id := gen_random_uuid();
    v_payment_id := gen_random_uuid();
    v_idempotency_key := 'pay_' || v_consultation_id::text || '_' || EXTRACT(EPOCH FROM now())::BIGINT;

    INSERT INTO public.consultations (
        id, citizen_id, expert_id, question_id, scheduled_at, duration_minutes,
        price_amount_tiyin, currency, commission_rate, commission_amount_tiyin,
        expert_payout_amount_tiyin, status, payment_status, payout_status,
        payment_id, meeting_type, notes
    ) VALUES (
        v_consultation_id, v_citizen_id, p_expert_id, p_question_id, p_scheduled_at, v_duration,
        v_price_tiyin, 'UZS', 0.1000, v_commission_tiyin, v_payout_tiyin,
        'awaiting_payment', 'pending', 'pending', v_payment_id, p_meeting_type, p_notes
    );

    INSERT INTO public.payments (
        id, consultation_id, citizen_id, expert_id, provider, idempotency_key, amount_tiyin, currency, status
    ) VALUES (
        v_payment_id, v_consultation_id, v_citizen_id, p_expert_id, v_provider_enum, v_idempotency_key, v_price_tiyin, 'UZS', 'pending'
    );

    INSERT INTO public.payment_audit_logs (payment_id, consultation_id, actor_id, action, new_state, notes)
    VALUES (v_payment_id, v_consultation_id, v_citizen_id, 'CONSULTATION_BOOKED',
            jsonb_build_object('status', 'awaiting_payment', 'price_amount_tiyin', v_price_tiyin),
            'Booking initiated.');

    RETURN jsonb_build_object(
        'success', TRUE,
        'consultation_id', v_consultation_id,
        'payment_id', v_payment_id,
        'idempotency_key', v_idempotency_key,
        'price_amount_uzs', v_price_uzs,
        'price_amount_tiyin', v_price_tiyin,
        'expert_name', v_expert_record.full_name,
        'scheduled_at', p_scheduled_at,
        'status', 'awaiting_payment',
        'provider', v_provider_enum
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.process_payment_webhook(
    p_payment_id UUID, p_provider TEXT, p_provider_transaction_id TEXT,
    p_paid_amount_tiyin BIGINT, p_status TEXT DEFAULT 'paid', p_error_message TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_payment RECORD;
    v_consultation RECORD;
    v_meeting_link TEXT;
BEGIN
    SELECT * INTO v_payment FROM public.payments WHERE id = p_payment_id FOR UPDATE;
    IF v_payment.id IS NULL THEN RAISE EXCEPTION 'Payment record not found.'; END IF;

    SELECT c.*, ep.user_id AS expert_user_id, p.full_name AS citizen_name
    INTO v_consultation FROM public.consultations c
    JOIN public.expert_profiles ep ON c.expert_id = ep.id
    JOIN public.profiles p ON c.citizen_id = p.id WHERE c.id = v_payment.consultation_id;

    IF v_payment.status = 'paid' THEN
        RETURN jsonb_build_object('success', TRUE, 'is_duplicate', TRUE, 'consultation_id', v_payment.consultation_id, 'status', 'paid');
    END IF;

    IF p_status = 'failed' THEN
        UPDATE public.payments SET status = 'failed', error_message = p_error_message, updated_at = now() WHERE id = p_payment_id;
        UPDATE public.consultations SET payment_status = 'failed', status = 'expired', updated_at = now() WHERE id = v_payment.consultation_id;
        INSERT INTO public.payment_audit_logs (payment_id, consultation_id, action, notes)
        VALUES (p_payment_id, v_payment.consultation_id, 'PAYMENT_FAILED', p_error_message);
        RETURN jsonb_build_object('success', FALSE, 'status', 'failed', 'error', p_error_message);
    END IF;

    IF p_paid_amount_tiyin != v_payment.amount_tiyin THEN
        UPDATE public.payments SET status = 'failed', error_message = 'Amount mismatch', updated_at = now() WHERE id = p_payment_id;
        UPDATE public.consultations SET status = 'disputed', payment_status = 'failed', updated_at = now() WHERE id = v_payment.consultation_id;
        RAISE EXCEPTION 'Amount Mismatch.';
    END IF;

    v_meeting_link := 'https://meet.lexhub.uz/room/' || v_consultation.id::text;

    UPDATE public.payments SET status = 'paid', provider_transaction_id = p_provider_transaction_id, paid_at = now(), updated_at = now() WHERE id = p_payment_id;
    UPDATE public.consultations SET status = 'confirmed', payment_status = 'paid', meeting_link = v_meeting_link, updated_at = now() WHERE id = v_payment.consultation_id;

    INSERT INTO public.payment_audit_logs (payment_id, consultation_id, action, new_state, provider_reference, notes)
    VALUES (p_payment_id, v_payment.consultation_id, 'PAYMENT_CAPTURED',
            jsonb_build_object('payment_status', 'paid', 'consultation_status', 'confirmed'),
            p_provider_transaction_id, 'Payment captured.');

    INSERT INTO public.user_notifications (user_id, title, message, type, data)
    VALUES (v_consultation.citizen_id, 'Konsultatsiya tasdiqlandi!', 'Advokat bilan uchrashuv band qilindi.', 'consultation_confirmed',
            jsonb_build_object('consultation_id', v_consultation.id, 'meeting_link', v_meeting_link));

    INSERT INTO public.user_notifications (user_id, title, message, type, data)
    VALUES (v_consultation.expert_user_id, 'Yangi konsultatsiya buyurtmasi!', v_consultation.citizen_name || ' siz bilan konsultatsiya band qildi.',
            'consultation_booked', jsonb_build_object('consultation_id', v_consultation.id, 'meeting_link', v_meeting_link));

    RETURN jsonb_build_object('success', TRUE, 'consultation_id', v_consultation.id, 'payment_id', p_payment_id, 'status', 'confirmed', 'payment_status', 'paid', 'meeting_link', v_meeting_link);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_consultation(p_consultation_id UUID, p_reason TEXT DEFAULT 'Foydalanuvchi tomonidan bekor qilindi')
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_user_id UUID;
    v_consultation RECORD;
    v_hours_until_start NUMERIC;
    v_refund_percent NUMERIC := 0.0;
    v_refund_tiyin BIGINT := 0;
    v_is_expert BOOLEAN := FALSE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

    SELECT c.*, ep.user_id AS expert_user_id INTO v_consultation
    FROM public.consultations c JOIN public.expert_profiles ep ON c.expert_id = ep.id
    WHERE c.id = p_consultation_id FOR UPDATE;

    IF v_consultation.id IS NULL THEN RAISE EXCEPTION 'Consultation not found.'; END IF;

    IF v_user_id = v_consultation.expert_user_id THEN
        v_is_expert := TRUE;
    ELSIF v_user_id != v_consultation.citizen_id AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied.';
    END IF;

    IF v_consultation.status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN
        RAISE EXCEPTION 'Invalid state transition.';
    END IF;

    IF v_consultation.payment_status = 'paid' THEN
        IF v_is_expert THEN
            v_refund_percent := 1.00;
        ELSE
            v_hours_until_start := EXTRACT(EPOCH FROM (v_consultation.scheduled_at - now())) / 3600.0;
            IF v_hours_until_start > 24.0 THEN v_refund_percent := 1.00;
            ELSIF v_hours_until_start >= 2.0 THEN v_refund_percent := 0.80;
            ELSE v_refund_percent := 0.00; END IF;
        END IF;
        v_refund_tiyin := ROUND(v_consultation.price_amount_tiyin * v_refund_percent)::BIGINT;
    END IF;

    UPDATE public.consultations SET
        status = 'cancelled',
        payment_status = CASE WHEN v_refund_percent = 1.00 THEN 'refunded'::payment_status WHEN v_refund_percent > 0.00 THEN 'partially_refunded'::payment_status ELSE payment_status END,
        cancelled_by = v_user_id, cancelled_at = now(), cancellation_reason = p_reason, refund_amount_tiyin = v_refund_tiyin, updated_at = now()
    WHERE id = p_consultation_id;

    INSERT INTO public.payment_audit_logs (consultation_id, actor_id, action, old_state, new_state, notes)
    VALUES (p_consultation_id, v_user_id, 'CONSULTATION_CANCELLED',
            jsonb_build_object('status', v_consultation.status),
            jsonb_build_object('status', 'cancelled', 'refund_amount_tiyin', v_refund_tiyin, 'refund_percent', (v_refund_percent * 100)),
            p_reason);

    RETURN jsonb_build_object('success', TRUE, 'consultation_id', p_consultation_id, 'status', 'cancelled', 'refund_percent', (v_refund_percent * 100), 'refund_amount_uzs', (v_refund_tiyin / 100.0));
END;
$$;
