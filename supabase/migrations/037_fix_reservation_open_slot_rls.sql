-- Fix: Allow any authenticated player to fill an open reservation slot
-- Previously, only the reservation owner could update, which silently blocked
-- other players from joining open slots via applyToReservation.
--
-- USING: controls which rows can be selected for update
--   - Owner, admin, or open friendly slot (no opponent, no challenge)
-- WITH CHECK: controls what the row must look like after update
--   - Owner, admin, or the new opponent must be the current player

DROP POLICY IF EXISTS reservations_update ON court_reservations;

CREATE POLICY reservations_update ON court_reservations
FOR UPDATE
USING (
  reserved_by = get_player_id()
  OR is_admin()
  OR (opponent_id IS NULL AND challenge_id IS NULL)
)
WITH CHECK (
  reserved_by = get_player_id()
  OR is_admin()
  OR (opponent_id = get_player_id() AND opponent_type = 'member')
);
