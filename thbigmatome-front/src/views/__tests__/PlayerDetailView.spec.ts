import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import PlayerDetailView from '../PlayerDetailView.vue'
import { appBarTitle } from '@/composables/useAppBarTitle'

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

vi.mock('@/components/players/PlayerDialog.vue', () => ({
  default: { template: '<div />' },
}))

import axios from '@/plugins/axios'

const vuetify = createVuetify({ components, directives })

// AsyncState（読み込み・空・失敗の出し方）が文言を引く
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

function createTestRouter(playerId = '1') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/players', name: 'Players', component: { template: '<div />' } },
      {
        path: '/players/:id',
        name: 'PlayerDetail',
        component: { template: '<div />' },
      },
      {
        path: '/player-cards/:id',
        name: 'PlayerCardDetail',
        component: { template: '<div />' },
      },
    ],
  })
  router.push(`/players/${playerId}`)
  return router
}

const mockPlayer = {
  id: 1,
  name: 'テスト選手',
  number: '10',
  short_name: 'テスト',
  player_cards: [
    {
      id: 101,
      card_type: 'pitcher',
      handedness: '右',
      speed: 3,
      bunt: 5,
      injury_rate: 2,
      is_pitcher: true,
      is_relief_only: false,
      starter_stamina: 6,
      relief_stamina: null,
      card_set: { id: 1, name: '2025年版' },
    },
  ],
}

describe('PlayerDetailView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('選手データが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockPlayer })
    const router = createTestRouter('1')
    await router.isReady()

    const wrapper = mount(PlayerDetailView, {
      global: {
        plugins: [vuetify, i18n, router],
      },
    })

    await flushPromises()

    // 選手名と背番号はヘッダーバー（タイトル・サブタイトル）が出す。本文には画面独自の帯を持たない
    expect(appBarTitle.value).toEqual({
      title: 'テスト選手',
      subtitle: '#10',
      back: { to: '/players', label: '選手一覧' },
    })
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.find('.detail-card-header').exists()).toBe(false)
    expect(wrapper.find('.detail-back-btn').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('一覧に戻る')
    expect(wrapper.text()).toContain('基本情報')
    wrapper.unmount()
    expect(appBarTitle.value).toBeNull()
  })

  it('カード一覧テーブルが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockPlayer })
    const router = createTestRouter('1')
    await router.isReady()

    const wrapper = mount(PlayerDetailView, {
      global: {
        plugins: [vuetify, i18n, router],
      },
    })

    await flushPromises()

    expect(wrapper.text()).toContain('2025年版')
    expect(wrapper.text()).toContain('投手')
  })

  it('series が東方Project で表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { ...mockPlayer, series: 'touhou' } })
    const router = createTestRouter('1')
    await router.isReady()

    const wrapper = mount(PlayerDetailView, {
      global: {
        plugins: [vuetify, i18n, router],
      },
    })

    await flushPromises()

    expect(wrapper.text()).toContain('東方Project')
  })

  it('series が null のとき — を表示する', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: { ...mockPlayer, series: null } })
    const router = createTestRouter('1')
    await router.isReady()

    const wrapper = mount(PlayerDetailView, {
      global: {
        plugins: [vuetify, i18n, router],
      },
    })

    await flushPromises()

    expect(wrapper.text()).toContain('所属作品')
  })

  it('APIエラー時にエラーメッセージを表示する', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('Network error'))
    const router = createTestRouter('1')
    await router.isReady()

    const wrapper = mount(PlayerDetailView, {
      global: {
        plugins: [vuetify, i18n, router],
      },
    })

    await flushPromises()

    expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
      '選手情報の取得に失敗しました',
    )
    // 取得に失敗しても戻り先は宣言されている
    expect(appBarTitle.value).toEqual({
      title: '選手詳細',
      subtitle: null,
      back: { to: '/players', label: '選手一覧' },
    })
    // 再読み込みで取り直せる
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockPlayer })
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(appBarTitle.value?.title).toBe('テスト選手')
    wrapper.unmount()
  })
})
