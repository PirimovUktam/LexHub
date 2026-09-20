-- GoTrue deletes auth.sessions on logout/revoke. Use that authoritative state;
-- no client-writable cutoff, duplicate session store, or shorter JWT workaround.
BEGIN;

DO $$
DECLARE existing_hook text;
BEGIN
    IF to_regclass('auth.sessions') IS NULL OR to_regclass('storage.objects') IS NULL
       OR to_regprocedure('auth.jwt()') IS NULL THEN
        RAISE EXCEPTION 'Native Auth sessions and Storage prerequisites required';
    END IF;
    SELECT split_part(setting, '=', 2) INTO existing_hook
      FROM pg_roles r CROSS JOIN LATERAL unnest(r.rolconfig) setting
      WHERE r.rolname = 'authenticator' AND setting LIKE 'pgrst.db_pre_request=%';
    IF coalesce(existing_hook, '') NOT IN ('', 'public.require_active_session') THEN
        RAISE EXCEPTION 'Existing PostgREST pre-request hook requires explicit reconciliation';
    END IF;
    IF (SELECT count(*) FROM pg_tables WHERE schemaname = 'public') < 23
       OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE c.relkind='r' AND (n.nspname='public'
             OR (n.nspname='storage' AND c.relname='objects')) AND NOT c.relrowsecurity) THEN
        RAISE EXCEPTION 'Expected RLS-enabled application and Storage tables';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_session_active()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE session_claim text := auth.jwt()->>'session_id';
BEGIN
    IF auth.role() = 'service_role' THEN RETURN true; END IF;
    IF auth.role() IS DISTINCT FROM 'authenticated' OR auth.uid() IS NULL
       OR session_claim IS NULL OR session_claim !~*
          '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN false;
    END IF;
    RETURN EXISTS (SELECT 1 FROM auth.sessions s
        WHERE s.id = session_claim::uuid AND s.user_id = auth.uid()
          AND (s.not_after IS NULL OR s.not_after > statement_timestamp()));
END;
$$;

CREATE OR REPLACE FUNCTION public.require_active_session()
RETURNS void LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
    IF auth.role() = 'authenticated' AND NOT public.is_session_active() THEN
        RAISE EXCEPTION 'Session is no longer active' USING ERRCODE = '42501';
    END IF;
END;
$$;

-- Keep the exact application profile allowlist, also guarding direct RPC use.
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT jsonb_build_object(
        'id', p.id, 'full_name', p.full_name, 'avatar_url', p.avatar_url,
        'phone', p.phone, 'bio', p.bio, 'role', p.role,
        'reputation_points', p.reputation_points, 'is_verified', p.is_verified,
        'created_at', p.created_at, 'updated_at', p.updated_at)
    FROM public.profiles p WHERE p.id = auth.uid() AND public.is_session_active();
$$;

DO $$
DECLARE signature regprocedure; function_name text; relation regclass;
BEGIN
    FOR signature, function_name IN
        SELECT p.oid::regprocedure,p.proname FROM pg_proc p
        JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname IN
            ('is_session_active','require_active_session','get_my_profile')
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role',signature);
    END LOOP;
    -- A restrictive policy is ANDed with existing ownership/moderation policies.
    -- InitPlan evaluates the indexed session lookup once per statement.
    FOR relation IN
        SELECT c.oid::regclass FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE c.relkind='r' AND (n.nspname='public'
            OR (n.nspname='storage' AND c.relname='objects'))
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS active_session_required ON %s',relation);
        EXECUTE format('CREATE POLICY active_session_required ON %s AS RESTRICTIVE
            FOR ALL TO authenticated USING ((SELECT public.is_session_active()))
            WITH CHECK ((SELECT public.is_session_active()))',relation);
    END LOOP;
END;
$$;
-- Anonymous callers only receive false, never session/account metadata.
GRANT EXECUTE ON FUNCTION public.is_session_active() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.require_active_session() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

-- Covers SECURITY DEFINER RPCs and views as well as normal REST table requests.
-- Anonymous public reads and trusted service-role workflows retain their grants.
ALTER ROLE authenticator SET pgrst.db_pre_request = 'public.require_active_session';
NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';
COMMIT;

-- Postflight: 24 restrictive policies; pre-request hook configured; active login
-- succeeds, identical JWT after global logout gets 42501, fresh login succeeds.
