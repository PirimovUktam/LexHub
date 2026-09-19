-- LexHub reproducible, EMPTY LOCAL Supabase database bootstrap.
-- psql entry point; docs/STAGE1_DATABASE.md describes prerequisites and limits.
-- NEVER run on an existing project. This does not repair migration history.
\set ON_ERROR_STOP on
DO $$
BEGIN
    IF inet_server_addr() IS NOT NULL
       AND inet_server_addr() NOT IN ('127.0.0.1'::inet, '::1'::inet) THEN
        RAISE EXCEPTION 'Bootstrap accepts a loopback/local database only';
    END IF;
    IF to_regclass('public.profiles') IS NOT NULL
       OR to_regclass('public.questions') IS NOT NULL
       OR to_regclass('public.categories') IS NOT NULL THEN
        RAISE EXCEPTION 'Bootstrap requires an empty application schema';
    END IF;
END;
$$;
\ir ../migrations/20260819_base_schema.sql
\ir replay_prerequisites.sql
\ir ../migrations/20260820_p0_security_remediation.sql
\ir ../migrations/20260821000500_community_qa_triggers.sql
\ir ../migrations/20260821010000_expert_verification_and_privacy.sql
\ir ../migrations/20260821020000_legal_rag_chunks_and_rpc.sql
\ir ../migrations/20260822_citizen_services_freshness_and_seed.sql
\ir ../migrations/20260823_legal_document_templates_and_user_docs.sql
\ir ../migrations/20260824_unified_global_search_rpc.sql
\ir ../migrations/20260825000500_step1_payments_enums.sql
\ir ../migrations/20260825010000_step2_payments_tables_and_logic.sql
\ir ../migrations/20260826000500_bulletproof_auth_signup_trigger.sql
\ir ../migrations/20260826010000_fix_profile_anti_tampering_and_auth_trigger.sql
\ir ../migrations/20260827_profile_invariant_final_fix.sql
\ir ../migrations/20260828_mvp_blockers_p0_07_p1_05_p1_06.sql
\ir ../migrations/20260829000500_expert_license_visibility_and_lock.sql
\ir ../migrations/20260829010000_expert_rejection_and_revocation.sql
\ir ../migrations/20260829020000_questions_schema_drift_alignment.sql
\ir ../migrations/20260829120000_profiles_anon_column_privileges.sql
\ir ../migrations/20260829130000_expert_moderation_guard_fix_and_apply_cooldown.sql
\ir ../migrations/20260830010000_client_error_logs.sql
\ir ../migrations/20260830020000_expert_moderation_runtime_assertions.sql
\ir ../migrations/20260830030000_expert_rejection_reason_and_withdraw.sql
\ir ../migrations/20260830040000_probe_residue_cleanup.sql
\ir ../migrations/20260830050000_purge_logs_guard_fix.sql
\ir ../migrations/20260830060000_expert_rating_no_fabrication.sql
\ir ../migrations/20260830061000_expert_rating_constraint_runtime_proof.sql
\ir ../migrations/20260830070000_expert_cooldown_machine_readable.sql
\ir ../migrations/20260830080000_questions_anonymity_rls_enforcement.sql
\ir ../migrations/20260830090000_document_templates_catalog_parity.sql
\ir ../migrations/20260830100000_rls_never_enabled_tables.sql
\ir ../migrations/20260830110000_missing_write_policies_parity.sql
\ir ../migrations/20260830120000_tighten_loose_write_policies.sql
\ir ../migrations/20260903000000_profiles_anon_row_visibility.sql
\ir ../migrations/20260903001000_revoke_anon_write_grants.sql
\ir ../migrations/20260919001000_stage1_authorization_and_booking.sql
\ir ../migrations/20260919002000_reviewed_legal_excerpts_and_deadlines.sql
