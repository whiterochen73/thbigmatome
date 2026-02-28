import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import GameRecordDetailView from '../GameRecordDetailView.vue'

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

function createTestRouter(id = '1') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/game-records', name: 'GameRecordList', component: { template: '<div />' } },
      { path: '/game-records/:id', name: 'GameRecordDetail', component: { template: '<div />' } },
    ],
  })
  router.push(`/game-records/${id}`)
  return router
}

const mockAtBatRecords = [
  {
    id: 1,
    game_record_id: 1,
    inning: 1,
    half: 'top',
    ab_num: 1,
    batter_name: '博麗霊夢',
    pitcher_name: '霧雨魔理沙',
    result_code: 'K',
    runs_scored: 0,
    runners_before: '---',
    runners_after: '---',
    strategy: null,
    play_description: '三振',
    is_modified: false,
    modified_fields: [],
  },
  {
    id: 2,
    game_record_id: 1,
    inning: 1,
    half: 'top',
    ab_num: 2,
    batter_name: '霧雨魔理沙',
    pitcher_name: '霧雨魔理沙',
    result_code: 'HR',
    runs_scored: 1,
    runners_before: '---',
    runners_after: '---',
    strategy: null,
    play_description: '本塁打',
    is_modified: true,
    modified_fields: ['result_code'],
  },
]

const mockGameRecord = {
  id: 1,
  game_date: '2024-05-01',
  team_id: 1,
  opponent_team_name: '霧雨チーム',
  score_home: 3,
  score_away: 1,
  status: 'draft',
  stadium: '幻想郷球場',
  at_bat_records: mockAtBatRecords,
}

describe('GameRecordDetailView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({ data: mockGameRecord })
  })

  it('コンポーネントがマウントされること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('マウント時にgame_recordを取得すること', async () => {
    const router = createTestRouter()
    await router.isReady()
    mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/game_records/1')
  })

  it('試合サマリーが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('霧雨チーム')
    expect(wrapper.text()).toContain('幻想郷球場')
  })

  it('打者名が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('博麗霊夢')
    expect(wrapper.text()).toContain('霧雨魔理沙')
  })

  it('イニングラベルが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('1回表')
  })

  it('draft状態では確定ボタンが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('このゲームを確定')
  })

  it('confirmed状態では確定ボタンが表示されないこと', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: { ...mockGameRecord, status: 'confirmed' },
    })
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).not.toContain('このゲームを確定')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('試合記録の取得に失敗しました')
  })

  it('is_modified=trueの行は修正済みアイコンが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    const icons = wrapper.findAll('.mdi-pencil-circle')
    expect(icons.length).toBeGreaterThan(0)
  })

  it('確定ボタンクリックでPOSTが呼ばれること', async () => {
    vi.mocked(axios.post).mockResolvedValue({
      data: { ...mockGameRecord, status: 'confirmed' },
    })
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(GameRecordDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()

    const btns = wrapper.findAll('button')
    const confirmButton = btns.find((b) => b.text().includes('確定'))
    if (confirmButton) {
      await confirmButton.trigger('click')
      await flushPromises()
      expect(axios.post).toHaveBeenCalledWith('/game_records/1/confirm')
    }
  })
})
