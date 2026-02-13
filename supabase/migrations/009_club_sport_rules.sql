-- ============================================================
-- SmashRank - Phase 10: Configurable Rules per Club Sport
-- Adds toggleable rules: ambulance, cooldown, position gap
-- ============================================================

-- ============================================================
-- ADD RULE COLUMNS TO club_sports (defaults = true = backward compatible)
-- ============================================================
ALTER TABLE club_sports
  ADD COLUMN rule_ambulance_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN rule_cooldown_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN rule_position_gap_enabled BOOLEAN NOT NULL DEFAULT true;

-- ============================================================
-- UPDATED RPC: create_challenge
-- Now respects club_sport rules for position gap and cooldown
-- ============================================================
CREATE OR REPLACE FUNCTION create_challenge(
  p_challenger_auth_id UUID,
  p_challenged_id UUID,
  p_club_id UUID DEFAULT NULL,
  p_sport_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_challenger_id UUID;
  v_challenge_id UUID;
  v_challenger_pos INT;
  v_challenged_pos INT;
  v_challenger_member RECORD;
  v_challenged_member RECORD;
  v_active_challenge_count INT;
  v_rule_position_gap BOOLEAN;
  v_rule_cooldown BOOLEAN;
BEGIN
  SELECT id INTO v_challenger_id FROM players WHERE auth_id = p_challenger_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado para auth_id: %', p_challenger_auth_id;
  END IF;

  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

  -- Fetch rules for this club+sport
  SELECT rule_position_gap_enabled, rule_cooldown_enabled
  INTO v_rule_position_gap, v_rule_cooldown
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  -- Get challenger membership for this sport
  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_challenger_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e membro ativo deste esporte neste clube';
  END IF;

  -- Get challenged membership for this sport
  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador desafiado nao e membro ativo deste esporte neste clube';
  END IF;

  IF (SELECT status FROM players WHERE id = v_challenger_id) != 'active' THEN
    RAISE EXCEPTION 'Jogador nao esta ativo';
  END IF;
  IF (SELECT status FROM players WHERE id = p_challenged_id) NOT IN ('active') THEN
    RAISE EXCEPTION 'Jogador desafiado nao esta disponivel';
  END IF;
  IF (SELECT fee_status FROM players WHERE id = v_challenger_id) = 'overdue' THEN
    RAISE EXCEPTION 'Mensalidade em atraso. Regularize para desafiar.';
  END IF;
  IF v_challenger_member.must_be_challenged_first THEN
    RAISE EXCEPTION 'Voce deve ser desafiado primeiro apos retornar da ambulancia';
  END IF;

  v_challenger_pos := v_challenger_member.ranking_position;
  v_challenged_pos := v_challenged_member.ranking_position;

  -- CONDITIONAL: Position gap check (only if rule enabled)
  IF v_rule_position_gap AND v_challenger_pos - v_challenged_pos > 2 THEN
    RAISE EXCEPTION 'So pode desafiar jogadores ate 2 posicoes a frente';
  END IF;

  -- Always enforce: must challenge upward
  IF v_challenged_pos >= v_challenger_pos THEN
    RAISE EXCEPTION 'So pode desafiar jogadores acima no ranking';
  END IF;

  -- CONDITIONAL: Cooldown checks (only if rule enabled)
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RAISE EXCEPTION 'Cooldown ativo ate %', v_challenger_member.challenger_cooldown_until;
    END IF;
    IF v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
      RAISE EXCEPTION 'Este jogador esta protegido temporariamente';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = v_challenger_id OR challenged_id = v_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo neste esporte';
  END IF;

  INSERT INTO challenges (
    challenger_id, challenged_id, club_id, sport_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    v_challenger_id, p_challenged_id, p_club_id, p_sport_id,
    v_challenger_pos, v_challenged_pos,
    now() + INTERVAL '48 hours'
  )
  RETURNING id INTO v_challenge_id;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    p_challenged_id, 'challenge_received', 'Novo Desafio!',
    format('Voce foi desafiado pelo jogador da posicao #%s. Responda em 48h.', v_challenger_pos),
    jsonb_build_object('challenge_id', v_challenge_id),
    p_club_id
  );

  RETURN v_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: validate_challenge_creation
-- Now respects club_sport rules
-- ============================================================
CREATE OR REPLACE FUNCTION validate_challenge_creation(
  p_challenger_id UUID,
  p_challenged_id UUID,
  p_club_id UUID DEFAULT NULL,
  p_sport_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_challenger RECORD;
  v_challenged RECORD;
  v_challenger_member RECORD;
  v_challenged_member RECORD;
  v_active_challenge_count INT;
  v_rule_position_gap BOOLEAN;
  v_rule_cooldown BOOLEAN;
BEGIN
  IF p_club_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'club_id e obrigatorio');
  END IF;
  IF p_sport_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'sport_id e obrigatorio');
  END IF;

  -- Fetch rules
  SELECT rule_position_gap_enabled, rule_cooldown_enabled
  INTO v_rule_position_gap, v_rule_cooldown
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  SELECT * INTO v_challenger FROM players WHERE id = p_challenger_id;
  SELECT * INTO v_challenged FROM players WHERE id = p_challenged_id;

  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenger_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Desafiante nao e membro deste esporte');
  END IF;

  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Desafiado nao e membro deste esporte');
  END IF;

  IF v_challenger.status != 'active' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador nao esta ativo');
  END IF;
  IF v_challenged.status NOT IN ('active') THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador desafiado nao esta disponivel');
  END IF;
  IF v_challenger.fee_status = 'overdue' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Mensalidade em atraso.');
  END IF;
  IF v_challenger_member.must_be_challenged_first THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Voce deve ser desafiado primeiro apos retornar da ambulancia');
  END IF;

  -- CONDITIONAL: Position gap
  IF v_rule_position_gap AND v_challenger_member.ranking_position - v_challenged_member.ranking_position > 2 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores ate 2 posicoes a frente');
  END IF;

  IF v_challenged_member.ranking_position >= v_challenger_member.ranking_position THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores acima no ranking');
  END IF;

  -- CONDITIONAL: Cooldown
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RETURN jsonb_build_object('valid', FALSE, 'error',
        format('Cooldown ativo ate %s', v_challenger_member.challenger_cooldown_until));
    END IF;
    IF v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
      RETURN jsonb_build_object('valid', FALSE, 'error', 'Este jogador esta protegido temporariamente');
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Um dos jogadores ja possui um desafio ativo neste esporte');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: swap_ranking_after_challenge
-- Only sets cooldowns if rule_cooldown_enabled
-- ============================================================
CREATE OR REPLACE FUNCTION swap_ranking_after_challenge(
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
  v_challenger_id UUID;
  v_challenged_id UUID;
  v_club_id UUID;
  v_sport_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
  v_challenge RECORD;
  v_rule_cooldown BOOLEAN;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found: %', p_challenge_id;
  END IF;
  IF v_challenge.status NOT IN ('scheduled', 'wo_challenged') THEN
    RAISE EXCEPTION 'Challenge is not in valid status: %', v_challenge.status;
  END IF;

  v_challenger_id := v_challenge.challenger_id;
  v_challenged_id := v_challenge.challenged_id;
  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;

  -- Fetch cooldown rule
  SELECT rule_cooldown_enabled INTO v_rule_cooldown
  FROM club_sports WHERE club_id = v_club_id AND sport_id = v_sport_id AND is_active = true;
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  SELECT ranking_position INTO v_winner_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_winner_id;
  SELECT ranking_position INTO v_loser_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_loser_id;

  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak, club_id, sport_id)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak, v_club_id, v_sport_id);

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

  UPDATE challenges
  SET status = 'completed', winner_id = p_winner_id, loser_id = p_loser_id, completed_at = now()
  WHERE id = p_challenge_id;

  -- CONDITIONAL: Only set cooldowns if rule enabled
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

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_winner_id, 'match_result', 'Resultado Registrado', 'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_loser_id, 'match_result', 'Resultado Registrado', 'O resultado do seu desafio foi registrado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: activate_ambulance
-- Rejects if ambulance rule is disabled for this club+sport
-- ============================================================
CREATE OR REPLACE FUNCTION activate_ambulance(
  p_player_id UUID,
  p_reason TEXT,
  p_club_id UUID DEFAULT NULL,
  p_sport_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_current_pos INT;
  v_new_pos INT;
  v_max_pos INT;
  v_ambulance_id UUID;
  v_rule_ambulance BOOLEAN;
BEGIN
  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

  -- Check if ambulance rule is enabled
  SELECT rule_ambulance_enabled INTO v_rule_ambulance
  FROM club_sports WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  IF NOT COALESCE(v_rule_ambulance, true) THEN
    RAISE EXCEPTION 'Regra de ambulancia esta desabilitada neste esporte';
  END IF;

  SELECT ranking_position INTO v_current_pos FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_player_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found in club sport: %', p_player_id;
  END IF;

  SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND status = 'active';
  v_new_pos := LEAST(v_current_pos + 3, v_max_pos);

  UPDATE club_members
  SET ranking_position = ranking_position - 1
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND ranking_position > v_current_pos
    AND ranking_position <= v_new_pos
    AND player_id != p_player_id;

  UPDATE club_members
  SET ranking_position = v_new_pos,
      ambulance_active = TRUE,
      ambulance_started_at = now(),
      ambulance_protection_until = now() + INTERVAL '10 days',
      must_be_challenged_first = TRUE
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_player_id;

  UPDATE players SET status = 'ambulance' WHERE id = p_player_id;

  INSERT INTO ambulances (player_id, reason, position_at_activation, initial_penalty_applied, protection_ends_at, club_id, sport_id)
  VALUES (p_player_id, p_reason, v_current_pos, TRUE, now() + INTERVAL '10 days', p_club_id, p_sport_id)
  RETURNING id INTO v_ambulance_id;

  INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
  VALUES (p_player_id, v_current_pos, v_new_pos, 'ambulance_penalty', v_ambulance_id, p_club_id, p_sport_id);

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    p_player_id, 'ambulance_activated', 'Ambulancia Ativada',
    format('Ambulancia ativada. Voce foi para a posicao #%s (era #%s). Protecao de 10 dias ativa.', v_new_pos, v_current_pos),
    jsonb_build_object('ambulance_id', v_ambulance_id, 'reason', p_reason, 'old_position', v_current_pos, 'new_position', v_new_pos),
    p_club_id
  );

  RETURN v_ambulance_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: apply_ambulance_daily_penalties
-- Only applies to club_sports where ambulance rule is enabled
-- ============================================================
CREATE OR REPLACE FUNCTION apply_ambulance_daily_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_ambulance RECORD;
  v_current_pos INT;
  v_max_pos INT;
BEGIN
  FOR v_ambulance IN
    SELECT a.*, cm.ranking_position, a.club_id as amb_club_id, a.sport_id as amb_sport_id
    FROM ambulances a
    JOIN club_members cm ON cm.player_id = a.player_id AND cm.club_id = a.club_id
      AND cm.sport_id = COALESCE(a.sport_id, cm.sport_id)
    JOIN club_sports cs ON cs.club_id = a.club_id AND cs.sport_id = COALESCE(a.sport_id, cs.sport_id)
      AND cs.is_active = true AND cs.rule_ambulance_enabled = true
    WHERE a.is_active = TRUE
      AND a.club_id IS NOT NULL
      AND a.protection_ends_at < now()
      AND (a.last_daily_penalty_at IS NULL
           OR a.last_daily_penalty_at < now() - INTERVAL '1 day')
  LOOP
    SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
    WHERE club_id = v_ambulance.amb_club_id
      AND sport_id = COALESCE(v_ambulance.amb_sport_id, sport_id)
      AND status = 'active';

    v_current_pos := v_ambulance.ranking_position;
    IF v_current_pos < v_max_pos THEN
      UPDATE club_members
      SET ranking_position = ranking_position - 1
      WHERE club_id = v_ambulance.amb_club_id
        AND sport_id = COALESCE(v_ambulance.amb_sport_id, sport_id)
        AND ranking_position = v_current_pos + 1
        AND player_id != v_ambulance.player_id;

      UPDATE club_members
      SET ranking_position = v_current_pos + 1
      WHERE club_id = v_ambulance.amb_club_id
        AND sport_id = COALESCE(v_ambulance.amb_sport_id, sport_id)
        AND player_id = v_ambulance.player_id;

      UPDATE ambulances
      SET daily_penalties_applied = daily_penalties_applied + 1,
          last_daily_penalty_at = now()
      WHERE id = v_ambulance.id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
      VALUES (v_ambulance.player_id, v_current_pos, v_current_pos + 1, 'ambulance_daily_penalty', v_ambulance.id,
        v_ambulance.amb_club_id, v_ambulance.amb_sport_id);

      INSERT INTO notifications (player_id, type, title, body, data, club_id)
      VALUES (
        v_ambulance.player_id, 'ranking_change', 'Penalizacao Diaria - Ambulancia',
        format('Voce perdeu 1 posicao por ambulancia ativa. Agora: #%s.', v_current_pos + 1),
        jsonb_build_object('old_position', v_current_pos, 'new_position', v_current_pos + 1),
        v_ambulance.amb_club_id
      );

      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
