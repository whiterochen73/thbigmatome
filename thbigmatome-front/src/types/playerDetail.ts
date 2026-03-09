export interface PlayerDetail {
  id: number | null
  name: string
  number: string | null
  short_name: string | null
  throwing_hand: string | null
  batting_hand: string | null
  batting_skill_ids: number[]
  player_type_ids: number[]
  biorhythm_ids: number[]
  bunt: number
  steal_start: number
  steal_end: number
  speed: number
  injury_rate: number
  is_pitcher: boolean
  is_relief_only: boolean
  pitching_style_description: string | null
  pinch_pitching_style_id: number | null
  pitching_skill_ids: number[]
  catcher_ids: number[]
  catcher_pitching_style_id: number | null
  partner_pitcher_ids: number[]
  special_throwing_c: number | null
}
