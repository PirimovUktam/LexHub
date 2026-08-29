-- ==============================================================================
-- MIGRATION: 20260821_legal_rag_chunks_and_rpc.sql
-- LexHub Platform — Legal RAG (pgvector similarity search & law chunks)
-- Dependencies: 20260819_base_schema.sql (law_article_chunks, vector extension)
-- ==============================================================================

-- 1. Ensure Vector Extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Ensure Table Exists
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

-- 3. Full-Text Search Function on Law Chunks (Fallback when embeddings not supplied)
CREATE OR REPLACE FUNCTION public.search_law_articles(
    search_query text,
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
    lex_url TEXT
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
        lac.lex_url
    FROM public.law_article_chunks lac
    WHERE lac.status = 'active'
      AND (filter_jurisdiction IS NULL OR lac.jurisdiction = filter_jurisdiction)
      AND (
          lac.article_title ILIKE '%' || search_query || '%'
          OR lac.content ILIKE '%' || search_query || '%'
          OR lac.document_name ILIKE '%' || search_query || '%'
      )
    ORDER BY lac.article_number ASC
    LIMIT match_count;
END;
$$;

-- 4. RLS Policy for Law Article Chunks (Public Read Only)
ALTER TABLE public.law_article_chunks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Law chunks are readable by everyone" ON public.law_article_chunks;
CREATE POLICY "Law chunks are readable by everyone" ON public.law_article_chunks 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage law chunks" ON public.law_article_chunks;
CREATE POLICY "Admins can manage law chunks" ON public.law_article_chunks 
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);
