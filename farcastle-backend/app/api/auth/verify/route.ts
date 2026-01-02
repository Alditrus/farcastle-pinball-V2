import { NextResponse } from 'next/server';

const NEYNAR_API_KEY = process.env.NEYNAR_API_KEY!;

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { message, signature, nonce } = body;
    
    // Verify the signature with Neynar
    const response = await fetch('https://api.neynar.com/v2/farcaster/auth/verify', {
      method: 'POST',
      headers: {
        'api_key': NEYNAR_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message,
        signature,
        nonce
      })
    });
    
    const data = await response.json();
    
    // data will contain: { fid, username, custody_address, verified_addresses, etc }
    return NextResponse.json(data);
    
  } catch (error) {
    console.error('Error verifying auth:', error);
    return NextResponse.json({ error: 'Failed to verify authentication' }, { status: 500 });
  }
}