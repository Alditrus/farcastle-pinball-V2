import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// Server-side score calculation based on game events
function calculateScore(gameState: any): number {
  // This is where YOU define the scoring logic
  // The client sends events, server calculates the score
  const events = gameState.events || [];
  
  let score = 0;
  for (const event of events) {
    switch (event.type) {
      case 'hit_bumper':
        score += 100;
        break;
      case 'hit_target':
        score += event.data.targetValue || 50;
        break;
      case 'multiball':
        score += 500;
        break;
      // Add all your scoring rules here
    }
  }
  
  return score;
}

// Validation logic
function validateGameSession(gameState: any): { valid: boolean; reason?: string } {
  const events = gameState.events || [];
  
  // Example validations:
  if (events.length === 0) {
    return { valid: false, reason: 'No events recorded' };
  }
  
  // Check for suspicious timing
  const timestamps = events.map((e: any) => e.timestamp);
  const duration = timestamps[timestamps.length - 1] - timestamps[0];
  
  if (duration < 5000) { // Less than 5 seconds
    return { valid: false, reason: 'Game too short' };
  }
  
  if (duration > 600000) { // More than 10 minutes
    return { valid: false, reason: 'Game too long' };
  }
  
  // Check for impossible event sequences
  // Add your game-specific validation logic here
  
  return { valid: true };
}

export async function POST(request: Request) {
  try {
    const { sessionId, fid } = await request.json();

    if (!sessionId || !fid) {
      return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
    }

    // Get session
    const { data: session, error: sessionError } = await supabase
      .from('game_sessions')
      .select('*')
      .eq('id', sessionId)
      .eq('fid', fid)
      .eq('is_active', true)
      .single();

    if (sessionError || !session) {
      return NextResponse.json({ error: 'Invalid session' }, { status: 404 });
    }

    // Validate game session
    const validation = validateGameSession(session.game_state);
    if (!validation.valid) {
      console.warn(`Invalid game session: ${validation.reason}`);
      // Mark session as ended but don't record score
      await supabase
        .from('game_sessions')
        .update({ is_active: false })
        .eq('id', sessionId);
      
      return NextResponse.json({ 
        error: 'Game validation failed',
        reason: validation.reason 
      }, { status: 400 });
    }

    // Calculate score server-side
    const calculatedScore = calculateScore(session.game_state);
    
    // Calculate duration
    const events = session.game_state.events || [];
    const gameDuration = events.length > 0
      ? (events[events.length - 1].timestamp - events[0].timestamp) / 1000
      : 0;

    // Insert verified score
    const { data: scoreData, error: scoreError } = await supabase
      .from('scores')
      .insert({
        fid: session.fid,
        score: calculatedScore,
        game_session_id: session.id,
        verified: true,
        game_duration_seconds: Math.round(gameDuration),
        events_count: events.length,
        ip_address: request.headers.get('x-forwarded-for') || 'unknown'
      })
      .select()
      .single();

    if (scoreError) throw scoreError;

    // Mark session as complete
    await supabase
      .from('game_sessions')
      .update({ is_active: false })
      .eq('id', sessionId);

    // First, get the current total
    const { data: player } = await supabase
        .from('players')
        .select('total_games_played')
        .eq('fid', session.fid)
        .single();

    // Then increment it
    await supabase
        .from('players')
        .update({ 
            total_games_played: (player?.total_games_played || 0) + 1,
            updated_at: new Date().toISOString()
        })
        .eq('fid', session.fid);

    return NextResponse.json({ 
      success: true,
      score: calculatedScore,
      scoreId: scoreData.id
    });
  } catch (error) {
    console.error('End game error:', error);
    return NextResponse.json({ error: 'Failed to end game' }, { status: 500 });
  }
}