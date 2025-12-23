import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// Server-side score calculation based on game events
function calculateScore(gameState: any): number {
  const events = gameState.events || [];
  
  let score = 0;
  let currentBumperLevel = 1;
  
  // Bumper level points mapping
  const bumperLevelPoints: { [key: number]: number } = {
    1: 2000,
    2: 3500,
    3: 5000,
    4: 6500,
    5: 8000,
    6: 10000
  };
  
  // Mission rewards mapping
  const missionRewards: { [key: string]: number } = {
    "raise_the_dead": 500000,
    "communion_with_the_void": 1000000,
    "wrath_of_baalhorn": 1500000,
    "requiem_of_the_moon": 2000000,
    "the_wardens_coffers": 3500000,
    "the_stone_blacksmiths_apprentice": 4000000,
    "lich_mode": 5000000
  };
  
  for (const event of events) {
    switch (event.type) {
      case 'bumper':
        score += bumperLevelPoints[currentBumperLevel] || 2000;
        break;
      case 'alcove_bumper':
        score += 5000;
        break;
      case 'slingshot':
        score += 1000;
        break;
      case 'target':
        score += 10000;
        break;
      case 'target_set_complete':
        score += 50000;
        break;
      case 'candle':
        score += 7000;
        break;
      case 'candle_set_complete':
        score += 80000;
        // Upgrade bumper level
        if (currentBumperLevel < 6) {
          currentBumperLevel++;
        }
        break;
      case 'rail_exit':
        score += 200;
        break;
      case 'rollover':
        score += 6000;
        break;
      case 'spinner':
        score += 200;
        break;
      case 'sinkhole':
        score += 70000;
        break;
      case 'jackpot':
        score += 10000000;
        break;
      case 'minigame_win':
        score += 500;
        break;
      case 'mission_complete':
        // Award mission completion points
        const missionId = event.data?.mission_id;
        if (missionId && missionRewards[missionId]) {
          score += missionRewards[missionId];
        }
        break;
      default:
        score += 10;
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
    const body = await request.json();
    
    console.log('=== GAME END REQUEST ===');
    console.log('Body:', body);
    
    const fid = parseInt(body.fid);
    const sessionId = body.sessionId;
    
    console.log('Parsed FID:', fid);
    console.log('Session ID:', sessionId);
    
    if (!sessionId || !fid || isNaN(fid)) {
      console.log('Validation failed');
      return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
    }

    // Get session
    console.log('Looking up session:', sessionId, 'for FID:', fid);
    const { data: session, error: sessionError } = await supabase
      .from('game_sessions')
      .select('*')
      .eq('id', sessionId)
      .eq('fid', fid)
      .eq('is_active', true)
      .single();

    console.log('Session query result:', { session, error: sessionError });

    if (sessionError || !session) {
      console.log('Session not found or inactive');
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