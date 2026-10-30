// 離脱を記録した時点（試合日 D に対して）。数え始めが変わる（裁定 AMB-25）
//   pre_game: D の当日から数える / in_game: D の試合には出ていて、翌日から数える
export type AbsencePhase = 'pre_game' | 'in_game'

export interface PlayerAbsence {
  id: number
  team_membership_id: number
  season_id: number
  absence_type: 'injury' | 'suspension' | 'reconditioning'
  reason: string | null
  start_date: string
  duration: number
  duration_unit: 'days' | 'games'
  phase: AbsencePhase
  // 離脱が始まる最初の日（試合中は start_date の翌日）。復帰日は effective_end_date
  effective_start_date: string
  effective_end_date: string | null
  created_at: string
  updated_at: string
  player_name: string
  player_id: number
}
