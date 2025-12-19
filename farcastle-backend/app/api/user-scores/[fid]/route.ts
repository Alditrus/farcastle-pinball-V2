import { createClient } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export async function GET(
  request: Request,
  { params }: { params: Promise<{ fid: string }> }
) {
  try {
    // Await the params (Next.js 15 change)
    const { fid: fidString } = await params;
    const fid = parseInt(fidString);
    
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '10');

    const { data: scores, error } = await supabase
      .from('scores')
      .select('score, created_at')
      .eq('fid', fid)
      .eq('verified', true)
      .order('score', { ascending: false })
      .limit(limit);

    if (error) throw error;

    return NextResponse.json({ 
      fid,
      scores: scores || [] 
    });
  } catch (error) {
    console.error('User scores error:', error);
    return NextResponse.json({ error: 'Failed to fetch user scores' }, { status: 500 });
  }
}