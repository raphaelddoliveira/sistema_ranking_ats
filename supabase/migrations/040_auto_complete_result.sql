-- ============================================================
-- Migration 040: Auto-complete challenge result (no confirmation needed)
-- When a player submits the result, it goes directly to completed
-- with ranking swap + cooldowns applied immediately.
-- ============================================================

CREATE OR REPLACE FUNCTION submit_challenge_result(
  p_challenge_id UUID,
  p_submitter_id UUID,
  p_winner_id UUID,
  p_loser_id UUID,
  p_sets JSONB,
  p_winner_sets INT,
  p_loser_sets INT,
  p_super_tiebreak BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_club_id UUID;
  v_sport_id UUID;
  v_challenger_id UUID;
  v_challenged_id UUID;
  v_opponent_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
  v_rule_cooldown BOOLEAN;
  v_rule_result_delay BOOLEAN;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;

  -- Allow submission from scheduled or pending_result (resubmission after dispute)
  IF v_challenge.status NOT IN ('scheduled', 'pending_result') THEN
    RAISE EXCEPTION 'Desafio nao esta em status valido: %', v_challenge.status;
  END IF;

  -- Verify submitter is a participant
  IF p_submitter_id != v_challenge.challenger_id AND p_submitter_id != v_challenge.challenged_id THEN
    RAISE EXCEPTION 'Apenas participantes podem registrar resultado';
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;
  v_challenger_id := v_challenge.challenger_id;
  v_challenged_id := v_challenge.challenged_id;

  -- Check result delay rule (40 min after scheduled time)
  SELECT rule_result_delay_enabled INTO v_rule_result_delay
  FROM club_sports WHERE club_id = v_club_id AND sport_id = v_sport_id AND is_active = true;
  v_rule_result_delay := COALESCE(v_rule_result_delay, true);

  IF v_rule_result_delay AND v_challenge.chosen_date IS NOT NULL
     AND now() < v_challenge.chosen_date + INTERVAL '40 minutes' THEN
    RAISE EXCEPTION 'Resultado so pode ser registrado 40 minutos apos o horario agendado';
  END IF;

  -- If resubmitting, delete previous match
  DELETE FROM matches WHERE challenge_id = p_challenge_id;

  -- Insert match record (final, not provisional)
  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak, club_id, sport_id)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak, v_club_id, v_sport_id);

  -- Determine opponent for notification
  IF p_submitter_id = v_challenger_id THEN
    v_opponent_id := v_challenged_id;
  ELSE
    v_opponent_id := v_challenger_id;
  END IF;

  -- ── Ranking swap: only if challenger won AND was below ──
  SELECT ranking_position INTO v_winner_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_winner_id;
  SELECT ranking_position INTO v_loser_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_loser_id;

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

  -- ── Mark challenge as completed ──
  UPDATE challenges
  SET status = 'completed',
      winner_id = p_winner_id,
      loser_id = p_loser_id,
      completed_at = now(),
      result_submitted_by = p_submitter_id
  WHERE id = p_challenge_id;

  -- ── Set cooldowns ──
  SELECT rule_cooldown_enabled INTO v_rule_cooldown
  FROM club_sports WHERE club_id = v_club_id AND sport_id = v_sport_id AND is_active = true;
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  -- Cooldowns count from the match time (chosen_date), not from now()
  -- e.g. match at 17:15 → 48h cooldown expires at 17:15 two days later
  IF v_rule_cooldown THEN
    UPDATE club_members
    SET challenger_cooldown_until = COALESCE(v_challenge.chosen_date, now()) + INTERVAL '48 hours',
        last_challenge_date = COALESCE(v_challenge.chosen_date, now()),
        challenges_this_month = challenges_this_month + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;

    UPDATE club_members
    SET challenged_protection_until = COALESCE(v_challenge.chosen_date, now()) + INTERVAL '24 hours'
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenged_id;
  ELSE
    UPDATE club_members
    SET last_challenge_date = COALESCE(v_challenge.chosen_date, now()),
        challenges_this_month = challenges_this_month + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;
  END IF;

  -- ── Notify both players ──
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_winner_id, 'match_result', 'Resultado Registrado', 'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_loser_id, 'match_result', 'Resultado Registrado', 'O resultado do desafio foi registrado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
