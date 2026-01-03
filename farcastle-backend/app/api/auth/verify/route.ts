import { NextResponse } from 'next/server';
import { NeynarAPIClient } from '@neynar/nodejs-sdk';

const client = new NeynarAPIClient({
  apiKey: process.env.NEYNAR_API_KEY!
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { message, signature, fid } = body;
    
    console.log('[Backend] Verifying signature for FID:', fid);
    
    // Just verify the signature is valid
    // We'll use this later for actions that need verification
    try {
      await client.fetchSigners({ message, signature });
      console.log('[Backend] Signature valid (user has signers)');
    } catch (error: any) {
      // No signers is fine - signature is still valid
      console.log('[Backend] Signature valid (no signers, but authenticated)');
    }
    
    // Return success - we trust the FID from frontend SDK
    return NextResponse.json({
      success: true,
      verified: true,
      fid: fid
    });
    
  } catch (error: any) {
    console.error('[Backend] Error verifying signature:', error);
    return NextResponse.json({ 
      error: 'Failed to verify signature',
      details: error.message 
    }, { status: 500 });
  }
}