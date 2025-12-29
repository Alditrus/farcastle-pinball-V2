import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';
import { calculateScore } from '../scoring';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// Validation logic
function validateGameSession(events: any[]): { valid: boolean; reason?: string } {
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

    // Fetch all events for this session from game_events table
    console.log('Fetching events for session:', sessionId);
    const { data: events, error: eventsError } = await supabase
      .from('game_events')
      .select('event_type, event_data, timestamp')
      .eq('session_id', sessionId)
      .order('timestamp', { ascending: true });

    if (eventsError) {
      console.error('Failed to fetch events:', eventsError);
      return NextResponse.json({ error: 'Failed to fetch game events' }, { status: 500 });
    }

    console.log('Found', events?.length || 0, 'events for session');

    // Log all events for debugging
    if (events && events.length > 0) {
      console.log('Event types:', events.map(e => e.event_type).join(', '));
      const multiplierEvents = events.filter(e => e.event_type === 'multiplier_applied');
      if (multiplierEvents.length > 0) {
        console.log('Multiplier events found:', multiplierEvents.length);
        multiplierEvents.forEach(e => {
          console.log('  Multiplier event data:', JSON.stringify(e.event_data));
        });
      } else {
        console.log('⚠️ No multiplier_applied events found in this session');
      }
    }

    // Validate game session
    const validation = validateGameSession(events || []);
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
    const calculatedScore = calculateScore(events || []);

    // Calculate duration
    const gameDuration = events && events.length > 0
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
        events_count: events?.length || 0,
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