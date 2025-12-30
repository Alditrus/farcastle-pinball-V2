import { createClient } from '@supabase/supabase-js';
import { NeynarAPIClient, Configuration } from '@neynar/nodejs-sdk';
import { NextResponse } from 'next/server';
import crypto from 'crypto';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY! // Service role for writing
);

const neynarConfig = new Configuration({
  apiKey: process.env.NEYNAR_API_KEY!,
});
const neynarClient = new NeynarAPIClient(neynarConfig);

export async function POST(request: Request) {
  try {
    const body = await request.json();

    // DEBUG LOGGING
    console.log('Received body:', body);
    console.log('FID value:', body.fid);
    console.log('FID type:', typeof body.fid);

    const fid = parseInt(body.fid);
    
    if (!fid || isNaN(fid)) {
      return NextResponse.json({ error: 'Valid FID required' }, { status: 400 });
    }

    // Create or update player with cached Neynar data
    // Check if we have recent cached data (within 24 hours)
    const { data: existingPlayer } = await supabase
      .from('players')
      .select('fid, username, display_name, pfp_url, updated_at')
      .eq('fid', fid)
      .single();

    const needsRefresh = !existingPlayer ||
      !existingPlayer.updated_at ||
      (Date.now() - new Date(existingPlayer.updated_at).getTime() > 24 * 60 * 60 * 1000);

    if (needsRefresh) {
      // Fetch fresh data from Neynar
      try {
        const neynarResponse = await neynarClient.fetchBulkUsers({ fids: [fid] });
        const user = neynarResponse.users[0];

        if (user) {
          await supabase
            .from('players')
            .upsert({
              fid,
              username: user.username,
              display_name: user.display_name,
              pfp_url: user.pfp_url,
              updated_at: new Date().toISOString()
            }, { onConflict: 'fid' });

          console.log(`✅ Cached Neynar data for FID ${fid}`);
        }
      } catch (neynarError) {
        console.error('Failed to fetch Neynar data:', neynarError);
        // Continue with upsert even if Neynar fails
        await supabase
          .from('players')
          .upsert({ fid }, { onConflict: 'fid' });
      }
    } else {
      console.log(`Using cached data for FID ${fid} (age: ${(Date.now() - new Date(existingPlayer.updated_at).getTime()) / 1000 / 60} minutes)`);
    }

    // Generate server seed for verification
    const serverSeed = crypto.randomBytes(32).toString('hex');

    // Create game session
    const { data: session, error } = await supabase
      .from('game_sessions')
      .insert({
        fid,
        server_seed: serverSeed,
        game_state: {}
      })
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({ 
      sessionId: session.id,
      // Don't send server_seed to client yet
    });
  } catch (error) {
    console.error('Start game error:', error);
    return NextResponse.json({ error: 'Failed to start game' }, { status: 500 });
  }
}