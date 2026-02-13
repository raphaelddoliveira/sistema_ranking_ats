-- ============================================================
-- SmashRank - Migration 010: Sport-Specific Courts/Fields
-- Links courts to a specific sport (quadra/campo/etc)
-- ============================================================

-- 1. Add sport_id column (nullable initially for backfill)
ALTER TABLE courts ADD COLUMN sport_id UUID REFERENCES sports(id);

-- 2. Backfill: assign all existing courts to Tenis
UPDATE courts SET sport_id = (SELECT id FROM sports WHERE name = 'Tenis');

-- 3. Make NOT NULL after backfill
ALTER TABLE courts ALTER COLUMN sport_id SET NOT NULL;

-- 4. Create index for sport-based queries
CREATE INDEX idx_courts_sport ON courts(club_id, sport_id);
