-- ============================================================
-- Migration 047: RLS — club admin pode reagendar (não só superadmin)
-- ============================================================
-- Bug em produção: ao reagendar um desafio (ex.: adiamento por chuva),
-- um ADMIN DE CLUBE que não é participante recebia
--   AppException(42501): new row violates row-level security policy
--   for table "court_reservations"
-- porque as políticas de RLS só aceitavam o DONO da reserva
-- (reserved_by = get_player_id()) ou SUPERADMIN (is_admin() checa
-- players.role = 'superadmin'). selectCourtAndDate grava a reserva com
-- reserved_by = participante (correto — o admin não entra como jogador),
-- então o admin de clube caía fora das duas condições.
--
-- Correção: adicionar is_club_admin(club_id) às políticas que o
-- reagendamento toca (INSERT/UPDATE de court_reservations e UPDATE de
-- challenges). is_club_admin checa club_members.role = 'admin' ativo no
-- clube da linha — permissão correta para o admin agir pelos jogadores.
--
-- Aditivo: só ADICIONA uma condição (amplia para club admin); ninguém que
-- já podia perde acesso. Aplicar no Supabase (staging -> produção).
-- ============================================================

-- court_reservations: INSERT ------------------------------------------------
DROP POLICY IF EXISTS reservations_insert ON court_reservations;
CREATE POLICY reservations_insert ON court_reservations
  FOR INSERT TO authenticated
  WITH CHECK (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
  );

-- court_reservations: UPDATE (preserva a lógica de vaga aberta da 037) ------
DROP POLICY IF EXISTS reservations_update ON court_reservations;
CREATE POLICY reservations_update ON court_reservations
  FOR UPDATE TO authenticated
  USING (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
    OR (opponent_id IS NULL AND challenge_id IS NULL)
  )
  WITH CHECK (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
    OR (opponent_id = get_player_id() AND opponent_type = 'member')
  );

-- challenges: UPDATE --------------------------------------------------------
DROP POLICY IF EXISTS challenges_update ON challenges;
CREATE POLICY challenges_update ON challenges
  FOR UPDATE TO authenticated
  USING (
    challenger_id = get_player_id()
    OR challenged_id = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
  );
