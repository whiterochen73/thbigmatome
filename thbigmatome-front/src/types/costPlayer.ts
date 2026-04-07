export interface CostPlayer {
  id: number
  number: string | null
  name: string
  player_types: { id: number; name: string }[]
  normal_cost: number | null
  relief_only_cost: number | null
  pitcher_only_cost: number | null
  fielder_only_cost: number | null
  two_way_cost: number | null
  available_cost_types?: string[]
  player_card_id?: number | null
  variant?: string | null
  card_label?: string | null
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  [key: string]: any
}
