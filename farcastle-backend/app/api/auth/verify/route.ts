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
    
    // Verify using Neynar SDK
    const data = await client.fetchSigners({ 
      message, 
      signature 
    });
    
    console.log('[Backend] Verification response:', data);
    
    // Extract FID from signers response
    if (!data.signers || data.signers.length === 0) {
      throw new Error('No signers found');
    }
    
    const fid = data.signers[0].fid;
    
    if (!fid) {
      throw new Error('No FID in signer data');
    }
    
    // Fetch user details
    const { users } = await client.fetchBulkUsers({ fids: [fid] });
    const user = users[0];
    
    return NextResponse.json({
      success: true,
      fid: fid,
      username: user?.username || 'Player',
      display_name: user?.display_name || 'Player',
      pfp_url: user?.pfp_url || '',
      custody_address: user?.custody_address || '',
      verified_addresses: user?.verified_addresses || {}
    });
    
  } catch (error: any) {
    console.error('[Backend] Error verifying auth:', error);
    return NextResponse.json({ 
      error: 'Failed to verify authentication',
      details: error.message 
    }, { status: 500 });
  }
}