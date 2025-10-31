// server.js
import express from 'express';
import cors from 'cors';
import { createClient } from '@farcaster/quick-auth';
import { NeynarAPIClient } from '@neynar/nodejs-sdk';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Farcaster Quick Auth client
const farcasterClient = createClient();

// Initialize Neynar client
const neynarClient = new NeynarAPIClient({
  apiKey: process.env.NEYNAR_API_KEY
});

// Initialize SQLite database
let db;

async function initDatabase() {
  db = await open({
    filename: './scores.db',
    driver: sqlite3.Database
  });

  // Create scores table
  await db.exec(`
    CREATE TABLE IF NOT EXISTS scores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fid INTEGER NOT NULL,
      score INTEGER NOT NULL,
      timestamp INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_fid ON scores(fid);
    CREATE INDEX IF NOT EXISTS idx_score ON scores(score DESC);
  `);

  // Create user cache table for Neynar data
  await db.exec(`
    CREATE TABLE IF NOT EXISTS user_cache (
      fid INTEGER PRIMARY KEY,
      username TEXT,
      display_name TEXT,
      pfp_url TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);
}

app.use(cors());
app.use(express.json());

// Middleware to verify Farcaster JWT
async function verifyFarcasterAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No authorization token provided' });
  }

  const token = authHeader.substring(7);

  try {
    const { payload } = await farcasterClient.verifyJwt(token);
    req.fid = parseInt(payload.sub); // FID is in the 'sub' claim
    next();
  } catch (error) {
    console.error('JWT verification failed:', error);
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// Auth endpoint - verifies token and returns FID
app.post('/auth', verifyFarcasterAuth, async (req, res) => {
  try {
    res.json({
      success: true,
      fid: req.fid
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Submit score endpoint
app.post('/scores', async (req, res) => {
  try {
    const { fid, score, timestamp } = req.body;

    if (!fid || score === undefined) {
      return res.status(400).json({ error: 'Missing fid or score' });
    }

    // Insert score
    const result = await db.run(
      'INSERT INTO scores (fid, score, timestamp) VALUES (?, ?, ?)',
      [fid, score, timestamp || Date.now()]
    );

    // Get user's rank
    const rankResult = await db.get(
      `SELECT COUNT(*) + 1 as rank 
       FROM (SELECT fid, MAX(score) as best_score FROM scores GROUP BY fid)
       WHERE best_score > (SELECT MAX(score) FROM scores WHERE fid = ?)`,
      [fid]
    );

    res.json({
      success: true,
      id: result.lastID,
      rank: rankResult.rank,
      score: score
    });
  } catch (error) {
    console.error('Score submission error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get leaderboard with user info from Neynar
app.get('/leaderboard', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;

    // Get top scores (best score per user)
    const topScores = await db.all(
      `SELECT fid, MAX(score) as best_score, MAX(timestamp) as last_played
       FROM scores
       GROUP BY fid
       ORDER BY best_score DESC
       LIMIT ?`,
      [limit]
    );

    // Fetch user info from Neynar or cache
    const leaderboardWithUsers = await Promise.all(
      topScores.map(async (entry, index) => {
        let userInfo = await db.get(
          'SELECT * FROM user_cache WHERE fid = ?',
          [entry.fid]
        );

        // If not in cache or older than 1 hour, fetch from Neynar
        if (!userInfo || 
            Date.now() - new Date(userInfo.updated_at).getTime() > 3600000) {
          try {
            const neynarUser = await neynarClient.fetchBulkUsers({
              fids: [entry.fid]
            });

            if (neynarUser.users && neynarUser.users.length > 0) {
              const user = neynarUser.users[0];
              userInfo = {
                fid: entry.fid,
                username: user.username,
                display_name: user.display_name,
                pfp_url: user.pfp_url
              };

              // Update cache
              await db.run(
                `INSERT OR REPLACE INTO user_cache 
                 (fid, username, display_name, pfp_url, updated_at)
                 VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`,
                [userInfo.fid, userInfo.username, userInfo.display_name, 
                 userInfo.pfp_url]
              );
            }
          } catch (neynarError) {
            console.error('Neynar fetch error:', neynarError);
            // Use cached data if available, or fallback
            if (!userInfo) {
              userInfo = {
                fid: entry.fid,
                username: `user-${entry.fid}`,
                display_name: `User ${entry.fid}`,
                pfp_url: null
              };
            }
          }
        }

        return {
          rank: index + 1,
          fid: entry.fid,
          score: entry.best_score,
          username: userInfo.username,
          display_name: userInfo.display_name,
          pfp_url: userInfo.pfp_url,
          last_played: entry.last_played
        };
      })
    );

    res.json({
      success: true,
      leaderboard: leaderboardWithUsers
    });
  } catch (error) {
    console.error('Leaderboard fetch error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get specific user's scores
app.get('/scores/:fid', async (req, res) => {
  try {
    const fid = parseInt(req.params.fid);

    // Get best score
    const bestScore = await db.get(
      'SELECT MAX(score) as best_score FROM scores WHERE fid = ?',
      [fid]
    );

    // Get rank
    const rankResult = await db.get(
      `SELECT COUNT(*) + 1 as rank 
       FROM (SELECT fid, MAX(score) as best_score FROM scores GROUP BY fid)
       WHERE best_score > ?`,
      [bestScore?.best_score || 0]
    );

    // Get recent scores
    const recentScores = await db.all(
      'SELECT score, timestamp FROM scores WHERE fid = ? ORDER BY timestamp DESC LIMIT 10',
      [fid]
    );

    res.json({
      success: true,
      fid: fid,
      best_score: bestScore?.best_score || 0,
      rank: rankResult?.rank || 0,
      recent_scores: recentScores
    });
  } catch (error) {
    console.error('User score fetch error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Initialize and start server
initDatabase().then(() => {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}).catch(error => {
  console.error('Failed to initialize database:', error);
  process.exit(1);
});