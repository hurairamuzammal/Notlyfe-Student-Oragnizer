-- ==============================================================================
-- Row Level Security (RLS) & Minimum Client Version Enforcement for Notlyfe
-- Restricts all table data and storage objects to the owning authenticated user
-- AND requires a supported app build via the x-notlyfe-build request header.
-- ==============================================================================

-- 0. APP CONFIG & VERSION GATE
CREATE TABLE IF NOT EXISTS public.app_config (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  min_supported_version TEXT NOT NULL DEFAULT '2.1.0',
  min_supported_build INTEGER NOT NULL DEFAULT 3,
  latest_version TEXT NOT NULL DEFAULT '2.1.0',
  download_url TEXT NOT NULL DEFAULT 'https://github.com/hurairamuzammal/Notlyfe-Student-Oragnizer/releases/latest',
  update_message TEXT NOT NULL DEFAULT 'This version of Notlyfe is no longer supported due to security and storage upgrades. Please install v2.1.0 or newer.',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.app_config (
  id, min_supported_version, min_supported_build, latest_version, download_url, update_message
) VALUES (
  1,
  '2.1.0',
  3,
  '2.1.0',
  'https://github.com/hurairamuzammal/Notlyfe-Student-Oragnizer/releases/latest',
  'This version of Notlyfe is no longer supported due to security and storage upgrades. Please install v2.1.0 or newer.'
)
ON CONFLICT (id) DO UPDATE SET
  min_supported_version = EXCLUDED.min_supported_version,
  min_supported_build = EXCLUDED.min_supported_build,
  latest_version = EXCLUDED.latest_version,
  download_url = EXCLUDED.download_url,
  update_message = EXCLUDED.update_message,
  updated_at = NOW();

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read app config" ON public.app_config;
CREATE POLICY "Anyone can read app config"
ON public.app_config FOR SELECT
TO anon, authenticated
USING (true);

CREATE OR REPLACE FUNCTION public.is_client_version_supported()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  headers_json JSONB;
  build_header TEXT;
  min_build INTEGER;
BEGIN
  SELECT COALESCE(min_supported_build, 3)
  INTO min_build
  FROM public.app_config
  WHERE id = 1;

  headers_json := COALESCE(
    NULLIF(current_setting('request.headers', true), '')::jsonb,
    '{}'::jsonb
  );
  build_header := headers_json ->> 'x-notlyfe-build';

  IF build_header IS NULL OR build_header !~ '^[0-9]+$' THEN
    RETURN FALSE;
  END IF;

  RETURN build_header::integer >= COALESCE(min_build, 3);
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 1. COURSES TABLE
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own courses" ON public.courses;
DROP POLICY IF EXISTS "Users can insert own courses" ON public.courses;
DROP POLICY IF EXISTS "Users can update own courses" ON public.courses;
DROP POLICY IF EXISTS "Users can delete own courses" ON public.courses;

CREATE POLICY "Users can view own courses"
ON public.courses FOR SELECT
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can insert own courses"
ON public.courses FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can update own courses"
ON public.courses FOR UPDATE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported())
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can delete own courses"
ON public.courses FOR DELETE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

-- 2. NOTES TABLE (user_id stored as text)
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notes" ON public.notes;
DROP POLICY IF EXISTS "Users can insert own notes" ON public.notes;
DROP POLICY IF EXISTS "Users can update own notes" ON public.notes;
DROP POLICY IF EXISTS "Users can delete own notes" ON public.notes;

CREATE POLICY "Users can view own notes"
ON public.notes FOR SELECT
TO authenticated
USING ((select auth.uid())::text = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can insert own notes"
ON public.notes FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid())::text = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can update own notes"
ON public.notes FOR UPDATE
TO authenticated
USING ((select auth.uid())::text = user_id AND public.is_client_version_supported())
WITH CHECK ((select auth.uid())::text = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can delete own notes"
ON public.notes FOR DELETE
TO authenticated
USING ((select auth.uid())::text = user_id AND public.is_client_version_supported());

-- 3. TODO TABLE
ALTER TABLE public.todo ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.todo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own todos" ON public.todo;
DROP POLICY IF EXISTS "Users can insert own todos" ON public.todo;
DROP POLICY IF EXISTS "Users can update own todos" ON public.todo;
DROP POLICY IF EXISTS "Users can delete own todos" ON public.todo;

CREATE POLICY "Users can view own todos"
ON public.todo FOR SELECT
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can insert own todos"
ON public.todo FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can update own todos"
ON public.todo FOR UPDATE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported())
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can delete own todos"
ON public.todo FOR DELETE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

-- 4. USER_FILES TABLE
ALTER TABLE public.user_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own files" ON public.user_files;
DROP POLICY IF EXISTS "Users can insert own files" ON public.user_files;
DROP POLICY IF EXISTS "Users can update own files" ON public.user_files;
DROP POLICY IF EXISTS "Users can delete own files" ON public.user_files;

CREATE POLICY "Users can view own files"
ON public.user_files FOR SELECT
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can insert own files"
ON public.user_files FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can update own files"
ON public.user_files FOR UPDATE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported())
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can delete own files"
ON public.user_files FOR DELETE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

-- 5. USER_PROFILE TABLE
ALTER TABLE public.user_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profile;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profile;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profile;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.user_profile;

CREATE POLICY "Users can view own profile"
ON public.user_profile FOR SELECT
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can insert own profile"
ON public.user_profile FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can update own profile"
ON public.user_profile FOR UPDATE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported())
WITH CHECK ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE POLICY "Users can delete own profile"
ON public.user_profile FOR DELETE
TO authenticated
USING ((select auth.uid()) = user_id AND public.is_client_version_supported());

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.user_profile (user_id, full_name)
  VALUES (new.id, COALESCE(new.raw_user_meta_data->>'full_name', ''))
  ON CONFLICT (user_id) DO UPDATE
  SET full_name = EXCLUDED.full_name
  WHERE public.user_profile.full_name IS NULL
     OR public.user_profile.full_name = ''
     OR public.user_profile.full_name = 'Anonymous';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. STORAGE POLICIES FOR uploaded_files
DROP POLICY IF EXISTS "Public can view uploaded files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can read files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own files" ON storage.objects;
DROP POLICY IF EXISTS allow_uploads ON storage.objects;
DROP POLICY IF EXISTS "Users can view own storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own storage objects" ON storage.objects;

CREATE POLICY "Users can view own storage objects"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'uploaded_files'
  AND public.is_client_version_supported()
  AND (
    (auth.uid())::text = (storage.foldername(name))[1]
    OR ((storage.foldername(name))[1] = 'public' AND (auth.uid())::text = (storage.foldername(name))[2])
  )
);

CREATE POLICY "Users can upload own storage objects"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'uploaded_files'
  AND public.is_client_version_supported()
  AND (
    (auth.uid())::text = (storage.foldername(name))[1]
    OR ((storage.foldername(name))[1] = 'public' AND (auth.uid())::text = (storage.foldername(name))[2])
  )
);

CREATE POLICY "Users can update own storage objects"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'uploaded_files'
  AND public.is_client_version_supported()
  AND (
    (auth.uid())::text = (storage.foldername(name))[1]
    OR ((storage.foldername(name))[1] = 'public' AND (auth.uid())::text = (storage.foldername(name))[2])
  )
)
WITH CHECK (
  bucket_id = 'uploaded_files'
  AND public.is_client_version_supported()
  AND (
    (auth.uid())::text = (storage.foldername(name))[1]
    OR ((storage.foldername(name))[1] = 'public' AND (auth.uid())::text = (storage.foldername(name))[2])
  )
);

CREATE POLICY "Users can delete own storage objects"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'uploaded_files'
  AND public.is_client_version_supported()
  AND (
    (auth.uid())::text = (storage.foldername(name))[1]
    OR ((storage.foldername(name))[1] = 'public' AND (auth.uid())::text = (storage.foldername(name))[2])
  )
);
