import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import RosterStatusTab from '../RosterStatusTab.vue'

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

const vuetify = createVuetify({ components, directives })

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

const mountComponent = () =>
  mount(RosterStatusTab, {
    global: {
      plugins: [vuetify],
    },
  })

describe('RosterStatusTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('マウント時にroster_status APIが呼ばれる', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    mountComponent()
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/roster_status')
  })

  it('全チームCSV出力ボタンが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    const wrapper = mountComponent()
    await flushPromises()
    const btn = wrapper.find('a[href*="roster_status.csv"]')
    expect(btn.exists()).toBe(true)
    expect(btn.attributes('href')).not.toContain('team_id')
  })

  it('全チームCSVのhrefにbaseURLが含まれる', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    const wrapper = mountComponent()
    await flushPromises()
    const btn = wrapper.find('a[href*="roster_status.csv"]')
    expect(btn.attributes('href')).toContain('http://localhost:3000/api/v1')
  })

  it('警告ありチームに警告チップが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    const wrapper = mountComponent()
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain('警告あり')
  })

  it('APIエラー時にクラッシュしない', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('network error'))
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })
})
