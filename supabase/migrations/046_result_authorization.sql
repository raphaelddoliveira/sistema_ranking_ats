-- ============================================================
-- Migration 046: Autorização e validação de resultados
-- ============================================================
-- Fecha buracos de "editar jogo direto" no backend (auditoria):
--  1. Trigger em `matches`: vencedor e perdedor TÊM que ser os dois
--     participantes do desafio (cobre submit normal, WO e edição admin).
--     Impede um admin/usuário marcar um terceiro como vencedor e
--     corromper o ranking.
--  2. record_wo: passa a exigir que quem chama seja participante ou
--     administrador do clube (antes não tinha NENHUMA checagem — qualquer
--     usuário autenticado podia declarar WO em qualquer jogo).
--
-- Mudanças ADITIVAS e fail-closed: fluxos legítimos (vencedor/perdedor =
-- os dois participantes, chamados por participante/admin) continuam
-- funcionando; só chamadas indevidas são barradas.
--
-- ATENÇÃO: aplicar e TESTAR em staging antes de produção.
-- ============================================================

-- 1. Validação de participantes em qualquer escrita na tabela matches ----
CREATE OR REPLACE FUNCTION validate_match_participants()
RETURNS TRIGGER AS $$
DECLARE
  v_challenger UUID;
  v_challenged UUID;
BEGIN
  SELECT challenger_id, challenged_id
    INTO v_challenger, v_challenged
  FROM challenges
  WHERE id = NEW.challenge_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partida sem desafio válido (challenge_id %)', NEW.challenge_id;
  END IF;

  IF NEW.winner_id = NEW.loser_id
     OR NEW.winner_id NOT IN (v_challenger, v_challenged)
     OR NEW.loser_id NOT IN (v_challenger, v_challenged) THEN
    RAISE EXCEPTION
      'Vencedor e perdedor devem ser os dois participantes do desafio';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_match_participants ON matches;
CREATE TRIGGER trg_validate_match_participants
  BEFORE INSERT OR UPDATE ON matches
  FOR EACH ROW EXECUTE FUNCTION validate_match_participants();

-- 2. record_wo com autorização ------------------------------------------
CREATE OR REPLACE FUNCTION record_wo(
  p_challenge_id UUID,
  p_winner_id UUID,
  p_loser_id UUID
) RETURNS void AS $$
DECLARE
  v_challenge RECORD;
  v_caller UUID;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found: %', p_challenge_id;
  END IF;
  IF v_challenge.status != 'scheduled' THEN
    RAISE EXCEPTION 'Challenge is not in valid status for WO: %', v_challenge.status;
  END IF;

  -- Autorização: só participantes ou administrador do clube podem dar WO.
  v_caller := get_player_id();
  IF v_caller IS NULL
     OR (v_caller != v_challenge.challenger_id
         AND v_caller != v_challenge.challenged_id
         AND NOT is_club_admin(v_challenge.club_id)) THEN
    RAISE EXCEPTION 'Apenas participantes ou administradores podem registrar WO';
  END IF;

  -- Vencedor/perdedor têm que ser os dois participantes (defesa extra; o
  -- trigger em matches também garante isso).
  IF p_winner_id = p_loser_id
     OR p_winner_id NOT IN (v_challenge.challenger_id, v_challenge.challenged_id)
     OR p_loser_id NOT IN (v_challenge.challenger_id, v_challenge.challenged_id) THEN
    RAISE EXCEPTION 'Vencedor e perdedor devem ser os participantes do desafio';
  END IF;

  -- Use swap_ranking to handle ranking swap + match insert + notifications
  PERFORM swap_ranking_after_challenge(
    p_challenge_id, p_winner_id, p_loser_id,
    '[]'::JSONB, 0, 0, FALSE
  );

  -- Override status to WO (swap_ranking sets it to 'completed', we override)
  UPDATE challenges
  SET status = CASE
    WHEN p_loser_id = v_challenge.challenger_id THEN 'wo_challenger'::challenge_status
    ELSE 'wo_challenged'::challenge_status
  END,
  wo_player_id = p_loser_id
  WHERE id = p_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
