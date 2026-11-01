import { describe, it, expect, afterEach } from 'vitest'
import { mount, type VueWrapper } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import DashboardOverview from '../DashboardOverview.vue'
import type {
  AbsenceRecord,
  CooldownRecord,
  CostRecord,
  DashboardResource,
  RosterStatusRecord,
} from '@/types/commissionerDashboard'
import type { Team } from '@/types/team'
import { stackedLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

const ok = <T>(data: T[]): DashboardResource<T> => ({ data, loading: false, failed: false })
const pending = <T>(): DashboardResource<T> => ({ data: [], loading: true, failed: false })
const failed = <T>(): DashboardResource<T> => ({ data: [], loading: false, failed: true })

const team = (id: number, over: Partial<Team> = {}): Team => ({
  id,
  name: `チーム${id}`,
  short_name: `T${id}`,
  is_active: true,
  has_season: true,
  team_type: 'normal',
  season_current_date: '2026-05-08',
  ...over,
})
const cost = (team_id: number, total_cost: number, total_cost_limit = 200): CostRecord => ({
  team_id,
  team_name: `チーム${team_id}`,
  team_type: 'normal',
  total_cost,
  total_cost_limit,
  first_squad_cost: 120,
  first_squad_cost_limit: 120,
  first_squad_count: 28,
  exempt_count: 0,
  cost_usage_ratio: total_cost / total_cost_limit,
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
const absence = (team_id: number, remaining: number, name = '霧雨魔理沙'): AbsenceRecord => ({
  id: team_id * 10 + remaining,
  team_name: `チーム${team_id}`,
  team_id,
  player_name: name,
  player_id: team_id,
  absence_type: 'injury',
  reason: null,
  start_date: '2026-04-01',
  duration: 5,
  duration_unit: 'days',
  effective_end_date: '2026-04-20',
  remaining_days: remaining,
  remaining_games: null,
  season_current_date: '2026-04-10',
})
const cooldown = (team_id: number, remaining_days: number): CooldownRecord => ({
  team_id,
  team_name: `チーム${team_id}`,
  player_id: team_id,
  player_name: '博麗霊夢',
  demotion_date: '2026-04-01',
  cooldown_until: '2026-04-11',
  remaining_days,
  same_day_exempt: false,
})

type Props = {
  teams: DashboardResource<Team>
  absences: DashboardResource<AbsenceRecord>
  cooldowns: DashboardResource<CooldownRecord>
  costs: DashboardResource<CostRecord>
  rosterStatus: DashboardResource<RosterStatusRecord>
}
const baseProps = (over: Partial<Props> = {}): Props => ({
  teams: ok([team(1), team(2), team(3, { is_active: false })]),
  absences: ok([]),
  cooldowns: ok([]),
  costs: ok([]),
  rosterStatus: ok([]),
  ...over,
})

let mounted: VueWrapper[] = []
const mountOverview = (props: Props) => {
  const w = mount(DashboardOverview, {
    props,
    global: { plugins: [vuetify, i18n] },
    attachTo: document.body,
  })
  mounted.push(w)
  return w
}
afterEach(() => {
  mounted.forEach((w) => w.unmount())
  mounted = []
})

const tile = (w: VueWrapper, id: string) => w.find(`[data-testid="tile-${id}"]`)
const rowNames = (w: VueWrapper) =>
  w.findAll('[data-testid="team-table-card"] tbody tr').map((tr) => tr.find('b').text())

// Test Basis: thbig-dugout-commissioner-dashboard-visual-design.md §2 案 A+（要約タイル 5 つ・注意が要るもの・チームの表）/ §5 段 2
describe('DashboardOverview 要約タイル', () => {
  it('5 つのタイルに、稼働中・要確認・離脱・クールダウン・コスト上限の数を出す', () => {
    const w = mountOverview(
      baseProps({
        absences: ok([absence(1, 2), absence(1, 5), absence(2, 4)]),
        cooldowns: ok([cooldown(2, 1)]),
        costs: ok([cost(1, 190), cost(2, 201)]),
        rosterStatus: ok([roster(1), roster(2, ['コスト上限を超過しています'])]),
      }),
    )
    expect(tile(w, 'active').text()).toContain('2')
    expect(tile(w, 'active').text()).toContain('/ 3')
    expect(tile(w, 'violation').text()).toContain('1')
    expect(tile(w, 'absence').text()).toContain('3')
    expect(tile(w, 'absence').text()).toContain('2 チーム')
    expect(tile(w, 'absence').text()).toContain('2日以内に復帰 1 人')
    expect(tile(w, 'cooldown').text()).toContain('1')
    expect(tile(w, 'cooldown').text()).toContain('2日以内に明ける 1 人')
    expect(tile(w, 'cost').text()).toContain('2') // 95% 以上 1 + 超過 1
  })

  it('要確認が 0 件なら緑のチェックと「規定内」、1 件以上なら赤系の警告', () => {
    const zero = mountOverview(baseProps({ rosterStatus: ok([roster(1)]) }))
    expect(tile(zero, 'violation').find('.mdi-check-circle').exists()).toBe(true)
    expect(tile(zero, 'violation').text()).toContain('規定内')
    expect(tile(zero, 'violation').find('.bg-state-done').exists()).toBe(true)
    const one = mountOverview(baseProps({ rosterStatus: ok([roster(1, ['x'])]) }))
    expect(tile(one, 'violation').find('.mdi-alert-circle').exists()).toBe(true)
    expect(tile(one, 'violation').find('.bg-state-warn').exists()).toBe(true)
    expect(tile(one, 'violation').text()).not.toContain('規定内')
  })

  it('タイルを押すと、その明細のタブへ移るよう通知する', async () => {
    const w = mountOverview(baseProps())
    const expected: Record<string, string> = {
      active: 'teams',
      violation: 'rosterStatus',
      absence: 'absences',
      cooldown: 'cooldowns',
      cost: 'costs',
    }
    for (const [id, tab] of Object.entries(expected)) {
      await tile(w, id).find('button.overview-tile__go').trigger('click')
      expect(w.emitted('navigate')!.at(-1)).toEqual([tab])
    }
  })
})

// Test Basis: 設計 §5 段 2「AsyncState で API ごとに別々に読み込み中・失敗を出す（1 本が遅くても他を先に出す）」
describe('DashboardOverview API ごとの読み込み中・失敗', () => {
  it('costs が読み込み中でも、他のタイルとチームの表は先に出る', () => {
    const w = mountOverview(
      baseProps({
        costs: pending(),
        absences: ok([absence(1, 2)]),
        rosterStatus: ok([roster(1)]),
      }),
    )
    expect(tile(w, 'cost').find('[data-testid="state-loading"]').exists()).toBe(true)
    expect(tile(w, 'cost').find('[data-testid="state-error"]').exists()).toBe(false)
    expect(tile(w, 'absence').find('[data-testid="state-loading"]').exists()).toBe(false)
    expect(tile(w, 'absence').text()).toContain('1')
    expect(tile(w, 'active').find('[data-testid="state-loading"]').exists()).toBe(false)
    expect(rowNames(w)).toEqual(['チーム1', 'チーム2'])
  })

  it('costs が失敗しても、他のタイルは巻き込まず、再読み込みはその API だけを指す', async () => {
    const w = mountOverview(baseProps({ costs: failed(), absences: ok([absence(1, 2)]) }))
    expect(tile(w, 'cost').find('[data-testid="state-error"]').exists()).toBe(true)
    for (const id of ['active', 'violation', 'absence', 'cooldown']) {
      expect(tile(w, id).find('[data-testid="state-error"]').exists()).toBe(false)
    }
    // 「上限に近い」の段にも同じ失敗が出て、空（なし）とは出さない
    const near = w.find('[data-testid="attention-cost"]')
    expect(near.find('[data-testid="state-error"]').exists()).toBe(true)
    expect(near.text()).not.toContain('なし')
    await tile(w, 'cost').find('[data-testid="state-retry"]').trigger('click')
    expect(w.emitted('retry')!.at(-1)).toEqual(['costs'])
    // 表は出る（合計コストの列は「—」）
    expect(rowNames(w)).toEqual(['チーム1', 'チーム2'])
  })

  it('チームの取得が失敗したら表の場所にアラートを出し、空状態にはしない', async () => {
    const w = mountOverview(baseProps({ teams: failed() }))
    const card = w.find('[data-testid="team-table-section"]')
    expect(card.find('[data-testid="state-error"]').exists()).toBe(true)
    expect(card.find('[data-testid="state-empty"]').exists()).toBe(false)
    await card.find('[data-testid="state-retry"]').trigger('click')
    expect(w.emitted('retry')!.at(-1)).toEqual(['teams'])
  })

  it('読み込み中のチーム表はスケルトン。読み込みが終わって稼働中が 0 なら空状態', () => {
    const loading = mountOverview(baseProps({ teams: pending() }))
    const sec = loading.find('[data-testid="team-table-section"]')
    expect(sec.find('[data-testid="state-loading"]').exists()).toBe(true)
    expect(sec.find('[data-testid="state-empty"]').exists()).toBe(false)
    const empty = mountOverview(baseProps({ teams: ok([team(3, { is_active: false })]) }))
    expect(
      empty.find('[data-testid="team-table-section"] [data-testid="state-empty"]').exists(),
    ).toBe(true)
  })
})

// Test Basis: Operator 決定 2026-11-02「要確認に合計コスト超過のチームも数える。重要度は規定違反より低く、一覧は後ろ・控えめ」
describe('DashboardOverview 要確認（規定違反 または 合計コスト超過）', () => {
  const warnTone = (w: VueWrapper) =>
    ['bg-state-warn', 'bg-state-done', 'bg-state-neutral'].filter((c) =>
      tile(w, 'violation').find(`.${c}`).exists(),
    )

  it('タイルは違反のみ・超過のみ・両方（1 回）・95% 以上で超過なし（数えない）を数える', () => {
    const count = (roster_: RosterStatusRecord[], costs: CostRecord[]) => {
      const w = mountOverview(baseProps({ rosterStatus: ok(roster_), costs: ok(costs) }))
      return tile(w, 'violation').find('.overview-tile__value').text().replace(/\s/g, '')
    }
    expect(count([roster(1, ['x'])], [cost(1, 100)])).toBe('1チーム')
    expect(count([roster(1)], [cost(1, 201)])).toBe('1チーム')
    expect(count([roster(1, ['x'])], [cost(1, 201)])).toBe('1チーム')
    expect(count([roster(1, ['x']), roster(2)], [cost(1, 201), cost(2, 220)])).toBe('2チーム')
    expect(count([roster(1)], [cost(1, 190), cost(2, 200)])).toBe('0チーム')
  })

  it('超過だけでもタイルは警告色。内訳（規定違反・合計コスト超過）を補足に出す', () => {
    const w = mountOverview(
      baseProps({ rosterStatus: ok([roster(1, ['x']), roster(2)]), costs: ok([cost(2, 201)]) }),
    )
    expect(warnTone(w)).toEqual(['bg-state-warn'])
    expect(tile(w, 'violation').text()).toContain('規定違反 1 ・ 合計コスト超過 1')
  })

  it('一覧は規定違反のチームが先、超過だけのチームは後ろで控えめ（中立のチップ・太字にしない）', () => {
    const w = mountOverview(
      baseProps({
        rosterStatus: ok([roster(1), roster(2, ['外の世界枠が上限を超過しています']), roster(3)]),
        costs: ok([cost(1, 230), cost(2, 205), cost(3, 190)]),
      }),
    )
    const g = w.find('[data-testid="attention-violation"]')
    const rows = g.findAll('.attention-row')
    expect(rows.map((r) => r.find('.attention-row__name').text())).toEqual(['チーム2', 'チーム1'])
    expect(rows.map((r) => r.attributes('data-testid'))).toEqual([
      'check-row-violation',
      'check-row-cost',
    ])
    expect(rows[0]!.classes()).not.toContain('attention-row--minor')
    expect(rows[1]!.classes()).toContain('attention-row--minor')
    // 規定違反かつ超過のチームは 1 行。超過は中立のチップで添える（赤にしない）
    expect(rows[0]!.text()).toContain('外の世界枠が上限を超過しています')
    expect(rows[0]!.text()).toContain('合計コスト超過 5')
    expect(rows[1]!.text()).toContain('合計コスト超過 30')
    const chips = w.findAllComponents(components.VChip)
    const over30 = chips.find((c) => c.text() === '合計コスト超過 30')!
    expect(over30.props('color')).toBe('state-neutral')
    expect(g.text()).not.toContain('チーム3')
    expect(g.find('[data-testid="check-cost-pending"]').exists()).toBe(false)
  })

  it('コストが読み込み中: 違反 0 件なら緑にせず中立色で「確認中」。違反があれば警告色のまま', () => {
    const zero = mountOverview(baseProps({ rosterStatus: ok([roster(1)]), costs: pending() }))
    expect(warnTone(zero)).toEqual(['bg-state-neutral'])
    expect(tile(zero, 'violation').find('.bg-state-done').exists()).toBe(false)
    expect(tile(zero, 'violation').text()).toContain('コストを確認中')
    expect(tile(zero, 'violation').text()).not.toContain('規定内')
    const g = zero.find('[data-testid="attention-violation"]')
    expect(g.find('.mdi-check-circle').exists()).toBe(false)
    expect(g.find('[data-testid="check-cost-pending"]').text()).toContain('確認中')
    const warn = mountOverview(
      baseProps({ rosterStatus: ok([roster(1, ['x'])]), costs: pending() }),
    )
    expect(warnTone(warn)).toEqual(['bg-state-warn'])
  })

  it('コストが失敗: 違反 0 件でも緑にせず中立色。失敗の旨を出す', () => {
    const w = mountOverview(baseProps({ rosterStatus: ok([roster(1)]), costs: failed() }))
    expect(warnTone(w)).toEqual(['bg-state-neutral'])
    expect(tile(w, 'violation').text()).toContain('コストを取得できません')
    const g = w.find('[data-testid="attention-violation"]')
    expect(g.find('.mdi-check-circle').exists()).toBe(false)
    expect(g.find('[data-testid="check-cost-pending"]').text()).toContain('取得に失敗')
    // グループの見出しチップも緑にしない
    const head = w.findAllComponents(components.VChip).find((c) => c.text().startsWith('要確認'))!
    expect(head.props('color')).toBe('state-neutral')
  })

  it('1軍登録状況（roster_status）が読み込み中・失敗の間は、要確認の数を出さない', () => {
    const loading = mountOverview(baseProps({ rosterStatus: pending(), costs: ok([cost(1, 250)]) }))
    expect(tile(loading, 'violation').find('.overview-tile__value').exists()).toBe(false)
    const bad = mountOverview(baseProps({ rosterStatus: failed(), costs: ok([cost(1, 250)]) }))
    expect(tile(bad, 'violation').find('.overview-tile__value').exists()).toBe(false)
  })
})

describe('DashboardOverview 注意が要るもの', () => {
  it('要確認が 0 件のときも「規定違反はありません」の 1 行を出す（見落としでないことを示す）', () => {
    const w = mountOverview(baseProps({ rosterStatus: ok([roster(1)]) }))
    const g = w.find('[data-testid="attention-violation"]')
    expect(g.find('.mdi-check-circle').exists()).toBe(true)
    expect(g.text()).toContain('規定違反はありません')
  })

  it('要確認は、違反のあるチームとその内容（赤系のチップ）を並べる', () => {
    const w = mountOverview(
      baseProps({ rosterStatus: ok([roster(1), roster(2, ['外の世界枠が上限を超過しています'])]) }),
    )
    const g = w.find('[data-testid="attention-violation"]')
    expect(g.text()).toContain('チーム2')
    expect(g.text()).toContain('外の世界枠が上限を超過しています')
    expect(g.text()).not.toContain('チーム1')
    const chip = w
      .findAllComponents(components.VChip)
      .find((c) => c.text() === '外の世界枠が上限を超過しています')!
    expect(chip.props('color')).toBe('state-warn')
    expect(chip.props('variant')).toBe('flat')
  })

  it('上限に近いチームは、残りコストつきで合計コストの多い順に並べる（95% 未満は出さない）', () => {
    const w = mountOverview(
      baseProps({
        costs: ok([cost(1, 189), cost(2, 190), cost(3, 199), cost(4, 201)]),
        teams: ok([team(1), team(2), team(3), team(4)]),
      }),
    )
    const g = w.find('[data-testid="attention-cost"]')
    const text = g.text()
    expect(text).toContain('チーム4')
    expect(text).toContain('チーム3')
    expect(text).toContain('チーム2')
    expect(text).not.toContain('チーム1')
    expect(text.indexOf('チーム4')).toBeLessThan(text.indexOf('チーム3'))
    expect(text.indexOf('チーム3')).toBeLessThan(text.indexOf('チーム2'))
    expect(text).toContain('残り 1')
    expect(text).toContain('超過 1')
  })

  it('まもなく動く: 2 日以内に復帰する人を並べ、3 日以上は出さない。クールダウンは人数で出す', () => {
    const w = mountOverview(
      baseProps({
        absences: ok([absence(1, 2, '霧雨魔理沙'), absence(2, 3, '博麗霊夢')]),
        cooldowns: ok([cooldown(1, 1), cooldown(2, 5)]),
      }),
    )
    const a = w.find('[data-testid="attention-soon-absence"]')
    expect(a.text()).toContain('霧雨魔理沙')
    expect(a.text()).toContain('あと 2日')
    expect(a.text()).not.toContain('博麗霊夢')
    const c = w.find('[data-testid="attention-soon-cooldown"]')
    expect(c.text()).toContain('1 人')
  })
})

describe('DashboardOverview チームの表', () => {
  it('稼働中のチームだけを、既定は進みが遅い順に並べる。休止中は末尾に件数だけ出す', () => {
    const w = mountOverview(
      baseProps({
        teams: ok([
          team(1, { season_current_date: '2026-06-01' }),
          team(2, { season_current_date: '2026-04-01' }),
          team(3, { is_active: false, season_current_date: '2026-03-25' }),
          team(4, { is_active: false }),
        ]),
      }),
    )
    expect(rowNames(w)).toEqual(['チーム2', 'チーム1'])
    expect(w.find('[data-testid="inactive-note"]').text()).toContain('休止中のチーム 2 件')
  })

  it('合計コストの注意は 94.9% / 95% / 100% / 100.1% の境界で、チップなし・上限に近い・上限に近い・超過', () => {
    const w = mountOverview(
      baseProps({
        teams: ok([1, 2, 3, 4].map((id) => team(id))),
        costs: ok([
          cost(1, 949, 1000),
          cost(2, 950, 1000),
          cost(3, 1000, 1000),
          cost(4, 1001, 1000),
        ]),
      }),
    )
    const chipsOf = (name: string) => {
      const tr = w
        .findAll('[data-testid="team-table-card"] tbody tr')
        .find((r) => r.find('b').text() === name)!
      return tr
        .findAllComponents(components.VChip)
        .map((c) => ({ text: c.text(), color: c.props('color') }))
        .filter((c) => c.text === '上限に近い' || c.text === '超過')
    }
    expect(chipsOf('チーム1')).toEqual([])
    expect(chipsOf('チーム2')).toEqual([{ text: '上限に近い', color: 'state-todo' }])
    expect(chipsOf('チーム3')).toEqual([{ text: '上限に近い', color: 'state-todo' }])
    expect(chipsOf('チーム4')).toEqual([{ text: '超過', color: 'state-warn' }])
  })

  it('チームごとの離脱・クールダウンを件数のチップで出す。注意が無い行は「—」', () => {
    const w = mountOverview(
      baseProps({
        teams: ok([team(1), team(2)]),
        absences: ok([absence(1, 5), absence(1, 6)]),
        cooldowns: ok([cooldown(1, 5)]),
      }),
    )
    const rows = w.findAll('[data-testid="team-table-card"] tbody tr')
    const t1 = rows.find((r) => r.find('b').text() === 'チーム1')!
    expect(t1.text()).toContain('離脱 2')
    expect(t1.text()).toContain('クールダウン 1')
    const t2 = rows.find((r) => r.find('b').text() === 'チーム2')!
    expect(t2.text()).not.toContain('離脱')
    expect(t2.find('.attention-none').text()).toBe('—')
  })

  it('1軍コストは上限ぴったりでも色を付けない（棒もチップも出さない）', () => {
    const w = mountOverview(
      baseProps({ teams: ok([team(1)]), rosterStatus: ok([roster(1)]), costs: ok([cost(1, 100)]) }),
    )
    const tr = w.find('[data-testid="team-table-card"] tbody tr')
    expect(tr.text()).toContain('120 / 120')
    const cell = tr.find('td.first-cost-cell')
    expect(cell.findComponent(components.VProgressLinear).exists()).toBe(false)
    expect(cell.findComponent(components.VChip).exists()).toBe(false)
  })

  // cmd_1804 subtask_1804a: Operator 決定 2026-11-02「ダッシュボードはマークのみ」。棒・チップは変えず記号だけ付ける
  it('1軍コストの記号: 上限ちょうど=緑のチェック、上限+1=赤の✕。棒・チップは出さない', () => {
    const w = mountOverview(
      baseProps({
        teams: ok([team(1), team(2)]),
        rosterStatus: ok([
          { ...roster(1), first_cost: 120, first_cost_limit: 120 },
          { ...roster(2), first_cost: 121, first_cost_limit: 120 },
        ]),
      }),
    )
    const cellOf = (name: string) =>
      w
        .findAll('[data-testid="team-table-card"] tbody tr')
        .find((r) => r.find('b').text() === name)!
        .find('td.first-cost-cell')
    const ok1 = cellOf('チーム1').find('[data-testid="limit-mark"]')
    expect(ok1.attributes('data-state')).toBe('ok')
    expect(ok1.classes()).toContain('mdi-check-circle')
    expect(ok1.classes()).toContain('text-meter-ok')
    const ng = cellOf('チーム2').find('[data-testid="limit-mark"]')
    expect(ng.attributes('data-state')).toBe('ng')
    expect(ng.classes()).toContain('mdi-close-circle')
    expect(ng.classes()).toContain('text-meter-ng')
    for (const n of ['チーム1', 'チーム2']) {
      expect(cellOf(n).findComponent(components.VProgressLinear).exists()).toBe(false)
      expect(cellOf(n).findComponent(components.VChip).exists()).toBe(false)
    }
  })

  it('1軍コストの上限が無い（25 人未満）時は記号を出さない', () => {
    const w = mountOverview(
      baseProps({
        teams: ok([team(1)]),
        rosterStatus: ok([{ ...roster(1), first_cost: 90, first_cost_limit: null }]),
      }),
    )
    expect(w.find('td.first-cost-cell [data-testid="limit-mark"]').exists()).toBe(false)
    expect(w.find('td.first-cost-cell').text()).toContain('90 / —')
  })

  it('合計コストの棒は、通常=link・上限に近い=meter-near・超過=meter-over', () => {
    const w = mountOverview(
      baseProps({
        teams: ok([1, 2, 3].map((id) => team(id))),
        costs: ok([cost(1, 100), cost(2, 190), cost(3, 201)]),
      }),
    )
    const colorOf = (name: string) => {
      const tr = w
        .findAll('[data-testid="team-table-card"] tbody tr')
        .find((r) => r.find('b').text() === name)!
      return tr.find('td.total-cost-cell').findComponent(components.VProgressLinear).props('color')
    }
    expect(colorOf('チーム1')).toBe('link')
    expect(colorOf('チーム2')).toBe('meter-near')
    expect(colorOf('チーム3')).toBe('meter-over')
  })

  it('行の操作は、そのチームのシーズンへ移る名前つきボタン', async () => {
    const w = mountOverview(baseProps({ teams: ok([team(7, { name: '紅魔館' })]) }))
    const btn = w.find('button[aria-label="紅魔館のシーズン"]')
    expect(btn.exists()).toBe(true)
    await btn.trigger('click')
    expect(w.emitted('open-season')![0]).toEqual([{ id: 7, name: '紅魔館' }])
  })

  it('他の API が読み込み中の列はスケルトン、失敗した列は「—」（行は出る）', () => {
    const loading = mountOverview(
      baseProps({ teams: ok([team(1)]), costs: pending(), rosterStatus: pending() }),
    )
    const tr = loading.find('[data-testid="team-table-card"] tbody tr')
    expect(tr.find('td.total-cost-cell [data-testid="cell-loading"]').exists()).toBe(true)
    expect(tr.find('td.first-cost-cell [data-testid="cell-loading"]').exists()).toBe(true)
    const bad = mountOverview(baseProps({ teams: ok([team(1)]), costs: failed() }))
    const tr2 = bad.find('[data-testid="team-table-card"] tbody tr')
    expect(tr2.find('td.total-cost-cell').text()).toBe('—')
  })

  it('スマホ幅では縦積みの行（名前=title・1軍=sub1・合計コスト=sub2・進み具合=note・注意=note2・操作=act）', () => {
    const w = mountOverview(baseProps({ teams: ok([team(1)]) }))
    expect(stackedLayout(w, 'progressKey')).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: {
        name: 'title',
        firstCount: 'sub1',
        totalCost: 'sub2',
        progressKey: 'note',
        attention: 'note2',
        actions: 'act',
      },
    })
  })

  it('画面に操作の説明文を足していない（Operator 決定）', () => {
    const w = mountOverview(baseProps({ teams: ok([team(1)]), rosterStatus: ok([roster(1)]) }))
    expect(w.text()).not.toMatch(/クリック|タップ|押すと|切り替え/)
  })
})

describe('DashboardOverview 進み具合の欄（試合数は今回出さない）', () => {
  it('日付の位置（その月日）だけを出し、試合数（消化/総数）は出さない', () => {
    const w = mountOverview(
      baseProps({ teams: ok([team(1, { season_current_date: '2026-05-08' })]) }),
    )
    const cell = w.find('[data-testid="team-table-card"] tbody tr td.progress-cell')
    expect(cell.text()).toContain('5月8日')
    expect(cell.text()).not.toMatch(/\d+\s*\/\s*\d+/)
  })
})
