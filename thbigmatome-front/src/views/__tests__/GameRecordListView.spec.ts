import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import GameRecordListView from '../GameRecordListView.vue'

vi.mock('@/plugins/axios', () => {
  return {
    default: {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn(),
      defaults: {
        baseURL: '',
        withCredentials: false,
        headers: { common: {} },
      },
      interceptors: {
        request: { use: vi.fn() },
        response: { use: vi.fn() },
      },
    },
  }
})

import axios from '@/plugins/axios'

const vuetify = createVuetify({ components, directives })

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/game-records', name: 'GameRecordList', component: { template: '<div />' } },
      { path: '/game-records/:id', name: 'GameRecordDetail', component: { template: '<div />' } },
    ],
  })
}

const mockGameRecords = [
  {
    id: 1,
    game_date: '2024-05-01',
    home_team_name: '博麗神社',
    away_team_name: '霧雨チーム',
    home_score: 3,
    away_score: 1,
    status: 'draft',
    venue: '幻想郷球場',
    at_bat_count: 18,
  },
  {
    id: 2,
    game_date: '2024-05-08',
    home_team_name: '紅魔館',
    away_team_name: '白玉楼',
    home_score: 5,
    away_score: 2,
    status: 'confirmed',
    venue: null,
    at_bat_count: 24,
  },
]

describe('GameRecordListView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({ data: mockGameRecords })
  })

  it('コンポーネントがマウントされること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('タイトルが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('パーサー結果レビュー')
  })

  it('マウント時にgame_recordsを取得すること', async () => {
    const router = createTestRouter()
    mount(GameRecordListView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/game_records')
  })

  it('試合記録の対戦カードが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('霧雨チーム')
    expect(wrapper.text()).toContain('博麗神社')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('試合記録の取得に失敗しました')
  })

  it('draftとconfirmedの両方のステータスが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('未確定')
    expect(wrapper.text()).toContain('確定済み')
  })
})
