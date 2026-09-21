BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS first_name text,
  ADD COLUMN IF NOT EXISTS last_name text,
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS occupation text,
  ADD COLUMN IF NOT EXISTS avatar_path text;

-- Existing names are not split heuristically; unknown details remain NULL.
CREATE OR REPLACE FUNCTION public.validate_profile_details()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF char_length(NEW.full_name) NOT BETWEEN 1 AND 128
     OR char_length(NEW.first_name) NOT BETWEEN 1 AND 64
     OR char_length(NEW.last_name) NOT BETWEEN 1 AND 64
     OR char_length(NEW.bio) > 300
     OR char_length(NEW.address) > 500
     OR char_length(NEW.occupation) > 128
     OR (NEW.phone IS NOT NULL AND NEW.phone <> '' AND NEW.phone !~ '^\+[1-9][0-9]{7,14}$')
     OR (NEW.gender IS NOT NULL AND NEW.gender NOT IN ('male', 'female'))
     OR (NEW.date_of_birth IS NOT NULL AND
         (NOT isfinite(NEW.date_of_birth) OR NEW.date_of_birth > CURRENT_DATE
          OR NEW.date_of_birth < DATE '0001-01-01'))
     OR (NEW.avatar_path IS NOT NULL AND
         NEW.avatar_path !~ ('^' || NEW.id::text || '/[0-9a-f-]{36}\.(png|jpg|webp)$'))
  THEN
    RAISE EXCEPTION 'invalid_profile_fields' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validate_profile_details ON public.profiles;
CREATE TRIGGER trg_validate_profile_details BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.validate_profile_details();

-- Preserve the public forum column contract, never grant new private columns.
REVOKE SELECT ON public.profiles FROM anon, authenticated;
REVOKE SELECT (first_name, last_name, date_of_birth, gender, address, occupation, avatar_path)
  ON public.profiles FROM anon, authenticated;
GRANT SELECT (id, full_name, avatar_url, role, is_verified, reputation_points,
              specialization, created_at, updated_at)
  ON public.profiles TO anon, authenticated;
REVOKE UPDATE ON public.profiles FROM anon, authenticated;
REVOKE UPDATE (first_name, last_name, date_of_birth, gender, address, occupation, avatar_path)
  ON public.profiles FROM anon, authenticated;
-- Compatibility for existing clients, with validation and existing ownership RLS.
GRANT UPDATE (full_name, avatar_url, phone, bio, updated_at)
  ON public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'id', p.id, 'full_name', p.full_name, 'avatar_url', p.avatar_url,
    'first_name', p.first_name, 'last_name', p.last_name,
    'email', u.email, 'phone', p.phone, 'bio', p.bio,
    'date_of_birth', p.date_of_birth, 'gender', p.gender,
    'address', p.address, 'occupation', p.occupation, 'avatar_path', p.avatar_path,
    'role', p.role, 'reputation_points', p.reputation_points,
    'is_verified', p.is_verified, 'created_at', p.created_at, 'updated_at', p.updated_at)
  FROM public.profiles p JOIN auth.users u ON u.id = p.id
  WHERE p.id = auth.uid() AND public.is_session_active();
$$;

CREATE OR REPLACE FUNCTION public.update_my_profile(p_changes jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  caller uuid := auth.uid();
  item record;
  profile public.profiles%ROWTYPE;
BEGIN
  IF caller IS NULL OR NOT public.is_session_active() THEN
    RAISE EXCEPTION 'profile_access_denied' USING ERRCODE = '42501';
  END IF;
  IF p_changes IS NULL OR jsonb_typeof(p_changes) <> 'object'
     OR octet_length(p_changes::text) > 8192 THEN
    RAISE EXCEPTION 'invalid_profile_fields' USING ERRCODE = '22023';
  END IF;
  FOR item IN SELECT key, value FROM jsonb_each(p_changes) LOOP
    IF item.key NOT IN ('full_name', 'first_name', 'last_name', 'phone', 'bio',
        'date_of_birth', 'gender', 'address', 'occupation', 'avatar_path')
       OR jsonb_typeof(item.value) NOT IN ('string', 'null') THEN
      RAISE EXCEPTION 'invalid_profile_fields' USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(item.value) = 'string' THEN
      p_changes := jsonb_set(p_changes, ARRAY[item.key],
        coalesce(to_jsonb(nullif(btrim(item.value #>> '{}'), '')), 'null'::jsonb));
    END IF;
  END LOOP;
  IF p_changes ? 'date_of_birth' AND p_changes->>'date_of_birth' IS NOT NULL AND
     p_changes->>'date_of_birth' !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RAISE EXCEPTION 'invalid_profile_fields' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO STRICT profile FROM public.profiles WHERE id = caller FOR UPDATE;
  BEGIN
    profile := jsonb_populate_record(profile, p_changes);
  EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN
    RAISE EXCEPTION 'invalid_profile_fields' USING ERRCODE = '22023';
  END;
  IF profile.avatar_path IS NOT NULL AND
     (profile.avatar_path !~ ('^' || caller::text || '/[0-9a-f-]{36}\.(png|jpg|webp)$') OR
      NOT EXISTS (SELECT 1 FROM storage.objects o
        WHERE o.bucket_id = 'user-avatars' AND o.name = profile.avatar_path)) THEN
    RAISE EXCEPTION 'invalid_avatar_reference' USING ERRCODE = '22023';
  END IF;
  IF (p_changes ? 'first_name' OR p_changes ? 'last_name') AND
     nullif(btrim(concat_ws(' ', profile.first_name, profile.last_name)), '') IS NOT NULL THEN
    profile.full_name := btrim(concat_ws(' ', profile.first_name, profile.last_name));
  END IF;
  IF profile.full_name IS NULL THEN
    RAISE EXCEPTION 'invalid_profile_fields' USING ERRCODE = '22023';
  END IF;
  UPDATE public.profiles SET full_name = profile.full_name,
    first_name = profile.first_name, last_name = profile.last_name,
    phone = profile.phone, bio = profile.bio, date_of_birth = profile.date_of_birth,
    gender = profile.gender, address = profile.address, occupation = profile.occupation,
    avatar_path = profile.avatar_path, updated_at = now()
  WHERE id = caller;
  RETURN public.get_my_profile();
END;
$$;
REVOKE ALL ON FUNCTION public.validate_profile_details() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_my_profile(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile(), public.update_my_profile(jsonb) TO authenticated;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('user-avatars', 'user-avatars', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS private_avatar_owner ON storage.objects;
CREATE POLICY private_avatar_owner ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'user-avatars' AND (storage.foldername(name))[1] = auth.uid()::text
       AND public.is_session_active())
WITH CHECK (bucket_id = 'user-avatars' AND
  name ~ ('^' || auth.uid()::text || '/[0-9a-f-]{36}\.(png|jpg|webp)$')
  AND public.is_session_active());
-- Restrictive policy prevents a future broad permissive policy opening this bucket.
DROP POLICY IF EXISTS private_avatar_isolation ON storage.objects;
CREATE POLICY private_avatar_isolation ON storage.objects AS RESTRICTIVE FOR ALL TO anon, authenticated
USING (bucket_id <> 'user-avatars' OR
       ((storage.foldername(name))[1] = auth.uid()::text AND public.is_session_active()))
WITH CHECK (bucket_id <> 'user-avatars' OR
       ((storage.foldername(name))[1] = auth.uid()::text AND public.is_session_active()));

COMMIT;
-- Postflight: inspect pg_policies and has_column_privilege for every private field;
-- get_my_profile/update_my_profile must require authenticated active sessions.
