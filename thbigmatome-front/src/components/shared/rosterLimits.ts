// 1軍の規定（人数・コスト・外の世界枠）の判定。画面（ロスター・コミッショナーのダッシュボード）から切り離した純関数。
// 値の出どころ: thbigmatome/app/services/roster_constraint_checker.rb（FIRST_SQUAD_MAX・OUTSIDE_WORLD_LIMIT）と
// config/cost_limits.yml（人数別のコスト上限・最低人数）。

export const MAX_FIRST_SQUAD_PLAYERS = 29
export const FIRST_SQUAD_MIN_PLAYERS = 25
export const OUTSIDE_WORLD_LIMIT = 4
export const COST_LIMIT_TIERS = [
  { minPlayers: 28, maxCost: 120 },
  { minPlayers: 27, maxCost: 119 },
  { minPlayers: 26, maxCost: 117 },
  { minPlayers: 25, maxCost: 114 },
]

export type LimitState = 'ok' | 'ng'

/** 1軍の人数に対するコスト上限。最低人数に満たない時は上限が無い（null） */
export function costLimitForCount(count: number): number | null {
  const tier = COST_LIMIT_TIERS.find((t) => count >= t.minPlayers)
  return tier ? tier.maxCost : null
}

/** 合計コストが上限ちょうどまでは ok、超えたら ng。途中の段階は無い。上限が無い時は判定しない（null） */
export function costLimitState(total: number, limit: number | null | undefined): LimitState | null {
  if (!limit || limit <= 0) return null
  return total <= limit ? 'ok' : 'ng'
}

/** 1軍の人数は 25〜29 が規定内（下限未満も上限超えも ng） */
export function countLimitState(count: number): LimitState {
  return count >= FIRST_SQUAD_MIN_PLAYERS && count <= MAX_FIRST_SQUAD_PLAYERS ? 'ok' : 'ng'
}

/**
 * 外の世界枠は、人数が上限（既定 4）以下で、かつ投手・野手の内訳が規定内（balanceOk）なら ok。下限は無い。
 * balanceOk を渡さない時は人数だけで判定する。
 */
export function outsideWorldLimitState(
  count: number,
  limit = OUTSIDE_WORLD_LIMIT,
  balanceOk = true,
): LimitState {
  return count <= limit && balanceOk ? 'ok' : 'ng'
}

/** 外の世界枠の選手の区分（サーバの TeamMembership#pitcher_fielder_kind）。カードが無い選手は null で、どちらにも数えない */
export type PitcherFielderKind = 'pitcher_only' | 'fielder_only' | 'two_way'

/** 外の世界枠の内訳（サーバの Team.outside_world_breakdown と同じ形） */
export interface OutsideWorldBreakdown {
  pitcher_only: number
  fielder_only: number
  two_way: number
  /** 4 人以上の時、投手に数える人と野手に数える人がそれぞれ 1 人以上いる（3 人以下は常に true） */
  balance_ok: boolean
}

/**
 * 1軍の外の世界枠の各選手の区分から内訳を数える。ロスター画面で 1軍を入れ替えた時に数え直すためのもの。
 * 区分そのものはサーバが決めた値をそのまま使い、画面では決め直さない。
 * 規定は Team.outside_world_balance_ok? と同じ（4 人以上なら、投手側・野手側の両方が 1 人以上）。
 */
export function outsideWorldBreakdownFromKinds(
  kinds: (PitcherFielderKind | null | undefined)[],
): OutsideWorldBreakdown {
  const pitcher_only = kinds.filter((k) => k === 'pitcher_only').length
  const fielder_only = kinds.filter((k) => k === 'fielder_only').length
  const two_way = kinds.filter((k) => k === 'two_way').length
  const balance_ok =
    kinds.length < OUTSIDE_WORLD_LIMIT || (pitcher_only + two_way > 0 && fielder_only + two_way > 0)
  return { pitcher_only, fielder_only, two_way, balance_ok }
}

/** 内訳の全部の表記「投：n/野：n/二刀流：n」 */
export function formatOutsideWorldBreakdown(b: OutsideWorldBreakdown): string {
  return `投：${b.pitcher_only}/野：${b.fielder_only}/二刀流：${b.two_way}`
}

/**
 * 内訳が規定外の時に添える「4 人いる側」。投手側だけ・野手側だけに偏っている時の、いる側と人数（例 投 4）。
 * 規定内・どちらにも数えられる人がいない時は null。
 */
export function outsideWorldImbalance(
  b: OutsideWorldBreakdown,
): { side: 'pitcher' | 'fielder'; label: string; count: number } | null {
  if (b.balance_ok) return null
  if (b.pitcher_only + b.two_way === 0 && b.fielder_only > 0) {
    return { side: 'fielder', label: `野 ${b.fielder_only}`, count: b.fielder_only }
  }
  if (b.fielder_only + b.two_way === 0 && b.pitcher_only > 0) {
    return { side: 'pitcher', label: `投 ${b.pitcher_only}`, count: b.pitcher_only }
  }
  return null
}

/**
 * 規定内=緑のチェック・規定外=赤の✕。色名は塗り・文字の両方に使える専用キー（meter-ok / meter-ng）。
 * on-* は Vuetify が bg-* / text-* を生成しないので使えない。
 */
export const LIMIT_APPEARANCE: Record<LimitState, { color: string; icon: string; label: string }> =
  {
    ok: { color: 'meter-ok', icon: 'mdi-check-circle', label: '規定内' },
    ng: { color: 'meter-ng', icon: 'mdi-close-circle', label: '規定外' },
  }
