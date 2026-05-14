-- ============================================================
-- Migration 045: Bug reports table
-- Allows users to send bug reports / feedback with screenshots
-- ============================================================

CREATE TABLE IF NOT EXISTS bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  club_id UUID REFERENCES clubs(id),
  report_type TEXT NOT NULL CHECK (report_type IN ('bug', 'suggestion', 'question')),
  description TEXT NOT NULL,
  screen_name TEXT,
  screenshot_url TEXT,
  app_version TEXT,
  user_agent TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'wont_fix')),
  admin_notes TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bug_reports_created ON bug_reports(created_at DESC);
CREATE INDEX idx_bug_reports_status ON bug_reports(status);
CREATE INDEX idx_bug_reports_player ON bug_reports(player_id);

-- RLS
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can insert their own report
CREATE POLICY bug_reports_insert ON bug_reports
FOR INSERT WITH CHECK (player_id = get_player_id());

-- Users can see their own reports; admins see all
CREATE POLICY bug_reports_select ON bug_reports
FOR SELECT USING (player_id = get_player_id() OR is_admin());

-- Only admins can update (status, notes)
CREATE POLICY bug_reports_update ON bug_reports
FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- ============================================================
-- Storage bucket for screenshots
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('bug-reports', 'bug-reports', true)
ON CONFLICT (id) DO NOTHING;

-- Bucket policies: authenticated users can upload to their folder; everyone can read
CREATE POLICY bug_reports_storage_upload ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'bug-reports');

CREATE POLICY bug_reports_storage_read ON storage.objects
FOR SELECT
USING (bucket_id = 'bug-reports');
