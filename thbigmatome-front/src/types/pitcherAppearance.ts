export type PitcherRole = 'starter' | 'reliever' | 'opener'
export type PitcherDecision = 'W' | 'L' | 'S' | 'H' | null
export type ResultCategory = 'normal' | 'ko' | 'no_game' | 'long_loss' | null
// その試合日の試合中に 1軍にいたか。first 以外は要確認（second = 2軍 / not_on_team = 在籍なし / no_membership = チームの登録なし）
export type RosterStatus = 'first' | 'second' | 'not_on_team' | 'no_membership'

export interface PitcherAppearanceInput {
  pitcher_id: number | null
  role: PitcherRole
  innings_pitched: number | null
  no_out_exit: boolean
  earned_runs: number
  fatigue_p_used: number
  decision: PitcherDecision
  is_opener: boolean
  pre_injury_days_excluded: number
  appearance_order: number
}

export interface PitcherAppearanceRecord extends PitcherAppearanceInput {
  id: number
  // サーバが直前の先発との中日数から決める連続中4日先発カウント。画面からは送らない
  consecutive_short_rest_count: number
  game_id: number
  team_id: number
  competition_id: number
  schedule_date: string
  result_category: ResultCategory
  injury_check: 'safe' | 'injured' | null
  is_opener: boolean
  appearance_order: number
  // 日程の行への紐づけ（対応する日程の行が無い登板は null）
  season_schedule_id?: number | null
  // 登板の保存は止めず、1軍でない投手は試合日ページの要確認の帯に出す。取れない時は null
  roster_status?: RosterStatus | null
  pitcher_name?: string | null
}
