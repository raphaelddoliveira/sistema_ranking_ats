-- ============================================================
-- Migration 041: Remove rematch restriction
-- Cooldowns (48h challenger / 24h challenged) are sufficient
-- to prevent immediate rematches. The extra "must play someone
-- else first" rule is removed — once cooldowns expire, any
-- eligible challenge is allowed.
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
  -- Protection does NOT apply to the #1 ranked player — they are always challengeable
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RETURN jsonb_build_object('valid', FALSE, 'error',
        format('Cooldown ativo ate %s', v_challenger_member.challenger_cooldown_until));
    END IF;
    IF v_challenged_member.ranking_position > 1
       AND v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
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
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Um dos jogadores ja possui um desafio ativo neste esporte');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
