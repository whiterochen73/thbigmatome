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
    expect(wrapper.text()).toContain('全チーム管理')
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
    const dashboardVm = wrapper.findComponent(CommissionerDashboard).vm as unknown as {
      activeTab: string
    }
    dashboardVm.activeTab = 'absences'
    await wrapper.vm.$nextTick()
    const chips = wrapper.findAll('.v-chip.bg-absence-out')
    expect(chips).toHaveLength(2)
    expect(chips.some((chip) => chip.find('.mdi-hospital-box').exists())).toBe(true)
    expect(chips.some((chip) => chip.find('.mdi-gavel').exists())).toBe(true)
  })

  it('displays absence list header', async () => {
    const wrapper = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('離脱者一覧')
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
    expect(wrapper.text()).toContain('コスト状況')
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
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(true)
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) =>
      Promise.resolve({
        data: url === '/teams' ? [{ id: 1, name: 'チームA', is_active: true }] : [],
      }),
    )
    const w2 = mount(CommissionerDashboardView, {
      global: { plugins: [vuetify, pinia, i18n], stubs: { TeamDialog: true, ConfirmDialog: true } },
    })
    await flushPromises()
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
    const { wrapper } = await mountDashboard()
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
    const { wrapper } = await mountDashboard()
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
