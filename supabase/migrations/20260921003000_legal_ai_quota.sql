-- Atomic per-account AI billing guard. No provider secret or service key needed.
-- Apply only through the approved environment migration workflow.
BEGIN;

CREATE SCHEMA IF NOT EXISTS legal_ai_private;
REVOKE ALL ON SCHEMA legal_ai_private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS legal_ai_private.usage (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    accepted_at timestamptz[] NOT NULL DEFAULT '{}'::timestamptz[],
    CONSTRAINT legal_ai_usage_bounded CHECK (cardinality(accepted_at) <= 10)
);
ALTER TABLE legal_ai_private.usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE legal_ai_private.usage FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_legal_ai_quota()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    caller uuid := auth.uid();
    recent timestamptz[];
    instant timestamptz;
    wait_seconds integer;
BEGIN
    IF caller IS NULL OR auth.role() IS DISTINCT FROM 'authenticated' THEN
        RAISE EXCEPTION 'Authenticated user required' USING ERRCODE = '42501';
    END IF;

    INSERT INTO legal_ai_private.usage(user_id) VALUES (caller)
        ON CONFLICT (user_id) DO NOTHING;
    -- Serialize competing isolates/requests for this account before counting.
    SELECT accepted_at INTO STRICT recent
      FROM legal_ai_private.usage WHERE user_id = caller FOR UPDATE;
    instant := clock_timestamp();
    SELECT coalesce(array_agg(stamp ORDER BY stamp), '{}'::timestamptz[])
      INTO recent FROM unnest(recent) AS stamp
      WHERE stamp > instant - interval '1 hour';

    IF cardinality(recent) >= 10 THEN
        wait_seconds := greatest(1, ceil(extract(epoch FROM
            recent[1] + interval '1 hour' - instant))::integer);
        RETURN jsonb_build_object('allowed', false,
            'retry_after_seconds', wait_seconds, 'remaining', 0);
    END IF;

    UPDATE legal_ai_private.usage SET accepted_at = array_append(recent, instant)
      WHERE user_id = caller;
    RETURN jsonb_build_object('allowed', true, 'retry_after_seconds', 0,
        'remaining', 9 - cardinality(recent));
END;
$$;

-- Remove execute privileges from every overload, including stale overloads.
DO $$
DECLARE signature regprocedure;
BEGIN
    FOR signature IN
        SELECT p.oid::regprocedure FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'consume_legal_ai_quota'
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', signature);
    END LOOP;
END;
$$;
GRANT EXECUTE ON FUNCTION public.consume_legal_ai_quota() TO authenticated;

COMMIT;

-- Verification: anon execute=false, authenticated execute=true; direct table
-- privileges=false; the eleventh call in one rolling hour returns allowed=false.
-- SELECT has_function_privilege('anon', 'public.consume_legal_ai_quota()', 'EXECUTE');
-- SELECT has_function_privilege('authenticated', 'public.consume_legal_ai_quota()', 'EXECUTE');
