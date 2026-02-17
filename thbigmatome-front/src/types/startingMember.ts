import type { Player } from './player';

export interface StartingMember {
  battingOrder: number;
  position: string | null;
  player: Player | null;
}
