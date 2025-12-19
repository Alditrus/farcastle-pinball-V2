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

    // Get top scores (best score per player)
    const { data: topScores, error } = await supabase
      .from('scores')
      .select('fid, score')
      .eq('verified', true)
      .order('score', { ascending: false })
      .limit(limit);

    if (error) throw error;

    // Deduplicate by FID (keep highest score)
    const uniqueScores = topScores.reduce((acc: any[], curr) => {
      const existing = acc.find(s => s.fid === curr.fid);
      if (!existing || curr.score > existing.score) {
        return [...acc.filter(s => s.fid !== curr.fid), curr];
      }
      return acc;
    }, []);

    // Sort and limit again after deduplication
    const finalScores = uniqueScores
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    // Enrich with Neynar data
    const fids = finalScores.map(s => s.fid);
    let users: any[] = [];
    
    if (fids.length > 0) {
      try {
        const neynarResponse = await neynarClient.fetchBulkUsers({ fids });
        users = neynarResponse.users;
      } catch (neynarError) {
        console.error('Neynar API error:', neynarError);
        // Continue without user data if Neynar fails
      }
    }

    // Combine data
    const leaderboard = finalScores.map((scoreEntry, index) => {
      const user = users.find(u => u.fid === scoreEntry.fid);
      return {
        rank: index + 1,
        fid: scoreEntry.fid,
        username: user?.username || `User ${scoreEntry.fid}`,
        display_name: user?.display_name || `User ${scoreEntry.fid}`,
        pfp_url: user?.pfp_url || null,
        score: scoreEntry.score
      };
    });

    return NextResponse.json({ leaderboard });
  } catch (error) {
    console.error('Leaderboard error:', error);
    return NextResponse.json({ error: 'Failed to fetch leaderboard' }, { status: 500 });
  }
}