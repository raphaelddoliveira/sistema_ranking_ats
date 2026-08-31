-- ============================================================
-- Migration 049: reservas "fantasma" ligadas a desafio
-- ============================================================
-- Sintoma relatado no grupo (07/08 e 18/08): o MESMO desafio aparecia
-- ocupando duas quadras no mesmo horario, e desafio remarcado continuava
-- segurando a quadra da data antiga.
--
-- Duas causas, ambas confirmadas nos dados de producao:
--
-- 1) O cancelamento da reserva anterior (selectCourtAndDate / reschedule /
--    decline / cancel) roda como UPDATE direto. Quando a reserva antiga foi
--    criada pelo OUTRO participante, a RLS bloqueia sem erro: o UPDATE bate
--    em 0 linhas e a reserva velha continua 'confirmed'. A 048 ampliou a
--    policy, mas o app continua sem saber se o cancelamento funcionou.
--    -> agora o cancelamento passa por RPC SECURITY DEFINER, que nao depende
--       de quem criou a reserva e devolve a quantidade de linhas afetadas.
--
-- 2) _completeReservationForChallenge marcava como 'completed' TODAS as
--    reservas do desafio, sem filtro de status. Reserva ja cancelada era
--    RESSUSCITADA como 'completed' quando o resultado era lancado. Por isso
--    21 desafios (abr-ago/2026) tem 2+ reservas nao-canceladas, varios com
--    duas quadras no mesmo horario (ex.: a13e891c em 24/08, f144649e em
--    14/08, 81db9f20 em 27/08).
--    -> agora so a reserva de fato ativa vira 'completed'.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

-- 1. Limpeza dos dados sujos ------------------------------------------------
-- Mantem, por desafio, apenas UMA reserva nao-cancelada: a que casa com a
-- quadra/data do proprio desafio; empate resolve pela mais recente.
WITH ranked AS (
  SELECT
    r.id,
    row_number() OVER (
      PARTITION BY r.challenge_id
      ORDER BY
        (
          r.court_id = c.court_id
          AND r.reservation_date = (c.chosen_date AT TIME ZONE 'America/Sao_Paulo')::date
        ) DESC NULLS LAST,
        r.created_at DESC
    ) AS rn
  FROM court_reservations r
  JOIN challenges c ON c.id = r.challenge_id
  WHERE r.status IN ('confirmed', 'completed')
)
UPDATE court_reservations cr
SET status = 'cancelled',
    updated_at = now(),
    notes = coalesce(cr.notes || ' | ', '') || 'cancelada na limpeza 049 (reserva fantasma)'
FROM ranked
WHERE ranked.id = cr.id
  AND ranked.rn > 1;

-- 2. Trava no banco: um desafio nunca pode ter duas reservas ativas ---------
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_reservation_per_challenge
  ON court_reservations (challenge_id)
  WHERE challenge_id IS NOT NULL AND status = 'confirmed';

-- 3. Cancelamento das reservas do desafio (imune a RLS, com contagem) ------
CREATE OR REPLACE FUNCTION cancel_challenge_reservations(
  p_challenge_id uuid,
  p_keep_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed boolean;
  v_count integer;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM challenges ch
    WHERE ch.id = p_challenge_id
      AND (
        ch.challenger_id = get_player_id()
        OR ch.challenged_id = get_player_id()
        OR is_admin()
        OR is_club_admin(ch.club_id)
      )
  ) INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Sem permissao para alterar as reservas deste desafio'
      USING ERRCODE = '42501';
  END IF;

  UPDATE court_reservations
  SET status = 'cancelled',
      updated_at = now()
  WHERE challenge_id = p_challenge_id
    AND status = 'confirmed'
    AND (p_keep_id IS NULL OR id <> p_keep_id);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 4. Conclusao da reserva do desafio (nunca ressuscita cancelada) ----------
CREATE OR REPLACE FUNCTION complete_challenge_reservation(p_challenge_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_allowed boolean;
  v_keep uuid;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM challenges ch
    WHERE ch.id = p_challenge_id
      AND (
        ch.challenger_id = get_player_id()
        OR ch.challenged_id = get_player_id()
        OR is_admin()
        OR is_club_admin(ch.club_id)
      )
  ) INTO v_allowed;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'Sem permissao para alterar as reservas deste desafio'
      USING ERRCODE = '42501';
  END IF;

  -- a reserva "de verdade": a que casa com quadra/data do desafio
  SELECT r.id INTO v_keep
  FROM court_reservations r
  JOIN challenges c ON c.id = r.challenge_id
  WHERE r.challenge_id = p_challenge_id
    AND r.status = 'confirmed'
  ORDER BY
    (
      r.court_id = c.court_id
      AND r.reservation_date = (c.chosen_date AT TIME ZONE 'America/Sao_Paulo')::date
    ) DESC NULLS LAST,
    r.created_at DESC
  LIMIT 1;

  IF v_keep IS NULL THEN
    RETURN 0;
  END IF;

  -- qualquer outra reserva ativa do desafio e fantasma: cancela
  UPDATE court_reservations
  SET status = 'cancelled',
      updated_at = now()
  WHERE challenge_id = p_challenge_id
    AND status = 'confirmed'
    AND id <> v_keep;

  UPDATE court_reservations
  SET status = 'completed',
      updated_at = now()
  WHERE id = v_keep;

  RETURN 1;
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_challenge_reservations(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_challenge_reservation(uuid) TO authenticated;
