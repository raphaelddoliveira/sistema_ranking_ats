-- ============================================================
-- Migration 048: RLS — participante pode atualizar reservas do PRÓPRIO desafio
-- ============================================================
-- Bug em produção (reserva duplicada / desafio aparecendo em 2 datas):
-- ao reagendar, selectCourtAndDate cria a nova reserva e cancela a antiga com
--   UPDATE court_reservations SET status='cancelled'
--   WHERE challenge_id = X AND status='confirmed' AND id != <nova>
-- Mas a política de UPDATE só permitia o DONO (reserved_by = get_player_id()),
-- superadmin (is_admin) ou club admin (047). Quando o jogador B remarca um
-- desafio cuja reserva ORIGINAL foi criada pelo jogador A, o cancelamento da
-- reserva do A bate em 0 linhas (RLS bloqueia, SEM erro) — a antiga continua
-- 'confirmed' e o desafio passa a aparecer em DUAS datas.
--
-- Correção: permitir que QUALQUER participante do desafio (challenger ou
-- challenged) atualize as reservas ligadas àquele desafio. Assim o passo de
-- cancelamento do reagendamento funciona independente de quem agendou antes.
--
-- Aditivo: só amplia a condição; ninguém perde acesso. RLS apenas (sem deploy
-- do app). Aplicar no Supabase prod (azrobrhqzbuvijqpvsxn).
-- ============================================================

DROP POLICY IF EXISTS reservations_update ON court_reservations;
CREATE POLICY reservations_update ON court_reservations
  FOR UPDATE TO authenticated
  USING (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
    OR (opponent_id IS NULL AND challenge_id IS NULL)
    OR (
      challenge_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM challenges ch
        WHERE ch.id = court_reservations.challenge_id
          AND (ch.challenger_id = get_player_id()
               OR ch.challenged_id = get_player_id())
      )
    )
  )
  WITH CHECK (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
    OR (opponent_id = get_player_id() AND opponent_type = 'member')
    OR (
      challenge_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM challenges ch
        WHERE ch.id = court_reservations.challenge_id
          AND (ch.challenger_id = get_player_id()
               OR ch.challenged_id = get_player_id())
      )
    )
  );
