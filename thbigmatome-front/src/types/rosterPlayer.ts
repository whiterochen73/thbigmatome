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
  selected_cost_type:
    | 'normal_cost'
    | 'pitcher_only_cost'
    | 'fielder_only_cost'
    | 'relief_only_cost'
    | 'two_way_cost'
  handedness: string | null
  position: string | null
  player_types: string[]
  cooldown_until?: string
  same_day_exempt?: boolean
  is_outside_world?: boolean
  is_starter_pitcher?: boolean
  is_relief_only?: boolean
  is_absent?: boolean
  absence_info?: AbsenceInfo | null
}
