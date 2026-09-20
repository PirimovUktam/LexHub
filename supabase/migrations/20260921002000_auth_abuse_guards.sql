-- Auth server hooks, not a client/proxy limiter. No automatic remote activation.
-- Before User Created: Free/Pro. Password Verification Attempt: Team/Enterprise.
-- https://supabase.com/docs/guides/auth/auth-hooks
-- GoTrue calls these hooks in a separate transaction and translates the returned
-- error after committing; use an error object, never RAISE for quota exhaustion.
BEGIN;

CREATE SCHEMA IF NOT EXISTS auth_guard;
REVOKE ALL ON SCHEMA auth_guard FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA auth_guard TO supabase_auth_admin;

CREATE TABLE IF NOT EXISTS auth_guard.identity_salt (
    singleton BOOLEAN PRIMARY KEY DEFAULT true CHECK (singleton),
    salt UUID NOT NULL DEFAULT gen_random_uuid()
);
INSERT INTO auth_guard.identity_salt(singleton) VALUES (true)
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS auth_guard.attempt_windows (
    action TEXT NOT NULL CHECK (action IN ('signup', 'password')),
    scope TEXT NOT NULL CHECK (scope IN ('ip', 'identifier')),
    identity_hash BYTEA NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER NOT NULL CHECK (attempts > 0),
    PRIMARY KEY (action, scope, identity_hash)
);
CREATE INDEX IF NOT EXISTS auth_attempt_windows_expiry_idx
    ON auth_guard.attempt_windows(started_at);
ALTER TABLE auth_guard.identity_salt ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_guard.attempt_windows ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA auth_guard
    FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- Only trusted hooks call this helper; identity, action and limit are not RPC
-- arguments available to application users. Raw emails and IPs are not stored.
CREATE OR REPLACE FUNCTION auth_guard.identity_key(value TEXT)
RETURNS BYTEA LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT pg_catalog.sha256(pg_catalog.convert_to(salt::text || ':' || value, 'UTF8'))
    FROM auth_guard.identity_salt WHERE singleton;
$$;

CREATE OR REPLACE FUNCTION auth_guard.consume_attempt(
    p_action TEXT, p_scope TEXT, p_identity TEXT, p_limit INTEGER
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_hash BYTEA;
    v_row auth_guard.attempt_windows%ROWTYPE;
BEGIN
    IF p_identity IS NULL OR length(p_identity) = 0 OR length(p_identity) > 320
       OR p_limit < 1 OR p_limit > 60 THEN
        RAISE EXCEPTION 'Invalid auth guard input' USING ERRCODE = '22023';
    END IF;
    v_hash := auth_guard.identity_key(p_identity);
    DELETE FROM auth_guard.attempt_windows
    WHERE started_at < v_now - interval '1 day';
    -- The conflicting row is locked by PostgreSQL; parallel callers cannot
    -- both consume the last slot. Rejections do not extend the lockout window.
    INSERT INTO auth_guard.attempt_windows AS w
        (action, scope, identity_hash, started_at, attempts)
    VALUES (p_action, p_scope, v_hash, v_now, 1)
    ON CONFLICT (action, scope, identity_hash) DO UPDATE SET
        started_at = CASE WHEN w.started_at <= v_now - interval '15 minutes'
            THEN v_now ELSE w.started_at END,
        attempts = CASE WHEN w.started_at <= v_now - interval '15 minutes'
            THEN 1 ELSE least(w.attempts + 1, p_limit + 1) END
    RETURNING * INTO v_row;
    IF v_row.attempts > p_limit THEN
        RETURN greatest(1, ceil(extract(epoch FROM
            v_row.started_at + interval '15 minutes' - v_now))::integer);
    END IF;
    RETURN 0;
END;
$$;

CREATE OR REPLACE FUNCTION auth_guard.before_user_created(event JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_ip TEXT := event #>> '{metadata,ip_address}';
    v_identifier TEXT := lower(btrim(event #>> '{user,email}'));
    v_retry INTEGER;
    v_other_retry INTEGER;
BEGIN
    -- This metadata is supplied by GoTrue, not user.user_metadata. Missing or
    -- malformed identity fails closed; do not trust a client-provided IP.
    IF v_identifier IS NULL OR length(v_identifier) NOT BETWEEN 3 AND 320
       OR v_identifier !~ '^[^[:space:]@]+@[^[:space:]@]+$'
       OR v_ip IS NULL OR length(v_ip) NOT BETWEEN 2 AND 45 THEN
        RETURN jsonb_build_object('error', jsonb_build_object(
            'http_code', 400, 'message', 'Invalid signup request.'));
    END IF;
    BEGIN
        v_ip := host(v_ip::inet);
    EXCEPTION WHEN invalid_text_representation THEN
        RETURN jsonb_build_object('error', jsonb_build_object(
            'http_code', 400, 'message', 'Invalid signup request.'));
    END;
    v_retry := auth_guard.consume_attempt('signup', 'ip', v_ip, 10);
    v_other_retry := auth_guard.consume_attempt('signup', 'identifier', v_identifier, 3);
    v_retry := greatest(v_retry, v_other_retry);
    IF v_retry > 0 THEN
        -- The hosted Auth hook contract supports http_code/message, but does
        -- not allow supplying Retry-After headers. Do not claim otherwise.
        RETURN jsonb_build_object('error', jsonb_build_object('http_code', 429,
            'message', 'Too many signup attempts. Retry after ' || v_retry || ' seconds.'));
    END IF;
    RETURN '{}'::jsonb;
END;
$$;

CREATE OR REPLACE FUNCTION auth_guard.password_verification_attempt(event JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_user UUID;
    v_valid BOOLEAN;
    v_ip TEXT := event #>> '{metadata,ip_address}';
    v_retry INTEGER;
    v_other_retry INTEGER := 0;
BEGIN
    IF jsonb_typeof(event->'valid') IS DISTINCT FROM 'boolean' THEN
        RETURN jsonb_build_object('error', jsonb_build_object(
            'http_code', 400, 'message', 'Invalid authentication request.'));
    END IF;
    BEGIN
        v_user := (event->>'user_id')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        RETURN jsonb_build_object('error', jsonb_build_object(
            'http_code', 400, 'message', 'Invalid authentication request.'));
    END;
    IF v_user IS NULL THEN
        RETURN jsonb_build_object('error', jsonb_build_object(
            'http_code', 400, 'message', 'Invalid authentication request.'));
    END IF;
    v_valid := (event->>'valid')::boolean;
    IF v_valid THEN
        -- A correct guess must not bypass an active account cooldown. Lock
        -- the counter row so concurrent failed attempts and success serialize.
        SELECT greatest(1, ceil(extract(epoch FROM
            started_at + interval '15 minutes' - clock_timestamp()))::integer)
        INTO v_retry FROM auth_guard.attempt_windows
        WHERE action = 'password' AND scope = 'identifier'
          AND identity_hash = auth_guard.identity_key(v_user::text)
          AND attempts >= 10 AND started_at > clock_timestamp() - interval '15 minutes'
        FOR UPDATE;
        IF v_retry IS NOT NULL THEN
            RETURN jsonb_build_object('error', jsonb_build_object('http_code', 429,
                'message', 'Too many authentication attempts. Retry after ' || v_retry || ' seconds.'));
        END IF;
        -- Expired/below-limit failures can reset; existing sessions are untouched.
        DELETE FROM auth_guard.attempt_windows WHERE action = 'password'
            AND scope = 'identifier' AND identity_hash = auth_guard.identity_key(v_user::text);
        RETURN jsonb_build_object('decision', 'continue');
    END IF;
    v_retry := auth_guard.consume_attempt('password', 'identifier', v_user::text, 10);
    -- Newer GoTrue hook payloads include server-derived IP metadata. The older
    -- documented payload omits it; native Auth IP throttling still applies.
    IF v_ip IS NOT NULL THEN
        BEGIN
            IF length(v_ip) > 45 THEN RAISE invalid_text_representation; END IF;
            v_ip := host(v_ip::inet);
        EXCEPTION WHEN invalid_text_representation THEN
            RETURN jsonb_build_object('error', jsonb_build_object(
                'http_code', 400, 'message', 'Invalid authentication request.'));
        END;
        v_other_retry := auth_guard.consume_attempt('password', 'ip', v_ip, 60);
    END IF;
    v_retry := greatest(v_retry, v_other_retry);
    IF v_retry > 0 THEN
        RETURN jsonb_build_object('error', jsonb_build_object('http_code', 429,
            'message', 'Too many authentication attempts. Retry after ' || v_retry || ' seconds.'));
    END IF;
    RETURN jsonb_build_object('decision', 'continue');
END;
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA auth_guard
    FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION auth_guard.before_user_created(JSONB),
    auth_guard.password_verification_attempt(JSONB) TO supabase_auth_admin;
COMMIT;

-- After explicit configuration, inspect pg_proc/proacl, pg_namespace/nspacl and
-- Auth hook metadata. Function existence alone does not prove Auth enforcement.
