import type { PlayerCost } from './playerCost';

export interface Player {
  id: number;
  name: string;
  short_name: string;
  number: string;
  position: string;
  throwing_hand: string;
  batting_hand: string;
  player_type_ids: number[];
  cost_players: PlayerCost[];
}
