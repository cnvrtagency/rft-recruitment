-- ============================================================
-- RFT Recruitment — Supabase Schema
-- Run this once in the Supabase SQL Editor
-- ============================================================

-- Enquiries (employer briefs + candidate registrations from contact forms)
CREATE TABLE IF NOT EXISTS enquiries (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  type        TEXT        NOT NULL CHECK (type IN ('employer','candidate')),
  name        TEXT        NOT NULL,
  email       TEXT        NOT NULL,
  phone       TEXT,
  company     TEXT,
  sector      TEXT,
  role_type   TEXT,
  roles       TEXT,
  message     TEXT,
  status      TEXT        NOT NULL DEFAULT 'new'
                          CHECK (status IN ('new','contacted','closed')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- CV submissions (candidate form with file upload from homepage)
CREATE TABLE IF NOT EXISTS cv_submissions (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  name         TEXT        NOT NULL,
  email        TEXT        NOT NULL,
  phone        TEXT,
  sector       TEXT,
  job_title    TEXT,
  cv_url       TEXT,
  cv_filename  TEXT,
  message      TEXT,
  status       TEXT        NOT NULL DEFAULT 'new'
                           CHECK (status IN ('new','reviewed','shortlisted','placed')),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Job listings (managed in admin, displayed on the public site)
CREATE TABLE IF NOT EXISTS job_listings (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title         TEXT        NOT NULL,
  sector        TEXT        NOT NULL,
  location      TEXT,
  salary        TEXT,
  contract_type TEXT        NOT NULL DEFAULT 'permanent'
                            CHECK (contract_type IN ('permanent','contract')),
  description   TEXT,
  tags          TEXT[],
  published     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Row Level Security ───────────────────────────────────────

ALTER TABLE enquiries      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cv_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_listings   ENABLE ROW LEVEL SECURITY;

-- Enquiries: public can insert (contact forms); only authenticated admins can read/manage
CREATE POLICY "enquiries_insert_public"  ON enquiries FOR INSERT                WITH CHECK (true);
CREATE POLICY "enquiries_select_auth"    ON enquiries FOR SELECT  TO authenticated USING (true);
CREATE POLICY "enquiries_update_auth"    ON enquiries FOR UPDATE  TO authenticated USING (true);
CREATE POLICY "enquiries_delete_auth"    ON enquiries FOR DELETE  TO authenticated USING (true);

-- CV submissions: same pattern
CREATE POLICY "cv_insert_public"  ON cv_submissions FOR INSERT                WITH CHECK (true);
CREATE POLICY "cv_select_auth"    ON cv_submissions FOR SELECT  TO authenticated USING (true);
CREATE POLICY "cv_update_auth"    ON cv_submissions FOR UPDATE  TO authenticated USING (true);
CREATE POLICY "cv_delete_auth"    ON cv_submissions FOR DELETE  TO authenticated USING (true);

-- Job listings: public reads published rows only; authenticated admin can see and manage all
CREATE POLICY "jobs_select_public" ON job_listings FOR SELECT
  USING (published = true OR auth.uid() IS NOT NULL);
CREATE POLICY "jobs_insert_auth"   ON job_listings FOR INSERT  TO authenticated WITH CHECK (true);
CREATE POLICY "jobs_update_auth"   ON job_listings FOR UPDATE  TO authenticated USING (true);
CREATE POLICY "jobs_delete_auth"   ON job_listings FOR DELETE  TO authenticated USING (true);

-- ── Storage bucket for CVs ───────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('cvs', 'cvs', false)
ON CONFLICT (id) DO NOTHING;

-- Anon users (the public form) can upload to the cvs bucket
CREATE POLICY "cv_upload_public" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'cvs');

-- Only authenticated admins can view or delete uploaded CVs
CREATE POLICY "cv_read_auth" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'cvs');

CREATE POLICY "cv_delete_auth_obj" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'cvs');
