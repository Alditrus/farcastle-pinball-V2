import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';
import { calculateScore } from '../scoring';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: Request) {
  try {
    const { sessionId, eventType, eventData } = await request.json();

    if (!sessionId || !eventType) {
      return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
    }

    // Get session
    const { data: session, error: sessionError } = await supabase
      .from('game_sessions')
      .select('*')
      .eq('id', sessionId)
      .eq('is_active', true)
      .single();

    if (sessionError || !session) {
      return NextResponse.json({ error: 'Invalid session' }, { status: 404 });
    }

    // Insert event into game_events table (atomic operation - no race condition)
    const { error: insertError } = await supabase
      .from('game_events')
      .insert({
        session_id: sessionId,
        event_type: eventType,
        event_data: eventData,
        timestamp: Date.now()
      });

    if (insertError) {
      console.error('Failed to insert event:', insertError);
      return NextResponse.json({ error: 'Failed to record event' }, { status: 500 });
    }

    // Fetch all events for this session to calculate current score
    const { data: events, error: eventsError } = await supabase
      .from('game_events')
      .select('event_type, event_data, timestamp')
      .eq('session_id', sessionId)
      .order('timestamp', { ascending: true });

    if (eventsError) {
      console.error('Failed to fetch events for score calculation:', eventsError);
      // Still return success for the event insert, but without score
      return NextResponse.json({ success: true });
    }

    // Calculate current score based on all events
    const currentScore = calculateScore(events || []);

    console.log(`[Event] ${eventType} recorded. Current score: ${currentScore}`);

    return NextResponse.json({ success: true, score: currentScore });
  } catch (error) {
    console.error('Game event error:', error);
    return NextResponse.json({ error: 'Failed to record event' }, { status: 500 });
  }
}