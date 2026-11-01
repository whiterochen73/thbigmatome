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

/** 外の世界枠は上限（既定 4）までが ok。下限は無い */
export function outsideWorldLimitState(count: number, limit = OUTSIDE_WORLD_LIMIT): LimitState {
  return count <= limit ? 'ok' : 'ng'
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
