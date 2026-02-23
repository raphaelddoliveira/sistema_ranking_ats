-- ============================================================
-- 017_club_details.sql
-- Add address, contacts, and cover image fields to clubs
-- ============================================================

ALTER TABLE clubs ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS website text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS cover_url text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_street text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_number text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_complement text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_neighborhood text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_city text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_state text;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS address_zip text;
