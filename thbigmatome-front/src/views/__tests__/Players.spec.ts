import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia } from 'pinia'
import { createI18n } from 'vue-i18n'
import Players from '../Players.vue'

vi.mock('@/plugins/axios', () => {
  return {
    default: {
      get: vi.fn(),
      delete: vi.fn(),
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

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      playerList: {
        title: '選手一覧',
        addPlayer: '選手追加',
        noData: 'データなし',
        fetchFailed: '取得失敗',
        deleteSuccess: '削除成功',
        deleteFailed: '削除失敗',
        deleteConfirmTitle: '削除確認',
        deleteConfirmMessage: '削除しますか？',
        filters: { searchPlaceholder: '検索' },
        headers: {
          number: '背番号',
          name: '選手名',
          short_name: '略称',
          actions: '操作',
        },
      },
    },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/players', name: 'Players', component: { template: '<div />' } },
      { path: '/players/:id', name: 'PlayerDetail', component: { template: '<div />' } },
    ],
  })
}

const mockPlayers = [
  {
    id: 1,
    name: '博麗霊夢',
    number: '1',
    short_name: '霊夢',
    series: 'touhou',
    player_cards: [],
  },
  {
    id: 2,
    name: '霧雨魔理沙',
    number: '2',
    short_name: '魔理沙',
    series: null,
    player_cards: [],
  },
]

describe('Players', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('選手一覧が表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockPlayers })
    const router = createTestRouter()
    await router.push('/players')
    await router.isReady()

    const wrapper = mount(Players, {
      global: {
        plugins: [vuetify, router, i18n, createPinia()],
      },
    })

    await flushPromises()

    expect(wrapper.text()).toContain('博麗霊夢')
    expect(wrapper.text()).toContain('霧雨魔理沙')
  })

  it('series=touhou の選手に東方Projectチップが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockPlayers })
    const router = createTestRouter()
    await router.push('/players')
    await router.isReady()

    const wrapper = mount(Players, {
      global: {
        plugins: [vuetify, router, i18n, createPinia()],
      },
    })

    await flushPromises()

    expect(wrapper.text()).toContain('東方Project')
  })
})
