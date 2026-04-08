-- ============================================================
-- Migration 043: Fix admin_create_challenge
-- Add active challenge check to prevent duplicates
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
  v_active_count INT;
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

  -- Check for active challenges (even admin should not create duplicates)
  SELECT COUNT(*) INTO v_active_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo. Cancele ou edite o existente.';
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
