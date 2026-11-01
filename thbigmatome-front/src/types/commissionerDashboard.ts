import type { OutsideWorldBreakdown } from '@/components/shared/rosterLimits'

// コミッショナーのダッシュボード API（/commissioner/dashboard/*）の応答の形

export interface AbsenceRecord {
  id: number
  team_name: string
  team_id: number
  player_name: string
  player_id: number
  absence_type: string
  reason: string | null
  start_date: string
  duration: number
  duration_unit: string
  effective_end_date: string | null
  remaining_days: number | null
  remaining_games: number | null
  season_current_date: string
}

export interface CostRecord {
  team_id: number
  team_name: string
  team_type: string
  total_cost: number
  total_cost_limit: number
  first_squad_cost: number
  first_squad_cost_limit: number | null
  first_squad_count: number
  exempt_count: number
  cost_usage_ratio: number
}

export interface CooldownRecord {
  team_id: number
  team_name: string
  player_id: number
  player_name: string
  demotion_date: string
  cooldown_until: string
  remaining_days: number
  same_day_exempt: boolean
}

export interface RosterStatusRecord {
  team_id: number
  team_name: string
  team_type: string
  first_count: number
  second_count: number
  first_cost: number
  first_cost_limit: number | null
  outside_world_count: number
  outside_world_limit: number
  /** 外の世界枠の内訳。古い応答には無い */
  outside_world_breakdown?: OutsideWorldBreakdown
  warnings: string[]
}

/** 試合数の進み（/commissioner/dashboard/game_progress）。プレーオフは総数を持たず消化数だけ */
export interface GameProgressRecord {
  team_id: number
  /** レギュラーシーズンの消化数（両軍の得点が入った試合） */
  regular_played: number
  /** レギュラーシーズンの総数（日程マスタの試合日。通常 143） */
  regular_total: number
  /** まだ振り替えていない雨天中止・ノーゲームの数。0 なら画面に出さない */
  regular_unrescheduled: number
  playoff_played: number
}

/** 1 本の API の取得状態（API ごとに別々に持つ。遅い API が他を待たせない） */
export interface DashboardResource<T> {
  data: T[]
  loading: boolean
  failed: boolean
}
