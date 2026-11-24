-- ==============================================================================
-- Minimum Client Version Enforcement & Security Hardening Migration
-- Blocks legacy app versions (< v2.1.0 / build 3) at the database RLS layer.
-- ==============================================================================

-- 1. Remote version policy table (read-only for clients)
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

-- 2. Header-based client build verification function
-- Older APKs (v1.0.x - v2.0.1) do not send x-notlyfe-build and are rejected.
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
  client_build INTEGER;
  min_build INTEGER;
BEGIN
  SELECT COALESCE(min_supported_build, 1)
  INTO min_build
  FROM public.app_config
  WHERE id = 1;

  IF min_build IS NULL THEN
    min_build := 3;
  END IF;

  headers_json := COALESCE(
    NULLIF(current_setting('request.headers', true), '')::jsonb,
    '{}'::jsonb
  );
  build_header := headers_json ->> 'x-notlyfe-build';

  IF build_header IS NULL OR build_header !~ '^[0-9]+$' THEN
    RETURN FALSE;
  END IF;

  client_build := build_header::integer;
  RETURN client_build >= min_build;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- 3. Harden handle_new_user() with explicit empty search_path
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
