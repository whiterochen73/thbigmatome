import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { nextTick } from 'vue'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import PitcherStatusTab from '../PitcherStatusTab.vue'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

const mockPitchers = [
  {
    player_id: 1,
    player_name: '霊夢',
    last_role: 'starter',
    rest_days: 6,
    cumulative_innings: null,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'full',
  },
  {
    player_id: 2,
    player_name: '魔理沙',
    last_role: 'starter',
    rest_days: 3,
    cumulative_innings: null,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'injury_check',
  },
  {
    player_id: 3,
    player_name: 'チルノ',
    last_role: 'reliever',
    rest_days: 1,
    cumulative_innings: 2,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'reduced_0',
  },
  {
    player_id: 4,
    player_name: '妖夢',
    last_role: 'reliever',
    rest_days: null,
    cumulative_innings: 0,
    is_injured: true,
    is_unavailable: false,
    projected_status: 'injured',
  },
]

const mountComponent = (props = {}) =>
  mount(PitcherStatusTab, {
    props: {
      teamId: 1,
      gameDate: '2026-03-22',
      competitionId: null,
      ...props,
    },
    global: {
      plugins: [vuetify],
    },
  })

describe('PitcherStatusTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorage.clear()
    vi.mocked(axios.get).mockResolvedValue({ data: mockPitchers })
  })

  it('コンポーネントがマウントされること', () => {
    const wrapper = mountComponent()
    expect(wrapper.exists()).toBe(true)
  })

  it('APIから投手状態を取得してロードすること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/teams/1/pitcher_game_states/fatigue_summary', {
      params: { date: '2026-03-22' },
    })
    expect(wrapper.text()).toContain('霊夢')
    expect(wrapper.text()).toContain('魔理沙')
  })

  it('先発投手セクションとリリーフ投手セクションが表示されること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).toContain('先発投手')
    expect(wrapper.text()).toContain('リリーフ投手')
  })

  it('先発投手が中日数降順でデフォルトソートされること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    // 霊夢(中6日)が魔理沙(中3日)より先に来る
    const text = wrapper.text()
    const reimuIdx = text.indexOf('霊夢')
    const marisaIdx = text.indexOf('魔理沙')
    expect(reimuIdx).toBeLessThan(marisaIdx)
  })

  it('ステータスバッジが正しく表示されること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).toContain('✅全快')
    expect(wrapper.text()).toContain('⚠️負傷CK要')
    expect(wrapper.text()).toContain('⚡P減少')
    expect(wrapper.text()).toContain('🏥負傷中')
  })

  it('先発投手の累積IPは"-"が表示されること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    // starters table: 累積IP列は"-"
    const starterSection = wrapper.findAll('v-table, table').at(0)
    expect(starterSection?.text()).toContain('-')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).toContain('投手状態の取得に失敗しました')
  })

  it('localStorageに保存した並び順が復元されること', async () => {
    // 逆順を保存 (魔理沙→霊夢)
    localStorage.setItem(
      'pitcher_status_order_1',
      JSON.stringify({ starters: [2, 1], relievers: [] }),
    )
    const wrapper = mountComponent()
    await flushPromises()
    const text = wrapper.text()
    const reimuIdx = text.indexOf('霊夢')
    const marisaIdx = text.indexOf('魔理沙')
    expect(marisaIdx).toBeLessThan(reimuIdx)
  })

  it('ローディング中はスピナーが表示されること', async () => {
    vi.mocked(axios.get).mockReturnValue(new Promise(() => {}))
    const wrapper = mountComponent()
    await nextTick()
    expect(wrapper.find('[data-testid="loading-spinner"]').exists()).toBe(true)
  })

  it('teamIdが変わると再フェッチすること', async () => {
    const wrapper = mountComponent({ teamId: 1 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(1)
    await wrapper.setProps({ teamId: 2 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(axios.get).toHaveBeenLastCalledWith('/teams/2/pitcher_game_states/fatigue_summary', {
      params: { date: '2026-03-22' },
    })
  })
})
