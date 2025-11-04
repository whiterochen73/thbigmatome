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
  defense_p?: string;
  defense_c?: string;
  defense_1b?: string;
  defense_2b?: string;
  defense_3b?: string;
  defense_ss?: string;
  defense_of?: string;
  defense_lf?: string;
  defense_cf?: string;
  defense_rf?: string;
  throwing_c?: number;
  throwing_of?: string;
  throwing_lf?: string;
  throwing_cf?: string;
  throwing_rf?: string;
}
