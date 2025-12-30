-- Add columns to players table for caching Neynar data
-- Run this migration in your Supabase SQL Editor

ALTER TABLE players
ADD COLUMN IF NOT EXISTS username TEXT,
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS pfp_url TEXT;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_players_updated_at ON players(updated_at);
