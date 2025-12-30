import { createClient } from '@supabase/supabase-js';
import { NeynarAPIClient, Configuration } from '@neynar/nodejs-sdk';
import { NextResponse } from 'next/server';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY! // Anon key is fine for reading
);

const neynarConfig = new Configuration({
  apiKey: process.env.NEYNAR_API_KEY!,
});
const neynarClient = new NeynarAPIClient(neynarConfig);

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '10');

    // Optimized query: Get max score per FID directly using SQL
    const { data: topScores, error } = await supabase.rpc('get_top_scores', {
      score_limit: limit
    });

    if (error) {
      console.error('RPC error:', error);
      // Fallback to old method if RPC doesn't exist yet
      const { data: fallbackScores, error: fallbackError } = await supabase
        .from('scores')
        .select('fid, score')
        .eq('verified', true)
        .order('score', { ascending: false })
        .limit(limit * 3); // Fetch more to account for duplicates

      if (fallbackError) throw fallbackError;

      // Deduplicate by FID (keep highest score)
      const uniqueScores = fallbackScores.reduce((acc: any[], curr) => {
        const existing = acc.find((s: any) => s.fid === curr.fid);
        if (!existing || curr.score > existing.score) {
          return [...acc.filter((s: any) => s.fid !== curr.fid), curr];
        }
        return acc;
      }, []);

      // Sort and limit
      const finalScores = uniqueScores
        .sort((a, b) => b.score - a.score)
        .slice(0, limit);

      return await enrichLeaderboardWithPlayers(finalScores);
    }

    return await enrichLeaderboardWithPlayers(topScores);
  } catch (error) {
    console.error('Leaderboard error:', error);
    return NextResponse.json({ error: 'Failed to fetch leaderboard' }, { status: 500 });
  }
}

// Helper function to enrich scores with player data
async function enrichLeaderboardWithPlayers(scores: any[]) {
  const fids = scores.map((s: any) => s.fid);

  // Get cached player data from database
  const { data: players, error: playersError } = await supabase
    .from('players')
    .select('fid, username, display_name, pfp_url, updated_at')
    .in('fid', fids);

  if (playersError) {
    console.error('Failed to fetch players:', playersError);
  }

  // Find FIDs that need refreshing (no data or stale)
  const now = Date.now();
  const staleThreshold = 24 * 60 * 60 * 1000; // 24 hours
  const fidsNeedingRefresh = fids.filter(fid => {
    const player = players?.find(p => p.fid === fid);
    if (!player || !player.username) return true;
    if (!player.updated_at) return true;
    return (now - new Date(player.updated_at).getTime() > staleThreshold);
  });

  // Refresh stale data from Neynar (if any)
  if (fidsNeedingRefresh.length > 0 && fidsNeedingRefresh.length <= 10) {
    // Only refresh if it's a reasonable number (avoid rate limit)
    try {
      console.log(`Refreshing ${fidsNeedingRefresh.length} stale player records`);
      const neynarResponse = await neynarClient.fetchBulkUsers({ fids: fidsNeedingRefresh });

      // Update database with fresh data
      for (const user of neynarResponse.users) {
        await supabase
          .from('players')
          .upsert({
            fid: user.fid,
            username: user.username,
            display_name: user.display_name,
            pfp_url: user.pfp_url,
            updated_at: new Date().toISOString()
          }, { onConflict: 'fid' });
      }

      // Refresh our players array
      const { data: refreshedPlayers } = await supabase
        .from('players')
        .select('fid, username, display_name, pfp_url, updated_at')
        .in('fid', fids);

      if (refreshedPlayers) {
        players?.push(...refreshedPlayers.filter(rp => !players.find(p => p.fid === rp.fid)));
      }
    } catch (neynarError) {
      console.error('Failed to refresh Neynar data:', neynarError);
      // Continue with cached/partial data
    }
  }

  // Build leaderboard with cached player data
  const leaderboard = scores.map((scoreEntry: any, index: number) => {
    const player = players?.find(p => p.fid === scoreEntry.fid);
    return {
      rank: index + 1,
      fid: scoreEntry.fid,
      username: player?.username || `User ${scoreEntry.fid}`,
      display_name: player?.display_name || `User ${scoreEntry.fid}`,
      pfp_url: player?.pfp_url || null,
      score: scoreEntry.score
    };
  });

  return NextResponse.json({ leaderboard });
}