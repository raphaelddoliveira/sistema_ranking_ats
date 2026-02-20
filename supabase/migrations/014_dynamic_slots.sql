-- ============================================================
-- 014_dynamic_slots.sql
-- Migrate from individual court_slot records to config-based
-- dynamic slot generation on the courts table
-- ============================================================

-- 1. Add schedule config columns to courts table
ALTER TABLE courts
  ADD COLUMN slot_duration_minutes INT NOT NULL DEFAULT 60,
  ADD COLUMN opening_time TIME NOT NULL DEFAULT '07:00',
  ADD COLUMN closing_time TIME NOT NULL DEFAULT '22:00',
  ADD COLUMN operating_days INT[] NOT NULL DEFAULT '{0,1,2,3,4,5,6}';

-- 2. Backfill config from existing court_slots data
UPDATE courts c SET
  slot_duration_minutes = COALESCE(
    (SELECT EXTRACT(EPOCH FROM (cs.end_time - cs.start_time))::int / 60
     FROM court_slots cs
     WHERE cs.court_id = c.id AND cs.is_active = TRUE
     ORDER BY cs.start_time
     LIMIT 1),
    60
  ),
  opening_time = COALESCE(
    (SELECT MIN(cs.start_time)
     FROM court_slots cs
     WHERE cs.court_id = c.id AND cs.is_active = TRUE),
    '07:00'
  ),
  closing_time = COALESCE(
    (SELECT MAX(cs.end_time)
     FROM court_slots cs
     WHERE cs.court_id = c.id AND cs.is_active = TRUE),
    '22:00'
  ),
  operating_days = COALESCE(
    (SELECT ARRAY_AGG(DISTINCT cs.day_of_week ORDER BY cs.day_of_week)
     FROM court_slots cs
     WHERE cs.court_id = c.id AND cs.is_active = TRUE),
    '{0,1,2,3,4,5,6}'
  );

-- 3. Make court_slot_id nullable on court_reservations (backward compat)
ALTER TABLE court_reservations
  ALTER COLUMN court_slot_id DROP NOT NULL;

-- 4. Drop FK constraint so we can drop court_slots
ALTER TABLE court_reservations
  DROP CONSTRAINT IF EXISTS court_reservations_court_slot_id_fkey;

-- 5. Drop RLS policies for court_slots
DROP POLICY IF EXISTS court_slots_select ON court_slots;
DROP POLICY IF EXISTS court_slots_admin ON court_slots;

-- 6. Drop the court_slots table
DROP TABLE IF EXISTS court_slots;
