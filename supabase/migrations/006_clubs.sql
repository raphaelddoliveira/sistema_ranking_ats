-- ============================================================
-- SmashRank - Phase 8: Club System (Multi-Tenant)
-- ============================================================

-- ============================================================
-- NEW ENUM TYPES
-- ============================================================
CREATE TYPE club_member_role AS ENUM ('admin', 'member');
CREATE TYPE club_member_status AS ENUM ('active', 'pending', 'inactive');
CREATE TYPE join_request_status AS ENUM ('pending', 'approved', 'rejected');

-- ============================================================
-- NEW TABLE: clubs
-- ============================================================
CREATE TABLE clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  invite_code TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  created_by UUID NOT NULL REFERENCES players(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_clubs_invite_code ON clubs(invite_code);
CREATE INDEX idx_clubs_created_by ON clubs(created_by);

CREATE TRIGGER trg_clubs_updated_at BEFORE UPDATE ON clubs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- NEW TABLE: club_members
-- Ranking, cooldowns, and ambulance state per club
-- ============================================================
CREATE TABLE club_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  role club_member_role NOT NULL DEFAULT 'member',
  ranking_position INT,
  challenges_this_month INT NOT NULL DEFAULT 0,
  last_challenge_date TIMESTAMPTZ,
  challenger_cooldown_until TIMESTAMPTZ,
  challenged_protection_until TIMESTAMPTZ,
  ambulance_active BOOLEAN NOT NULL DEFAULT FALSE,
  ambulance_started_at TIMESTAMPTZ,
  ambulance_protection_until TIMESTAMPTZ,
  must_be_challenged_first BOOLEAN NOT NULL DEFAULT FALSE,
  status club_member_status NOT NULL DEFAULT 'active',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_club_member UNIQUE (club_id, player_id)
);

CREATE INDEX idx_club_members_club ON club_members(club_id);
CREATE INDEX idx_club_members_player ON club_members(player_id);
CREATE INDEX idx_club_members_ranking ON club_members(club_id, ranking_position);
CREATE INDEX idx_club_members_status ON club_members(club_id, status);

CREATE TRIGGER trg_club_members_updated_at BEFORE UPDATE ON club_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- NEW TABLE: club_join_requests
-- ============================================================
CREATE TABLE club_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  status join_request_status NOT NULL DEFAULT 'pending',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES players(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_join_requests_club ON club_join_requests(club_id);
CREATE INDEX idx_join_requests_player ON club_join_requests(player_id);
CREATE INDEX idx_join_requests_pending ON club_join_requests(club_id, status) WHERE status = 'pending';

-- ============================================================
-- ADD club_id TO EXISTING TABLES
-- ============================================================
ALTER TABLE challenges ADD COLUMN club_id UUID REFERENCES clubs(id);
ALTER TABLE matches ADD COLUMN club_id UUID REFERENCES clubs(id);
ALTER TABLE courts ADD COLUMN club_id UUID REFERENCES clubs(id);
ALTER TABLE court_reservations ADD COLUMN club_id UUID REFERENCES clubs(id);
ALTER TABLE ranking_history ADD COLUMN club_id UUID REFERENCES clubs(id);
ALTER TABLE ambulances ADD COLUMN club_id UUID REFERENCES clubs(id);
ALTER TABLE notifications ADD COLUMN club_id UUID REFERENCES clubs(id);

CREATE INDEX idx_challenges_club ON challenges(club_id);
CREATE INDEX idx_matches_club ON matches(club_id);
CREATE INDEX idx_courts_club ON courts(club_id);
CREATE INDEX idx_reservations_club ON court_reservations(club_id);
CREATE INDEX idx_ranking_history_club ON ranking_history(club_id);
CREATE INDEX idx_ambulances_club ON ambulances(club_id);
CREATE INDEX idx_notifications_club ON notifications(club_id);

-- ============================================================
-- REMOVE RANKING/COOLDOWN/AMBULANCE FIELDS FROM players
-- (these now live in club_members)
-- ============================================================
ALTER TABLE players DROP COLUMN IF EXISTS ranking_position;
ALTER TABLE players DROP COLUMN IF EXISTS challenges_this_month;
ALTER TABLE players DROP COLUMN IF EXISTS last_challenge_date;
ALTER TABLE players DROP COLUMN IF EXISTS challenger_cooldown_until;
ALTER TABLE players DROP COLUMN IF EXISTS challenged_protection_until;
ALTER TABLE players DROP COLUMN IF EXISTS ambulance_active;
ALTER TABLE players DROP COLUMN IF EXISTS ambulance_started_at;
ALTER TABLE players DROP COLUMN IF EXISTS ambulance_protection_until;
ALTER TABLE players DROP COLUMN IF EXISTS must_be_challenged_first;

DROP INDEX IF EXISTS idx_players_ranking;

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION is_club_member(p_club_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id
      AND player_id = get_player_id()
      AND status = 'active'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

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
-- GENERATE INVITE CODE HELPER
-- ============================================================
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    v_code := upper(substr(md5(random()::text), 1, 8));
    SELECT EXISTS(SELECT 1 FROM clubs WHERE invite_code = v_code) INTO v_exists;
    IF NOT v_exists THEN
      RETURN v_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- RPC: create_club
-- Creates club + auto-inserts creator as admin member
-- ============================================================
CREATE OR REPLACE FUNCTION create_club(
  p_auth_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_player_id UUID;
  v_club_id UUID;
  v_invite_code TEXT;
BEGIN
  SELECT id INTO v_player_id FROM players WHERE auth_id = p_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found for auth_id: %', p_auth_id;
  END IF;

  v_invite_code := generate_invite_code();

  INSERT INTO clubs (name, description, invite_code, created_by)
  VALUES (p_name, p_description, v_invite_code, v_player_id)
  RETURNING id INTO v_club_id;

  -- Creator is admin with ranking position 1
  INSERT INTO club_members (club_id, player_id, role, ranking_position, status)
  VALUES (v_club_id, v_player_id, 'admin', 1, 'active');

  RETURN v_club_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: join_club_by_code
-- Creates a pending join request
-- ============================================================
CREATE OR REPLACE FUNCTION join_club_by_code(
  p_auth_id UUID,
  p_invite_code TEXT
)
RETURNS UUID AS $$
DECLARE
  v_player_id UUID;
  v_club_id UUID;
  v_existing_member BOOLEAN;
  v_existing_request BOOLEAN;
  v_request_id UUID;
BEGIN
  SELECT id INTO v_player_id FROM players WHERE auth_id = p_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found for auth_id: %', p_auth_id;
  END IF;

  SELECT id INTO v_club_id FROM clubs WHERE invite_code = upper(p_invite_code);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Codigo de convite invalido';
  END IF;

  -- Check if already a member
  SELECT EXISTS(
    SELECT 1 FROM club_members WHERE club_id = v_club_id AND player_id = v_player_id AND status = 'active'
  ) INTO v_existing_member;
  IF v_existing_member THEN
    RAISE EXCEPTION 'Voce ja e membro deste clube';
  END IF;

  -- Check if already has pending request
  SELECT EXISTS(
    SELECT 1 FROM club_join_requests WHERE club_id = v_club_id AND player_id = v_player_id AND status = 'pending'
  ) INTO v_existing_request;
  IF v_existing_request THEN
    RAISE EXCEPTION 'Voce ja tem uma solicitacao pendente para este clube';
  END IF;

  INSERT INTO club_join_requests (club_id, player_id)
  VALUES (v_club_id, v_player_id)
  RETURNING id INTO v_request_id;

  -- Notify club admins
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  SELECT
    cm.player_id,
    'general',
    'Nova Solicitacao de Entrada',
    format('%s quer entrar no clube.', (SELECT full_name FROM players WHERE id = v_player_id)),
    jsonb_build_object('request_id', v_request_id, 'requesting_player_id', v_player_id),
    v_club_id
  FROM club_members cm
  WHERE cm.club_id = v_club_id AND cm.role = 'admin' AND cm.status = 'active';

  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: approve_join_request
-- ============================================================
CREATE OR REPLACE FUNCTION approve_join_request(
  p_request_id UUID,
  p_admin_auth_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_request RECORD;
  v_next_pos INT;
BEGIN
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;

  SELECT * INTO v_request FROM club_join_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitacao nao encontrada';
  END IF;
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Solicitacao ja foi processada';
  END IF;

  -- Verify admin is club admin
  IF NOT EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = v_request.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas admins do clube podem aprovar solicitacoes';
  END IF;

  -- Get next ranking position
  SELECT COALESCE(MAX(ranking_position), 0) + 1 INTO v_next_pos
  FROM club_members WHERE club_id = v_request.club_id AND status = 'active';

  -- Create club member
  INSERT INTO club_members (club_id, player_id, role, ranking_position, status)
  VALUES (v_request.club_id, v_request.player_id, 'member', v_next_pos, 'active')
  ON CONFLICT (club_id, player_id) DO UPDATE SET status = 'active', ranking_position = v_next_pos;

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
-- RPC: reject_join_request
-- ============================================================
CREATE OR REPLACE FUNCTION reject_join_request(
  p_request_id UUID,
  p_admin_auth_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_request RECORD;
BEGIN
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;

  SELECT * INTO v_request FROM club_join_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitacao nao encontrada';
  END IF;
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Solicitacao ja foi processada';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = v_request.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas admins do clube podem rejeitar solicitacoes';
  END IF;

  UPDATE club_join_requests
  SET status = 'rejected', resolved_at = now(), resolved_by = v_admin_id
  WHERE id = p_request_id;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_request.player_id,
    'general',
    'Solicitacao Recusada',
    format('Sua solicitacao para o clube %s foi recusada.', (SELECT name FROM clubs WHERE id = v_request.club_id)),
    jsonb_build_object('club_id', v_request.club_id),
    v_request.club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: swap_ranking_after_challenge
-- Now works with club_members instead of players
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

  -- Get positions from club_members
  SELECT ranking_position INTO v_winner_pos FROM club_members WHERE club_id = v_club_id AND player_id = p_winner_id;
  SELECT ranking_position INTO v_loser_pos FROM club_members WHERE club_id = v_club_id AND player_id = p_loser_id;

  -- Record match
  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak, club_id)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak, v_club_id);

  -- Only swap if challenger won AND challenger was below (higher number)
  IF p_winner_id = v_challenger_id AND v_winner_pos > v_loser_pos THEN
    UPDATE club_members SET ranking_position = v_loser_pos WHERE club_id = v_club_id AND player_id = p_winner_id;
    UPDATE club_members SET ranking_position = v_loser_pos + 1 WHERE club_id = v_club_id AND player_id = p_loser_id;

    -- Push everyone between old positions down by 1
    UPDATE club_members
    SET ranking_position = ranking_position + 1
    WHERE club_id = v_club_id
      AND ranking_position > v_loser_pos
      AND ranking_position < v_winner_pos
      AND player_id != p_winner_id
      AND player_id != p_loser_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id)
    VALUES (p_winner_id, v_winner_pos, v_loser_pos, 'challenge_win', p_challenge_id, v_club_id);
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id)
    VALUES (p_loser_id, v_loser_pos, v_loser_pos + 1, 'challenge_loss', p_challenge_id, v_club_id);

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

  -- Update challenge status
  UPDATE challenges
  SET status = 'completed', winner_id = p_winner_id, loser_id = p_loser_id, completed_at = now()
  WHERE id = p_challenge_id;

  -- Set cooldowns on club_members
  UPDATE club_members
  SET challenger_cooldown_until = now() + INTERVAL '48 hours',
      last_challenge_date = now(),
      challenges_this_month = challenges_this_month + 1
  WHERE club_id = v_club_id AND player_id = v_challenger_id;

  UPDATE club_members
  SET challenged_protection_until = now() + INTERVAL '24 hours'
  WHERE club_id = v_club_id AND player_id = v_challenged_id;

  -- Notification: match_result
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_winner_id, 'match_result', 'Resultado Registrado', 'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (p_loser_id, 'match_result', 'Resultado Registrado', 'O resultado do seu desafio foi registrado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: create_challenge
-- Now requires club_id, validates membership, reads from club_members
-- ============================================================
CREATE OR REPLACE FUNCTION create_challenge(
  p_challenger_auth_id UUID,
  p_challenged_id UUID,
  p_club_id UUID DEFAULT NULL
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

  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'club_id e obrigatorio';
  END IF;

  -- Get challenger membership
  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_challenger_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e membro ativo deste clube';
  END IF;

  -- Get challenged membership
  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador desafiado nao e membro ativo deste clube';
  END IF;

  -- Validate: challenger status
  IF (SELECT status FROM players WHERE id = v_challenger_id) != 'active' THEN
    RAISE EXCEPTION 'Jogador nao esta ativo';
  END IF;

  -- Validate: challenged status
  IF (SELECT status FROM players WHERE id = p_challenged_id) NOT IN ('active') THEN
    RAISE EXCEPTION 'Jogador desafiado nao esta disponivel';
  END IF;

  -- Validate: fee
  IF (SELECT fee_status FROM players WHERE id = v_challenger_id) = 'overdue' THEN
    RAISE EXCEPTION 'Mensalidade em atraso. Regularize para desafiar.';
  END IF;

  -- Validate: must be challenged first (ambulance)
  IF v_challenger_member.must_be_challenged_first THEN
    RAISE EXCEPTION 'Voce deve ser desafiado primeiro apos retornar da ambulancia';
  END IF;

  -- Validate: ranking gap
  v_challenger_pos := v_challenger_member.ranking_position;
  v_challenged_pos := v_challenged_member.ranking_position;

  IF v_challenger_pos - v_challenged_pos > 2 THEN
    RAISE EXCEPTION 'So pode desafiar jogadores ate 2 posicoes a frente';
  END IF;
  IF v_challenged_pos >= v_challenger_pos THEN
    RAISE EXCEPTION 'So pode desafiar jogadores acima no ranking';
  END IF;

  -- Validate: cooldown
  IF v_challenger_member.challenger_cooldown_until IS NOT NULL
     AND v_challenger_member.challenger_cooldown_until > now() THEN
    RAISE EXCEPTION 'Cooldown ativo ate %', v_challenger_member.challenger_cooldown_until;
  END IF;

  -- Validate: protection
  IF v_challenged_member.challenged_protection_until IS NOT NULL
     AND v_challenged_member.challenged_protection_until > now() THEN
    RAISE EXCEPTION 'Este jogador esta protegido temporariamente';
  END IF;

  -- Validate: active challenges in this club
  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = v_challenger_id OR challenged_id = v_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo neste clube';
  END IF;

  INSERT INTO challenges (
    challenger_id, challenged_id, club_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    v_challenger_id, p_challenged_id, p_club_id,
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
-- Now reads from club_members
-- ============================================================
CREATE OR REPLACE FUNCTION validate_challenge_creation(
  p_challenger_id UUID,
  p_challenged_id UUID,
  p_club_id UUID DEFAULT NULL
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

  SELECT * INTO v_challenger FROM players WHERE id = p_challenger_id;
  SELECT * INTO v_challenged FROM players WHERE id = p_challenged_id;

  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenger_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Desafiante nao e membro deste clube');
  END IF;

  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Desafiado nao e membro deste clube');
  END IF;

  IF v_challenger.status != 'active' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador nao esta ativo');
  END IF;
  IF v_challenged.status NOT IN ('active') THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador desafiado nao esta disponivel');
  END IF;
  IF v_challenger.fee_status = 'overdue' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Mensalidade em atraso. Regularize para desafiar.');
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
  WHERE club_id = p_club_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Um dos jogadores ja possui um desafio ativo neste clube');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: activate_ambulance
-- Now works with club_members
-- ============================================================
CREATE OR REPLACE FUNCTION activate_ambulance(
  p_player_id UUID,
  p_reason TEXT,
  p_club_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_current_pos INT;
  v_new_pos INT;
  v_max_pos INT;
  v_ambulance_id UUID;
BEGIN
  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'club_id e obrigatorio';
  END IF;

  SELECT ranking_position INTO v_current_pos FROM club_members
  WHERE club_id = p_club_id AND player_id = p_player_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found in club: %', p_player_id;
  END IF;

  SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
  WHERE club_id = p_club_id AND status = 'active';
  v_new_pos := LEAST(v_current_pos + 3, v_max_pos);

  -- Shift players between old+1 and new up by 1
  UPDATE club_members
  SET ranking_position = ranking_position - 1
  WHERE club_id = p_club_id
    AND ranking_position > v_current_pos
    AND ranking_position <= v_new_pos
    AND player_id != p_player_id;

  UPDATE club_members
  SET ranking_position = v_new_pos,
      ambulance_active = TRUE,
      ambulance_started_at = now(),
      ambulance_protection_until = now() + INTERVAL '10 days',
      must_be_challenged_first = TRUE
  WHERE club_id = p_club_id AND player_id = p_player_id;

  -- Update player global status
  UPDATE players SET status = 'ambulance' WHERE id = p_player_id;

  INSERT INTO ambulances (player_id, reason, position_at_activation, initial_penalty_applied, protection_ends_at, club_id)
  VALUES (p_player_id, p_reason, v_current_pos, TRUE, now() + INTERVAL '10 days', p_club_id)
  RETURNING id INTO v_ambulance_id;

  INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id)
  VALUES (p_player_id, v_current_pos, v_new_pos, 'ambulance_penalty', v_ambulance_id, p_club_id);

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
-- UPDATED RPC: deactivate_ambulance
-- Now works with club_members
-- ============================================================
CREATE OR REPLACE FUNCTION deactivate_ambulance(
  p_player_id UUID,
  p_club_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'club_id e obrigatorio';
  END IF;

  UPDATE ambulances
  SET is_active = FALSE, deactivated_at = now()
  WHERE player_id = p_player_id AND club_id = p_club_id AND is_active = TRUE;

  UPDATE club_members
  SET ambulance_active = FALSE,
      ambulance_started_at = NULL,
      ambulance_protection_until = NULL
  WHERE club_id = p_club_id AND player_id = p_player_id;

  -- Check if player has ambulance in any other club, if not set global status back
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
-- UPDATED RPC: apply_ambulance_daily_penalties
-- Now works with club_members
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
    SELECT a.*, cm.ranking_position, a.club_id as amb_club_id
    FROM ambulances a
    JOIN club_members cm ON cm.player_id = a.player_id AND cm.club_id = a.club_id
    WHERE a.is_active = TRUE
      AND a.club_id IS NOT NULL
      AND a.protection_ends_at < now()
      AND (a.last_daily_penalty_at IS NULL
           OR a.last_daily_penalty_at < now() - INTERVAL '1 day')
  LOOP
    SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
    WHERE club_id = v_ambulance.amb_club_id AND status = 'active';

    v_current_pos := v_ambulance.ranking_position;
    IF v_current_pos < v_max_pos THEN
      UPDATE club_members
      SET ranking_position = ranking_position - 1
      WHERE club_id = v_ambulance.amb_club_id
        AND ranking_position = v_current_pos + 1
        AND player_id != v_ambulance.player_id;

      UPDATE club_members
      SET ranking_position = v_current_pos + 1
      WHERE club_id = v_ambulance.amb_club_id AND player_id = v_ambulance.player_id;

      UPDATE ambulances
      SET daily_penalties_applied = daily_penalties_applied + 1,
          last_daily_penalty_at = now()
      WHERE id = v_ambulance.id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id)
      VALUES (v_ambulance.player_id, v_current_pos, v_current_pos + 1, 'ambulance_daily_penalty', v_ambulance.id, v_ambulance.amb_club_id);

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
-- UPDATED RPC: apply_overdue_penalties
-- Now works with club_members
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
    SELECT cm.*, p.fee_status, p.id as pid, cm.club_id as cm_club_id
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
    WHERE club_id = v_member.cm_club_id AND status = 'active';

    v_new_pos := LEAST(v_member.ranking_position + 10, v_max_pos);

    UPDATE club_members
    SET ranking_position = ranking_position - 1
    WHERE club_id = v_member.cm_club_id
      AND ranking_position > v_member.ranking_position
      AND ranking_position <= v_new_pos
      AND player_id != v_member.player_id;

    UPDATE club_members
    SET ranking_position = v_new_pos
    WHERE club_id = v_member.cm_club_id AND player_id = v_member.player_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, club_id)
    VALUES (v_member.player_id, v_member.ranking_position, v_new_pos, 'overdue_penalty', v_member.cm_club_id);

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_member.player_id, 'payment_overdue', 'Penalizacao por Inadimplencia',
      format('Voce perdeu %s posicoes por atraso na mensalidade (15+ dias).', v_new_pos - v_member.ranking_position),
      jsonb_build_object('old_position', v_member.ranking_position, 'new_position', v_new_pos),
      v_member.cm_club_id
    );

    v_count := v_count + 1;
  END LOOP;

  -- Update player fee_status (global)
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
-- UPDATED RPC: apply_monthly_inactivity_penalties
-- Now works with club_members
-- ============================================================
CREATE OR REPLACE FUNCTION apply_monthly_inactivity_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_member RECORD;
  v_max_pos INT;
BEGIN
  FOR v_member IN
    SELECT cm.*, cm.club_id as cm_club_id
    FROM club_members cm
    JOIN players p ON p.id = cm.player_id
    WHERE p.status = 'active'
      AND cm.status = 'active'
      AND cm.challenges_this_month = 0
  LOOP
    SELECT MAX(ranking_position) INTO v_max_pos FROM club_members
    WHERE club_id = v_member.cm_club_id AND status = 'active';

    IF v_member.ranking_position < v_max_pos THEN
      UPDATE club_members
      SET ranking_position = ranking_position - 1
      WHERE club_id = v_member.cm_club_id
        AND ranking_position = v_member.ranking_position + 1
        AND player_id != v_member.player_id;

      UPDATE club_members
      SET ranking_position = v_member.ranking_position + 1
      WHERE club_id = v_member.cm_club_id AND player_id = v_member.player_id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, club_id)
      VALUES (v_member.player_id, v_member.ranking_position, v_member.ranking_position + 1, 'monthly_inactivity', v_member.cm_club_id);

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

  -- Reset monthly challenge count for all active members
  UPDATE club_members SET challenges_this_month = 0
  WHERE status = 'active';

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: expire_pending_challenges
-- Now club-aware
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

-- ============================================================
-- RLS POLICIES FOR NEW TABLES
-- ============================================================

-- CLUBS
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;

CREATE POLICY clubs_select ON clubs
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY clubs_insert ON clubs
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

CREATE POLICY clubs_update ON clubs
  FOR UPDATE TO authenticated
  USING (is_club_admin(id) OR is_admin());

-- CLUB_MEMBERS
ALTER TABLE club_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY club_members_select ON club_members
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY club_members_insert ON club_members
  FOR INSERT TO authenticated
  WITH CHECK (is_club_admin(club_id) OR is_admin());

CREATE POLICY club_members_update ON club_members
  FOR UPDATE TO authenticated
  USING (is_club_admin(club_id) OR is_admin());

CREATE POLICY club_members_delete ON club_members
  FOR DELETE TO authenticated
  USING (is_club_admin(club_id) OR is_admin());

-- CLUB_JOIN_REQUESTS
ALTER TABLE club_join_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY join_requests_select ON club_join_requests
  FOR SELECT TO authenticated
  USING (player_id = get_player_id() OR is_club_admin(club_id) OR is_admin());

CREATE POLICY join_requests_insert ON club_join_requests
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

CREATE POLICY join_requests_update ON club_join_requests
  FOR UPDATE TO authenticated
  USING (is_club_admin(club_id) OR is_admin());
