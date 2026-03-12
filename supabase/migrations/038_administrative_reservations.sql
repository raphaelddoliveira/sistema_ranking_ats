-- Add reservation_type to court_reservations for administrative bookings
-- Administrative reservations block a court slot with a title/reason instead of players

-- Add reservation_type column
DO $$ BEGIN
  CREATE TYPE reservation_type AS ENUM ('regular', 'administrative');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE court_reservations
  ADD COLUMN IF NOT EXISTS reservation_type reservation_type NOT NULL DEFAULT 'regular';

-- For administrative reservations, notes serves as the title/reason
-- and reserved_by is nullable (admin creates it but it's not "their" reservation)

-- Allow reserved_by to be NULL for administrative reservations
ALTER TABLE court_reservations
  ALTER COLUMN reserved_by DROP NOT NULL;

-- RPC for admin to create administrative reservation
CREATE OR REPLACE FUNCTION admin_create_administrative_reservation(
  p_admin_auth_id UUID,
  p_court_id UUID,
  p_reservation_date DATE,
  p_start_time TIME,
  p_end_time TIME,
  p_title TEXT,
  p_club_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_player_id UUID;
  v_reservation_id UUID;
BEGIN
  -- Verify admin
  SELECT id INTO v_admin_player_id FROM players WHERE auth_id = p_admin_auth_id;
  IF v_admin_player_id IS NULL THEN
    RAISE EXCEPTION 'Player not found for auth_id %', p_admin_auth_id;
  END IF;

  IF NOT (is_admin() OR EXISTS (
    SELECT 1 FROM club_members
    WHERE player_id = v_admin_player_id AND role = 'admin'
  )) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Check slot availability
  IF EXISTS (
    SELECT 1 FROM court_reservations
    WHERE court_id = p_court_id
      AND reservation_date = p_reservation_date
      AND start_time = p_start_time
      AND status = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'Slot already booked';
  END IF;

  -- Create administrative reservation
  INSERT INTO court_reservations (
    court_id, reserved_by, reservation_date, start_time, end_time,
    status, notes, reservation_type, club_id
  ) VALUES (
    p_court_id, v_admin_player_id, p_reservation_date, p_start_time, p_end_time,
    'confirmed', p_title, 'administrative', p_club_id
  )
  RETURNING id INTO v_reservation_id;

  RETURN v_reservation_id;
END;
$$;
