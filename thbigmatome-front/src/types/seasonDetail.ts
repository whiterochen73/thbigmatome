import type { SeasonSchedule } from './seasonSchedule'

export interface SeasonDetail {
  id: number
  name: string
  // 現在日 = 今の範囲の最後の試合日（サーバが日程の結果から導く）
  current_date: string
  // 今の範囲（最後に結果が入った日の翌日〜次の試合日）。最終試合日の後などで範囲が無い時は null
  current_range: { start_date: string; end_date: string } | null
  start_date: string
  end_date: string
  key_player_id: number | null
  key_player_name: string | null
  season_schedules: SeasonSchedule[]
}
