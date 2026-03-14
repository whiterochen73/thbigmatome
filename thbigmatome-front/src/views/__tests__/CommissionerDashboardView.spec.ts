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

  it('displays absence records', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: mockAbsences })
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
})
