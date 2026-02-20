-- Add court_id to challenges for the new flow:
-- Challenger selects a court+date, challenged player accepts/declines.
ALTER TABLE challenges
  ADD COLUMN court_id UUID REFERENCES courts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_challenges_court_id ON challenges(court_id);
