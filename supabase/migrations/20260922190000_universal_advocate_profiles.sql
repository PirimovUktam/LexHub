-- Additive professional profile. Expert approval remains authoritative in
-- expert_profiles/profiles; public display fields require explicit publication.
BEGIN;

DO $$ BEGIN
  IF to_regclass('public.expert_profiles') IS NULL
     OR to_regclass('public.consultations') IS NULL
     OR to_regprocedure('public.is_session_active()') IS NULL THEN
    RAISE EXCEPTION 'Advocate profile prerequisites missing';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.advocate_profiles (
  expert_id uuid PRIMARY KEY REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  first_name text NOT NULL CHECK (char_length(btrim(first_name)) BETWEEN 1 AND 64),
  last_name text NOT NULL CHECK (char_length(btrim(last_name)) BETWEEN 1 AND 64),
  bio text NOT NULL DEFAULT '' CHECK (char_length(bio) <= 3000),
  address text NOT NULL DEFAULT '' CHECK (char_length(address) <= 500),
  public_phone text CHECK (public_phone IS NULL OR public_phone ~ '^\+[1-9][0-9]{7,14}$'),
  public_email text CHECK (public_email IS NULL OR
    (char_length(public_email) <= 254 AND public_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')),
  specializations text[] NOT NULL DEFAULT '{}' CHECK (cardinality(specializations) <= 12),
  languages text[] NOT NULL DEFAULT '{}' CHECK (cardinality(languages) <= 12),
  avatar_path text,
  accepting_clients boolean NOT NULL DEFAULT true,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.advocate_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
  description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
  price_uzs numeric(12,2) CHECK (price_uzs >= 0),
  duration_minutes integer CHECK (duration_minutes BETWEEN 5 AND 480),
  delivery_mode text NOT NULL CHECK (delivery_mode IN ('online','offline','written')),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order BETWEEN 0 AND 9999),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.advocate_experience (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  organization text NOT NULL CHECK (char_length(btrim(organization)) BETWEEN 1 AND 200),
  position text NOT NULL CHECK (char_length(btrim(position)) BETWEEN 1 AND 120),
  start_date date NOT NULL CHECK (isfinite(start_date)),
  end_date date CHECK (isfinite(end_date) AND end_date >= start_date),
  description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.advocate_education (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  institution text NOT NULL CHECK (char_length(btrim(institution)) BETWEEN 1 AND 200),
  qualification text NOT NULL CHECK (char_length(btrim(qualification)) BETWEEN 1 AND 200),
  start_year integer NOT NULL CHECK (start_year BETWEEN 1900 AND 2200),
  end_year integer CHECK (end_year BETWEEN start_year AND 2200),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.advocate_working_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  weekday integer NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  opens_at time,
  closes_at time,
  is_closed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(expert_id, weekday),
  CHECK ((is_closed AND opens_at IS NULL AND closes_at IS NULL) OR
    (NOT is_closed AND opens_at IS NOT NULL AND closes_at IS NOT NULL AND closes_at > opens_at))
);
CREATE TABLE IF NOT EXISTS public.advocate_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 160),
  kind text NOT NULL CHECK (kind IN ('license','certificate','diploma')),
  object_path text NOT NULL UNIQUE,
  is_public boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.advocate_consultation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  service_id uuid REFERENCES public.advocate_services(id) ON DELETE SET NULL,
  service_title text,
  price_uzs numeric(12,2),
  kind text NOT NULL CHECK (kind IN ('consultation','message')),
  message text NOT NULL CHECK (char_length(btrim(message)) BETWEEN 1 AND 4000),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','cancelled','completed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.advocate_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.advocate_consultation_requests(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.advocate_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expert_id uuid NOT NULL REFERENCES public.expert_profiles(id) ON DELETE CASCADE,
  consultation_id uuid NOT NULL UNIQUE REFERENCES public.consultations(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text NOT NULL CHECK (char_length(btrim(comment)) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS advocate_requests_requester ON public.advocate_consultation_requests(requester_id, created_at DESC);
CREATE INDEX IF NOT EXISTS advocate_requests_expert ON public.advocate_consultation_requests(expert_id, created_at DESC);
CREATE INDEX IF NOT EXISTS advocate_messages_request ON public.advocate_messages(request_id, created_at);
CREATE INDEX IF NOT EXISTS advocate_messages_sender ON public.advocate_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS advocate_reviews_expert ON public.advocate_reviews(expert_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.owns_advocate(p_expert_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.is_session_active() AND EXISTS (
    SELECT 1 FROM public.expert_profiles WHERE id = p_expert_id AND user_id = auth.uid());
$$;
CREATE OR REPLACE FUNCTION public.is_advocate_public(p_expert_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM public.expert_profiles e
    LEFT JOIN public.advocate_profiles a ON a.expert_id = e.id
    JOIN public.profiles p ON p.id = e.user_id
    WHERE e.id = p_expert_id AND (a.expert_id IS NULL OR a.is_published)
      AND e.verified_at IS NOT NULL AND e.rejected_at IS NULL AND p.is_verified
      AND p.role::text IN ('verified_expert','lawyer'));
$$;
CREATE OR REPLACE FUNCTION public.is_advocate_request_participant(p_request_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.is_session_active() AND EXISTS (
    SELECT 1 FROM public.advocate_consultation_requests r
    JOIN public.expert_profiles e ON e.id = r.expert_id
    WHERE r.id = p_request_id AND auth.uid() IN (r.requester_id, e.user_id));
$$;

-- Shared child write guard keeps identity/timestamps immutable and ensures a
-- document references an existing object owned by the same professional.
CREATE OR REPLACE FUNCTION public.guard_advocate_child_write()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.id IS DISTINCT FROM OLD.id
      OR NEW.expert_id IS DISTINCT FROM OLD.expert_id
      OR NEW.created_at IS DISTINCT FROM OLD.created_at) THEN
    RAISE EXCEPTION 'advocate_identity_immutable' USING ERRCODE = '42501';
  END IF;
  IF TG_TABLE_NAME = 'advocate_documents' THEN
    IF NEW.object_path !~ ('^' || auth.uid()::text || '/[0-9a-f-]{36}\.(png|jpg|webp|pdf)$')
       OR NOT EXISTS (SELECT 1 FROM storage.objects o
         WHERE o.bucket_id = 'advocate-documents' AND o.name = NEW.object_path) THEN
      RAISE EXCEPTION 'invalid_advocate_document' USING ERRCODE = '22023';
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN NEW.created_at := now(); END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DO $$ DECLARE relation text; BEGIN
  FOREACH relation IN ARRAY ARRAY['advocate_profiles','advocate_services',
    'advocate_experience','advocate_education','advocate_working_hours',
    'advocate_documents','advocate_consultation_requests','advocate_messages','advocate_reviews'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', relation);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', relation);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role', relation);
    EXECUTE format('GRANT SELECT ON TABLE public.%I TO authenticated', relation);
    EXECUTE format('DROP POLICY IF EXISTS active_session_required ON public.%I', relation);
    EXECUTE format('CREATE POLICY active_session_required ON public.%I AS RESTRICTIVE FOR ALL TO authenticated
      USING ((SELECT public.is_session_active())) WITH CHECK ((SELECT public.is_session_active()))', relation);
  END LOOP;
  FOREACH relation IN ARRAY ARRAY['advocate_services','advocate_experience',
    'advocate_education','advocate_working_hours','advocate_documents'] LOOP
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(expert_id)', relation || '_expert', relation);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated', relation);
    EXECUTE format('DROP POLICY IF EXISTS advocate_child_owner ON public.%I', relation);
    EXECUTE format('CREATE POLICY advocate_child_owner ON public.%I FOR ALL TO authenticated
      USING (public.owns_advocate(expert_id)) WITH CHECK (public.owns_advocate(expert_id))', relation);
    EXECUTE format('DROP TRIGGER IF EXISTS advocate_child_write ON public.%I', relation);
    EXECUTE format('CREATE TRIGGER advocate_child_write BEFORE INSERT OR UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.guard_advocate_child_write()', relation);
  END LOOP;
END $$;
DROP POLICY IF EXISTS advocate_profile_owner ON public.advocate_profiles;
CREATE POLICY advocate_profile_owner ON public.advocate_profiles FOR SELECT TO authenticated
  USING (public.owns_advocate(expert_id));
DROP POLICY IF EXISTS advocate_requests_participant ON public.advocate_consultation_requests;
CREATE POLICY advocate_requests_participant ON public.advocate_consultation_requests FOR SELECT TO authenticated
  USING (public.is_advocate_request_participant(id));
DROP POLICY IF EXISTS advocate_messages_participant ON public.advocate_messages;
CREATE POLICY advocate_messages_participant ON public.advocate_messages FOR SELECT TO authenticated
  USING (public.is_advocate_request_participant(request_id));
DROP POLICY IF EXISTS advocate_reviews_owner ON public.advocate_reviews;
CREATE POLICY advocate_reviews_owner ON public.advocate_reviews FOR SELECT TO authenticated
  USING (reviewer_id = auth.uid());

CREATE OR REPLACE FUNCTION public.get_advocate_profile(p_expert_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE result jsonb; owner boolean := public.owns_advocate(p_expert_id);
BEGIN
  PERFORM public.require_active_session();
  IF NOT owner AND NOT public.is_advocate_public(p_expert_id) THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.advocate_profiles WHERE expert_id = p_expert_id) THEN
    RETURN (SELECT jsonb_build_object('id', e.id, 'user_id', e.user_id, 'is_owner', owner,
      'full_name', p.full_name, 'first_name', NULL, 'last_name', NULL,
      'avatar_path', NULL, 'avatar_url', p.avatar_url, 'bio', '', 'address', '',
      'public_phone', NULL, 'public_email', NULL,
      'specializations', CASE WHEN nullif(e.specialization,'') IS NULL THEN '[]'::jsonb
        ELSE jsonb_build_array(e.specialization) END, 'languages', '[]'::jsonb,
      'experience_years', e.experience_years, 'workplace', e.workplace,
      'accepting_clients', e.is_available_for_booking, 'is_published', NOT owner OR public.is_advocate_public(e.id),
      'verified', public.is_advocate_public(e.id),
      'license_number', CASE WHEN public.is_advocate_public(e.id) THEN e.license_number END,
      'rating', NULL, 'reviews_count', 0,
      'consultations_count', (SELECT count(*) FROM public.consultations c
        WHERE c.expert_id=e.id AND c.status::text='completed'),
      'services', '[]'::jsonb, 'experience', '[]'::jsonb, 'education', '[]'::jsonb,
      'working_hours', '[]'::jsonb, 'documents', '[]'::jsonb, 'reviews', '[]'::jsonb,
      'eligible_consultation_ids', '[]'::jsonb, 'created_at',e.created_at,'updated_at',e.updated_at)
      FROM public.expert_profiles e JOIN public.profiles p ON p.id=e.user_id WHERE e.id=p_expert_id);
  END IF;
  SELECT jsonb_build_object(
    'id', a.expert_id, 'user_id', e.user_id, 'is_owner', owner,
    'full_name', concat_ws(' ', a.first_name, a.last_name),
    'first_name', a.first_name, 'last_name', a.last_name,
    'avatar_path', a.avatar_path, 'bio', a.bio, 'address', a.address,
    'public_phone', a.public_phone, 'public_email', a.public_email,
    'specializations', a.specializations, 'languages', a.languages,
    'experience_years', e.experience_years, 'workplace', e.workplace,
    'accepting_clients', a.accepting_clients, 'is_published', a.is_published,
    'verified', e.verified_at IS NOT NULL AND e.rejected_at IS NULL AND p.is_verified
      AND p.role::text IN ('verified_expert','lawyer'),
    'license_number', CASE WHEN e.verified_at IS NOT NULL AND e.rejected_at IS NULL
      AND p.is_verified AND p.role::text IN ('verified_expert','lawyer') THEN e.license_number END,
    'created_at', a.created_at, 'updated_at', a.updated_at,
    'rating', (SELECT round(avg(r.rating),2) FROM public.advocate_reviews r WHERE r.expert_id = a.expert_id),
    'reviews_count', (SELECT count(*) FROM public.advocate_reviews r WHERE r.expert_id = a.expert_id),
    'consultations_count', (SELECT count(*) FROM public.consultations c WHERE c.expert_id = a.expert_id AND c.status::text = 'completed'),
    'services', coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.sort_order, s.created_at)
      FROM public.advocate_services s WHERE s.expert_id = a.expert_id AND (owner OR s.is_active)), '[]'::jsonb),
    'experience', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.start_date DESC)
      FROM public.advocate_experience x WHERE x.expert_id = a.expert_id), '[]'::jsonb),
    'education', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.start_year DESC)
      FROM public.advocate_education x WHERE x.expert_id = a.expert_id), '[]'::jsonb),
    'working_hours', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.weekday)
      FROM public.advocate_working_hours x WHERE x.expert_id = a.expert_id), '[]'::jsonb),
    'documents', coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM public.advocate_documents x WHERE x.expert_id = a.expert_id AND (owner OR x.is_public)), '[]'::jsonb),
    'reviews', coalesce((SELECT jsonb_agg(jsonb_build_object('id', r.id, 'rating', r.rating,
      'comment', r.comment, 'created_at', r.created_at, 'updated_at', r.updated_at) ORDER BY r.created_at DESC)
      FROM public.advocate_reviews r WHERE r.expert_id = a.expert_id), '[]'::jsonb),
    'eligible_consultation_ids', coalesce((SELECT jsonb_agg(c.id) FROM public.consultations c
      WHERE c.expert_id = a.expert_id AND c.citizen_id = auth.uid() AND c.status::text = 'completed'
        AND NOT EXISTS (SELECT 1 FROM public.advocate_reviews r WHERE r.consultation_id = c.id)), '[]'::jsonb))
    INTO result FROM public.advocate_profiles a JOIN public.expert_profiles e ON e.id = a.expert_id
    JOIN public.profiles p ON p.id = e.user_id WHERE a.expert_id = p_expert_id;
  RETURN result;
END;
$$;
CREATE OR REPLACE FUNCTION public.get_my_advocate_profile()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.get_advocate_profile(e.id) FROM public.expert_profiles e
    JOIN public.advocate_profiles a ON a.expert_id = e.id
    WHERE e.user_id = auth.uid() AND public.is_session_active();
$$;
-- Preserve the existing directory column contract and verified legacy profiles.
-- Private account phone and avatar_path never become professional publication.
-- Existing installations use either text or varchar for these two columns.
-- Preserve their exact types/typmods in place; replacing the view must not
-- require dropping dependants, changing grants, or rewriting account columns.
DO $advocate_directory$
DECLARE view_full_name_type text; view_phone_type text;
BEGIN
  SELECT max(CASE WHEN attname = 'full_name' THEN pg_catalog.format_type(atttypid, atttypmod) END),
         max(CASE WHEN attname = 'phone' THEN pg_catalog.format_type(atttypid, atttypmod) END)
    INTO view_full_name_type, view_phone_type
    FROM pg_catalog.pg_attribute
    WHERE attrelid = 'public.public_expert_profiles_view'::regclass
      AND attname IN ('full_name', 'phone') AND NOT attisdropped
      AND atttypid IN ('pg_catalog.text'::regtype, 'pg_catalog.varchar'::regtype);
  IF view_full_name_type IS NULL OR view_phone_type IS NULL THEN
    RAISE EXCEPTION 'Unsupported advocate directory name/phone column contract';
  END IF;
  EXECUTE format($view$
CREATE OR REPLACE VIEW public.public_expert_profiles_view AS
SELECT e.id AS expert_id, e.user_id,
  (CASE WHEN a.expert_id IS NULL THEN p.full_name
    ELSE concat_ws(' ',a.first_name,a.last_name) END)::%s AS full_name,
  CASE WHEN a.expert_id IS NULL THEN p.avatar_url ELSE NULL::text END AS avatar_url,
  a.public_phone::%s AS phone, p.role, p.is_verified AS is_profile_verified,
  CASE WHEN cardinality(a.specializations)>0 THEN a.specializations[1]::varchar(128)
    ELSE e.specialization END AS specialization,
  e.experience_years, e.education, e.workplace,
  (SELECT round(avg(r.rating),2)::numeric(3,2) FROM public.advocate_reviews r WHERE r.expert_id=e.id) AS rating,
  (SELECT count(*)::integer FROM public.advocate_reviews r WHERE r.expert_id=e.id) AS reviews_count,
  e.consultation_fee, coalesce(a.accepting_clients,e.is_available_for_booking) AS is_available_for_booking,
  e.verified_at, e.created_at, coalesce(a.updated_at,e.updated_at) AS updated_at, e.license_number,
  a.avatar_path, a.specializations,
  (SELECT count(*)::integer FROM public.consultations c WHERE c.expert_id=e.id AND c.status::text='completed') AS consultations_count
FROM public.expert_profiles e JOIN public.profiles p ON p.id=e.user_id
LEFT JOIN public.advocate_profiles a ON a.expert_id=e.id
WHERE public.is_advocate_public(e.id)
  AND (auth.role() IS DISTINCT FROM 'authenticated' OR public.is_session_active());
$view$, view_full_name_type, view_phone_type);
END $advocate_directory$;
GRANT SELECT ON public.public_expert_profiles_view TO anon, authenticated;
CREATE OR REPLACE FUNCTION public.get_advocate_directory()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM public.require_active_session();
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(v) ORDER BY v.updated_at DESC)
    FROM public.public_expert_profiles_view v), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_advocate_profile(p_profile jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller uuid := auth.uid(); expert uuid; item record; a public.advocate_profiles%ROWTYPE;
BEGIN
  IF caller IS NULL OR NOT public.is_session_active() THEN
    RAISE EXCEPTION 'advocate_access_denied' USING ERRCODE = '42501';
  END IF;
  IF p_profile IS NULL OR jsonb_typeof(p_profile) <> 'object' OR octet_length(p_profile::text) > 16384 THEN
    RAISE EXCEPTION 'invalid_advocate_profile' USING ERRCODE = '22023';
  END IF;
  FOR item IN SELECT key,value FROM jsonb_each(p_profile) LOOP
    IF item.key NOT IN ('first_name','last_name','bio','address','public_phone','public_email',
      'specializations','languages','avatar_path','accepting_clients','is_published','experience_years','workplace')
      OR (item.key IN ('specializations','languages') AND jsonb_typeof(item.value) <> 'array')
      OR (item.key IN ('accepting_clients','is_published') AND jsonb_typeof(item.value) <> 'boolean')
      OR (item.key = 'experience_years' AND (jsonb_typeof(item.value) <> 'number' OR
        item.value::text !~ '^[0-9]{1,2}$'))
      OR (item.key NOT IN ('specializations','languages','accepting_clients','is_published','experience_years')
        AND jsonb_typeof(item.value) NOT IN ('string','null')) THEN
      RAISE EXCEPTION 'invalid_advocate_profile' USING ERRCODE = '22023';
    END IF;
    IF item.key IN ('specializations','languages') AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(item.value) v WHERE jsonb_typeof(v) <> 'string'
        OR char_length(btrim(v #>> '{}')) NOT BETWEEN 1 AND 80) THEN
      RAISE EXCEPTION 'invalid_advocate_profile' USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF char_length(p_profile->>'workplace') > 255 THEN
    RAISE EXCEPTION 'invalid_advocate_profile' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.expert_profiles(user_id, rating, reviews_count, experience_years)
    VALUES(caller, NULL, 0, 0) ON CONFLICT(user_id) DO NOTHING;
  SELECT id INTO STRICT expert FROM public.expert_profiles WHERE user_id = caller FOR UPDATE;
  INSERT INTO public.advocate_profiles(expert_id, first_name, last_name)
    SELECT expert, p_profile->>'first_name', p_profile->>'last_name'
    WHERE NOT EXISTS (SELECT 1 FROM public.advocate_profiles WHERE expert_id = expert);
  SELECT * INTO STRICT a FROM public.advocate_profiles WHERE expert_id = expert FOR UPDATE;
  a := jsonb_populate_record(a, p_profile - ARRAY['experience_years','workplace']);
  IF a.avatar_path IS NOT NULL AND (a.avatar_path !~
      ('^' || caller::text || '/[0-9a-f-]{36}\.(png|jpg|webp)$') OR NOT EXISTS (
        SELECT 1 FROM storage.objects o WHERE o.bucket_id = 'advocate-documents' AND o.name = a.avatar_path)) THEN
    RAISE EXCEPTION 'invalid_advocate_avatar' USING ERRCODE = '22023';
  END IF;
  UPDATE public.advocate_profiles SET first_name = btrim(a.first_name), last_name = btrim(a.last_name),
    bio = a.bio, address = a.address, public_phone = a.public_phone, public_email = a.public_email,
    specializations = a.specializations, languages = a.languages, avatar_path = a.avatar_path,
    accepting_clients = a.accepting_clients, is_published = a.is_published, updated_at = now()
    WHERE expert_id = expert;
  UPDATE public.expert_profiles SET
    experience_years = CASE WHEN p_profile ? 'experience_years' THEN (p_profile->>'experience_years')::integer ELSE experience_years END,
    workplace = CASE WHEN p_profile ? 'workplace' THEN p_profile->>'workplace' ELSE workplace END,
    specialization = CASE WHEN cardinality(a.specializations) > 0 THEN a.specializations[1] ELSE specialization END,
    is_available_for_booking = a.accepting_clients WHERE id = expert;
  RETURN public.get_advocate_profile(expert);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_advocate_request(p_expert_id uuid, p_message text,
  p_service_id uuid DEFAULT NULL, p_kind text DEFAULT 'consultation')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller uuid := auth.uid(); result public.advocate_consultation_requests%ROWTYPE;
  service public.advocate_services%ROWTYPE;
BEGIN
  IF caller IS NULL OR NOT public.is_session_active() OR NOT public.is_advocate_public(p_expert_id)
    OR public.owns_advocate(p_expert_id) THEN
    RAISE EXCEPTION 'advocate_request_denied' USING ERRCODE = '42501';
  END IF;
  IF p_message IS NULL OR char_length(btrim(p_message)) NOT BETWEEN 1 AND 4000
    OR p_kind IS NULL OR p_kind NOT IN ('consultation','message') THEN
    RAISE EXCEPTION 'invalid_advocate_request' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.expert_profiles e
    LEFT JOIN public.advocate_profiles a ON a.expert_id = e.id
    WHERE e.id = p_expert_id AND coalesce(a.accepting_clients, e.is_available_for_booking)) THEN
    RAISE EXCEPTION 'advocate_unavailable' USING ERRCODE = '22023';
  END IF;
  IF p_service_id IS NOT NULL THEN
    SELECT * INTO service FROM public.advocate_services
      WHERE id = p_service_id AND expert_id = p_expert_id AND is_active FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'invalid_advocate_service' USING ERRCODE = '22023'; END IF;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('advocate_request:' || caller::text));
  IF (SELECT count(*) FROM public.advocate_consultation_requests
      WHERE requester_id = caller AND created_at > now() - interval '1 hour') >= 10
    OR (SELECT count(*) FROM public.advocate_consultation_requests
      WHERE requester_id = caller AND expert_id = p_expert_id AND created_at > now() - interval '1 hour') >= 3 THEN
    RAISE EXCEPTION 'advocate_request_rate_limited' USING ERRCODE = 'PT429';
  END IF;
  INSERT INTO public.advocate_consultation_requests(expert_id, requester_id, service_id,
      service_title, price_uzs, kind, message)
    VALUES(p_expert_id, caller, p_service_id, service.title, service.price_uzs, p_kind, btrim(p_message))
    RETURNING * INTO result;
  RETURN to_jsonb(result);
END;
$$;
CREATE OR REPLACE FUNCTION public.update_advocate_request_status(p_request_id uuid, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.advocate_consultation_requests%ROWTYPE; owner boolean;
BEGIN
  IF NOT public.is_advocate_request_participant(p_request_id) THEN
    RAISE EXCEPTION 'advocate_request_denied' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO STRICT r FROM public.advocate_consultation_requests WHERE id = p_request_id FOR UPDATE;
  owner := public.owns_advocate(r.expert_id);
  IF p_status IS NULL OR NOT (
    (owner AND r.status = 'pending' AND p_status IN ('accepted','declined')) OR
    (NOT owner AND r.status IN ('pending','accepted') AND p_status = 'cancelled') OR
    (NOT owner AND r.status = 'accepted' AND p_status = 'completed')) THEN
    RAISE EXCEPTION 'invalid_advocate_request_transition' USING ERRCODE = '22023';
  END IF;
  UPDATE public.advocate_consultation_requests SET status = p_status, updated_at = now()
    WHERE id = p_request_id RETURNING * INTO r;
  RETURN to_jsonb(r);
END;
$$;
CREATE OR REPLACE FUNCTION public.send_advocate_message(p_request_id uuid, p_body text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE result public.advocate_messages%ROWTYPE;
BEGIN
  IF NOT public.is_advocate_request_participant(p_request_id) THEN
    RAISE EXCEPTION 'advocate_message_denied' USING ERRCODE = '42501';
  END IF;
  IF p_body IS NULL OR char_length(btrim(p_body)) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'invalid_advocate_message' USING ERRCODE = '22023';
  END IF;
  -- Hold the row through INSERT so cancellation/completion cannot race past
  -- a previously observed open state. A waiter rechecks the current status.
  PERFORM 1 FROM public.advocate_consultation_requests
    WHERE id = p_request_id AND status IN ('pending','accepted') FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'advocate_conversation_closed' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('advocate_message:' || auth.uid()::text));
  IF (SELECT count(*) FROM public.advocate_messages WHERE sender_id = auth.uid()
    AND created_at > now() - interval '1 minute') >= 30 THEN
    RAISE EXCEPTION 'advocate_message_rate_limited' USING ERRCODE = 'PT429';
  END IF;
  INSERT INTO public.advocate_messages(request_id, sender_id, body)
    VALUES(p_request_id, auth.uid(), btrim(p_body)) RETURNING * INTO result;
  RETURN to_jsonb(result);
END;
$$;
CREATE OR REPLACE FUNCTION public.save_advocate_review(p_consultation_id uuid, p_rating integer, p_comment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE expert uuid; result public.advocate_reviews%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_session_active() THEN
    RAISE EXCEPTION 'advocate_review_denied' USING ERRCODE = '42501';
  END IF;
  SELECT c.expert_id INTO expert FROM public.consultations c
    JOIN public.expert_profiles e ON e.id = c.expert_id
    WHERE c.id = p_consultation_id AND c.citizen_id = auth.uid() AND c.status::text = 'completed'
      AND e.user_id <> auth.uid();
  IF expert IS NULL THEN RAISE EXCEPTION 'advocate_review_denied' USING ERRCODE = '42501'; END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 OR p_comment IS NULL
    OR char_length(btrim(p_comment)) NOT BETWEEN 1 AND 2000 THEN
    RAISE EXCEPTION 'invalid_advocate_review' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.advocate_reviews(expert_id, consultation_id, reviewer_id, rating, comment)
    VALUES(expert, p_consultation_id, auth.uid(), p_rating, btrim(p_comment))
    ON CONFLICT(consultation_id) DO UPDATE SET rating = EXCLUDED.rating, comment = EXCLUDED.comment, updated_at = now()
    RETURNING * INTO result;
  RETURN to_jsonb(result);
END;
$$;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  VALUES('advocate-documents','advocate-documents',false,10485760,
    ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
  ON CONFLICT(id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;
CREATE OR REPLACE FUNCTION public.can_read_advocate_object(p_name text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT ((storage.foldername(p_name))[1] = auth.uid()::text AND public.is_session_active())
    OR EXISTS (SELECT 1 FROM public.advocate_profiles a WHERE a.avatar_path = p_name
      AND public.is_advocate_public(a.expert_id))
    OR EXISTS (SELECT 1 FROM public.advocate_documents d WHERE d.object_path = p_name
      AND d.is_public AND public.is_advocate_public(d.expert_id));
$$;
DROP POLICY IF EXISTS advocate_objects_read ON storage.objects;
CREATE POLICY advocate_objects_read ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'advocate-documents' AND public.can_read_advocate_object(name));
DROP POLICY IF EXISTS advocate_objects_owner ON storage.objects;
CREATE POLICY advocate_objects_owner ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'advocate-documents' AND (storage.foldername(name))[1] = auth.uid()::text
    AND public.is_session_active())
  WITH CHECK (bucket_id = 'advocate-documents' AND public.is_session_active()
    AND name ~ ('^' || auth.uid()::text || '/[0-9a-f-]{36}\.(png|jpg|webp|pdf)$'));
DROP POLICY IF EXISTS advocate_objects_read_boundary ON storage.objects;
CREATE POLICY advocate_objects_read_boundary ON storage.objects AS RESTRICTIVE FOR SELECT TO anon, authenticated
  USING (bucket_id <> 'advocate-documents' OR public.can_read_advocate_object(name));
DO $$ DECLARE operation text; BEGIN
  FOREACH operation IN ARRAY ARRAY['INSERT','UPDATE','DELETE'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', 'advocate_objects_' || lower(operation) || '_boundary');
    IF operation = 'INSERT' THEN
      EXECUTE 'CREATE POLICY advocate_objects_insert_boundary ON storage.objects AS RESTRICTIVE FOR INSERT TO anon, authenticated
        WITH CHECK (bucket_id <> ''advocate-documents'' OR
          (public.is_session_active() AND name ~ (''^'' || auth.uid()::text || ''/[0-9a-f-]{36}\.(png|jpg|webp|pdf)$'')))';
    ELSIF operation = 'UPDATE' THEN
      EXECUTE 'CREATE POLICY advocate_objects_update_boundary ON storage.objects AS RESTRICTIVE FOR UPDATE TO anon, authenticated
        USING (bucket_id <> ''advocate-documents'' OR (public.is_session_active() AND (storage.foldername(name))[1] = auth.uid()::text))
        WITH CHECK (bucket_id <> ''advocate-documents'' OR
          (public.is_session_active() AND name ~ (''^'' || auth.uid()::text || ''/[0-9a-f-]{36}\.(png|jpg|webp|pdf)$'')))';
    ELSE
      EXECUTE 'CREATE POLICY advocate_objects_delete_boundary ON storage.objects AS RESTRICTIVE FOR DELETE TO anon, authenticated
        USING (bucket_id <> ''advocate-documents'' OR (public.is_session_active() AND (storage.foldername(name))[1] = auth.uid()::text))';
    END IF;
  END LOOP;
END $$;

DO $$ DECLARE f record; BEGIN
  FOR f IN SELECT p.oid::regprocedure signature, p.proname FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public'
      AND p.proname IN ('owns_advocate','is_advocate_public','is_advocate_request_participant',
        'guard_advocate_child_write','get_advocate_profile','get_my_advocate_profile','get_advocate_directory',
        'save_advocate_profile','send_advocate_request','update_advocate_request_status',
        'send_advocate_message','save_advocate_review','can_read_advocate_object') LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', f.signature);
    IF f.proname <> 'guard_advocate_child_write' THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f.signature);
    END IF;
    IF f.proname IN ('owns_advocate','is_advocate_public','is_advocate_request_participant',
      'get_advocate_profile','get_advocate_directory','can_read_advocate_object') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon', f.signature);
    END IF;
  END LOOP;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;

-- Read-only postflight: private bucket, 9 RLS tables, no anon table grants,
-- public read RPCs only; runtime ownership/revocation tests remain required.
-- SELECT id,public,file_size_limit FROM storage.buckets WHERE id='advocate-documents';
-- SELECT tablename,policyname,cmd FROM pg_policies WHERE tablename LIKE 'advocate_%';
-- SELECT has_function_privilege('anon','public.save_advocate_profile(jsonb)','EXECUTE');
