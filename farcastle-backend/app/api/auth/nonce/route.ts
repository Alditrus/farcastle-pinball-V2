import { NextResponse } from 'next/server';

const NEYNAR_API_KEY = process.env.NEYNAR_API_KEY!;

export async function GET() {
  try {
    const response = await fetch('https://api.neynar.com/v2/farcaster/auth/nonce', {
      headers: {
        'api_key': NEYNAR_API_KEY
      }
    });
    
    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching nonce:', error);
    return NextResponse.json({ error: 'Failed to fetch nonce' }, { status: 500 });
  }
}