export interface PlayerCardSummary {
  id: number
  card_type: string
  handedness: string | null
  speed: number | null
  bunt: number | null
  injury_rate: number | null
  is_pitcher: boolean
  is_relief_only: boolean
  starter_stamina: number | null
  relief_stamina: number | null
  card_set: { id: number; name: string; is_current?: boolean }
  card_set_name?: string
  card_set_current?: boolean
  variant?: string | null
  version_label?: string | null
  image_url?: string | null
}

export interface CostSummary {
  cost_name: string
  is_current?: boolean
  // カードごとの行はそのカード、null は選手の既定の行
  player_card_id?: number | null
  card_set_name?: string | null
  version_label?: string | null
  normal_cost: number | null
  pitcher_only_cost: number | null
  fielder_only_cost: number | null
  relief_only_cost: number | null
  two_way_cost: number | null
}

export interface PlayerDetail {
  id: number | null
  name: string
  number: string | null
  short_name: string | null
  series?: string | null
  player_cards?: PlayerCardSummary[]
  costs?: CostSummary[]
}
