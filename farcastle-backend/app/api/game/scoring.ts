// Shared scoring utilities for game events

// Server-side score calculation based on game events
export function calculateScore(events: any[]): number {
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
    switch (event.event_type) {
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
        const missionId = event.event_data?.mission_id;
        if (missionId && missionRewards[missionId]) {
          score += missionRewards[missionId];
        }
        break;
      case 'multiplier_applied':
        // Apply score multiplier (from minigame)
        const multiplierValue = event.event_data?.multiplier || 1;
        const scoreBefore = score;
        score *= multiplierValue;
        console.log(`[Multiplier] Applied ${multiplierValue}x: ${scoreBefore} → ${score}`);
        break;
      default:
        score += 10;
    }
  }

  return score;
}
