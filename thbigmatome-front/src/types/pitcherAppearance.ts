export type PitcherRole = 'starter' | 'reliever' | 'opener'
export type PitcherDecision = 'W' | 'L' | 'S' | 'H' | null
export type ResultCategory = 'normal' | 'ko' | 'no_game' | 'long_loss' | null

export interface PitcherAppearanceInput {
  pitcher_id: number | null
  role: PitcherRole
  innings_pitched: number | null
  earned_runs: number
  fatigue_p_used: number
  decision: PitcherDecision
  is_opener: boolean
  consecutive_short_rest_count: number
  pre_injury_days_excluded: number
  appearance_order: number
}

export interface PitcherAppearanceRecord extends PitcherAppearanceInput {
  id: number
  game_id: number
  team_id: number
  competition_id: number
  schedule_date: string
  result_category: ResultCategory
  injury_check: 'safe' | 'injured' | null
  is_opener: boolean
  appearance_order: number
}

export interface PitcherAppearanceResponse {
  pitcher_appearance: PitcherAppearanceRecord
  warnings: string[]
}
