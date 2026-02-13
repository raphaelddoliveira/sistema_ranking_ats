-- ============================================================
-- SmashRank - Phase 9: Multi-Sport Support
-- Adds sport as a sub-level within clubs
-- ============================================================

-- ============================================================
-- NEW TABLE: sports (reference/seed data)
-- ============================================================
CREATE TABLE sports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  scoring_type TEXT NOT NULL CHECK (scoring_type IN ('sets_games', 'sets_points', 'simple_score')),
  config JSONB NOT NULL DEFAULT '{}',
  icon TEXT NOT NULL DEFAULT 'sports',
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed sports with scoring configurations
INSERT INTO sports (name, scoring_type, config, icon, display_order) VALUES
  ('Tenis', 'sets_games', '{"max_sets": 3, "games_to_win": 6, "has_tiebreak": true, "has_super_tiebreak": true}', 'sports_tennis', 1),
  ('Volei de Quadra', 'sets_points', '{"max_sets": 5, "points_to_win": 25, "final_set_points": 15, "min_diff": 2}', 'sports_volleyball', 2),
  ('Volei de Areia', 'sets_points', '{"max_sets": 3, "points_to_win": 21, "final_set_points": 15, "min_diff": 2}', 'sports_volleyball', 3),
  ('Futevolei', 'sets_points', '{"max_sets": 3, "points_to_win": 18, "final_set_points": 15, "min_diff": 2}', 'sports_volleyball', 4),
  ('Futsal', 'simple_score', '{"halves": 2}', 'sports_soccer', 5),
  ('Futebol de Campo', 'simple_score', '{"halves": 2}', 'sports_soccer', 6);

-- ============================================================
-- NEW TABLE: club_sports (which sports a club offers)
-- ============================================================
CREATE TABLE club_sports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  sport_id UUID NOT NULL REFERENCES sports(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(club_id, sport_id)
);

CREATE INDEX idx_club_sports_club ON club_sports(club_id);

-- ============================================================
-- ADD sport_id TO EXISTING TABLES
-- ============================================================

-- 1. club_members: add sport_id, migrate data, update constraint
ALTER TABLE club_members ADD COLUMN sport_id UUID REFERENCES sports(id);

-- Migrate existing data: set all to Tenis
UPDATE club_members SET sport_id = (SELECT id FROM sports WHERE name = 'Tenis');

ALTER TABLE club_members ALTER COLUMN sport_id SET NOT NULL;

-- Drop old unique constraint and create new one
ALTER TABLE club_members DROP CONSTRAINT IF EXISTS uq_club_member;
ALTER TABLE club_members ADD CONSTRAINT uq_club_member UNIQUE (club_id, player_id, sport_id);

-- Update ranking index to include sport_id
DROP INDEX IF EXISTS idx_club_members_ranking;
CREATE INDEX idx_club_members_ranking ON club_members(club_id, sport_id, ranking_position);
CREATE INDEX idx_club_members_sport ON club_members(sport_id);

-- 2. challenges: add sport_id
ALTER TABLE challenges ADD COLUMN sport_id UUID REFERENCES sports(id);
UPDATE challenges SET sport_id = (SELECT id FROM sports WHERE name = 'Tenis') WHERE sport_id IS NULL;
ALTER TABLE challenges ALTER COLUMN sport_id SET NOT NULL;
CREATE INDEX idx_challenges_sport ON challenges(sport_id);

-- 3. matches: add sport_id
ALTER TABLE matches ADD COLUMN sport_id UUID REFERENCES sports(id);
UPDATE matches SET sport_id = (SELECT id FROM sports WHERE name = 'Tenis') WHERE sport_id IS NULL;
ALTER TABLE matches ALTER COLUMN sport_id SET NOT NULL;

-- 4. ranking_history: add sport_id
ALTER TABLE ranking_history ADD COLUMN sport_id UUID REFERENCES sports(id);
UPDATE ranking_history SET sport_id = (SELECT id FROM sports WHERE name = 'Tenis') WHERE sport_id IS NULL;

-- 5. ambulances: add sport_id
ALTER TABLE ambulances ADD COLUMN sport_id UUID REFERENCES sports(id);
UPDATE ambulances SET sport_id = (SELECT id FROM sports WHERE name = 'Tenis') WHERE sport_id IS NULL;

-- ============================================================
-- AUTO-CREATE club_sports for existing clubs (Tenis)
-- ============================================================
INSERT INTO club_sports (club_id, sport_id)
SELECT DISTINCT cm.club_id, cm.sport_id
FROM club_members cm
WHERE cm.status = 'active'
ON CONFLICT (club_id, sport_id) DO NOTHING;

-- ============================================================
-- RLS FOR NEW TABLES
-- ============================================================
ALTER TABLE sports ENABLE ROW LEVEL SECURITY;
CREATE POLICY sports_select ON sports FOR SELECT TO authenticated USING (TRUE);

ALTER TABLE club_sports ENABLE ROW LEVEL SECURITY;
CREATE POLICY club_sports_select ON club_sports FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY club_sports_insert ON club_sports FOR INSERT TO authenticated WITH CHECK (is_club_admin(club_id) OR is_admin());
CREATE POLICY club_sports_update ON club_sports FOR UPDATE TO authenticated USING (is_club_admin(club_id) OR is_admin());
CREATE POLICY club_sports_delete ON club_sports FOR DELETE TO authenticated USING (is_club_admin(club_id) OR is_admin());

-- ============================================================
-- UPDATED HELPER: is_club_admin checks ANY sport row
-- (admin role applies to the whole club)
-- ============================================================
CREATE OR REPLACE FUNCTION is_club_admin(p_club_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id
      AND player_id = get_player_id()
      AND role = 'admin'
      AND status = 'active'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- UPDATED RPC: create_club
-- Now also creates a club_sport entry; creator gets enrolled
-- ============================================================
CREATE OR REPLACE FUNCTION create_club(
  p_auth_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_sport_ids UUID[] DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_player_id UUID;
  v_club_id UUID;
  v_invite_code TEXT;
  v_sport_id UUID;
  v_default_sport_id UUID;
BEGIN
  SELECT id INTO v_player_id FROM players WHERE auth_id = p_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found for auth_id: %', p_auth_id;
  END IF;

  v_invite_code := generate_invite_code();

  INSERT INTO clubs (name, description, invite_code, created_by)
  VALUES (p_name, p_description, v_invite_code, v_player_id)
  RETURNING id INTO v_club_id;

  -- If no sports specified, default to Tenis
  IF p_sport_ids IS NULL OR array_length(p_sport_ids, 1) IS NULL THEN
    SELECT id INTO v_default_sport_id FROM sports WHERE name = 'Tenis';
    p_sport_ids := ARRAY[v_default_sport_id];
  END IF;

  -- Create club_sports and enroll creator as admin in each sport
  FOREACH v_sport_id IN ARRAY p_sport_ids
  LOOP
    INSERT INTO club_sports (club_id, sport_id) VALUES (v_club_id, v_sport_id);

    INSERT INTO club_members (club_id, player_id, sport_id, role, ranking_position, status)
    VALUES (v_club_id, v_player_id, v_sport_id, 'admin', 1, 'active');
  END LOOP;

  RETURN v_club_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: approve_join_request
-- Enrolls player in specified sports (or all active club sports)
-- ============================================================
CREATE OR REPLACE FUNCTION approve_join_request(
  p_request_id UUID,
  p_admin_auth_id UUID,
  p_sport_ids UUID[] DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_request RECORD;
  v_next_pos INT;
  v_sport_id UUID;
  v_sport_ids UUID[];
BEGIN
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;

  SELECT * INTO v_request FROM club_join_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitacao nao encontrada';
  END IF;
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Solicitacao ja foi processada';
  END IF;

  -- Verify admin
  IF NOT EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = v_request.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas admins do clube podem aprovar solicitacoes';
  END IF;

  -- If no sports specified, use all active club sports
  IF p_sport_ids IS NULL OR array_length(p_sport_ids, 1) IS NULL THEN
    SELECT array_agg(sport_id) INTO v_sport_ids
    FROM club_sports WHERE club_id = v_request.club_id AND is_active = true;
  ELSE
    v_sport_ids := p_sport_ids;
  END IF;

  -- Enroll in each sport
  FOREACH v_sport_id IN ARRAY v_sport_ids
  LOOP
    SELECT COALESCE(MAX(ranking_position), 0) + 1 INTO v_next_pos
    FROM club_members WHERE club_id = v_request.club_id AND sport_id = v_sport_id AND status = 'active';

    INSERT INTO club_members (club_id, player_id, sport_id, role, ranking_position, status)
    VALUES (v_request.club_id, v_request.player_id, v_sport_id, 'member', v_next_pos, 'active')
    ON CONFLICT (club_id, player_id, sport_id) DO UPDATE SET status = 'active', ranking_position = v_next_pos;
  END LOOP;

  -- Update request
  UPDATE club_join_requests
  SET status = 'approved', resolved_at = now(), resolved_by = v_admin_id
  WHERE id = p_request_id;

  -- Notify the player
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_request.player_id,
    'general',
    'Solicitacao Aprovada!',
    format('Voce foi aceito no clube %s!', (SELECT name FROM clubs WHERE id = v_request.club_id)),
    jsonb_build_object('club_id', v_request.club_id),
    v_request.club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: remove_club_member
-- Removes ALL sport rows for this player in this club
-- ============================================================
CREATE OR REPLACE FUNCTION remove_club_member(
  p_member_id UUID,
  p_admin_auth_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_member RECORD;
BEGIN
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;

  SELECT * INTO v_member FROM club_members WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membro nao encontrado';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = v_member.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas admins do clube podem remover membros';
  END IF;

  IF v_member.player_id = v_admin_id THEN
    RAISE EXCEPTION 'Voce nao pode remover a si mesmo';
  END IF;

  -- Deactivate ALL sport rows for this player in this club
  UPDATE club_members
  SET status = 'inactive', ranking_position = NULL
  WHERE club_id = v_member.club_id AND player_id = v_member.player_id;

  -- Recompact ranking positions for each sport
  WITH ranked AS (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY sport_id ORDER BY ranking_position) as new_pos
    FROM club_members
    WHERE club_id = v_member.club_id
      AND status = 'active'
      AND ranking_position IS NOT NULL
  )
  UPDATE club_members cm
  SET ranking_position = r.new_pos
  FROM ranked r
  WHERE cm.id = r.id;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_member.player_id,
    'general',
    'Removido do Clube',
    format('Voce foi removido do clube %s.', (SELECT name FROM clubs WHERE id = v_member.club_id)),
    jsonb_build_object('club_id', v_member.club_id),
    v_member.club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- NEW RPC: enroll_member_in_sport
-- ============================================================
CREATE OR REPLACE FUNCTION enroll_member_in_sport(
  p_club_id UUID,
  p_player_id UUID,
  p_sport_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_next_pos INT;
  v_member_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  -- Check if player is already a member of this club (any sport)
  IF NOT EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = p_player_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Jogador nao e membro ativo deste clube';
  END IF;

  -- Check if sport is available in this club
  IF NOT EXISTS(
    SELECT 1 FROM club_sports WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Este esporte nao esta disponivel neste clube';
  END IF;

  -- Check if already enrolled
  IF EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = p_player_id AND sport_id = p_sport_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Jogador ja esta inscrito neste esporte';
  END IF;

  -- Get role from existing membership (preserve admin status)
  SELECT (role = 'admin') INTO v_is_admin FROM club_members
  WHERE club_id = p_club_id AND player_id = p_player_id AND status = 'active'
  LIMIT 1;

  SELECT COALESCE(MAX(ranking_position), 0) + 1 INTO v_next_pos
  FROM club_members WHERE club_id = p_club_id AND sport_id = p_sport_id AND status = 'active';

  INSERT INTO club_members (club_id, player_id, sport_id, role, ranking_position, status)
  VALUES (p_club_id, p_player_id, p_sport_id,
    CASE WHEN v_is_admin THEN 'admin'::club_member_role ELSE 'member'::club_member_role END,
    v_next_pos, 'active')
  ON CONFLICT (club_id, player_id, sport_id) DO UPDATE
    SET status = 'active', ranking_position = v_next_pos
  RETURNING id INTO v_member_id;

  RETURN v_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: create_challenge
-- Now requires sport_id
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
BEGIN
  SELECT id INTO v_challenger_id FROM players WHERE auth_id = p_challenger_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado para auth_id: %', p_challenger_auth_id;
  END IF;

  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

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

  IF v_challenger_pos - v_challenged_pos > 2 THEN
    RAISE EXCEPTION 'So pode desafiar jogadores ate 2 posicoes a frente';
  END IF;
  IF v_challenged_pos >= v_challenger_pos THEN
    RAISE EXCEPTION 'So pode desafiar jogadores acima no ranking';
  END IF;

  IF v_challenger_member.challenger_cooldown_until IS NOT NULL
     AND v_challenger_member.challenger_cooldown_until > now() THEN
    RAISE EXCEPTION 'Cooldown ativo ate %', v_challenger_member.challenger_cooldown_until;
  END IF;
  IF v_challenged_member.challenged_protection_until IS NOT NULL
     AND v_challenged_member.challenged_protection_until > now() THEN
    RAISE EXCEPTION 'Este jogador esta protegido temporariamente';
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
-- Now requires sport_id
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
BEGIN
  IF p_club_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'club_id e obrigatorio');
  END IF;
  IF p_sport_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'sport_id e obrigatorio');
  END IF;

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
  IF v_challenger_member.ranking_position - v_challenged_member.ranking_position > 2 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores ate 2 posicoes a frente');
  END IF;
  IF v_challenged_member.ranking_position >= v_challenger_member.ranking_position THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores acima no ranking');
  END IF;
  IF v_challenger_member.challenger_cooldown_until IS NOT NULL
     AND v_challenger_member.challenger_cooldown_until > now() THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      format('Cooldown ativo ate %s', v_challenger_member.challenger_cooldown_until));
  END IF;
  IF v_challenged_member.challenged_protection_until IS NOT NULL
     AND v_challenged_member.challenged_protection_until > now() THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Este jogador esta protegido temporariamente');
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
-- Now sport-aware via challenge's sport_id
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

  UPDATE club_members
  SET challenger_cooldown_until = now() + INTERVAL '48 hours',
      last_challenge_date = now(),
      challenges_this_month = challenges_this_month + 1
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;

  UPDATE club_members
  SET challenged_protection_until = now() + INTERVAL '24 hours'
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenged_id;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_winner_id, 'match_result', 'Resultado Registrado', 'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_loser_id, 'match_result', 'Resultado Registrado', 'O resultado do seu desafio foi registrado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: activate_ambulance (sport-aware)
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
BEGIN
  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

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
-- UPDATED RPC: deactivate_ambulance (sport-aware)
-- ============================================================
CREATE OR REPLACE FUNCTION deactivate_ambulance(
  p_player_id UUID,
  p_club_id UUID DEFAULT NULL,
  p_sport_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

  UPDATE ambulances
  SET is_active = FALSE, deactivated_at = now()
  WHERE player_id = p_player_id AND club_id = p_club_id AND sport_id = p_sport_id AND is_active = TRUE;

  UPDATE club_members
  SET ambulance_active = FALSE,
      ambulance_started_at = NULL,
      ambulance_protection_until = NULL
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_player_id;

  IF NOT EXISTS(
    SELECT 1 FROM club_members WHERE player_id = p_player_id AND ambulance_active = TRUE
  ) THEN
    UPDATE players SET status = 'active' WHERE id = p_player_id;
  END IF;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    p_player_id, 'ambulance_expired', 'Ambulancia Desativada',
    'Sua ambulancia foi desativada. Voce esta de volta ao ranking ativo.',
    jsonb_build_object(), p_club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: apply_ambulance_daily_penalties (sport-aware)
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

-- ============================================================
-- UPDATED RPC: apply_monthly_inactivity_penalties (sport-aware)
-- ============================================================
CREATE OR REPLACE FUNCTION apply_monthly_inactivity_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_member RECORD;
  v_max_pos INT;
BEGIN
  FOR v_member IN
    SELECT cm.*, cm.club_id as cm_club_id, cm.sport_id as cm_sport_id
    FROM club_members cm
    JOIN players p ON p.id = cm.player_id
    WHERE p.status = 'active'
      AND cm.status = 'active'
      AND cm.challenges_this_month = 0
  LOOP
    SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
    WHERE club_id = v_member.cm_club_id AND sport_id = v_member.cm_sport_id AND status = 'active';

    IF v_member.ranking_position < v_max_pos THEN
      UPDATE club_members
      SET ranking_position = ranking_position - 1
      WHERE club_id = v_member.cm_club_id AND sport_id = v_member.cm_sport_id
        AND ranking_position = v_member.ranking_position + 1
        AND player_id != v_member.player_id;

      UPDATE club_members
      SET ranking_position = v_member.ranking_position + 1
      WHERE club_id = v_member.cm_club_id AND sport_id = v_member.cm_sport_id
        AND player_id = v_member.player_id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, club_id, sport_id)
      VALUES (v_member.player_id, v_member.ranking_position, v_member.ranking_position + 1,
        'monthly_inactivity', v_member.cm_club_id, v_member.cm_sport_id);

      INSERT INTO notifications (player_id, type, title, body, data, club_id)
      VALUES (
        v_member.player_id, 'ranking_change', 'Penalizacao por Inatividade',
        format('Voce perdeu 1 posicao por nao ter jogado nenhum desafio este mes. Agora: #%s.', v_member.ranking_position + 1),
        jsonb_build_object('old_position', v_member.ranking_position, 'new_position', v_member.ranking_position + 1),
        v_member.cm_club_id
      );

      v_count := v_count + 1;
    END IF;
  END LOOP;

  UPDATE club_members SET challenges_this_month = 0
  WHERE status = 'active';

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: apply_overdue_penalties (sport-aware)
-- ============================================================
CREATE OR REPLACE FUNCTION apply_overdue_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_member RECORD;
  v_new_pos INT;
  v_max_pos INT;
BEGIN
  FOR v_member IN
    SELECT cm.*, p.fee_status, p.id as pid, cm.club_id as cm_club_id, cm.sport_id as cm_sport_id
    FROM club_members cm
    JOIN players p ON p.id = cm.player_id
    JOIN monthly_fees mf ON mf.player_id = p.id
    WHERE mf.status = 'overdue'
      AND mf.due_date + INTERVAL '15 days' <= CURRENT_DATE
      AND p.status = 'active'
      AND p.fee_status != 'overdue'
      AND cm.status = 'active'
  LOOP
    SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
    WHERE club_id = v_member.cm_club_id AND sport_id = v_member.cm_sport_id AND status = 'active';

    v_new_pos := LEAST(v_member.ranking_position + 10, v_max_pos);

    UPDATE club_members
    SET ranking_position = ranking_position - 1
    WHERE club_id = v_member.cm_club_id AND sport_id = v_member.cm_sport_id
      AND ranking_position > v_member.ranking_position
      AND ranking_position <= v_new_pos
      AND player_id != v_member.player_id;

    UPDATE club_members
    SET ranking_position = v_new_pos
    WHERE club_id = v_member.cm_club_id AND sport_id = v_member.cm_sport_id
      AND player_id = v_member.player_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, club_id, sport_id)
    VALUES (v_member.player_id, v_member.ranking_position, v_new_pos, 'overdue_penalty',
      v_member.cm_club_id, v_member.cm_sport_id);

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_member.player_id, 'payment_overdue', 'Penalizacao por Inadimplencia',
      format('Voce perdeu %s posicoes por atraso na mensalidade (15+ dias).', v_new_pos - v_member.ranking_position),
      jsonb_build_object('old_position', v_member.ranking_position, 'new_position', v_new_pos),
      v_member.cm_club_id
    );

    v_count := v_count + 1;
  END LOOP;

  UPDATE players
  SET fee_status = 'overdue', fee_overdue_since = CURRENT_DATE
  WHERE id IN (
    SELECT p.id FROM players p
    JOIN monthly_fees mf ON mf.player_id = p.id
    WHERE mf.status = 'overdue'
      AND mf.due_date + INTERVAL '15 days' <= CURRENT_DATE
      AND p.fee_status != 'overdue'
  );

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: expire_pending_challenges (sport-aware via challenge)
-- ============================================================
CREATE OR REPLACE FUNCTION expire_pending_challenges()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_challenge RECORD;
BEGIN
  FOR v_challenge IN
    SELECT * FROM challenges
    WHERE status = 'pending'
      AND response_deadline < now()
  LOOP
    UPDATE challenges SET status = 'scheduled' WHERE id = v_challenge.id;

    PERFORM swap_ranking_after_challenge(
      v_challenge.id,
      v_challenge.challenger_id,
      v_challenge.challenged_id,
      '[]'::JSONB, 0, 0, FALSE
    );

    UPDATE challenges
    SET status = 'wo_challenged', wo_player_id = v_challenge.challenged_id
    WHERE id = v_challenge.id;

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_challenge.challenged_id, 'wo_warning', 'WO - Desafio Expirado',
      'Voce nao respondeu ao desafio em 48h e perdeu por WO.',
      jsonb_build_object('challenge_id', v_challenge.id),
      v_challenge.club_id
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
