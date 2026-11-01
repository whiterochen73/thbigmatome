import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import GameRecordListView from '../GameRecordListView.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

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
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

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
  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b3-10〜b3-12
  it('βと全ステータスの状態チップに役割色、flat、アイコンを付ける', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    for (const [label, color, icon] of [
      ['β', 'state-neutral', 'mdi-flask-outline'],
      ['未確定', 'state-todo', 'mdi-circle-outline'],
      ['確定済み', 'state-done', 'mdi-check-circle'],
    ]) {
      const matching = wrapper
        .findAllComponents(components.VChip)
        .filter((chip) => chip.text() === label)
      expect(matching.length, label).toBeGreaterThan(0)
      for (const chip of matching) {
        expect(chip.props('color')).toBe(color)
        expect(chip.props('variant')).toBe('flat')
        expect(chip.props('prependIcon')).toBe(icon)
      }
    }
  })
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({
      data: { game_records: mockGameRecords, pagination: mockPagination },
    })
  })

  it('コンポーネントがマウントされること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面タイトルはヘッダーバーが持つ。本文に置かない）
  it('画面タイトルを本文に持たず、骨格（PageLayout）で描く', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('パーサー結果レビュー')
  })

  it('マウント時にgame_recordsを取得すること', async () => {
    const router = createTestRouter()
    mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/game_records')
  })

  it('試合記録の対戦カードが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('霧雨チーム')
    expect(wrapper.text()).toContain('白玉楼')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('試合記録の取得に失敗しました')
  })

  it('draftとconfirmedの両方のステータスが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameRecordListView, { global: { plugins: [i18n, vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('未確定')
    expect(wrapper.text()).toContain('確定済み')
  })
})
