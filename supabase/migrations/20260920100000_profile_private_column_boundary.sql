-- Authenticated forum access must not expose another account's private fields.
-- Own-profile reads use an auth.uid()-bound RPC; public embeds keep their columns.
BEGIN;

DO $$
DECLARE v_columns text;
BEGIN
    IF to_regclass('public.profiles') IS NULL THEN
        RAISE EXCEPTION 'Required profiles table is missing';
    END IF;
    SELECT string_agg(quote_ident(attname), ', ') INTO v_columns
    FROM pg_attribute WHERE attrelid = 'public.profiles'::regclass
      AND attnum > 0 AND NOT attisdropped;
    -- Table-level SELECT overrides column restrictions. Clear both ACL layers,
    -- including historical explicit grants, before restoring the public subset.
    REVOKE SELECT ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
    EXECUTE format('REVOKE SELECT (%s) ON public.profiles FROM PUBLIC, anon, authenticated', v_columns);
END;
$$;

GRANT SELECT (id, full_name, avatar_url, role, is_verified,
    reputation_points, specialization, created_at, updated_at)
ON public.profiles TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT jsonb_build_object(
        'id', p.id, 'full_name', p.full_name, 'avatar_url', p.avatar_url,
        'phone', p.phone, 'bio', p.bio, 'role', p.role,
        'reputation_points', p.reputation_points, 'is_verified', p.is_verified,
        'created_at', p.created_at, 'updated_at', p.updated_at
    )
    FROM public.profiles AS p
    WHERE p.id = auth.uid();
$$;

DO $$
DECLARE v_function regprocedure;
BEGIN
    FOR v_function IN
        SELECT p.oid::regprocedure FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'get_my_profile'
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', v_function);
    END LOOP;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

COMMIT;

-- Verification: authenticated SELECT(phone/bio/license_number) must be denied;
-- get_my_profile() must return only auth.uid(), and safe community embeds remain.
