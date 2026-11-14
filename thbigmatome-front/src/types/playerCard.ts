// 選手カード表示（PlayerCardItem）で使う型

export interface Defense {
  id?: number
  position: string
  range_value?: number
  error_rank?: string
  throwing?: string | null
}

export interface PlayerCard {
  id: number
  card_set_id: number
  player_id: number
  card_type: 'pitcher' | 'batter'
  is_pitcher?: boolean
  player_name: string
  player_number: string
  card_set_name: string
  variant?: string | null
  version_label?: string | null
  speed: number
  steal_start: number
  steal_end: number
  injury_rate: number
  cost?: number | null
  defenses?: Defense[]
  unique_traits?: string | null
  image_url?: string | null
}
