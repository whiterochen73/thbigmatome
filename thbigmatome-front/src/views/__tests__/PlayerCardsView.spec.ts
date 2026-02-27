import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import PlayerCardsView from '../PlayerCardsView.vue'

vi.mock('@/plugins/axios', () => {
  return {
    default: {
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
    },
  }
})

import axios from '@/plugins/axios'

const vuetify = createVuetify({ components, directives })

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/player-cards', name: 'PlayerCards', component: { template: '<div />' } },
      { path: '/player-cards/:id', name: 'PlayerCardDetail', component: { template: '<div />' } },
    ],
  })
}

const mockPlayerCardsResponse = {
  player_cards: [
    {
      id: 1,
      card_set_id: 1,
      player_id: 1,
      card_type: 'pitcher',
      player_name: '博麗霊夢',
      player_number: '1',
      card_set_name: 'ハチナイ2024',
      speed: 3,
      steal_start: 10,
      steal_end: 10,
      injury_rate: 3,
      card_image_path: null,
    },
    {
      id: 2,
      card_set_id: 1,
      player_id: 2,
      card_type: 'batter',
      player_name: '霧雨魔理沙',
      player_number: '2',
      card_set_name: 'ハチナイ2024',
      speed: 4,
      steal_start: 8,
      steal_end: 8,
      injury_rate: 2,
      card_image_path: null,
    },
  ],
  meta: { total: 2, page: 1, per_page: 50 },
}

const mockCardSetsResponse = [{ id: 1, name: 'ハチナイ2024', year: 2024 }]

describe('PlayerCardsView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (url === '/card_sets') {
        return Promise.resolve({ data: mockCardSetsResponse })
      }
      if (url === '/player_cards') {
        return Promise.resolve({ data: mockPlayerCardsResponse })
      }
      return Promise.resolve({ data: [] })
    })
  })

  it('コンポーネントがマウントされること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('タイトルが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('選手カード一覧')
  })

  it('マウント時にcard_setsとplayer_cardsを取得すること', async () => {
    const router = createTestRouter()
    mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/card_sets')
    expect(axios.get).toHaveBeenCalledWith('/player_cards', expect.any(Object))
  })

  it('選手カード一覧が表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('博麗霊夢')
    expect(wrapper.text()).toContain('霧雨魔理沙')
  })

  it('合計件数が表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('2件')
  })

  it('フィルターセクションが存在すること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('カードセット')
    expect(wrapper.text()).toContain('選手名')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('選手カードの取得に失敗しました')
  })
})
