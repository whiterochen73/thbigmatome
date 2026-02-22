import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import StatsView from '../StatsView.vue'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
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

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

describe('StatsView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('renders successfully', async () => {
    const wrapper = mount(StatsView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays tabs for batting, pitching and team', async () => {
    const wrapper = mount(StatsView, { global: { plugins: [vuetify] } })
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain('打撃成績')
    expect(text).toContain('投手成績')
    expect(text).toContain('チーム成績')
  })

  it('fetches stats when competition is selected', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url === '/competitions') return Promise.resolve({ data: [{ id: 1, name: '大会A' }] })
      if (url === '/stats/batting') return Promise.resolve({ data: { batting_stats: [] } })
      if (url === '/stats/pitching') return Promise.resolve({ data: { pitching_stats: [] } })
      if (url === '/stats/team') return Promise.resolve({ data: { team_stats: [] } })
      return Promise.resolve({ data: [] })
    })

    const wrapper = mount(StatsView, { global: { plugins: [vuetify] } })
    await flushPromises()

    // Simulate competition selection by directly calling fetchStats via exposed API
    const vm = wrapper.vm as unknown as {
      selectedCompetitionId: number
      fetchStats: () => Promise<void>
    }
    vm.selectedCompetitionId = 1
    await vm.fetchStats()
    await flushPromises()

    expect(axios.get).toHaveBeenCalledWith(
      '/stats/batting',
      expect.objectContaining({ params: { competition_id: 1 } }),
    )
    expect(axios.get).toHaveBeenCalledWith(
      '/stats/pitching',
      expect.objectContaining({ params: { competition_id: 1 } }),
    )
    expect(axios.get).toHaveBeenCalledWith(
      '/stats/team',
      expect.objectContaining({ params: { competition_id: 1 } }),
    )
  })
})
