-- READ ONLY. Targeted prerequisites, not permission to apply migrations.
-- Backup/PITR/restore evidence and explicit approval are separate gates.
-- Missing relations may produce an error: stop rather than assuming readiness.
WITH required_tables(name) AS (VALUES
    ('answers'), ('expert_profiles'), ('profiles'), ('questions'),
    ('consultations'), ('payments'), ('payment_audit_logs'),
    ('law_article_chunks'), ('citizen_services'), ('service_steps'),
    ('document_templates')
), required_columns(table_name, column_name, udt_name) AS (VALUES
    ('answers','user_id','uuid'), ('answers','question_id','uuid'),
    ('answers','is_accepted','bool'), ('answers','upvotes_count','int4'),
    ('expert_profiles','user_id','uuid'), ('expert_profiles','verified_at','timestamptz'),
    ('expert_profiles','rating','numeric'), ('expert_profiles','reviews_count','int4'),
    ('expert_profiles','rejected_at','timestamptz'), ('expert_profiles','rejection_reason','text'),
    ('consultations','fee','numeric'), ('consultations','price_amount_tiyin','int8'),
    ('profiles','is_verified','bool'), ('law_article_chunks','content','text'),
    ('law_article_chunks','lex_url','text'), ('service_steps','warning_note','text')
), checks AS (
    SELECT 'required_tables' AS check_name,
        NOT EXISTS (SELECT 1 FROM required_tables WHERE to_regclass('public.' || name) IS NULL) AS passed
    UNION ALL SELECT 'required_column_types', NOT EXISTS (
        SELECT 1 FROM required_columns r LEFT JOIN information_schema.columns c
        ON c.table_schema='public' AND c.table_name=r.table_name AND c.column_name=r.column_name
        WHERE c.udt_name IS DISTINCT FROM r.udt_name)
    UNION ALL SELECT 'private_tables_rls', count(*) = 5 AND bool_and(c.relrowsecurity)
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname IN
            ('answers','expert_profiles','profiles','questions','consultations')
    UNION ALL SELECT 'moderation_helper', to_regprocedure('public.is_admin_or_moderator()') IS NOT NULL
    UNION ALL SELECT 'booking_signature',
        to_regprocedure('public.book_consultation(uuid,timestamptz,text,text,uuid,text)') IS NOT NULL
        AND (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='book_consultation') = 1
    UNION ALL SELECT 'existing_acceptance_trigger', EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgrelid=to_regclass('public.answers')
        AND tgname='trg_handle_answer_acceptance' AND tgenabled='O' AND tgtype=19
        AND tgfoid=to_regprocedure('public.handle_answer_acceptance()'))
    UNION ALL SELECT 'four_existing_legal_excerpts', count(*) = 4
        FROM public.law_article_chunks
        WHERE chunk_id IN ('const_art_27','const_art_28','const_art_29','labor_art_560')
    UNION ALL SELECT 'labour_service', count(*) = 1 FROM public.citizen_services
        WHERE id='service_labor_complaint'
    UNION ALL SELECT 'labour_step', count(*) = 1 FROM public.service_steps
        WHERE service_id='service_labor_complaint' AND step_number=3
    UNION ALL SELECT 'labour_template', count(*) = 1 FROM public.document_templates
        WHERE id='template_labor_complaint'
)
SELECT check_name, coalesce(passed, false) AS passed FROM checks ORDER BY check_name;
