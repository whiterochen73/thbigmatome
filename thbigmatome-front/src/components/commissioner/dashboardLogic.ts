import type {
  AbsenceRecord,
  CooldownRecord,
  CostRecord,
  GameProgressRecord,
  RosterStatusRecord,
} from '@/types/commissionerDashboard'
import type { Team } from '@/types/team'

// コミッショナーのダッシュボードの数え方・判定。画面（概況・コスト・1軍登録）から切り離した純関数。

export type DashboardTab =
  | 'overview'
  | 'absences'
  | 'cooldowns'
  | 'costs'
  | 'rosterStatus'
  | 'teams'
export type DashboardResourceKey =
  | 'teams'
  | 'absences'
  | 'cooldowns'
  | 'costs'
  | 'rosterStatus'
  | 'gameProgress'

/** 「復帰間近」の線。復帰・クールダウン明けまで残りがこの値以下 */
export const IMMINENT_REMAINING = 2

export type CostLevel = 'normal' | 'near' | 'over'

/**
 * 合計コストの注意の線。上限の 95% 以上は 'near'（上限ちょうどを含む）、超過は 'over'。
 * 浮動小数の誤差を避けるため、割合ではなく整数のまま比べる。上限が無い・0 の時は 'normal'。
 * 1軍コストには使わない（1軍は上限ぴったりが通常で、色を付けない）。
 */
export function costLevel(total: number, limit: number | null | undefined): CostLevel {
  if (!limit || limit <= 0) return 'normal'
  if (total > limit) return 'over'
  if (total * 100 >= limit * 95) return 'near'
  return 'normal'
}

/**
 * 合計コストの棒の色。通常は注意なしの色、95% 以上は琥珀、超過は濃い赤（1軍コストの棒は常に通常の色）。
 * 棒は背景として塗られるので、Vuetify が bg-* を生成する塗り用のキー（meter-*）を返す。
 * on-state-* は文字色用で bg-* が生成されず、棒の色が付かない。
 */
export function costBarColor(level: CostLevel): string {
  if (level === 'over') return 'meter-over'
  if (level === 'near') return 'meter-near'
  return 'link'
}

/**
 * コストタブの合計コストの棒の横に出す印（文字なし）。通常は無し。読み上げ用の label は aria-label と title に使う。
 * 色は棒と同じ（costBarColor）。
 */
export function costMark(
  total: number,
  limit: number | null | undefined,
): { icon: string; label: string } | null {
  const level = costLevel(total, limit)
  if (level === 'over') return { icon: 'mdi-alert-circle', label: '合計コスト超過' }
  if (level === 'near') return { icon: 'mdi-alert', label: '合計コストが上限に近い' }
  return null
}

/** 外の世界枠の内訳の規定違反として足す文言（サーバの warnings には内訳の違反が載らない） */
export const OUTSIDE_WORLD_BALANCE_WARNING = '外の世界枠は投手と野手の両方が必要です'

/**
 * 1軍の規定違反の一覧。サーバの warnings（コスト超過・外の世界枠の人数超過）に、
 * 外の世界枠の内訳の違反（投手側・野手側のどちらかが 0 人）を足す。内訳が無い古い応答は warnings のまま。
 */
export function rosterWarnings(record: RosterStatusRecord): string[] {
  if (record.outside_world_breakdown?.balance_ok === false) {
    return [...record.warnings, OUTSIDE_WORLD_BALANCE_WARNING]
  }
  return record.warnings
}

export function remainingCount(absence: AbsenceRecord): number | null {
  return absence.duration_unit === 'days' ? absence.remaining_days : absence.remaining_games
}

export function isImminent(count: number | null): boolean {
  return count !== null && count <= IMMINENT_REMAINING
}

/** 'YYYY-MM-DD'（時刻つきも可）を「5月8日」にする。Date を経由しないので時差で日がずれない */
export function formatMonthDay(value: string | null | undefined): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value ?? '')
  if (!m) return '—'
  return `${Number(m[2])}月${Number(m[3])}日`
}

export interface CheckRow {
  team_id: number
  team_name: string
  /** 規定違反の内容。無ければ空（合計コスト超過だけのチーム） */
  warnings: string[]
  /** 合計コストの超過分（合計 - 上限）。超過していなければ null */
  overBy: number | null
}

/**
 * 要確認のチームの一覧。規定違反のチームを先に（API の順）、合計コスト超過だけのチームをその後ろに
 * （超過の大きい順）並べる。規定違反の方が重要度が高い。規定違反かつ超過のチームは 1 行で、overBy も持つ。
 * 95% 以上でも超過していないチームは入れない。
 */
export function buildCheckRows(
  rosterStatus: RosterStatusRecord[],
  costs: CostRecord[],
): CheckRow[] {
  const overBy = new Map<number, number>()
  for (const c of costs) {
    if (costLevel(c.total_cost, c.total_cost_limit) === 'over') {
      overBy.set(c.team_id, c.total_cost - c.total_cost_limit)
    }
  }
  const violation = rosterStatus
    .filter((r) => rosterWarnings(r).length > 0)
    .map((r) => ({
      team_id: r.team_id,
      team_name: r.team_name,
      warnings: rosterWarnings(r),
      overBy: overBy.get(r.team_id) ?? null,
    }))
  const violationIds = new Set(violation.map((r) => r.team_id))
  const overOnly = costs
    .filter((c) => overBy.has(c.team_id) && !violationIds.has(c.team_id))
    .map((c) => ({
      team_id: c.team_id,
      team_name: c.team_name,
      warnings: [] as string[],
      overBy: overBy.get(c.team_id)!,
    }))
    .sort((a, b) => b.overBy - a.overBy)
  return [...violation, ...overOnly]
}

export type CheckState = 'warn' | 'done' | 'neutral'

/**
 * 要確認の表示の状態。1 件以上なら警告（赤系）。0 件で「問題なし」の緑を出せるのは、規定違反の元（roster_status）と
 * 合計コスト超過の元（costs）の両方が取れている時だけ。どちらかが読み込み中・失敗なら中立色（0 件に見せない）。
 */
export function checkState(count: number, rosterReady: boolean, costsReady: boolean): CheckState {
  if (count > 0) return 'warn'
  return rosterReady && costsReady ? 'done' : 'neutral'
}

/** 要確認の状態ごとの色（設計の規則内: 警告=state-warn・問題なし=state-done・不明=state-neutral） */
export const CHECK_COLOR: Record<CheckState, string> = {
  warn: 'state-warn',
  done: 'state-done',
  neutral: 'state-neutral',
}

export interface DashboardSources {
  teams: Team[]
  absences: AbsenceRecord[]
  cooldowns: CooldownRecord[]
  costs: CostRecord[]
  rosterStatus: RosterStatusRecord[]
}

export interface DashboardSummary {
  activeTeams: number
  totalTeams: number
  inactiveTeams: number
  /** 規定違反（roster_status の warnings、または外の世界枠の内訳の違反）のチーム数 */
  violationTeams: number
  /** 要確認のチーム数。規定違反、または合計コスト超過（100% 超）のチーム。同じチームは 1 回 */
  checkTeams: number
  absenceCount: number
  absenceTeams: number
  absenceSoon: number
  cooldownCount: number
  cooldownTeams: number
  cooldownSoon: number
  costNearTeams: number
  costOverTeams: number
  costWatchTeams: number
}

/** 要約タイル・タブの件数の元。どの値も自分の API だけから数える（別の API が遅くても出せる） */
export function summarize(src: DashboardSources): DashboardSummary {
  const activeTeams = src.teams.filter((t) => t.is_active).length
  const levels = src.costs.map((c) => costLevel(c.total_cost, c.total_cost_limit))
  const costNearTeams = levels.filter((l) => l === 'near').length
  const costOverTeams = levels.filter((l) => l === 'over').length
  const checkTeams = buildCheckRows(src.rosterStatus, src.costs).length
  return {
    activeTeams,
    totalTeams: src.teams.length,
    inactiveTeams: src.teams.length - activeTeams,
    violationTeams: src.rosterStatus.filter((r) => rosterWarnings(r).length > 0).length,
    checkTeams,
    absenceCount: src.absences.length,
    absenceTeams: new Set(src.absences.map((a) => a.team_id)).size,
    absenceSoon: src.absences.filter((a) => isImminent(remainingCount(a))).length,
    cooldownCount: src.cooldowns.length,
    cooldownTeams: new Set(src.cooldowns.map((c) => c.team_id)).size,
    cooldownSoon: src.cooldowns.filter((c) => isImminent(c.remaining_days)).length,
    costNearTeams,
    costOverTeams,
    costWatchTeams: costNearTeams + costOverTeams,
  }
}

export interface TeamRow {
  id: number
  name: string
  manager: string | null
  /** 試合数の進み（game_progress と team_id で結合）。まだ無い・取れないチームは null */
  games: GameProgressRecord | null
  /** 並べ替え用。レギュラーの消化数。試合数の無いチームは末尾になる大きな値 */
  progressKey: number
  /** 消化数 / 総数（0〜1）。総数が 0・試合数なしは null */
  progressRatio: number | null
  firstCount: number | null
  secondCount: number | null
  firstCost: number | null
  firstCostLimit: number | null
  totalCost: number | null
  totalCostLimit: number | null
  costLevel: CostLevel
  absenceCount: number
  cooldownCount: number
  warnings: string[]
  /** 出る注意のチップの数（要確認・コスト・離脱・クールダウン）。「注意が多い順」の並べ替え用 */
  attention: number
}

/** 試合数の無いチームを並べ替えの末尾（昇順）に回す値 */
const NO_GAMES_KEY = Number.MAX_SAFE_INTEGER

export interface TeamRowSources extends DashboardSources {
  gameProgress: GameProgressRecord[]
}

/** 稼働中のチーム 1 つを 1 行にする。API の値は team_id で結合し、無いものは null / 0 */
export function buildTeamRows(src: TeamRowSources): TeamRow[] {
  const active = src.teams.filter((t) => t.is_active)

  return active.map((t) => {
    const roster = src.rosterStatus.find((r) => r.team_id === t.id)
    const cost = src.costs.find((c) => c.team_id === t.id)
    const absenceCount = src.absences.filter((a) => a.team_id === t.id).length
    const cooldownCount = src.cooldowns.filter((c) => c.team_id === t.id).length
    const level = cost ? costLevel(cost.total_cost, cost.total_cost_limit) : 'normal'
    const warnings = roster ? rosterWarnings(roster) : []
    const games = src.gameProgress.find((g) => g.team_id === t.id) ?? null
    return {
      id: t.id,
      name: t.name,
      manager: t.director?.name ?? null,
      games,
      progressKey: games ? games.regular_played : NO_GAMES_KEY,
      progressRatio:
        games && games.regular_total > 0 ? games.regular_played / games.regular_total : null,
      firstCount: roster?.first_count ?? null,
      secondCount: roster?.second_count ?? null,
      firstCost: roster?.first_cost ?? null,
      firstCostLimit: roster?.first_cost_limit ?? null,
      totalCost: cost?.total_cost ?? null,
      totalCostLimit: cost?.total_cost_limit ?? null,
      costLevel: level,
      absenceCount,
      cooldownCount,
      warnings,
      attention:
        (warnings.length > 0 ? 1 : 0) +
        (level !== 'normal' ? 1 : 0) +
        (absenceCount > 0 ? 1 : 0) +
        (cooldownCount > 0 ? 1 : 0),
    }
  })
}
