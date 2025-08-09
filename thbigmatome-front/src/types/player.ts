import type { PlayerCost } from './playerCost';

export interface Player {
  id: number;
  name: string;
  short_name: string;
  number: string;
  position: string;
  player_type_ids: number[];
  cost_players: PlayerCost[];
}
