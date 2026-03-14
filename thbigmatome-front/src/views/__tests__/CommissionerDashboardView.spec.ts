import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import CommissionerDashboardView from '../commissioner/CommissionerDashboardView.vue'

vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
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

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

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
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays dashboard title', async () => {
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('ダッシュボード')
  })

  it('fetches absences on mount', async () => {
    mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/absences')
  })

  it('fetches costs on mount', async () => {
    mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/costs')
  })

  it('displays absence records', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url.includes('absences')) return Promise.resolve({ data: mockAbsences })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('霧雨魔理沙')
    expect(wrapper.text()).toContain('博麗霊夢')
  })

  it('displays absence list header', async () => {
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('離脱者一覧')
  })

  it('fetches cooldowns on mount', async () => {
    mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/cooldowns')
  })

  it('displays cost tab', async () => {
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('コスト状況')
  })

  it('displays cooldown tab', async () => {
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('クールダウン')
  })

  it('displays cooldown records when cooldown tab is active', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url.includes('cooldowns')) return Promise.resolve({ data: mockCooldowns })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    const vm = wrapper.vm as unknown as { activeTab: string }
    vm.activeTab = 'cooldowns'
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('クールダウン中選手')
  })

  it('displays cost records when cost tab is active', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url.includes('costs')) return Promise.resolve({ data: mockCosts })
      return Promise.resolve({ data: [] })
    })
    const wrapper = mount(CommissionerDashboardView, { global: { plugins: [vuetify] } })
    await flushPromises()
    // コストタブに切り替え
    const vm = wrapper.vm as unknown as { activeTab: string }
    vm.activeTab = 'costs'
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('チーム別コスト使用状況')
  })
})
