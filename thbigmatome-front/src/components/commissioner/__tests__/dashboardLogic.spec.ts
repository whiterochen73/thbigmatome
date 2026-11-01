import { describe, it, expect } from 'vitest'
import vuetify from '@/plugins/vuetify'
import {
  costLevel,
  costBarColor,
  remainingCount,
  isImminent,
  formatMonthDay,
  summarize,
  buildTeamRows,
  buildCheckRows,
  checkState,
} from '../dashboardLogic'
import type {
  AbsenceRecord,
  CooldownRecord,
  CostRecord,
  RosterStatusRecord,
} from '@/types/commissionerDashboard'
import type { Team } from '@/types/team'

// Test Basis: thbig-dugout-commissioner-dashboard-visual-design.md §2 案 A+（注意の線）/ Operator 決定 2026-11-02
// 「合計コスト 95% 以上は黄、超過は赤。1軍コストは色を付けない」
describe('costLevel（合計コストの注意の線）', () => {
  it.each([
    // 上限 1000 で 94.9% / 95% / 100% / 100.1% の境界
    [949, 1000, 'normal'],
    [950, 1000, 'near'],
    [1000, 1000, 'near'],
    [1001, 1000, 'over'],
    // 実際の上限 200
    [189, 200, 'normal'],
    [190, 200, 'near'],
    [200, 200, 'near'],
    [201, 200, 'over'],
    [0, 200, 'normal'],
  ])('合計 %i / 上限 %i → %s', (total, limit, expected) => {
    expect(costLevel(total, limit)).toBe(expected)
  })

  it('旧い線（90%）では注意にしない', () => {
    expect(costLevel(180, 200)).toBe('normal')
    expect(costLevel(185, 200)).toBe('normal')
  })

  it('上限が無い・0 の時は注意にしない（0 割りで落とさない）', () => {
    expect(costLevel(100, null)).toBe('normal')
    expect(costLevel(100, 0)).toBe('normal')
  })
})

describe('costBarColor', () => {
  it('通常=link・上限に近い=meter-near・超過=meter-over', () => {
    expect(costBarColor('normal')).toBe('link')
    expect(costBarColor('near')).toBe('meter-near')
    expect(costBarColor('over')).toBe('meter-over')
  })

  // v-progress-linear は color 名を bg-{名前} のクラスで背景に塗る。Vuetify が bg-* を生成しない名前
  // （on-state-* など文字色用のキー）を渡すと背景色が付かず、色の文字列だけ見る spec をすり抜ける。
  // 実描画の computed background は subtask_1794h の記録（light/dark × 通常・上限に近い・超過）を参照
  it.each(['normal', 'near', 'over'] as const)(
    '%s の棒の色は Vuetify のテーマが bg-* を生成する名前で、文字色用の on-* ではない',
    (level) => {
      const name = costBarColor(level)
      const css = vuetify.theme.styles.value
      expect(name.startsWith('on-')).toBe(false)
      expect(css).toContain(`.bg-${name} `)
    },
  )
})

describe('remainingCount / isImminent', () => {
  const base = { duration_unit: 'days', remaining_days: 3, remaining_games: null }
  it('日数の離脱は remaining_days、試合数の離脱は remaining_games を使う', () => {
    expect(remainingCount(base as AbsenceRecord)).toBe(3)
    expect(
      remainingCount({
        duration_unit: 'games',
        remaining_days: null,
        remaining_games: 2,
      } as AbsenceRecord),
    ).toBe(2)
  })
  it('2 以下が「まもなく動く」。3 は含めない。null は含めない', () => {
    expect(isImminent(2)).toBe(true)
    expect(isImminent(0)).toBe(true)
    expect(isImminent(3)).toBe(false)
    expect(isImminent(null)).toBe(false)
  })
})

describe('formatMonthDay', () => {
  it('YYYY-MM-DD を「5月8日」にする（時差で日がずれない）', () => {
    expect(formatMonthDay('2026-05-08')).toBe('5月8日')
    expect(formatMonthDay('2026-10-09')).toBe('10月9日')
    expect(formatMonthDay('2026-01-01T00:00:00.000Z')).toBe('1月1日')
  })
  it('空は「—」', () => {
    expect(formatMonthDay(null)).toBe('—')
    expect(formatMonthDay(undefined)).toBe('—')
    expect(formatMonthDay('')).toBe('—')
  })
})

const team = (id: number, over: Partial<Team> = {}): Team => ({
  id,
  name: `チーム${id}`,
  short_name: `T${id}`,
  is_active: true,
  has_season: true,
  team_type: 'normal',
  ...over,
})
const cost = (team_id: number, total_cost: number): CostRecord => ({
  team_id,
  team_name: `チーム${team_id}`,
  team_type: 'normal',
  total_cost,
  total_cost_limit: 200,
  first_squad_cost: 150,
  first_squad_cost_limit: 170,
  first_squad_count: 25,
  exempt_count: 0,
  cost_usage_ratio: total_cost / 200,
})
const roster = (team_id: number, warnings: string[] = []): RosterStatusRecord => ({
  team_id,
  team_name: `チーム${team_id}`,
  team_type: 'normal',
  first_count: 28,
  second_count: 7,
  first_cost: 120,
  first_cost_limit: 120,
  outside_world_count: 3,
  outside_world_limit: 4,
  warnings,
})
const absence = (team_id: number, remaining: number | null, unit = 'days'): AbsenceRecord => ({
  id: team_id * 100 + (remaining ?? 99),
  team_name: `チーム${team_id}`,
  team_id,
  player_name: '選手',
  player_id: 1,
  absence_type: 'injury',
  reason: null,
  start_date: '2026-04-01',
  duration: 5,
  duration_unit: unit,
  effective_end_date: '2026-04-20',
  remaining_days: unit === 'days' ? remaining : null,
  remaining_games: unit === 'games' ? remaining : null,
  season_current_date: '2026-04-10',
})
const cooldown = (team_id: number, remaining_days: number): CooldownRecord => ({
  team_id,
  team_name: `チーム${team_id}`,
  player_id: team_id,
  player_name: '選手',
  demotion_date: '2026-04-01',
  cooldown_until: '2026-04-11',
  remaining_days,
  same_day_exempt: false,
})

// Test Basis: Operator 決定 2026-11-02「要確認に合計コスト超過（100% 超）のチームも数える。同じチームは 1 回。重要度は規定違反より低い」
describe('要確認（規定違反 または 合計コスト超過）', () => {
  const sources = (rosterStatus: RosterStatusRecord[], costs: CostRecord[]) =>
    summarize({ teams: [], absences: [], cooldowns: [], costs, rosterStatus })

  it('違反のみ・超過のみ・両方（1 回だけ）・95% 以上で超過していない（数えない）', () => {
    expect(sources([roster(1, ['x'])], [cost(1, 100)]).checkTeams).toBe(1)
    expect(sources([roster(1)], [cost(1, 201)]).checkTeams).toBe(1)
    expect(sources([roster(1, ['x'])], [cost(1, 201)]).checkTeams).toBe(1)
    expect(sources([roster(1, ['x']), roster(2)], [cost(1, 201), cost(2, 300)]).checkTeams).toBe(2)
    // 95% ちょうど・上限ちょうどは超過ではない。189 は通常
    expect(sources([roster(1)], [cost(1, 190), cost(2, 200), cost(3, 189)]).checkTeams).toBe(0)
    expect(sources([], []).checkTeams).toBe(0)
  })

  it('違反の数（violationTeams）は超過を含めない', () => {
    const s = sources([roster(1, ['x'])], [cost(1, 201), cost(2, 250)])
    expect(s.violationTeams).toBe(1)
    expect(s.checkTeams).toBe(2)
    expect(s.costOverTeams).toBe(2)
  })

  it('一覧は規定違反が先、超過だけのチームは後ろ（超過の大きい順）。両方のチームは 1 行で超過分も持つ', () => {
    const rows = buildCheckRows(
      [roster(1), roster(2, ['a']), roster(3, ['b']), roster(4)],
      [cost(1, 205), cost(2, 100), cost(3, 230), cost(4, 260), cost(5, 190)],
    )
    expect(rows.map((r) => r.team_id)).toEqual([2, 3, 4, 1])
    expect(rows.map((r) => r.overBy)).toEqual([null, 30, 60, 5])
    expect(rows.map((r) => r.warnings.length > 0)).toEqual([true, true, false, false])
  })

  it('checkState: 1 件以上は警告。0 件で緑は両方の API が取れた時だけ（片方でも読み込み中・失敗なら中立）', () => {
    expect(checkState(1, false, false)).toBe('warn')
    expect(checkState(2, true, false)).toBe('warn')
    expect(checkState(0, true, true)).toBe('done')
    expect(checkState(0, true, false)).toBe('neutral')
    expect(checkState(0, false, true)).toBe('neutral')
    expect(checkState(0, false, false)).toBe('neutral')
  })
})

describe('summarize（要約タイルの数え方）', () => {
  it('稼働中・休止中のチーム数', () => {
    const s = summarize({
      teams: [team(1), team(2), team(3, { is_active: false })],
      absences: [],
      cooldowns: [],
      costs: [],
      rosterStatus: [],
    })
    expect(s.activeTeams).toBe(2)
    expect(s.totalTeams).toBe(3)
    expect(s.inactiveTeams).toBe(1)
  })

  it('要確認は roster_status の warnings があるチームの数', () => {
    const s = summarize({
      teams: [],
      absences: [],
      cooldowns: [],
      costs: [],
      rosterStatus: [roster(1), roster(2, ['コスト上限を超過しています']), roster(3, ['a', 'b'])],
    })
    expect(s.violationTeams).toBe(2)
  })

  it('離脱は人数・チーム数・2 以内に戻る人数（日数・試合数どちらも）', () => {
    const s = summarize({
      teams: [],
      absences: [absence(1, 2), absence(1, 3), absence(2, 1, 'games'), absence(3, null)],
      cooldowns: [],
      costs: [],
      rosterStatus: [],
    })
    expect(s.absenceCount).toBe(4)
    expect(s.absenceTeams).toBe(3)
    expect(s.absenceSoon).toBe(2)
  })

  it('クールダウンは人数・チーム数・2 日以内に明ける人数', () => {
    const s = summarize({
      teams: [],
      absences: [],
      cooldowns: [cooldown(1, 2), cooldown(1, 3), cooldown(2, 0)],
      costs: [],
      rosterStatus: [],
    })
    expect(s.cooldownCount).toBe(3)
    expect(s.cooldownTeams).toBe(2)
    expect(s.cooldownSoon).toBe(2)
  })

  it('コストの注意は 95% 以上（上限ちょうどを含む）と超過に分けて数える', () => {
    const s = summarize({
      teams: [],
      absences: [],
      cooldowns: [],
      costs: [cost(1, 189), cost(2, 190), cost(3, 200), cost(4, 201)],
      rosterStatus: [],
    })
    expect(s.costNearTeams).toBe(2)
    expect(s.costOverTeams).toBe(1)
    expect(s.costWatchTeams).toBe(3)
  })
})

describe('buildTeamRows（チームの表）', () => {
  const input = () => ({
    teams: [
      team(1, {
        season_current_date: '2026-05-08',
        director: { id: 9, name: '監督1' } as Team['director'],
      }),
      team(2, { season_current_date: '2026-04-01' }),
      team(3, { season_current_date: null }),
      team(4, { is_active: false, season_current_date: '2026-03-25' }),
    ],
    absences: [absence(1, 5), absence(1, 6)],
    cooldowns: [cooldown(2, 4)],
    costs: [cost(1, 190), cost(2, 201), cost(3, 100)],
    rosterStatus: [roster(1), roster(2, ['外の世界枠が上限を超過しています'])],
  })

  it('稼働中のチームだけを行にする（休止中は入れない）', () => {
    expect(buildTeamRows(input()).map((r) => r.id)).toEqual([1, 2, 3])
  })

  it('API の値を team_id で結合する。無いものは null / 0', () => {
    const rows = buildTeamRows(input())
    const r1 = rows.find((r) => r.id === 1)!
    expect(r1.manager).toBe('監督1')
    expect(r1.firstCount).toBe(28)
    expect(r1.secondCount).toBe(7)
    expect(r1.totalCost).toBe(190)
    expect(r1.costLevel).toBe('near')
    expect(r1.absenceCount).toBe(2)
    expect(r1.cooldownCount).toBe(0)
    const r3 = rows.find((r) => r.id === 3)!
    expect(r3.firstCount).toBeNull()
    expect(r3.costLevel).toBe('normal')
    expect(r3.absenceCount).toBe(0)
  })

  it('注意の数 = 要確認・コスト（注意/超過）・離脱・クールダウンのうち出るチップの数', () => {
    const rows = buildTeamRows(input())
    expect(rows.find((r) => r.id === 1)!.attention).toBe(2) // コスト near + 離脱
    expect(rows.find((r) => r.id === 2)!.attention).toBe(3) // 要確認 + コスト over + クールダウン
    expect(rows.find((r) => r.id === 3)!.attention).toBe(0)
  })

  it('進み具合は稼働中チームの最小〜最大の日付の中の位置（0〜1）。日付なしは null で並べ替えでは末尾', () => {
    const rows = buildTeamRows(input())
    expect(rows.find((r) => r.id === 2)!.progressRatio).toBe(0)
    expect(rows.find((r) => r.id === 1)!.progressRatio).toBe(1)
    expect(rows.find((r) => r.id === 3)!.progressRatio).toBeNull()
    const sorted = [...rows].sort((a, b) => a.progressKey.localeCompare(b.progressKey))
    expect(sorted.map((r) => r.id)).toEqual([2, 1, 3])
  })

  it('稼働中が 1 チームだけ（最小 = 最大）でも割り算で落ちない', () => {
    const rows = buildTeamRows({
      teams: [team(1, { season_current_date: '2026-05-08' })],
      absences: [],
      cooldowns: [],
      costs: [],
      rosterStatus: [],
    })
    expect(rows[0]!.progressRatio).toBe(0)
  })
})
