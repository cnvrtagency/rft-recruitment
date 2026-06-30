-- Tighten admin access and bring the live database schema in line with the app.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE enquiries ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE cv_submissions ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE cv_submissions ADD COLUMN IF NOT EXISTS cv_category TEXT;
ALTER TABLE job_listings ADD COLUMN IF NOT EXISTS slug TEXT;

CREATE TABLE IF NOT EXISTS cv_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  phone TEXT,
  type TEXT DEFAULT 'candidate',
  company TEXT,
  sector TEXT,
  notes TEXT,
  status TEXT DEFAULT 'new',
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE,
  email TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT admin_users_identity CHECK (user_id IS NOT NULL OR email IS NOT NULL)
);

INSERT INTO admin_users (email)
VALUES ('danlyons20@gmail.com')
ON CONFLICT (email) DO NOTHING;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users au
    WHERE au.user_id = auth.uid()
       OR lower(au.email) = lower(auth.jwt() ->> 'email')
  );
$$;

ALTER TABLE enquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE cv_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE cv_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "enquiries_insert_public" ON enquiries;
DROP POLICY IF EXISTS "enquiries_select_auth" ON enquiries;
DROP POLICY IF EXISTS "enquiries_update_auth" ON enquiries;
DROP POLICY IF EXISTS "enquiries_delete_auth" ON enquiries;
CREATE POLICY "enquiries_insert_public" ON enquiries
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "enquiries_select_admin" ON enquiries
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "enquiries_update_admin" ON enquiries
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "enquiries_delete_admin" ON enquiries
  FOR DELETE TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "cv_insert_public" ON cv_submissions;
DROP POLICY IF EXISTS "cv_select_auth" ON cv_submissions;
DROP POLICY IF EXISTS "cv_update_auth" ON cv_submissions;
DROP POLICY IF EXISTS "cv_delete_auth" ON cv_submissions;
CREATE POLICY "cv_insert_public" ON cv_submissions
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "cv_select_admin" ON cv_submissions
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "cv_update_admin" ON cv_submissions
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "cv_delete_admin" ON cv_submissions
  FOR DELETE TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "jobs_select_public" ON job_listings;
DROP POLICY IF EXISTS "jobs_insert_auth" ON job_listings;
DROP POLICY IF EXISTS "jobs_update_auth" ON job_listings;
DROP POLICY IF EXISTS "jobs_delete_auth" ON job_listings;
CREATE POLICY "jobs_select_public" ON job_listings
  FOR SELECT USING (published = true OR public.is_admin());
CREATE POLICY "jobs_insert_admin" ON job_listings
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY "jobs_update_admin" ON job_listings
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "jobs_delete_admin" ON job_listings
  FOR DELETE TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "auth manage cv_categories" ON cv_categories;
DROP POLICY IF EXISTS "cv_categories_select_admin" ON cv_categories;
DROP POLICY IF EXISTS "cv_categories_insert_admin" ON cv_categories;
DROP POLICY IF EXISTS "cv_categories_update_admin" ON cv_categories;
DROP POLICY IF EXISTS "cv_categories_delete_admin" ON cv_categories;
CREATE POLICY "cv_categories_select_admin" ON cv_categories
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "cv_categories_insert_admin" ON cv_categories
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY "cv_categories_update_admin" ON cv_categories
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "cv_categories_delete_admin" ON cv_categories
  FOR DELETE TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "anon insert leads" ON leads;
DROP POLICY IF EXISTS "auth full leads" ON leads;
DROP POLICY IF EXISTS "leads_insert_public" ON leads;
DROP POLICY IF EXISTS "leads_select_admin" ON leads;
DROP POLICY IF EXISTS "leads_update_admin" ON leads;
DROP POLICY IF EXISTS "leads_delete_admin" ON leads;
CREATE POLICY "leads_insert_public" ON leads
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "leads_select_admin" ON leads
  FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "leads_update_admin" ON leads
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "leads_delete_admin" ON leads
  FOR DELETE TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "admin_users_manage_admin" ON admin_users;
CREATE POLICY "admin_users_manage_admin" ON admin_users
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

INSERT INTO storage.buckets (id, name, public)
VALUES ('cvs', 'cvs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "cv_upload_public" ON storage.objects;
DROP POLICY IF EXISTS "cv_read_auth" ON storage.objects;
DROP POLICY IF EXISTS "cv_delete_auth_obj" ON storage.objects;
DROP POLICY IF EXISTS "cv_read_admin" ON storage.objects;
DROP POLICY IF EXISTS "cv_delete_admin_obj" ON storage.objects;
CREATE POLICY "cv_upload_public" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'cvs');
CREATE POLICY "cv_read_admin" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'cvs' AND public.is_admin());
CREATE POLICY "cv_delete_admin_obj" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'cvs' AND public.is_admin());

CREATE INDEX IF NOT EXISTS job_listings_slug_idx ON job_listings (slug);
CREATE INDEX IF NOT EXISTS enquiries_created_at_idx ON enquiries (created_at DESC);
CREATE INDEX IF NOT EXISTS cv_submissions_created_at_idx ON cv_submissions (created_at DESC);
