-- ==============================================================================
-- MIGRATION: 20260824_unified_global_search_rpc.sql
-- LexHub Platform — Unified Global Search & Hybrid Semantic Search Engine
-- Multi-entity (Laws, Experts, Services, Templates, Community) with Ranking & Filtering
-- Schema-Accurate, Self-Healing and Resilient
-- ==============================================================================

-- 1. RECONCILE PREREQUISITE COLUMNS ACROSS ALL SEARCH TARGETS
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active';

ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active';

ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS has_expert_answer BOOLEAN DEFAULT FALSE;

-- 2. UNIFIED GLOBAL SEARCH RPC FUNCTION
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
