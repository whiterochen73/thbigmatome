export interface PlayerAbsence {
  id: number
  team_membership_id: number
  season_id: number
  absence_type: 'injury' | 'suspension' | 'reconditioning'
  reason: string | null
  start_date: string
  duration: number
  duration_unit: 'days' | 'games'
  effective_end_date: string | null
  created_at: string
  updated_at: string
  player_name: string
}
