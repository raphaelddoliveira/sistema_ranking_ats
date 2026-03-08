-- ============================================================
-- 034: Social features - Follows + Challenge Likes
-- ============================================================

-- 1. FOLLOWS TABLE
CREATE TABLE follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  followed_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_follow UNIQUE (follower_id, followed_id),
  CONSTRAINT chk_no_self_follow CHECK (follower_id != followed_id)
);

CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_followed ON follows(followed_id);

-- RLS
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY follows_select ON follows
  FOR SELECT TO authenticated USING (true);

CREATE POLICY follows_insert ON follows
  FOR INSERT TO authenticated
  WITH CHECK (follower_id = get_player_id());

CREATE POLICY follows_delete ON follows
  FOR DELETE TO authenticated
  USING (follower_id = get_player_id());

-- 2. CHALLENGE LIKES TABLE
CREATE TABLE challenge_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_challenge_like UNIQUE (challenge_id, player_id)
);

CREATE INDEX idx_challenge_likes_challenge ON challenge_likes(challenge_id);
CREATE INDEX idx_challenge_likes_player ON challenge_likes(player_id);

-- RLS
ALTER TABLE challenge_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY challenge_likes_select ON challenge_likes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY challenge_likes_insert ON challenge_likes
  FOR INSERT TO authenticated
  WITH CHECK (player_id = get_player_id());

CREATE POLICY challenge_likes_delete ON challenge_likes
  FOR DELETE TO authenticated
  USING (player_id = get_player_id());
