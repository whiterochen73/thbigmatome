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
  card_set: { id: number; name: string }
}

export interface PlayerDetail {
  id: number | null
  name: string
  number: string | null
  short_name: string | null
  player_cards?: PlayerCardSummary[]
}
