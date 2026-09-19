-- READ ONLY. Expected metadata after both Stage 1 migrations.
-- Passing does not prove runtime authorization, backup recovery or deployment.
WITH guards(table_name, trigger_name, function_name) AS (VALUES
    ('answers','trg_00_guard_answer_write','guard_answer_write'),
    ('expert_profiles','trg_protect_expert_profile_sensitive_fields','protect_expert_profile_sensitive_fields')
), checks AS (
    SELECT 'insert_update_invoker_guards' AS check_name, count(*) = 2 AND
        bool_and(t.tgtype=23 AND t.tgenabled='O' AND NOT p.prosecdef) AS passed
        FROM guards g JOIN pg_trigger t ON t.tgrelid=to_regclass('public.' || g.table_name)
            AND t.tgname=g.trigger_name
        JOIN pg_proc p ON p.oid=t.tgfoid AND p.proname=g.function_name
    UNION ALL SELECT 'restrictive_answer_policies', count(*) = 2 AND
        bool_and(permissive='RESTRICTIVE' AND roles=ARRAY['authenticated']::name[]
            AND ((policyname='stage1_answer_insert_identity' AND cmd='INSERT' AND with_check IS NOT NULL)
              OR (policyname='stage1_answer_update_actor' AND cmd='UPDATE' AND qual IS NOT NULL AND with_check IS NOT NULL)))
        FROM pg_policies WHERE schemaname='public' AND tablename='answers'
        AND policyname IN ('stage1_answer_insert_identity','stage1_answer_update_actor')
    UNION ALL SELECT 'private_tables_rls', count(*) = 5 AND bool_and(c.relrowsecurity)
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname IN
            ('answers','expert_profiles','profiles','questions','consultations')
    UNION ALL SELECT 'guard_rpc_acl', count(*) = 4 AND bool_and(
        NOT has_function_privilege('anon',p.oid,'EXECUTE') AND
        (has_function_privilege('authenticated',p.oid,'EXECUTE') = (p.proname='book_consultation')))
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname IN
            ('guard_answer_write','handle_answer_acceptance','protect_expert_profile_sensitive_fields','book_consultation')
    UNION ALL SELECT 'booking_definer_signature', EXISTS (
        SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.book_consultation(uuid,timestamptz,text,text,uuid,text)')
        AND prosecdef AND proconfig @> ARRAY['search_path=public'])
    -- MD5 is a content equality check, not an authenticity/signature claim.
    -- Expected text comes from the reviewed 20260919002000 migration.
    UNION ALL SELECT 'reviewed_legal_excerpts', count(*) = 4 AND bool_and(status='active' AND
        md5(content) = CASE chunk_id
            WHEN 'const_art_27' THEN '5d71d8583c351159c42f0406993623a0'
            WHEN 'const_art_28' THEN 'a25c8d7b2475c4c04d6270cb7259a86a'
            WHEN 'const_art_29' THEN 'aeb3bcbc3cc73cdacf0c52afe93b1230'
            WHEN 'labor_art_560' THEN '6119f50de1871c0b518253f1721e16e9' END AND
        lex_url = CASE chunk_id
            WHEN 'const_art_27' THEN 'https://lex.uz/docs/6445145#6445434'
            WHEN 'const_art_28' THEN 'https://lex.uz/docs/6445145#6445509'
            WHEN 'const_art_29' THEN 'https://lex.uz/docs/6445145#6445518'
            WHEN 'labor_art_560' THEN 'https://lex.uz/docs/6257288#6269139' END)
        FROM public.law_article_chunks
        WHERE chunk_id IN ('const_art_27','const_art_28','const_art_29','labor_art_560')
    UNION ALL SELECT 'labour_service_reference', count(*) = 1 AND bool_and(
        deadline_law_reference='Mehnat kodeksi 560-modda (Ishga tiklash nizosi: uch oy; boshqa mehnat nizolari: olti oy; qonundagi istisnolar hisobga olinadi)'
        AND source_url='https://lex.uz/docs/6257288#6269139')
        FROM public.citizen_services WHERE id='service_labor_complaint'
    UNION ALL SELECT 'labour_template_reference', count(*) = 1 AND bool_and(
        legal_basis='O''zbekiston Respublikasining Mehnat kodeksi 161, 560, 561-moddalari'
        AND source_url='https://lex.uz/docs/6257288#6269151')
        FROM public.document_templates WHERE id='template_labor_complaint'
)
SELECT check_name, coalesce(passed, false) AS passed FROM checks ORDER BY check_name;
