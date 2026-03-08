-- ============================================================
-- 035: Admin Controls - Create reservations + Submit results
-- ============================================================

-- ============================================================
-- RPC: admin_create_reservation
-- Admin cria reserva para dois jogadores do clube
-- ============================================================
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
RETURNS UUID AS $$
DECLARE
  v_admin_id UUID;
  v_admin_member RECORD;
  v_court RECORD;
  v_player2_name TEXT;
  v_player1_name TEXT;
  v_reservation_id UUID;
  v_slot_id UUID;
BEGIN
  -- Get admin player_id
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  -- Validate admin is club admin
  SELECT * INTO v_admin_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e admin deste clube';
  END IF;

  -- Validate court belongs to club
  SELECT * INTO v_court FROM courts WHERE id = p_court_id AND club_id = p_club_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quadra nao encontrada neste clube';
  END IF;

  -- Validate players are different
  IF p_player1_id = p_player2_id THEN
    RAISE EXCEPTION 'Os dois jogadores devem ser diferentes';
  END IF;

  -- Get player names
  SELECT full_name INTO v_player1_name FROM players WHERE id = p_player1_id;
  SELECT full_name INTO v_player2_name FROM players WHERE id = p_player2_id;

  -- Get a slot_id for this court (just pick first active one)
  SELECT id INTO v_slot_id FROM court_slots
  WHERE court_id = p_court_id AND is_active = true
  LIMIT 1;

  IF v_slot_id IS NULL THEN
    -- If no active slot, pick any slot
    SELECT id INTO v_slot_id FROM court_slots WHERE court_id = p_court_id LIMIT 1;
  END IF;

  IF v_slot_id IS NULL THEN
    RAISE EXCEPTION 'Nenhum horario disponivel para esta quadra';
  END IF;

  -- Check for conflicting reservation on same court/date/time
  IF EXISTS (
    SELECT 1 FROM court_reservations
    WHERE court_id = p_court_id
      AND reservation_date = p_reservation_date
      AND start_time = p_start_time
      AND status = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'Ja existe uma reserva confirmada nesta quadra, data e horario';
  END IF;

  -- Create reservation
  INSERT INTO court_reservations (
    court_slot_id, court_id, reserved_by, reservation_date,
    start_time, end_time, status, opponent_id, opponent_type, opponent_name, club_id
  ) VALUES (
    v_slot_id, p_court_id, p_player1_id, p_reservation_date,
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: admin_submit_challenge_result
-- Admin submete resultado de desafio (sem confirmação)
-- Combina submit + confirm em um passo
-- ============================================================
CREATE OR REPLACE FUNCTION admin_submit_challenge_result(
  p_admin_auth_id UUID,
  p_challenge_id UUID,
  p_winner_id UUID,
  p_loser_id UUID,
  p_sets JSONB,
  p_winner_sets INT,
  p_loser_sets INT,
  p_super_tiebreak BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_challenge RECORD;
  v_club_id UUID;
  v_sport_id UUID;
  v_admin_member RECORD;
  v_challenger_id UUID;
  v_challenged_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
  v_rule_cooldown BOOLEAN;
BEGIN
  -- Get admin player_id
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  -- Get challenge
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;

  -- Allow submission for scheduled or pending_result
  IF v_challenge.status NOT IN ('scheduled', 'pending_result') THEN
    RAISE EXCEPTION 'Desafio nao esta em status valido para registrar resultado: %', v_challenge.status;
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;
  v_challenger_id := v_challenge.challenger_id;
  v_challenged_id := v_challenge.challenged_id;

  -- Validate admin is club admin
  SELECT * INTO v_admin_member FROM club_members
  WHERE club_id = v_club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e admin deste clube';
  END IF;

  -- Validate winner/loser are participants
  IF p_winner_id NOT IN (v_challenger_id, v_challenged_id) OR
     p_loser_id NOT IN (v_challenger_id, v_challenged_id) THEN
    RAISE EXCEPTION 'Vencedor e perdedor devem ser participantes do desafio';
  END IF;

  -- Delete previous match if resubmitting
  DELETE FROM matches WHERE challenge_id = p_challenge_id;

  -- Insert match record
  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak, club_id, sport_id)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak, v_club_id, v_sport_id);

  -- Fetch cooldown rule
  SELECT rule_cooldown_enabled INTO v_rule_cooldown
  FROM club_sports WHERE club_id = v_club_id AND sport_id = v_sport_id AND is_active = true;
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  -- Get current positions
  SELECT ranking_position INTO v_winner_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_winner_id;
  SELECT ranking_position INTO v_loser_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_loser_id;

  -- Ranking swap: only if challenger won AND was below
  IF p_winner_id = v_challenger_id AND v_winner_pos > v_loser_pos THEN
    UPDATE club_members SET ranking_position = v_loser_pos
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_winner_id;
    UPDATE club_members SET ranking_position = v_loser_pos + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_loser_id;

    UPDATE club_members
    SET ranking_position = ranking_position + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id
      AND ranking_position > v_loser_pos
      AND ranking_position < v_winner_pos
      AND player_id != p_winner_id
      AND player_id != p_loser_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (p_winner_id, v_winner_pos, v_loser_pos, 'challenge_win', p_challenge_id, v_club_id, v_sport_id);
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (p_loser_id, v_loser_pos, v_loser_pos + 1, 'challenge_loss', p_challenge_id, v_club_id, v_sport_id);

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      p_winner_id, 'ranking_change', 'Ranking Atualizado!',
      format('Voce subiu para a posicao #%s (era #%s).', v_loser_pos, v_winner_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_winner_pos, 'new_position', v_loser_pos),
      v_club_id
    );
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      p_loser_id, 'ranking_change', 'Ranking Atualizado',
      format('Voce desceu para a posicao #%s (era #%s).', v_loser_pos + 1, v_loser_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_loser_pos, 'new_position', v_loser_pos + 1),
      v_club_id
    );
  END IF;

  -- Update challenge to completed
  UPDATE challenges
  SET status = 'completed',
      winner_id = p_winner_id,
      loser_id = p_loser_id,
      completed_at = now(),
      result_submitted_by = NULL
  WHERE id = p_challenge_id;

  -- Set cooldowns
  IF v_rule_cooldown THEN
    UPDATE club_members
    SET challenger_cooldown_until = now() + INTERVAL '48 hours',
        last_challenge_date = now(),
        challenges_this_month = challenges_this_month + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;

    UPDATE club_members
    SET challenged_protection_until = now() + INTERVAL '24 hours'
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenged_id;
  ELSE
    UPDATE club_members
    SET last_challenge_date = now(),
        challenges_this_month = challenges_this_month + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;
  END IF;

  -- Mark linked reservation as completed
  UPDATE court_reservations
  SET status = 'completed', updated_at = now()
  WHERE challenge_id = p_challenge_id AND status = 'confirmed';

  -- Notify both players
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_winner_id, 'match_result', 'Resultado Registrado (Admin)',
    'O administrador registrou o resultado do desafio. Voce venceu!',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_loser_id, 'match_result', 'Resultado Registrado (Admin)',
    'O administrador registrou o resultado do desafio.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Update admin_annul_challenge to handle non-completed statuses
-- For non-completed: just cancel (no ranking to revert)
-- ============================================================
CREATE OR REPLACE FUNCTION admin_annul_challenge(
  p_challenge_id UUID,
  p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_club_id UUID;
  v_sport_id UUID;
  v_rh RECORD;
  v_admin_role TEXT;
  v_player_current_pos INT;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;

  -- Reject if already in a terminal state
  IF v_challenge.status IN ('cancelled', 'annulled', 'expired') THEN
    RAISE EXCEPTION 'Desafio ja esta em status final: %', v_challenge.status;
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;

  -- Verify admin is club admin
  SELECT role INTO v_admin_role FROM club_members
  WHERE club_id = v_club_id AND player_id = p_admin_id AND status = 'active'
  LIMIT 1;

  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem anular desafios';
  END IF;

  -- For completed/WO statuses: reverse ranking changes
  IF v_challenge.status IN ('completed', 'wo_challenger', 'wo_challenged') THEN
    -- Reverse ranking changes from ranking_history
    FOR v_rh IN
      SELECT * FROM ranking_history
      WHERE reference_id = p_challenge_id
        AND club_id = v_club_id
        AND sport_id = v_sport_id
      ORDER BY created_at DESC
    LOOP
      SELECT ranking_position INTO v_player_current_pos FROM club_members
      WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_rh.player_id;

      IF v_player_current_pos IS NOT NULL AND v_player_current_pos = v_rh.new_position THEN
        IF v_rh.old_position < v_rh.new_position THEN
          UPDATE club_members
          SET ranking_position = ranking_position + 1
          WHERE club_id = v_club_id AND sport_id = v_sport_id
            AND ranking_position >= v_rh.old_position
            AND ranking_position < v_rh.new_position
            AND player_id != v_rh.player_id;
        ELSE
          UPDATE club_members
          SET ranking_position = ranking_position - 1
          WHERE club_id = v_club_id AND sport_id = v_sport_id
            AND ranking_position > v_rh.new_position
            AND ranking_position <= v_rh.old_position
            AND player_id != v_rh.player_id;
        END IF;

        UPDATE club_members
        SET ranking_position = v_rh.old_position
        WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_rh.player_id;
      END IF;
    END LOOP;

    -- Delete ranking_history entries
    DELETE FROM ranking_history WHERE reference_id = p_challenge_id;

    -- Delete match record
    DELETE FROM matches WHERE challenge_id = p_challenge_id;

    -- Update challenge status to annulled
    UPDATE challenges
    SET status = 'annulled',
        winner_id = NULL,
        loser_id = NULL,
        result_submitted_by = NULL
    WHERE id = p_challenge_id;
  ELSE
    -- For non-completed statuses (pending, dates_proposed, scheduled, pending_result):
    -- Just cancel the challenge and linked reservations

    -- Delete provisional match if pending_result
    IF v_challenge.status = 'pending_result' THEN
      DELETE FROM matches WHERE challenge_id = p_challenge_id;
    END IF;

    -- Cancel linked reservations
    UPDATE court_reservations
    SET status = 'cancelled', updated_at = now()
    WHERE challenge_id = p_challenge_id AND status = 'confirmed';

    -- Cancel the challenge
    UPDATE challenges
    SET status = 'cancelled',
        cancelled_at = now(),
        winner_id = NULL,
        loser_id = NULL,
        result_submitted_by = NULL
    WHERE id = p_challenge_id;
  END IF;

  -- Notify both players
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_challenge.challenger_id,
    'general',
    'Desafio Cancelado pelo Admin',
    'O administrador cancelou/anulou o desafio.',
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_challenge.challenged_id,
    'general',
    'Desafio Cancelado pelo Admin',
    'O administrador cancelou/anulou o desafio.',
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
