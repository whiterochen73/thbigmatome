import { describe, it, expect, vi, beforeEach } from 'vitest'
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

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}))

import axios from 'axios'

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
