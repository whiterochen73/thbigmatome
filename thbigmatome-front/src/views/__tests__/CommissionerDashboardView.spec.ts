import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { defineComponent, h } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createPinia } from 'pinia'
import { createI18n } from 'vue-i18n'
import CommissionerDashboardView from '../commissioner/CommissionerDashboardView.vue'
import CommissionerDashboard from '@/components/commissioner/CommissionerDashboard.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'

vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    delete: vi.fn(),
    defaults: {
      baseURL: '',
      withCredentials: false,
      headers: { common: {} },
    },
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

const { mockPush } = vi.hoisted(() => ({ mockPush: vi.fn() }))
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush }),
  useRoute: () => ({ params: {}, query: {} }),
}))

import axios from 'axios'
import {
  chooseRowMenuItem,
  stackedLayout,
  scrollLayout,
} from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })

// 先頭のタブは「概況」。明細のタブは activeTab を切り替えて開く
const showTab = async (wrapper: ReturnType<typeof mount>, tab: string) => {
  const vm = wrapper.findComponent(CommissionerDashboard).vm as unknown as { activeTab: string }
  vm.activeTab = tab
  await flushPromises()
}
const pinia = createPinia()
const i18n = createI18n({ legacy: false, locale: 'ja', messages: {} })

const mockAbsences = [
  {
    id: 1,
    team_name: 'チームA',
    team_id: 1,
    player_name: '霧雨魔理沙',
    player_id: 10,
    absence_type: 'injury',
    reason: '右肩負傷',
    start_date: '2026-04-15',
    duration: 5,
    duration_unit: 'days',
    effective_end_date: '2026-04-20',
    remaining_days: 3,
    remaining_games: null,
    season_current_date: '2026-04-17',
  },
  {
    id: 2,
    team_name: 'チームB',
    team_id: 2,
    player_name: '博麗霊夢',
    player_id: 11,
    absence_type: 'suspension',
    reason: null,
    start_date: '2026-04-10',
    duration: 3,
    duration_unit: 'games',
    effective_end_date: '2026-04-22',
    remaining_days: null,
    remaining_games: 2,
    season_current_date: '2026-04-17',
  },
]

const mockCooldowns = [
  {
    team_id: 1,
    team_name: 'チームA',
    player_id: 20,
    player_name: '博麗霊夢',
    demotion_date: '2026-04-10',
    cooldown_until: '2026-04-20',
    remaining_days: 3,
    same_day_exempt: false,
  },
]

const mockCosts = [
  {
    team_id: 1,
    team_name: 'チームA',
    team_type: 'normal',
    total_cost: 185,
    total_cost_limit: 200,
    first_squad_cost: 150,
    first_squad_cost_limit: 170,
    first_squad_count: 25,
    exempt_count: 1,
    cost_usage_ratio: 0.925,
  },
  {
    team_id: 2,
    team_name: 'チームB',
    team_type: 'hachinai',
    total_cost: 210,
    total_cost_limit: 200,
    first_squad_cost: 160,
    first_squad_cost_limit: 170,
    first_squad_count: 27,
    exempt_count: 0,
    cost_usage_ratio: 1.05,
  },
]

const mockRosterStatus = (team_id: number, team_name: string, warnings: string[]) => ({
  team_id,
  team_name,
  team_type: 'normal',
  first_count: 28,
  second_count: 7,
  first_cost: 120,
  first_cost_limit: 120,
  outside_world_count: 3,
  outside_world_limit: 4,
  warnings,
})

describe('CommissionerDashboardView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面タイトルはヘッダーバー。本文は骨格＋タブ）
  it('画面タイトルを本文に持たず、骨格（PageLayout）の中にタブを描く', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('ダッシュボード')
    expect(wrapper.text()).toContain('概況')
    expect(wrapper.text()).toContain('チーム管理')
  })

  it('fetches absences on mount', async () => {
    mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/absences')
  })

  it('fetches costs on mount', async () => {
    mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/costs')
  })

  it('displays absence records', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url.includes('absences')) return Promise.resolve({ data: mockAbsences })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    const dashboardVm = wrapper.findComponent(CommissionerDashboard).vm as unknown as {
      activeTab: string
    }
    dashboardVm.activeTab = 'absences'
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('霧雨魔理沙')
    expect(wrapper.text()).toContain('博麗霊夢')
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b5-3〜b5-7
  it('復帰間近と同日免除のチップを役割色で示す', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      Promise.resolve({
        data: url.includes('absences')
          ? mockAbsences
          : url.includes('cooldowns')
            ? [
                ...mockCooldowns,
                { ...mockCooldowns[0], player_id: 21, remaining_days: 2, same_day_exempt: true },
              ]
            : [],
      }),
    )
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    const dashboardVm = wrapper.findComponent(CommissionerDashboard).vm as unknown as {
      activeTab: string
    }
    dashboardVm.activeTab = 'absences'
    await wrapper.vm.$nextTick()
    const imminent = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text() === '2試合')
    expect(imminent).toHaveLength(1)
    expect(imminent[0]!.props('color')).toBe('state-done')
    expect(imminent[0]!.props('variant')).toBe('flat')
    expect(imminent[0]!.props('prependIcon')).toBe('mdi-clock-check-outline')
    dashboardVm.activeTab = 'cooldowns'
    await wrapper.vm.$nextTick()
    const cooldown = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text() === '2日')
    expect(cooldown).toHaveLength(1)
    expect(cooldown[0]!.props('color')).toBe('state-done')
    expect(cooldown[0]!.props('variant')).toBe('flat')
    expect(cooldown[0]!.props('prependIcon')).toBe('mdi-clock-check-outline')
    const exempt = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text() === '同日免除')
    expect(exempt).toHaveLength(1)
    expect(exempt[0]!.props('color')).toBe('state-neutral')
    expect(exempt[0]!.props('variant')).toBe('flat')
  })

  // Test Basis: thbig-dugout-visual-refresh-design.md §6.1, §6.5, §7 段3
  it('コミッショナー離脱一覧も負傷と出場停止を同色・別アイコンで示す', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      Promise.resolve({ data: url.includes('absences') ? mockAbsences : [] }),
    )
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    await showTab(wrapper, 'absences')
    // 概況にも離脱のチップが出るので、いま開いているタブの中で数える
    const chips = wrapper.findAll('.v-window-item--active .v-chip.bg-absence-out')
    expect(chips).toHaveLength(2)
    expect(chips.some((chip) => chip.find('.mdi-hospital-box').exists())).toBe(true)
    expect(chips.some((chip) => chip.find('.mdi-gavel').exists())).toBe(true)
  })

  it('displays absence list header', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('離脱者')
  })

  it('fetches cooldowns on mount', async () => {
    mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/cooldowns')
  })

  it('displays cost tab', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('コスト')
  })

  it('displays cooldown tab', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('クールダウン')
  })

  it('displays cooldown records when cooldown tab is active', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url.includes('cooldowns')) return Promise.resolve({ data: mockCooldowns })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    const dashboardVm = wrapper.findComponent(CommissionerDashboard).vm as unknown as {
      activeTab: string
    }
    dashboardVm.activeTab = 'cooldowns'
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('博麗霊夢')
  })

  it('displays cost records when cost tab is active', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url.includes('costs')) return Promise.resolve({ data: mockCosts })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    // コストタブに切り替え
    const dashboardVm = wrapper.findComponent(CommissionerDashboard).vm as unknown as {
      activeTab: string
    }
    dashboardVm.activeTab = 'costs'
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('185 / 200')
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.7（取得の失敗は空状態にせず、ページ内のアラート＋再読み込み）
  it('離脱者の取得に失敗したら、離脱者タブにアラートと再読み込みを出す（他のタブは巻き込まない）', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      url.includes('absences')
        ? Promise.reject(new Error('network'))
        : Promise.resolve({ data: [] }),
    )
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    const dashboardVm = wrapper.findComponent(CommissionerDashboard).vm as unknown as {
      activeTab: string
    }
    dashboardVm.activeTab = 'absences'
    await wrapper.vm.$nextTick()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(true)

    // 再読み込みで取り直す
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      Promise.resolve({ data: url.includes('absences') ? mockAbsences : [] }),
    )
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('霧雨魔理沙')
  })

  it('チームが 0 件なら空状態を出し、行の操作は名前つきのボタンになる', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    await showTab(wrapper, 'teams')
    expect(wrapper.find('.v-window-item--active [data-testid="state-empty"]').exists()).toBe(true)
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      Promise.resolve({
        data: url === '/teams' ? [{ id: 1, name: 'チームA', is_active: true }] : [],
      }),
    )
    const w2 = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    await showTab(w2, 'teams')
    const labels = w2.findAll('button[aria-label]').map((b) => b.attributes('aria-label'))
    expect(labels).toEqual(
      expect.arrayContaining([
        'チームAのシーズンポータル',
        'チームAのメンバー編集',
        'チームAのチーム編集',
        'チームAを削除',
      ]),
    )
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（列を落とせる表は <600px で縦積み、列を落とせない表は横スクロールで名前の列を固定）/ §4.2 段 4
describe('CommissionerDashboard 表のスマホ対応（段 4）', () => {
  const mountDashboard = async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url === '/teams')
        return Promise.resolve({
          data: [
            {
              id: 1,
              name: 'チームA',
              short_name: 'A',
              is_active: true,
              has_season: true,
              team_type: 'normal',
              director: { id: 1, name: '監督A' },
              season_current_date: '2026-04-17',
              last_game_real_date: null,
            },
          ],
        })
      if (url.includes('absences')) return Promise.resolve({ data: mockAbsences })
      if (url.includes('cooldowns')) return Promise.resolve({ data: mockCooldowns })
      if (url.includes('costs')) return Promise.resolve({ data: mockCosts })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, {
      attachTo: document.body,
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    const vm = wrapper.findComponent(CommissionerDashboard).vm as unknown as { activeTab: string }
    return {
      wrapper,
      show: async (tab: string) => {
        vm.activeTab = tab
        await flushPromises()
      },
    }
  }

  it('全チーム: 縦積み（ID=lead・チーム名=title・監督=sub1・種別=sub2・ゲーム内日付=note・操作=act）', async () => {
    const { wrapper, show } = await mountDashboard()
    await show('teams')
    expect(stackedLayout(wrapper, 'manager_name')).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: {
        id: 'lead',
        name: 'title',
        manager_name: 'sub1',
        team_type: 'sub2',
        season_current_date: 'note',
        actions: 'act',
      },
    })
    wrapper.unmount()
  })

  it('全チームの操作は 4 つ。PC はアイコン 4 つ、スマホは同じ 4 操作の操作メニュー', async () => {
    const { wrapper, show } = await mountDashboard()
    await show('teams')
    const full = wrapper.find('.row-actions.row-actions--full')
    expect(full.findAll('button')).toHaveLength(4)
    const menu = wrapper.find('.row-menu [data-testid="row-menu"]')
    expect(menu.attributes('aria-label')).toBe('チームAの操作')
    await menu.trigger('click')
    await flushPromises()
    const items = [...document.body.querySelectorAll('.v-list-item')].map((i) =>
      i.textContent?.trim(),
    )
    expect(items).toEqual(['シーズンポータル', 'メンバー編集', 'チーム編集', '削除'])
    wrapper.unmount()
  })

  it('離脱者: 縦積み（選手名=title・チーム=sub1・離脱種別=sub2・残り=note）', async () => {
    const { wrapper, show } = await mountDashboard()
    await show('absences')
    expect(stackedLayout(wrapper, 'absence_type')).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: { player_name: 'title', team_name: 'sub1', absence_type: 'sub2', remaining: 'note' },
    })
    wrapper.unmount()
  })

  it('クールダウン: 縦積み（選手名=title・チーム=sub1・残り日数=sub2・CD終了日=note）', async () => {
    const { wrapper, show } = await mountDashboard()
    await show('cooldowns')
    expect(stackedLayout(wrapper, 'remaining_days')).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: {
        player_name: 'title',
        team_name: 'sub1',
        remaining_days: 'sub2',
        cooldown_until: 'note',
      },
    })
    wrapper.unmount()
  })

  it('コスト状況: 横に比べる数値の表なので縦積みにせず、チームの列を固定して横スクロール', async () => {
    const { wrapper, show } = await mountDashboard()
    await show('costs')
    expect(scrollLayout(wrapper, 'first_squad_count')).toEqual({
      mobileBreakpoint: undefined,
      rows: false,
      fixedKeys: ['team_name'],
      allHaveMinWidth: true,
    })
    wrapper.unmount()
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.7（失敗はページ内のアラート＋「再読み込み」）/ subtask_1791o 申し送り（@retry の結線が 4 タブとも固定されていない）
describe('CommissionerDashboard 再読み込みの結線（タブごと）', () => {
  const teamA = [
    {
      id: 1,
      name: 'チームA',
      short_name: 'A',
      is_active: true,
      has_season: true,
      team_type: 'normal',
      director: { id: 1, name: '監督A' },
    },
  ]
  const cases = [
    { tab: 'teams', url: '/teams', data: teamA, text: 'チームA' },
    {
      tab: 'absences',
      url: '/commissioner/dashboard/absences',
      data: mockAbsences,
      text: '霧雨魔理沙',
    },
    { tab: 'costs', url: '/commissioner/dashboard/costs', data: mockCosts, text: '185 / 200' },
    {
      tab: 'cooldowns',
      url: '/commissioner/dashboard/cooldowns',
      data: mockCooldowns,
      text: '博麗霊夢',
    },
    {
      tab: 'rosterStatus',
      url: '/commissioner/dashboard/roster_status',
      data: [mockRosterStatus(1, 'チームA', [])],
      text: 'チームA',
    },
  ]

  it.each(cases)(
    '$tab タブ: 失敗でアラート → 再読み込みでそのタブの API だけを取り直して表を出す',
    async ({ tab, url, data, text }) => {
      let failing = true
      ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((u: string) => {
        if (u === url)
          return failing ? Promise.reject(new Error('network')) : Promise.resolve({ data })
        return Promise.resolve({ data: [] })
      })
      const wrapper = mount(CommissionerDashboardView, {
        global: {
          plugins: [vuetify, pinia, i18n],
          stubs: { TeamDialog: true, ConfirmDialog: true },
        },
      })
      await flushPromises()
      const vm = wrapper.findComponent(CommissionerDashboard).vm as unknown as { activeTab: string }
      vm.activeTab = tab
      await flushPromises()
      // 見ているタブの中だけで判定する（ほかのタブは別の取得で、空状態を出していてよい）
      const active = () => wrapper.find('.v-window-item--active')
      expect(active().find('[data-testid="state-error"]').exists()).toBe(true)
      expect(active().find('[data-testid="state-empty"]').exists()).toBe(false)

      failing = false
      const calls = (axios.get as ReturnType<typeof vi.fn>).mock.calls.filter((c) => c[0] === url)
      await active().find('[data-testid="state-retry"]').trigger('click')
      await flushPromises()
      const after = (axios.get as ReturnType<typeof vi.fn>).mock.calls.filter((c) => c[0] === url)
      expect(after).toHaveLength(calls.length + 1)
      expect(active().find('[data-testid="state-error"]').exists()).toBe(false)
      expect(active().text()).toContain(text)
    },
  )
})

// Test Basis: 操作メニューの各項目は、PC のアイコンボタンと同じ操作を呼ぶ（項目の取り違えを固定する。subtask_1791u の warning）
describe('CommissionerDashboard 全チームの操作メニューの各項目', () => {
  const confirmOpen = vi.fn().mockResolvedValue(true)
  const ConfirmStub = defineComponent({
    setup(_, { expose }) {
      expose({ open: confirmOpen })
      return () => h('div')
    },
  })

  const mountTeams = async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      Promise.resolve({
        data:
          url === '/teams'
            ? [
                {
                  id: 3,
                  name: 'チームA',
                  short_name: 'A',
                  is_active: true,
                  has_season: true,
                  team_type: 'normal',
                  director: { id: 1, name: '監督A' },
                },
              ]
            : [],
      }),
    )
    ;(axios.delete as ReturnType<typeof vi.fn>).mockResolvedValue({ data: {} })
    const wrapper = mount(CommissionerDashboardView, {
      attachTo: document.body,
      global: {
        plugins: [vuetify, pinia, i18n],
        stubs: { TeamDialog: true, ConfirmDialog: ConfirmStub },
      },
    })
    await flushPromises()
    await showTab(wrapper, 'teams')
    return wrapper
  }

  beforeEach(() => {
    vi.clearAllMocks()
    confirmOpen.mockResolvedValue(true)
  })
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('シーズンポータル → そのチームのシーズンへ遷移する', async () => {
    const wrapper = await mountTeams()
    await chooseRowMenuItem(wrapper, 'シーズンポータル')
    expect(mockPush).toHaveBeenCalledTimes(1)
    expect(mockPush).toHaveBeenCalledWith('/teams/3/season')
    wrapper.unmount()
  })

  it('メンバー編集 → そのチームのメンバー画面へ遷移する', async () => {
    const wrapper = await mountTeams()
    await chooseRowMenuItem(wrapper, 'メンバー編集')
    expect(mockPush).toHaveBeenCalledTimes(1)
    expect(mockPush).toHaveBeenCalledWith('/teams/3/members')
    wrapper.unmount()
  })

  it('チーム編集 → チームのダイアログを開く（遷移・削除はしない）', async () => {
    const wrapper = await mountTeams()
    await chooseRowMenuItem(wrapper, 'チーム編集')
    const dialog = wrapper.findComponent({ name: 'TeamDialog' })
    expect(dialog.props('isVisible')).toBe(true)
    expect((dialog.props('team') as { id: number }).id).toBe(3)
    expect(mockPush).not.toHaveBeenCalled()
    expect(axios.delete).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it('削除 → 確認のあとそのチームを DELETE する（遷移・ダイアログは呼ばない）', async () => {
    const wrapper = await mountTeams()
    await chooseRowMenuItem(wrapper, '削除')
    expect(confirmOpen).toHaveBeenCalledTimes(1)
    expect(axios.delete).toHaveBeenCalledWith('/teams/3')
    expect(mockPush).not.toHaveBeenCalled()
    expect(wrapper.findComponent({ name: 'TeamDialog' }).props('isVisible')).toBe(false)
    wrapper.unmount()
  })
})

const mountPlain = () =>
  mount(CommissionerDashboardView, {
    attachTo: document.body,
    global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
  })

const apiMock =
  (bodies: Record<string, unknown>, failing: string[] = []) =>
  (url: string) =>
    failing.includes(url)
      ? Promise.reject(new Error('network'))
      : Promise.resolve({ data: bodies[url] ?? [] })

// Test Basis: thbig-dugout-commissioner-dashboard-visual-design.md §2 案 A+（タブは概況・離脱者・クールダウン・コスト・1軍登録・チーム管理。アイコンと件数）/ Operator 決定 2026-11-02
describe('CommissionerDashboard タブ（概況が先頭・アイコンと件数）', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('並びは 概況・離脱者・クールダウン・コスト・1軍登録・チーム管理。先頭の概況が開く', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(apiMock({}))
    const wrapper = mountPlain()
    await flushPromises()
    const tabs = wrapper.findAllComponents(components.VTab)
    expect(tabs.map((t) => t.props('value'))).toEqual([
      'overview',
      'absences',
      'cooldowns',
      'costs',
      'rosterStatus',
      'teams',
    ])
    expect(tabs.map((t) => t.text().replace(/\d+$/, '').trim())).toEqual([
      '概況',
      '離脱者',
      'クールダウン',
      'コスト',
      '1軍登録',
      'チーム管理',
    ])
    expect(wrapper.find('.v-window-item--active [data-testid="dashboard-overview"]').exists()).toBe(
      true,
    )
    wrapper.unmount()
  })

  it('各タブにアイコンがつく（概況・離脱者・クールダウン・コスト・1軍登録・チーム管理）', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(apiMock({}))
    const wrapper = mountPlain()
    await flushPromises()
    expect(wrapper.findAllComponents(components.VTab).map((t) => t.props('prependIcon'))).toEqual([
      'mdi-view-dashboard-outline',
      'mdi-account-off-outline',
      'mdi-timer-sand',
      'mdi-currency-jpy',
      'mdi-clipboard-list-outline',
      'mdi-account-group-outline',
    ])
    wrapper.unmount()
  })

  it('離脱者・クールダウン・コスト・1軍登録・チーム管理に件数がつく。コストは 95% 以上と超過の合計、1軍登録は規定違反のチーム数', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({
        '/teams': [
          { id: 1, name: 'チームA', is_active: true },
          { id: 2, name: 'チームB', is_active: false },
          { id: 3, name: 'チームC', is_active: true },
        ],
        '/commissioner/dashboard/absences': mockAbsences,
        '/commissioner/dashboard/cooldowns': mockCooldowns,
        '/commissioner/dashboard/costs': [
          ...mockCosts, // 185（92.5%）と 210（超過）
          { ...mockCosts[0], team_id: 3, total_cost: 190, cost_usage_ratio: 0.95 },
        ],
        '/commissioner/dashboard/roster_status': [
          mockRosterStatus(1, 'チームA', []),
          mockRosterStatus(3, 'チームC', ['コスト上限を超過しています']),
        ],
      }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    const counts = Object.fromEntries(
      wrapper
        .findAllComponents(components.VTab)
        .map((t) => [t.props('value') as string, t.findComponent(components.VChip)]),
    )
    expect(counts.overview!.exists()).toBe(false)
    expect(counts.absences!.text()).toBe('2')
    expect(counts.cooldowns!.text()).toBe('1')
    expect(counts.costs!.text()).toBe('2')
    expect(counts.costs!.props('color')).toBe('state-warn')
    // 規定違反はチームC だけ。合計コスト超過のチーム2（210）は 1軍登録タブの件数に数えない
    expect(counts.rosterStatus!.text()).toBe('1')
    expect(counts.rosterStatus!.props('color')).toBe('state-warn')
    expect(counts.teams!.text()).toBe('3')
    for (const c of Object.values(counts).slice(1)) expect(c.props('variant')).toBe('flat')
    wrapper.unmount()
  })

  it('読み込み中・失敗の間は件数を出さない（0 と見分ける）。違反が 0 なら緑', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({ '/commissioner/dashboard/roster_status': [mockRosterStatus(1, 'チームA', [])] }, [
        '/commissioner/dashboard/absences',
      ]),
    )
    const wrapper = mountPlain()
    await flushPromises()
    const chip = (value: string) =>
      wrapper
        .findAllComponents(components.VTab)
        .find((t) => t.props('value') === value)!
        .findComponent(components.VChip)
    expect(chip('absences').exists()).toBe(false)
    expect(chip('rosterStatus').text()).toBe('0')
    expect(chip('rosterStatus').props('color')).toBe('state-done')
    wrapper.unmount()
  })

  // Test Basis: 設計書末尾の追記（2026-11-02 本体判断）「1軍登録タブの件数は規定違反だけに戻す。そのタブはロスター規定の表でコスト超過を表示しない」
  // （概況の「要確認」タイルは規定違反＋合計コスト超過のまま。Operator 決定は要確認タイルについてのもの）
  it('1軍登録の件数: 規定違反のチーム数だけ。合計コスト超過は数えない（違反と超過が重なっても 1 回）', async () => {
    const cost = (team_id: number, total_cost: number) => ({
      ...mockCosts[0],
      team_id,
      total_cost,
      cost_usage_ratio: total_cost / 200,
    })
    const countFor = async (roster: unknown[], costs: unknown[]) => {
      ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
        apiMock({
          '/commissioner/dashboard/roster_status': roster,
          '/commissioner/dashboard/costs': costs,
        }),
      )
      const wrapper = mountPlain()
      await flushPromises()
      const chip = wrapper
        .findAllComponents(components.VTab)
        .find((t) => t.props('value') === 'rosterStatus')!
        .findComponent(components.VChip)
      const result = [chip.text(), chip.props('color')]
      wrapper.unmount()
      return result
    }
    const warn = (id: number) => mockRosterStatus(id, `チーム${id}`, ['x'])
    expect(await countFor([warn(1)], [cost(1, 100)])).toEqual(['1', 'state-warn'])
    // 超過だけのチームは数えない
    expect(await countFor([], [cost(1, 201)])).toEqual(['0', 'state-done'])
    expect(await countFor([warn(1)], [cost(1, 201)])).toEqual(['1', 'state-warn'])
    expect(await countFor([warn(1)], [cost(1, 201), cost(2, 250)])).toEqual(['1', 'state-warn'])
    expect(await countFor([warn(1), warn(2)], [])).toEqual(['2', 'state-warn'])
    expect(await countFor([], [cost(1, 200), cost(2, 190)])).toEqual(['0', 'state-done'])
  })

  it('1軍登録の件数: コストの取得が失敗・読み込み中でも、規定違反の数だけで決まる（0 件なら緑・違反があれば警告色）', async () => {
    const chipOf = async (violations: string[]) => {
      ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
        apiMock(
          { '/commissioner/dashboard/roster_status': [mockRosterStatus(1, 'チームA', violations)] },
          ['/commissioner/dashboard/costs'],
        ),
      )
      const wrapper = mountPlain()
      await flushPromises()
      const chip = wrapper
        .findAllComponents(components.VTab)
        .find((t) => t.props('value') === 'rosterStatus')!
        .findComponent(components.VChip)
      const result = [chip.text(), chip.props('color')]
      wrapper.unmount()
      return result
    }
    expect(await chipOf([])).toEqual(['0', 'state-done'])
    expect(await chipOf(['x'])).toEqual(['1', 'state-warn'])
  })
})

// Test Basis: 同上 §5 段 2。概況と 1軍登録タブは roster_status を共用する（9 秒かかる API を 2 度呼ばない）
describe('CommissionerDashboard 概況の取得', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('6 本の API を最初に 1 度ずつ取る。1軍登録タブを開いても roster_status を取り直さない', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(apiMock({}))
    const wrapper = mountPlain()
    await flushPromises()
    await showTab(wrapper, 'rosterStatus')
    const urls = (axios.get as ReturnType<typeof vi.fn>).mock.calls.map((c) => c[0])
    for (const u of [
      '/teams',
      '/commissioner/dashboard/absences',
      '/commissioner/dashboard/cooldowns',
      '/commissioner/dashboard/costs',
      '/commissioner/dashboard/roster_status',
      '/commissioner/dashboard/game_progress',
    ]) {
      expect(urls.filter((x) => x === u)).toHaveLength(1)
    }
    wrapper.unmount()
  })

  it('遅い API（costs）が未着でも、他の API の値は先に概況に出る', async () => {
    let release: (v: { data: unknown[] }) => void = () => {}
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      url === '/commissioner/dashboard/costs'
        ? new Promise((resolve) => {
            release = resolve
          })
        : Promise.resolve({
            data:
              url === '/commissioner/dashboard/absences'
                ? mockAbsences
                : url === '/teams'
                  ? [{ id: 1, name: 'チームA', is_active: true }]
                  : [],
          }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    expect(wrapper.find('[data-testid="tile-absence"]').text()).toContain('2')
    expect(wrapper.find('[data-testid="tile-cost"] [data-testid="state-loading"]').exists()).toBe(
      true,
    )
    expect(wrapper.find('[data-testid="team-table-card"]').text()).toContain('チームA')
    release({ data: mockCosts })
    await flushPromises()
    expect(wrapper.find('[data-testid="tile-cost"] [data-testid="state-loading"]').exists()).toBe(
      false,
    )
    wrapper.unmount()
  })

  it('costs が失敗しても概況の他のタイルは数字を出し、再読み込みは costs だけを取り直す', async () => {
    let failing = true
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      url === '/commissioner/dashboard/costs' && failing
        ? Promise.reject(new Error('network'))
        : Promise.resolve({
            data:
              url === '/commissioner/dashboard/absences'
                ? mockAbsences
                : url === '/commissioner/dashboard/costs'
                  ? mockCosts
                  : [],
          }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    expect(wrapper.find('[data-testid="tile-cost"] [data-testid="state-error"]').exists()).toBe(
      true,
    )
    expect(wrapper.find('[data-testid="tile-absence"] [data-testid="state-error"]').exists()).toBe(
      false,
    )
    expect(wrapper.find('[data-testid="tile-absence"]').text()).toContain('2')
    failing = false
    const before = (axios.get as ReturnType<typeof vi.fn>).mock.calls.length
    await wrapper.find('[data-testid="tile-cost"] [data-testid="state-retry"]').trigger('click')
    await flushPromises()
    const added = (axios.get as ReturnType<typeof vi.fn>).mock.calls.slice(before).map((c) => c[0])
    expect(added).toEqual(['/commissioner/dashboard/costs'])
    expect(wrapper.find('[data-testid="tile-cost"] [data-testid="state-error"]').exists()).toBe(
      false,
    )
    wrapper.unmount()
  })

  // Test Basis: subtask_1794j「game_progress を他の API と独立に読み込み中・失敗を出す」/ subtask_1802b の API 形
  it('game_progress は team_id で結合して「消化 / 総数」と未振替を概況の表に出す', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({
        '/teams': [
          { id: 1, name: 'チームA', is_active: true },
          { id: 2, name: 'チームB', is_active: true },
        ],
        '/commissioner/dashboard/game_progress': [
          {
            team_id: 2,
            regular_played: 34,
            regular_total: 143,
            regular_unrescheduled: 1,
            playoff_played: 0,
          },
        ],
      }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    const rows = wrapper.findAll('[data-testid="team-table-card"] tbody tr')
    const rowB = rows.find((r) => r.find('b').text() === 'チームB')!
    expect(rowB.find('[data-testid="games-count"]').text().replace(/\s+/g, '')).toBe('34/143')
    expect(rowB.find('[data-testid="unrescheduled"]').text()).toBe('未振替 1')
    const rowA = rows.find((r) => r.find('b').text() === 'チームA')!
    expect(rowA.find('td.progress-cell').text()).toBe('—')
    wrapper.unmount()
  })

  it('遅い game_progress が未着でも、他の欄は先に出る。着いたら進み具合が出る', async () => {
    let release: (v: { data: unknown[] }) => void = () => {}
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      url === '/commissioner/dashboard/game_progress'
        ? new Promise((resolve) => {
            release = resolve
          })
        : Promise.resolve({
            data:
              url === '/commissioner/dashboard/absences'
                ? mockAbsences
                : url === '/teams'
                  ? [{ id: 1, name: 'チームA', is_active: true }]
                  : [],
          }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    expect(wrapper.find('[data-testid="tile-absence"]').text()).toContain('2')
    expect(wrapper.find('[data-testid="team-table-card"]').text()).toContain('チームA')
    expect(
      wrapper
        .find('[data-testid="team-table-card"] td.progress-cell [data-testid="cell-loading"]')
        .exists(),
    ).toBe(true)
    release({
      data: [
        {
          team_id: 1,
          regular_played: 10,
          regular_total: 143,
          regular_unrescheduled: 0,
          playoff_played: 0,
        },
      ],
    })
    await flushPromises()
    expect(wrapper.find('[data-testid="games-count"]').text().replace(/\s+/g, '')).toBe('10/143')
    wrapper.unmount()
  })

  it('game_progress が失敗しても他の欄は出し、再読み込みは game_progress だけを取り直す', async () => {
    let failing = true
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      url === '/commissioner/dashboard/game_progress' && failing
        ? Promise.reject(new Error('network'))
        : Promise.resolve({
            data:
              url === '/commissioner/dashboard/absences'
                ? mockAbsences
                : url === '/teams'
                  ? [{ id: 1, name: 'チームA', is_active: true }]
                  : url === '/commissioner/dashboard/game_progress'
                    ? [
                        {
                          team_id: 1,
                          regular_played: 7,
                          regular_total: 143,
                          regular_unrescheduled: 0,
                          playoff_played: 0,
                        },
                      ]
                    : [],
          }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    expect(wrapper.find('[data-testid="game-progress-error"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="tile-absence"]').text()).toContain('2')
    expect(wrapper.find('[data-testid="tile-absence"] [data-testid="state-error"]').exists()).toBe(
      false,
    )
    failing = false
    const before = (axios.get as ReturnType<typeof vi.fn>).mock.calls.length
    await wrapper
      .find('[data-testid="game-progress-error"] [data-testid="state-retry"]')
      .trigger('click')
    await flushPromises()
    const added = (axios.get as ReturnType<typeof vi.fn>).mock.calls.slice(before).map((c) => c[0])
    expect(added).toEqual(['/commissioner/dashboard/game_progress'])
    expect(wrapper.find('[data-testid="game-progress-error"]').exists()).toBe(false)
    expect(wrapper.find('[data-testid="games-count"]').text().replace(/\s+/g, '')).toBe('7/143')
    wrapper.unmount()
  })

  it('タイルを押すと、その明細のタブへ移る', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(apiMock({}))
    const wrapper = mountPlain()
    await flushPromises()
    await wrapper.find('[data-testid="tile-absence"] button.overview-tile__go').trigger('click')
    await flushPromises()
    const vm = wrapper.findComponent(CommissionerDashboard).vm as unknown as { activeTab: string }
    expect(vm.activeTab).toBe('absences')
    wrapper.unmount()
  })

  it('チームの表の「シーズン」は、そのチームを選んでシーズン画面へ遷移する', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({ '/teams': [{ id: 5, name: '紅魔館', is_active: true }] }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    await wrapper.find('button[aria-label="紅魔館のシーズン"]').trigger('click')
    expect(mockPush).toHaveBeenCalledWith('/teams/5/season')
    wrapper.unmount()
  })
})

// Test Basis: cmd_1814 ダッシュボードのチーム名（概況・一覧表）を押すと、そのチームを選んでシーズン画面（カレンダー）へ遷移する。
// 一覧表（離脱者・クールダウン・コスト・1軍登録・チーム管理）は行ごとのチーム名、a 要素なのでキーボードでも辿れる
describe('CommissionerDashboard チーム名のリンク', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })
  afterEach(() => {
    document.body.innerHTML = ''
  })

  const mountAll = async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({
        '/teams': [
          {
            id: 5,
            name: '紅魔館ヶ丘高校',
            short_name: '紅魔館',
            is_active: true,
            has_season: true,
            team_type: 'normal',
            season_current_date: '2026-04-17',
          },
        ],
        '/commissioner/dashboard/absences': mockAbsences.slice(1),
        '/commissioner/dashboard/cooldowns': mockCooldowns.slice(0, 1),
        '/commissioner/dashboard/costs': mockCosts.slice(0, 1),
        '/commissioner/dashboard/roster_status': [mockRosterStatus(1, 'チームA', [])],
      }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    return wrapper
  }
  const activeLinks = (wrapper: ReturnType<typeof mount>) =>
    wrapper.find('.v-window-item--active').findAll('a.team-name-link')

  it('概況のチームの表: 押すとそのチームを選び（正式名）、そのチームのシーズン画面へ遷移する', async () => {
    const wrapper = await mountAll()
    const link = activeLinks(wrapper).find((a) => a.text() === '紅魔館ヶ丘高校')!
    expect(link.attributes('href')).toBe('/teams/5/season')
    await link.trigger('click')
    expect(mockPush).toHaveBeenCalledTimes(1)
    expect(mockPush).toHaveBeenCalledWith('/teams/5/season')
    const store = useTeamSelectionStore(pinia)
    expect([store.selectedTeamId, store.selectedTeamName]).toEqual([5, '紅魔館ヶ丘高校'])
    wrapper.unmount()
  })

  it.each([
    ['absences', 'チームB', 2],
    ['cooldowns', 'チームA', 1],
    ['costs', 'チームA', 1],
    ['rosterStatus', 'チームA', 1],
    ['teams', '紅魔館ヶ丘高校', 5],
  ])(
    '%s の一覧表: チーム名が a 要素で、押すと選択中チームを切り替えて遷移する',
    async (tab, name, id) => {
      const wrapper = await mountAll()
      await showTab(wrapper, tab)
      const link = activeLinks(wrapper).find((a) => a.text() === name)!
      expect(link.attributes('href')).toBe(`/teams/${id}/season`)
      mockPush.mockClear()
      await link.trigger('click')
      expect(mockPush).toHaveBeenCalledTimes(1)
      expect(mockPush).toHaveBeenCalledWith(`/teams/${id}/season`)
      const store = useTeamSelectionStore(pinia)
      expect([store.selectedTeamId, store.selectedTeamName]).toEqual([id, name])
      wrapper.unmount()
    },
  )

  it('1軍登録の表: チーム名を押しても行は展開しない（行のほかの場所を押すと展開する）', async () => {
    const wrapper = await mountAll()
    await showTab(wrapper, 'rosterStatus')
    const row = wrapper.find('.v-window-item--active tbody tr')
    await row.find('a.team-name-link').trigger('click')
    await flushPromises()
    expect(wrapper.text()).not.toContain('1軍選手一覧')
    // 比較: 名前以外の場所を押すと展開する（上の「展開しない」が、展開の仕組みごと壊れていて通っているのではないことの確認）
    await row.findAll('td')[1].trigger('click')
    await flushPromises()
    expect(wrapper.text()).toContain('1軍選手一覧')
    wrapper.unmount()
  })
})

// Test Basis: Operator 決定 2026-11-02「1軍コストは色を付けない。合計コストは 95% 以上で黄、超過で赤」/ 設計 §2 案 A+ コスト関連の色
describe('CommissionerDashboard コスト状況の色', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  const costRow = (id: number, total: number, firstCost: number, firstLimit: number | null) => ({
    team_id: id,
    team_name: `チーム${id}`,
    team_type: 'normal',
    total_cost: total,
    total_cost_limit: 200,
    first_squad_cost: firstCost,
    first_squad_cost_limit: firstLimit,
    first_squad_count: 28,
    exempt_count: 0,
    cost_usage_ratio: total / 200,
  })
  const mountCosts = async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({
        '/commissioner/dashboard/costs': [
          costRow(1, 189, 120, 120), // 94.5%・1軍は上限ぴったり
          costRow(2, 190, 120, 120), // 95%
          costRow(3, 200, 100, 120), // 100%
          costRow(4, 201, 119, 120), // 超過
        ],
      }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    await showTab(wrapper, 'costs')
    const row = (name: string) =>
      wrapper.findAll('.v-window-item--active tbody tr').find((tr) => tr.text().includes(name))!
    return { wrapper, row }
  }

  it('合計コストの棒: 94.5% は通常（link）、95% と 100% は黄系、超過は赤系', async () => {
    const { wrapper, row } = await mountCosts()
    const color = (name: string) =>
      row(name).findComponent('[data-testid="total-cost-bar"]').props('color')
    expect(color('チーム1')).toBe('link')
    expect(color('チーム2')).toBe('meter-near')
    expect(color('チーム3')).toBe('meter-near')
    expect(color('チーム4')).toBe('meter-over')
    wrapper.unmount()
  })

  // Test Basis: cmd_1817 Operator 2026-11-02「コストタブではマークだけで十分かも」。文字は出さず、印と読み上げ用の aria-label・title を付ける
  it('合計コストの印: 94.5% は無し、95% と 100% は「上限に近い」の印（黄）、超過は「超過」の印（赤）。文字は出さず、チップも使わない', async () => {
    const { wrapper, row } = await mountCosts()
    const marks = (name: string) =>
      row(name)
        .findAll('[data-testid="total-cost-mark"]')
        .map((m) => ({
          level: m.attributes('data-level'),
          role: m.attributes('role'),
          label: m.attributes('aria-label'),
          title: m.attributes('title'),
          icon: m.classes().find((c) => c.startsWith('mdi-') && c !== 'mdi'),
          text: m.text(),
        }))
    expect(marks('チーム1')).toEqual([])
    const near = {
      level: 'near',
      role: 'img',
      label: '合計コストが上限に近い',
      title: '合計コストが上限に近い',
      icon: 'mdi-alert',
      text: '',
    }
    expect(marks('チーム2')).toEqual([near])
    expect(marks('チーム3')).toEqual([near])
    expect(marks('チーム4')).toEqual([
      {
        level: 'over',
        role: 'img',
        label: '合計コスト超過',
        title: '合計コスト超過',
        icon: 'mdi-alert-circle',
        text: '',
      },
    ])
    // 印の色は棒と同じ（黄系 = meter-near・赤系 = meter-over）
    const colorOf = (name: string) =>
      row(name).findComponent('[data-testid="total-cost-mark"]').props('color')
    expect(colorOf('チーム2')).toBe('meter-near')
    expect(colorOf('チーム4')).toBe('meter-over')
    // 文字のチップは出ない。「上限に近い」「超過」の文字も行に出ない。旧い「警告」も出さない
    for (const name of ['チーム1', 'チーム2', 'チーム3', 'チーム4']) {
      expect(
        row(name)
          .findAllComponents(components.VChip)
          .map((c) => c.text()),
      ).toEqual([])
      expect(row(name).text()).not.toContain('上限に近い')
      expect(row(name).text()).not.toContain('超過')
    }
    expect(wrapper.text()).not.toContain('警告')
    wrapper.unmount()
  })

  // cmd_1804 subtask_1804a: 1軍コストは記号だけ（棒は link のまま）。上限ちょうど=チェック、上限+1=✕
  it('1軍コストの記号: 上限ちょうど（120/120）はチェック、上限+1（121/120）は✕、上限なしは出さない', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({
        '/commissioner/dashboard/costs': [
          costRow(1, 100, 120, 120),
          costRow(2, 100, 121, 120),
          costRow(3, 100, 90, null),
        ],
      }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    await showTab(wrapper, 'costs')
    const mark = (name: string) =>
      wrapper
        .findAll('.v-window-item--active tbody tr')
        .find((tr) => tr.text().includes(name))!
        .find('[data-testid="limit-mark"]')
    expect(mark('チーム1').attributes('data-state')).toBe('ok')
    expect(mark('チーム1').classes()).toContain('mdi-check-circle')
    expect(mark('チーム2').attributes('data-state')).toBe('ng')
    expect(mark('チーム2').classes()).toContain('mdi-close-circle')
    expect(mark('チーム3').exists()).toBe(false)
    wrapper.unmount()
  })

  it('1軍コストの棒は、上限ぴったりでも超過に近くても色を付けない（常に link）', async () => {
    const { wrapper, row } = await mountCosts()
    for (const name of ['チーム1', 'チーム2', 'チーム3', 'チーム4']) {
      expect(row(name).findComponent('[data-testid="first-cost-bar"]').props('color')).toBe('link')
    }
    wrapper.unmount()
  })
})

// Test Basis: 設計 §2 案 A+「1軍登録の「OK」を毎行出さず違反の行だけ」
describe('CommissionerDashboard 1軍登録状況の状態', () => {
  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('違反の無い行に「OK」を出さず、違反の行だけ赤系の「警告あり」チップを出す', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation(
      apiMock({
        '/commissioner/dashboard/roster_status': [
          mockRosterStatus(1, 'チームA', []),
          mockRosterStatus(2, 'チームB', ['コスト上限を超過しています']),
        ],
      }),
    )
    const wrapper = mountPlain()
    await flushPromises()
    await showTab(wrapper, 'rosterStatus')
    const active = wrapper.find('.v-window-item--active')
    expect(active.text()).not.toContain('OK')
    const chips = active.findAllComponents(components.VChip).filter((c) => c.text() === '警告あり')
    expect(chips).toHaveLength(1)
    expect(chips[0]!.props('color')).toBe('state-warn')
    expect(chips[0]!.props('variant')).toBe('flat')
    expect(chips[0]!.props('prependIcon')).toBe('mdi-alert-circle')
    const rows = active.findAll('tbody tr')
    expect(rows.find((r) => r.text().includes('チームA'))!.text()).not.toContain('警告あり')
    expect(
      rows
        .find((r) => r.text().includes('チームA'))!
        .find('.status-none')
        .text(),
    ).toBe('—')
    wrapper.unmount()
  })
})
