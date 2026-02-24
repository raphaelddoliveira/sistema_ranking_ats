-- ============================================================
-- Feature: Admin Powers (Toggle ranking + Cancel reservations)
-- Admin pode desativar/ativar ranking de membros e cancelar reservas
-- ============================================================

-- ============================================================
-- RPC: admin_toggle_ranking_participation
-- Admin ativa/desativa ranking de um membro
-- Mesma lógica do toggle_ranking_participation mas iniciado por admin
-- ============================================================
CREATE OR REPLACE FUNCTION admin_toggle_ranking_participation(
  p_admin_auth_id UUID,
  p_member_id UUID,
  p_opt_in BOOLEAN
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_member RECORD;
  v_old_position INT;
  v_new_position INT;
  v_challenge RECORD;
  v_admin_member RECORD;
BEGIN
  -- Get admin player_id
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  -- Get target member
  SELECT * INTO v_member FROM club_members WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membro nao encontrado';
  END IF;

  -- Validate admin is actually admin of this club
  SELECT * INTO v_admin_member FROM club_members
  WHERE club_id = v_member.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e admin deste clube';
  END IF;

  -- ==================== OPT-OUT ====================
  IF p_opt_in = FALSE THEN
    IF v_member.ranking_position IS NULL THEN
      RAISE EXCEPTION 'Membro ja esta fora do ranking';
    END IF;

    v_old_position := v_member.ranking_position;

    -- Cancel active challenges for this player in this club+sport
    FOR v_challenge IN
      SELECT id, challenger_id, challenged_id FROM challenges
      WHERE club_id = v_member.club_id AND sport_id = v_member.sport_id
        AND status IN ('pending', 'dates_proposed', 'scheduled', 'pending_result')
        AND (challenger_id = v_member.player_id OR challenged_id = v_member.player_id)
    LOOP
      -- Cancel linked reservations
      UPDATE court_reservations
      SET status = 'cancelled'
      WHERE challenge_id = v_challenge.id AND status = 'confirmed';

      -- Cancel the challenge
      UPDATE challenges
      SET status = 'cancelled'
      WHERE id = v_challenge.id;

      -- Notify the opponent
      INSERT INTO notifications (player_id, type, title, body, data, club_id)
      VALUES (
        CASE WHEN v_challenge.challenger_id = v_member.player_id
             THEN v_challenge.challenged_id
             ELSE v_challenge.challenger_id
        END,
        'general',
        'Desafio Cancelado',
        'O ranking do oponente foi desativado pelo admin. O desafio foi cancelado automaticamente.',
        jsonb_build_object('challenge_id', v_challenge.id),
        v_member.club_id
      );
    END LOOP;

    -- Remove from ranking
    UPDATE club_members
    SET ranking_position = NULL, ranking_opt_in = FALSE
    WHERE id = v_member.id;

    -- Recompact ranking
    WITH ranked AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY ranking_position) AS new_pos
      FROM club_members
      WHERE club_id = v_member.club_id AND sport_id = v_member.sport_id
        AND status = 'active' AND ranking_position IS NOT NULL
    )
    UPDATE club_members cm
    SET ranking_position = ranked.new_pos
    FROM ranked
    WHERE cm.id = ranked.id;

    -- Record in ranking_history
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (v_member.player_id, v_old_position, NULL, 'admin_adjustment', v_member.id, v_member.club_id, v_member.sport_id);

    -- Notify member
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_member.player_id,
      'general',
      'Ranking Desativado',
      'O administrador desativou sua participacao no ranking. Seus desafios ativos foram cancelados.',
      jsonb_build_object('club_id', v_member.club_id, 'sport_id', v_member.sport_id),
      v_member.club_id
    );

  -- ==================== OPT-IN ====================
  ELSE
    IF v_member.ranking_position IS NOT NULL THEN
      RAISE EXCEPTION 'Membro ja esta no ranking';
    END IF;

    -- Get last position + 1
    SELECT COALESCE(MAX(ranking_position), 0) + 1 INTO v_new_position
    FROM club_members
    WHERE club_id = v_member.club_id AND sport_id = v_member.sport_id
      AND status = 'active' AND ranking_position IS NOT NULL;

    -- Add to ranking
    UPDATE club_members
    SET ranking_position = v_new_position, ranking_opt_in = TRUE
    WHERE id = v_member.id;

    -- Record in ranking_history
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (v_member.player_id, NULL, v_new_position, 'admin_adjustment', v_member.id, v_member.club_id, v_member.sport_id);

    -- Notify member
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_member.player_id,
      'general',
      'Ranking Ativado',
      format('O administrador ativou sua participacao no ranking na posicao #%s.', v_new_position),
      jsonb_build_object('club_id', v_member.club_id, 'sport_id', v_member.sport_id, 'position', v_new_position),
      v_member.club_id
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: admin_cancel_reservation
-- Admin cancela uma reserva de qualquer membro do seu clube
-- ============================================================
CREATE OR REPLACE FUNCTION admin_cancel_reservation(
  p_admin_auth_id UUID,
  p_reservation_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_reservation RECORD;
  v_court RECORD;
  v_admin_member RECORD;
BEGIN
  -- Get admin player_id
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  -- Get reservation
  SELECT * INTO v_reservation FROM court_reservations WHERE id = p_reservation_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reserva nao encontrada';
  END IF;

  IF v_reservation.status != 'confirmed' THEN
    RAISE EXCEPTION 'Reserva ja esta cancelada ou finalizada';
  END IF;

  -- Get court to find club_id
  SELECT * INTO v_court FROM courts WHERE id = v_reservation.court_id;

  -- Validate admin is admin of this club
  SELECT * INTO v_admin_member FROM club_members
  WHERE club_id = v_court.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e admin deste clube';
  END IF;

  -- Cancel the reservation
  UPDATE court_reservations
  SET status = 'cancelled', updated_at = now()
  WHERE id = p_reservation_id;

  -- If linked to a challenge, cancel the challenge too
  IF v_reservation.challenge_id IS NOT NULL THEN
    UPDATE challenges
    SET status = 'cancelled'
    WHERE id = v_reservation.challenge_id AND status IN ('pending', 'dates_proposed', 'scheduled', 'pending_result');
  END IF;

  -- Notify the reservation owner
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_reservation.reserved_by,
    'general',
    'Reserva Cancelada',
    format('O administrador cancelou sua reserva de %s (%s).',
      v_court.name,
      v_reservation.reservation_date
    ),
    jsonb_build_object('reservation_id', p_reservation_id),
    v_court.club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
