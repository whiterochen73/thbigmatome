import type { SeasonSchedule } from './seasonSchedule'

export interface SeasonDetail {
  id: number
  name: string
  current_date: string
  start_date: string
  end_date: string
  key_player_id: number | null
  key_player_name: string | null
  season_schedules: SeasonSchedule[]
}
