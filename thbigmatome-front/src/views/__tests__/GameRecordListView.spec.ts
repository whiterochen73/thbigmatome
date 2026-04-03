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
    team_id: 1,
    opponent_team_name: '霧雨チーム',
    score_home: 3,
    score_away: 1,
    status: 'draft',
    stadium: '幻想郷球場',
  },
  {
    id: 2,
    game_date: '2024-05-08',
    team_id: 2,
    opponent_team_name: '白玉楼',
    score_home: 5,
    score_away: 2,
    status: 'confirmed',
    stadium: null,
  },
]

const mockPagination = { page: 1, per_page: 20, total: 2, total_pages: 1 }

describe('GameRecordListView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({
      data: { game_records: mockGameRecords, pagination: mockPagination },
    })
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
    expect(wrapper.text()).toContain('白玉楼')
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
