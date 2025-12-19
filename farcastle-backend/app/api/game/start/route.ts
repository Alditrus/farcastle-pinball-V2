import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';
import crypto from 'crypto';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY! // Service role for writing
);

export async function POST(request: Request) {
  try {
    const { fid } = await request.json();
    
    if (!fid) {
      return NextResponse.json({ error: 'FID required' }, { status: 400 });
    }

    // Create or update player
    await supabase
      .from('players')
      .upsert({ fid }, { onConflict: 'fid' });

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