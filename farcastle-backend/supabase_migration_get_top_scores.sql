-- Create optimized function to get top scores per player
-- This avoids fetching all scores and deduplicating in code

CREATE OR REPLACE FUNCTION get_top_scores(score_limit INT DEFAULT 10)
RETURNS TABLE (fid INT, score BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.fid,
    MAX(s.score) as score
  FROM scores s
  WHERE s.verified = true
  GROUP BY s.fid
  ORDER BY MAX(s.score) DESC
  LIMIT score_limit;
END;
$$ LANGUAGE plpgsql;
