-- Fresh-database bridge for manual schema changes predating migration history.
-- Used ONLY by rebuild.sql after base_schema; never apply to an existing project.
-- Shape measured through read-only Supabase MCP on 2026-09-19.
BEGIN;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.questions)
       OR EXISTS (SELECT 1 FROM public.profiles) THEN
        RAISE EXCEPTION 'Bootstrap requires empty application tables';
    END IF;
END;
$$;

CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Categories are readable by everyone" ON public.categories
    FOR SELECT TO anon, authenticated USING (true);
GRANT SELECT ON public.categories TO anon, authenticated;

-- Existing public taxonomy, read through MCP on 2026-09-19; not legal advice.
INSERT INTO public.categories (name, slug, description) VALUES
    ('Maʼmuriy huquqi', 'administrative-law', 'Davlat organlari, jarimalar'),
    ('Fuqarolik huquqi', 'civil-law', 'Shartnomalar, daʼvo, kompensatsiya'),
    ('Jinoyat huquqi', 'criminal-law', 'Jinoyat ishlari, huquqiy himoya'),
    ('Oila huquqi', 'family-law', 'Nikoh, ajrim, voyaga yetmaganlar'),
    ('Mehnat huquqi', 'labor-law', 'Ishga oid huquqiy masalalar');

CREATE TABLE public.official_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.categories(id),
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.official_sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Official sources are readable by everyone" ON public.official_sources
    FOR SELECT TO anon, authenticated USING (true);
GRANT SELECT ON public.official_sources TO anon, authenticated;

ALTER TABLE public.profiles ADD COLUMN specialization TEXT;
ALTER TABLE public.profiles ADD COLUMN license_number TEXT;

-- UUID category references are used by the application and the live database.
-- No mapping/cast of existing user data is attempted: the empty-table guard above
-- is mandatory. Full content is restored separately from an approved backup.
ALTER TABLE public.questions DROP CONSTRAINT questions_category_id_fkey;
ALTER TABLE public.questions ALTER COLUMN category_id TYPE UUID
    USING category_id::UUID;
ALTER TABLE public.questions ALTER COLUMN category_id SET NOT NULL;
ALTER TABLE public.questions ADD CONSTRAINT questions_category_id_fkey
    FOREIGN KEY (category_id) REFERENCES public.categories(id);
ALTER TABLE public.questions ALTER COLUMN description DROP NOT NULL;
ALTER TABLE public.questions ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.questions DROP CONSTRAINT questions_user_id_fkey;
ALTER TABLE public.questions ADD CONSTRAINT questions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Columns present in production but absent from base_schema.
ALTER TABLE public.answers ADD COLUMN is_official_source BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.answers ADD COLUMN source_url TEXT;
ALTER TABLE public.answers ADD COLUMN source_title TEXT;
ALTER TABLE public.answers ADD COLUMN helpful_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.answers ALTER COLUMN body SET NOT NULL;
ALTER TABLE public.answers ALTER COLUMN content DROP NOT NULL;
COMMIT;
