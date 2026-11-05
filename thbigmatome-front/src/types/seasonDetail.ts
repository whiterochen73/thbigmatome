import type { SeasonSchedule } from './seasonSchedule'

export interface SeasonDetail {
  id: number
  // 現在日 = 今の範囲の最後の試合日（サーバが日程の結果から導く）
  current_date: string
  // 今の範囲（最後に結果が入った日の翌日〜次の試合日）。最終試合日に結果が入った後は最終試合日の 1 日。試合日がひとつも無い日程などで範囲が無い時は null
  current_range: { start_date: string; end_date: string } | null
  start_date: string
  end_date: string
  key_player_id: number | null
  key_player_name: string | null
  // 試合日とみなす種別（サーバの SeasonSchedule::GAME_DATE_TYPES）
  game_date_types: string[]
  season_schedules: SeasonSchedule[]
}
