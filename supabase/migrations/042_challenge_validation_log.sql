-- ============================================================
-- Migration 042: Log every challenge validation block
-- Stores the full context (both players' state) whenever a
-- rule prevents challenge creation, so admins can audit.
-- ============================================================

CREATE TABLE IF NOT EXISTS challenge_validation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID NOT NULL REFERENCES players(id),
  challenged_id UUID NOT NULL REFERENCES players(id),
  club_id UUID NOT NULL,
  sport_id UUID NOT NULL,
  rule_blocked TEXT NOT NULL,
  error_message TEXT NOT NULL,
  challenger_state JSONB,
  challenged_state JSONB,
  rules_state JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_validation_logs_created ON challenge_validation_logs(created_at DESC);
CREATE INDEX idx_validation_logs_club ON challenge_validation_logs(club_id, sport_id);

-- ============================================================
-- ALSO fix create_challenge: remove rematch restriction,
-- remove pending_result from active check, add #1 protection skip
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
  -- Protection does NOT apply to the #1 ranked player
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RAISE EXCEPTION 'Cooldown ativo ate %', v_challenger_member.challenger_cooldown_until;
    END IF;
    IF v_challenged_pos > 1
       AND v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
      RAISE EXCEPTION 'Este jogador esta protegido temporariamente';
    END IF;
  END IF;

  -- Active challenge check (pending_result does NOT block)
  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = v_challenger_id OR challenged_id = v_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo neste esporte';
  END IF;

  -- NO rematch restriction — cooldowns are sufficient

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
-- Admin: create challenge between any two players (no rule checks)
-- ============================================================
CREATE OR REPLACE FUNCTION admin_create_challenge(
  p_admin_auth_id UUID,
  p_challenger_id UUID,
  p_challenged_id UUID,
  p_club_id UUID,
  p_sport_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_admin_id UUID;
  v_challenge_id UUID;
  v_challenger_pos INT;
  v_challenged_pos INT;
BEGIN
  -- Verify admin
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas administradores podem criar desafios em nome de outros';
  END IF;

  -- Get positions
  SELECT ranking_position INTO v_challenger_pos FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_challenger_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafiante nao e membro ativo deste esporte';
  END IF;

  SELECT ranking_position INTO v_challenged_pos FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_challenged_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafiado nao e membro ativo deste esporte';
  END IF;

  -- Create challenge (no cooldown/position/protection checks)
  INSERT INTO challenges (
    challenger_id, challenged_id, club_id, sport_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    p_challenger_id, p_challenged_id, p_club_id, p_sport_id,
    v_challenger_pos, v_challenged_pos,
    now() + INTERVAL '48 hours'
  )
  RETURNING id INTO v_challenge_id;

  -- Notify both players
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES
    (p_challenger_id, 'challenge_received', 'Novo Desafio (Admin)',
     format('O administrador criou um desafio para voce contra o jogador #%s.', v_challenged_pos),
     jsonb_build_object('challenge_id', v_challenge_id), p_club_id),
    (p_challenged_id, 'challenge_received', 'Novo Desafio (Admin)',
     format('O administrador criou um desafio. Voce foi desafiado pelo jogador #%s.', v_challenger_pos),
     jsonb_build_object('challenge_id', v_challenge_id), p_club_id);

  RETURN v_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate validate_challenge_creation with logging on every block
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
  v_error TEXT;
  v_rule TEXT;
  v_challenger_state JSONB;
  v_challenged_state JSONB;
  v_rules_state JSONB;
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

  v_rules_state := jsonb_build_object(
    'position_gap_enabled', v_rule_position_gap,
    'cooldown_enabled', v_rule_cooldown
  );

  SELECT * INTO v_challenger FROM players WHERE id = p_challenger_id;
  SELECT * INTO v_challenged FROM players WHERE id = p_challenged_id;

  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenger_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    v_rule := 'member_check';
    v_error := 'Desafiante nao e membro deste esporte';
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', v_error);
  END IF;

  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    v_rule := 'member_check';
    v_error := 'Desafiado nao e membro deste esporte';
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', v_error);
  END IF;

  -- Build state snapshots now that we have both members
  v_challenger_state := jsonb_build_object(
    'player_status', v_challenger.status,
    'fee_status', v_challenger.fee_status,
    'ranking_position', v_challenger_member.ranking_position,
    'challenger_cooldown_until', v_challenger_member.challenger_cooldown_until,
    'challenged_protection_until', v_challenger_member.challenged_protection_until,
    'must_be_challenged_first', v_challenger_member.must_be_challenged_first,
    'last_challenge_date', v_challenger_member.last_challenge_date,
    'challenges_this_month', v_challenger_member.challenges_this_month
  );

  v_challenged_state := jsonb_build_object(
    'player_status', v_challenged.status,
    'fee_status', v_challenged.fee_status,
    'ranking_position', v_challenged_member.ranking_position,
    'challenger_cooldown_until', v_challenged_member.challenger_cooldown_until,
    'challenged_protection_until', v_challenged_member.challenged_protection_until,
    'must_be_challenged_first', v_challenged_member.must_be_challenged_first,
    'last_challenge_date', v_challenged_member.last_challenge_date,
    'challenges_this_month', v_challenged_member.challenges_this_month
  );

  IF v_challenger.status != 'active' THEN
    v_rule := 'challenger_status';
    v_error := 'Jogador nao esta ativo';
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', v_error);
  END IF;

  IF v_challenged.status NOT IN ('active') THEN
    v_rule := 'challenged_status';
    v_error := 'Jogador desafiado nao esta disponivel';
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', v_error);
  END IF;

  IF v_challenger.fee_status = 'overdue' THEN
    v_rule := 'fee_overdue';
    v_error := 'Mensalidade em atraso.';
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', v_error);
  END IF;

  IF v_challenger_member.must_be_challenged_first THEN
    v_rule := 'ambulance_restriction';
    v_error := 'Voce deve ser desafiado primeiro apos retornar da ambulancia';
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', v_error);
  END IF;

  -- CONDITIONAL: Position gap
  IF v_rule_position_gap AND v_challenger_member.ranking_position - v_challenged_member.ranking_position > 2 THEN
    v_rule := 'position_gap';
    v_error := format('So pode desafiar jogadores ate 2 posicoes a frente (desafiante #%s, desafiado #%s)',
      v_challenger_member.ranking_position, v_challenged_member.ranking_position);
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores ate 2 posicoes a frente');
  END IF;

  IF v_challenged_member.ranking_position >= v_challenger_member.ranking_position THEN
    v_rule := 'ranking_direction';
    v_error := format('So pode desafiar jogadores acima no ranking (desafiante #%s, desafiado #%s)',
      v_challenger_member.ranking_position, v_challenged_member.ranking_position);
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores acima no ranking');
  END IF;

  -- CONDITIONAL: Cooldown
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      v_rule := 'challenger_cooldown';
      v_error := format('Cooldown ativo ate %s (agora: %s)',
        v_challenger_member.challenger_cooldown_until, now());
      INSERT INTO challenge_validation_logs
        (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
      VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
      RETURN jsonb_build_object('valid', FALSE, 'error',
        format('Cooldown ativo ate %s', v_challenger_member.challenger_cooldown_until));
    END IF;
    IF v_challenged_member.ranking_position > 1
       AND v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
      v_rule := 'challenged_protection';
      v_error := format('Protecao ativa ate %s (agora: %s, posicao desafiado: #%s)',
        v_challenged_member.challenged_protection_until, now(), v_challenged_member.ranking_position);
      INSERT INTO challenge_validation_logs
        (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
      VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
      RETURN jsonb_build_object('valid', FALSE, 'error', 'Este jogador esta protegido temporariamente');
    END IF;
  END IF;

  -- Active challenge check
  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    v_rule := 'active_challenge';
    v_error := format('Desafio ativo encontrado (total: %s)', v_active_challenge_count);
    INSERT INTO challenge_validation_logs
      (challenger_id, challenged_id, club_id, sport_id, rule_blocked, error_message, challenger_state, challenged_state, rules_state)
    VALUES (p_challenger_id, p_challenged_id, p_club_id, p_sport_id, v_rule, v_error, v_challenger_state, v_challenged_state, v_rules_state);
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Um dos jogadores ja possui um desafio ativo neste esporte');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
