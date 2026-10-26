import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { nextTick } from 'vue'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createWebHistory } from 'vue-router'
import PitcherStatusTab from '../PitcherStatusTab.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: { template: '<div />' } },
    { path: '/player-cards/:id', name: 'PlayerCardDetail', component: { template: '<div />' } },
  ],
})

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
    as_starter: { status: 'full', notes: [] },
    as_reliever: { status: 'full', notes: [] },
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
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
    as_starter: { status: 'injury_check', notes: [] },
    as_reliever: { status: 'reduced_0', notes: [] },
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
  },
  {
    player_id: 3,
    player_name: 'チルノ',
    last_role: 'reliever',
    rest_days: 1,
    cumulative_innings: 2,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'fatigued_start',
    as_starter: { status: 'unavailable', notes: [] },
    as_reliever: { status: 'fatigued_start', notes: ['opener_injury_check'] },
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
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
    as_starter: { status: 'injured', notes: [] },
    as_reliever: { status: 'injured', notes: [] },
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
  },
]

const mountComponent = (props = {}) =>
  mount(PitcherStatusTab, {
    props: {
      teamId: 1,
      scheduleDate: '2026-03-22',
      competitionId: null,
      ...props,
    },
    global: {
      plugins: [vuetify, router],
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
    expect(wrapper.text()).toContain('✅ 全快')
    expect(wrapper.text()).toContain('⚠️ 負傷CK')
    expect(wrapper.text()).toContain('⚡ P0')
    expect(wrapper.text()).toContain('🏥 負傷中')
  })

  // cmd_1775 第3段 E10: 投手ごとに「先発なら」「リリーフなら」の 2 つを並べて出す
  it('「先発なら」「リリーフなら」の列見出しが先発・リリーフ両方の表に出る', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    for (const table of wrapper.findAll('table')) {
      expect(table.text()).toContain('先発なら')
      expect(table.text()).toContain('リリーフなら')
    }
  })

  it('投手ごとに 2 つの状態を出す（魔理沙: 先発なら 負傷CK / リリーフなら P0）', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.find('[data-testid="as-starter-2"]').text()).toContain('⚠️ 負傷CK')
    expect(wrapper.find('[data-testid="as-reliever-2"]').text()).toContain('⚡ P0')
  })

  it('最初から疲労状態は疲労P0 と別のバッジで出る（チルノ: 累積2）', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const cell = wrapper.find('[data-testid="as-reliever-3"]')
    expect(cell.text()).toContain('🔥 最初から疲労')
    expect(cell.text()).not.toContain('⚡ P0')
    expect(cell.text()).toContain('オープナーなら')
  })

  it('前回リリーフの中1日は「先発なら」が不可', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.find('[data-testid="as-starter-3"]').text()).toContain('🚫 不可')
  })

  it('省略された「先発なら」「リリーフなら」は「—」だけでバッジを出さない', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: [
        {
          ...mockPitchers[0],
          as_starter: null,
          as_starter_omitted_reason: 'relief_only_contract',
          as_reliever: null,
          as_reliever_omitted_reason: 'no_relief_stamina',
        },
      ],
    })
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.find('[data-testid="as-starter-1"]').text()).toBe('—')
    expect(wrapper.find('[data-testid="as-reliever-1"]').text()).toBe('—')
    expect(
      wrapper.find('[data-testid="as-starter-1"]').findComponent({ name: 'VChip' }).exists(),
    ).toBe(false)
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
