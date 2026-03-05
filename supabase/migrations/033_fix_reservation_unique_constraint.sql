-- ============================================================
-- 033: Fix reservation unique constraint
-- Allow rebooking cancelled slots by using a partial unique index
-- ============================================================

-- Drop the old constraint that blocks cancelled slots
ALTER TABLE court_reservations
  DROP CONSTRAINT IF EXISTS uq_reservation;

-- Create partial unique index only for active reservations
CREATE UNIQUE INDEX uq_reservation_active
  ON court_reservations (court_id, reservation_date, start_time)
  WHERE status = 'confirmed';
