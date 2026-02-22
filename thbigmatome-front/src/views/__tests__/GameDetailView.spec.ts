import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GameDetailView from '../GameDetailView.vue'

// Mock axios
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

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '1' } }),
  useRouter: () => ({ back: vi.fn() }),
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

const mockGame = {
  id: 1,
  competition_id: 10,
  home_team_id: 2,
  visitor_team_id: 3,
  real_date: '2026-04-01',
  status: 'confirmed',
  source: 'test',
  at_bats: [
    {
      id: 1,
      game_id: 1,
      inning: 1,
      half: 'top',
      seq: 1,
      batter_id: 101,
      pitcher_id: 201,
      result_code: '1B',
      play_type: 'normal',
      rolls: [3, 5],
      rbi: 1,
      runners: [],
      runners_after: [],
      outs_after: 0,
      scored: true,
    },
  ],
}

describe('GameDetailView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: mockGame })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(GameDetailView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays game detail header', async () => {
    const wrapper = mount(GameDetailView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('試合詳細')
  })

  it('fetches game on mount', async () => {
    mount(GameDetailView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/games/1')
  })
})
