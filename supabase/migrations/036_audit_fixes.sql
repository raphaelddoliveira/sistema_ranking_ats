-- ============================================================
-- 036_audit_fixes.sql
-- Fixes found during comprehensive codebase audit
-- ============================================================

-- 1. Add 'completed' to reservation_status enum
--    RPCs in 035 and Dart code set court_reservations.status = 'completed'
--    but the enum only had 'confirmed' and 'cancelled'
ALTER TYPE reservation_status ADD VALUE IF NOT EXISTS 'completed';

-- 2. Fix time overlap check in admin_create_reservation
--    Old check only compared exact start_time, missing overlapping slots
--    Also fixes the same issue for regular reservations via partial unique index
CREATE OR REPLACE FUNCTION admin_create_reservation(
  p_admin_auth_id UUID,
  p_player1_id UUID,
  p_player2_id UUID,
  p_court_id UUID,
  p_reservation_date DATE,
  p_start_time TIME,
  p_end_time TIME,
  p_club_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id UUID;
  v_court RECORD;
  v_player2_name TEXT;
  v_player1_name TEXT;
  v_reservation_id UUID;
BEGIN
  -- Get admin player_id
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  -- Verify admin is club admin
  IF NOT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Voce nao e administrador deste clube';
  END IF;

  -- Get court info
  SELECT * INTO v_court FROM courts WHERE id = p_court_id;
  IF v_court IS NULL THEN
    RAISE EXCEPTION 'Quadra nao encontrada';
  END IF;

  -- Validate both players are active members of the club
  IF NOT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = p_player1_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Jogador 1 nao e membro ativo do clube';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = p_player2_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Jogador 2 nao e membro ativo do clube';
  END IF;

  -- Get player names
  SELECT full_name INTO v_player1_name FROM players WHERE id = p_player1_id;
  SELECT full_name INTO v_player2_name FROM players WHERE id = p_player2_id;

  -- Check for overlapping reservation on same court/date (not just exact match)
  IF EXISTS (
    SELECT 1 FROM court_reservations
    WHERE court_id = p_court_id
      AND reservation_date = p_reservation_date
      AND status = 'confirmed'
      AND p_start_time < end_time
      AND p_end_time > start_time
  ) THEN
    RAISE EXCEPTION 'Ja existe uma reserva neste horario';
  END IF;

  -- Create reservation
  INSERT INTO court_reservations (
    court_id, reserved_by, reservation_date,
    start_time, end_time, status, opponent_id, opponent_type, opponent_name, club_id
  ) VALUES (
    p_court_id, p_player1_id, p_reservation_date,
    p_start_time, p_end_time, 'confirmed', p_player2_id, 'member', v_player2_name, p_club_id
  )
  RETURNING id INTO v_reservation_id;

  -- Notify player 1
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    p_player1_id,
    'general',
    'Reserva criada pelo admin',
    format('O administrador agendou uma partida para voce com %s em %s (%s %s-%s).',
      v_player2_name, v_court.name, p_reservation_date, p_start_time, p_end_time),
    jsonb_build_object('reservation_id', v_reservation_id),
    p_club_id
  );

  -- Notify player 2
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    p_player2_id,
    'general',
    'Reserva criada pelo admin',
    format('O administrador agendou uma partida para voce com %s em %s (%s %s-%s).',
      v_player1_name, v_court.name, p_reservation_date, p_start_time, p_end_time),
    jsonb_build_object('reservation_id', v_reservation_id),
    p_club_id
  );

  RETURN v_reservation_id;
END;
$$;

-- 3. Drop orphaned court_slot_id column from court_reservations
--    court_slots table was dropped in migration 014, this column is unused
ALTER TABLE court_reservations DROP COLUMN IF EXISTS court_slot_id;
