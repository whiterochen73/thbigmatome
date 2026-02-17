export interface AbsenceInfo {
  absence_type: 'injury' | 'suspension' | 'reconditioning'
  reason: string | null
  effective_end_date: string | null
  remaining_days: number | null
  duration_unit: 'days' | 'games'
}

export interface RosterPlayer {
  team_membership_id: number
  player_id: number
  number: string
  player_name: string
  squad: 'first' | 'second'
  cost: number
  selected_cost_type: string
  position: string // Added position
  throwing_hand: string
  batting_hand: string
  player_types: string[] // Added player_types (comma-separated string)
  cooldown_until?: string
  same_day_exempt?: boolean
  is_outside_world?: boolean
  is_absent?: boolean
  absence_info?: AbsenceInfo | null
}
