// One-time script to backfill player data from Neynar
// Run this once after adding the new columns to populate existing players

import { createClient } from '@supabase/supabase-js';
import { NeynarAPIClient, Configuration } from '@neynar/nodejs-sdk';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const neynarConfig = new Configuration({
  apiKey: process.env.NEYNAR_API_KEY!,
});
const neynarClient = new NeynarAPIClient(neynarConfig);

async function backfillPlayerData() {
  console.log('🔄 Starting player data backfill...');

  // Get all unique FIDs from players table
  const { data: players, error } = await supabase
    .from('players')
    .select('fid')
    .order('fid', { ascending: true });

  if (error) {
    console.error('Failed to fetch players:', error);
    return;
  }

  console.log(`Found ${players.length} players to backfill`);

  // Process in batches of 100 (Neynar bulk limit)
  const batchSize = 100;
  for (let i = 0; i < players.length; i += batchSize) {
    const batch = players.slice(i, i + batchSize);
    const fids = batch.map(p => p.fid);

    console.log(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(players.length / batchSize)} (${fids.length} FIDs)`);

    try {
      const neynarResponse = await neynarClient.fetchBulkUsers({ fids });

      // Update each user
      for (const user of neynarResponse.users) {
        await supabase
          .from('players')
          .update({
            username: user.username,
            display_name: user.display_name,
            pfp_url: user.pfp_url,
            updated_at: new Date().toISOString()
          })
          .eq('fid', user.fid);

        console.log(`  ✅ Updated FID ${user.fid}: ${user.username}`);
      }

      // Rate limit: wait 1 second between batches
      if (i + batchSize < players.length) {
        console.log('  ⏳ Waiting 1s to respect rate limits...');
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    } catch (error) {
      console.error(`  ❌ Failed to process batch starting at ${i}:`, error);
      // Continue with next batch even if one fails
    }
  }

  console.log('✅ Backfill complete!');
}

backfillPlayerData().catch(console.error);
