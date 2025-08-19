import type { Scoreboard } from './scoreboard';

export interface GameData {
  team_id: number;
  team_name: string;
  season_id: number;
  game_date: string;
  game_number: number;
  announced_starter_id: number | null;
  stadium: string;
  home_away: 'home' | 'visitor' | null;
  designated_hitter_enabled: boolean | null;
  opponent_team_id: number | null;
  opponent_team_name: string;
  score: number | null;
  opponent_score: number | null;
  winning_pitcher_id: number | null;
  losing_pitcher_id: number | null;
  save_pitcher_id: number | null;
  scoreboard: Scoreboard | null;
}