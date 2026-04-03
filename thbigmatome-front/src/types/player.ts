import type { PlayerCost } from './playerCost'

export interface Player {
  id: number
  name: string
  short_name: string
  number: string
  handedness: string | null
  position: string | null
  cost_players: PlayerCost[]
}
