import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import RosterStatusTab from '../RosterStatusTab.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    defaults: {
      baseURL: 'http://localhost:3000/api/v1',
      withCredentials: false,
      headers: { common: {} },
    },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'
import { scrollLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

const mockRosterStatus = [
  {
    team_id: 1,
    team_name: '紅魔館',
    team_type: 'normal',
    first_count: 27,
    second_count: 8,
    first_cost: 178,
    first_cost_limit: 190,
    outside_world_count: 3,
    outside_world_limit: 4,
    warnings: [],
  },
  {
    team_id: 2,
    team_name: '白玉楼',
    team_type: 'hachinai',
    first_count: 25,
    second_count: 10,
    first_cost: 195,
    first_cost_limit: 190,
    outside_world_count: 5,
    outside_world_limit: 4,
    warnings: ['コスト超過', '外枠超過'],
  },
]

// 1軍登録状況の取得は親（ダッシュボード）が持つ（概況と共用）。このタブは records / loading / failed を受けて描く
const mountComponent = (
  props: { records?: typeof mockRosterStatus; loading?: boolean; failed?: boolean } = {},
) =>
  mount(RosterStatusTab, {
    props: { records: mockRosterStatus, loading: false, failed: false, ...props },
    global: {
      plugins: [i18n, vuetify],
    },
  })

describe('RosterStatusTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('roster_status は親が取る。このタブはマウントしても自分では取らない', async () => {
    mountComponent()
    await flushPromises()
    expect(axios.get).not.toHaveBeenCalled()
  })

  it('全チームCSV出力ボタンが表示される', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const btn = wrapper.find('a[href*="roster_status.csv"]')
    expect(btn.exists()).toBe(true)
    expect(btn.attributes('href')).not.toContain('team_id')
  })

  it('全チームCSVのhrefにbaseURLが含まれる', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const btn = wrapper.find('a[href*="roster_status.csv"]')
    expect(btn.attributes('href')).toContain('http://localhost:3000/api/v1')
  })

  // cmd_1804 subtask_1804a: 1軍登録タブの人数・コスト・外枠は、規定内=チェック・規定外=✕の記号だけ（行・チップの色は変えない）
  describe('規定判定の記号', () => {
    const rec = (over: Partial<(typeof mockRosterStatus)[number]>) => ({
      ...mockRosterStatus[0]!,
      ...over,
    })
    // 列: 1 チーム名・2 タイプ・3 1軍・4 2軍・5 コスト・6 外枠・7 状態
    const stateAt = (w: ReturnType<typeof mountComponent>, col: number, row = 0) =>
      w
        .findAll('tbody tr')
        [row]!.findAll('td')
        [col - 1]!.find('[data-testid="limit-mark"]')
        .attributes('data-state')

    it('コスト: 上限ちょうど=ok・上限+1=ng・上限なし=記号なし', async () => {
      const w = mountComponent({
        records: [
          rec({ team_id: 1, first_cost: 114, first_cost_limit: 114 }),
          rec({ team_id: 2, first_cost: 115, first_cost_limit: 114 }),
          rec({ team_id: 3, first_cost: 90, first_cost_limit: null }),
        ],
      })
      await flushPromises()
      expect(stateAt(w, 5, 0)).toBe('ok')
      expect(stateAt(w, 5, 1)).toBe('ng')
      expect(
        w.findAll('tbody tr')[2]!.findAll('td')[4]!.find('[data-testid="limit-mark"]').exists(),
      ).toBe(false)
    })

    it('外枠: 上限ちょうど（4/4）=ok・上限+1（5/4）=ng。上限は API の outside_world_limit', async () => {
      const w = mountComponent({
        records: [
          rec({ team_id: 1, outside_world_count: 4, outside_world_limit: 4 }),
          rec({ team_id: 2, outside_world_count: 5, outside_world_limit: 4 }),
        ],
      })
      await flushPromises()
      expect(stateAt(w, 6, 0)).toBe('ok')
      expect(stateAt(w, 6, 1)).toBe('ng')
      expect(w.findAll('tbody tr')[1]!.findAll('td')[5]!.find('.mdi-close-circle').exists()).toBe(
        true,
      )
      expect(w.findAll('tbody tr')[0]!.findAll('td')[5]!.find('.mdi-check-circle').exists()).toBe(
        true,
      )
    })

    it('人数: 24=ng・25=ok・29=ok・30=ng', async () => {
      const w = mountComponent({
        records: [24, 25, 29, 30].map((n, i) => rec({ team_id: i + 1, first_count: n })),
      })
      await flushPromises()
      expect([0, 1, 2, 3].map((i) => stateAt(w, 3, i))).toEqual(['ng', 'ok', 'ok', 'ng'])
    })

    it('記号を足しても既存の「超過」チップ・「警告あり」チップは変わらない', async () => {
      const w = mountComponent()
      await flushPromises()
      const chips = w.findAllComponents(components.VChip).map((c) => c.text())
      expect(chips.filter((t) => t === '超過')).toHaveLength(2)
      expect(chips.filter((t) => t === '警告あり')).toHaveLength(1)
    })
  })

  it('警告ありチームに警告チップが表示される', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain('警告あり')
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b5-8〜b5-13
  it('展開した一軍・二軍チップと外の世界の印を役割色で示す', async () => {
    vi.mocked(axios.get).mockImplementation((url: string) =>
      Promise.resolve({
        data: url.includes('/teams/')
          ? [
              { player_name: '投手A', squad: 'first', is_outside_world: true },
              { player_name: '野手B', squad: 'second', is_outside_world: false },
            ]
          : mockRosterStatus,
      }),
    )
    const wrapper = mountComponent()
    await flushPromises()
    wrapper.vm.expanded = [2]
    await flushPromises()
    const chips = wrapper.findAllComponents(components.VChip)
    const first = chips.filter((chip) => chip.text() === '1軍')
    const second = chips.filter((chip) => chip.text() === '2軍')
    expect(first).toHaveLength(1)
    expect(second).toHaveLength(1)
    expect(first[0]!.props('color')).toBe('zone-game')
    expect(first[0]!.props('prependIcon')).toBe('mdi-numeric-1-box-outline')
    expect(second[0]!.props('color')).toBe('state-neutral')
    expect(second[0]!.props('prependIcon')).toBe('mdi-numeric-2-box-outline')
    for (const chip of [...first, ...second]) expect(chip.props('variant')).toBe('flat')
    expect(wrapper.find('.on-state-info.mdi-earth').exists()).toBe(true)
  })

  it('取得失敗時（failed）にクラッシュしない', async () => {
    const wrapper = mountComponent({ records: [], failed: true })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
    // 失敗は空状態ではなくページ内のアラート＋再読み込みで出す。再読み込みは親へ通知する
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    expect(wrapper.emitted('retry')).toHaveLength(1)
  })

  it('0 件なら空状態を出し、読み込み中は空状態を出さない', async () => {
    const wrapper = mountComponent({ records: [], loading: true })
    expect(wrapper.find('[data-testid="state-loading"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
    await wrapper.setProps({ loading: false })
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-commissioner-dashboard-visual-design.md §2 案 A+（「OK」を毎行出さず違反の行だけ）。色は Operator 決定 2026-11-02
  it('状態の列: 違反の無い行は「OK」を出さず「—」、違反の行は赤系（state-warn）の「警告あり」', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).not.toContain('OK')
    const rows = wrapper.findAll('tbody tr')
    expect(
      rows
        .find((r) => r.text().includes('紅魔館'))!
        .find('.status-none')
        .text(),
    ).toBe('—')
    const chip = wrapper.findAllComponents(components.VChip).filter((c) => c.text() === '警告あり')
    expect(chip).toHaveLength(1)
    expect(chip[0]!.props('color')).toBe('state-warn')
    expect(chip[0]!.props('variant')).toBe('flat')
    expect(chip[0]!.props('prependIcon')).toBe('mdi-alert-circle')
  })

  it('コスト・外枠が上限を超えた時の「超過」チップも赤系（state-warn）で、上限内の行には出さない', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const over = wrapper.findAllComponents(components.VChip).filter((c) => c.text() === '超過')
    expect(over).toHaveLength(2) // 白玉楼のコストと外枠
    for (const c of over) {
      expect(c.props('color')).toBe('state-warn')
      expect(c.props('variant')).toBe('flat')
    }
    const row1 = wrapper.findAll('tbody tr').find((r) => r.text().includes('紅魔館'))!
    expect(row1.text()).not.toContain('超過')
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（列を落とせる表は <600px で縦積み、列を落とせない表は横スクロールで名前の列を固定）/ §4.2 段 4
describe('RosterStatusTab 表のスマホ対応（段 4）', () => {
  it('1軍登録状況: 横に比べる数値の表なので縦積みにせず、チーム名の列を固定して横スクロール', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(scrollLayout(wrapper, 'first_cost')).toEqual({
      mobileBreakpoint: undefined,
      rows: false,
      fixedKeys: ['team_name'],
      allHaveMinWidth: true,
    })
  })

  it('チームを展開すると、読み込み中はスケルトン、失敗はアラート＋再読み込み、取れたら選手の表（選手名を固定）', async () => {
    vi.mocked(axios.get).mockImplementation((url: string) =>
      url.includes('/teams/')
        ? Promise.reject(new Error('network'))
        : Promise.resolve({ data: mockRosterStatus }),
    )
    const wrapper = mountComponent()
    await flushPromises()
    await wrapper.find('tbody tr').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
      '1軍選手一覧の取得に失敗しました',
    )
    vi.mocked(axios.get).mockImplementation((url: string) =>
      Promise.resolve({
        data: url.includes('/teams/')
          ? [{ number: '1', player_name: '投手A', squad: 'first', is_outside_world: false }]
          : mockRosterStatus,
      }),
    )
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('投手A')
    expect(scrollLayout(wrapper, 'is_outside_world').fixedKeys).toEqual(['player_name'])
  })

  // Test Basis: team_rosters_controller#show は { season_id, ..., roster: [...] } を返す。配列だと思って読むと表が描けず空白になる（実機で確認）
  it('展開した行の選手一覧は、API が返す { roster: [...] } の包みから読む（配列の旧い形も受ける）', async () => {
    const players = [{ number: '1', player_name: '投手A', squad: 'first', is_outside_world: false }]
    for (const body of [{ season_id: 1, roster: players }, players]) {
      vi.mocked(axios.get).mockImplementation((url: string) =>
        Promise.resolve({ data: url.includes('/teams/') ? body : mockRosterStatus }),
      )
      const wrapper = mountComponent()
      await flushPromises()
      await wrapper.find('tbody tr').trigger('click')
      await flushPromises()
      expect(wrapper.text()).toContain('投手A')
      expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    }
  })
})
