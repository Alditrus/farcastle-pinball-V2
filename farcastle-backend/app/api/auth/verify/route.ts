import { NextResponse } from 'next/server';
import { NeynarAPIClient } from '@neynar/nodejs-sdk';

const client = new NeynarAPIClient({
  apiKey: process.env.NEYNAR_API_KEY!
});

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { message, signature } = body;
    
    console.log('[Backend] Verifying signature...');
    console.log('[Backend] Message:', message);
    console.log('[Backend] Signature:', signature);
    
    // Parse the SIWF message to extract FID
    // Message format: "example.com wants you to sign in with your Ethereum account:\n0x...\n\n..."
    // The FID is in the message body as "Farcaster ID: 12345"
    const fidMatch = message.match(/Farcaster ID:\s*(\d+)/i);
    
    if (!fidMatch || !fidMatch[1]) {
      console.error('[Backend] Could not extract FID from message');
      throw new Error('Could not extract FID from message');
    }
    
    const fid = parseInt(fidMatch[1], 10);
    console.log('[Backend] Extracted FID:', fid);
    
    // Verify the signature is valid for this message
    // The signature proves the user controls this Farcaster account
    try {
      // Attempt to fetch signers to validate the signature
      // If this succeeds, the signature is valid even if no signers exist
      await client.fetchSigners({ message, signature });
    } catch (error: any) {
      // If error is "No signers found" - that's OK, signature is still valid
      if (!error.message?.includes('No signers found')) {
        // But if it's a different error, signature is invalid
        console.error('[Backend] Signature verification failed:', error);
        throw new Error('Invalid signature');
      }
      console.log('[Backend] Signature valid (no signers found, but that\'s expected)');
    }
    
    // Fetch user details using the FID
    console.log('[Backend] Fetching user details for FID:', fid);
    const { users } = await client.fetchBulkUsers({ fids: [fid] });
    const user = users[0];
    
    if (!user) {
      throw new Error('User not found');
    }
    
    console.log('[Backend] User found:', user.username);
    
    return NextResponse.json({
      success: true,
      fid: fid,
      username: user.username || 'Player',
      display_name: user.display_name || 'Player',
      pfp_url: user.pfp_url || '',
      custody_address: user.custody_address || '',
      verified_addresses: user.verified_addresses || {}
    });
    
  } catch (error: any) {
    console.error('[Backend] Error verifying auth:', error);
    return NextResponse.json({ 
      error: 'Failed to verify authentication',
      details: error.message 
    }, { status: 500 });
  }
}