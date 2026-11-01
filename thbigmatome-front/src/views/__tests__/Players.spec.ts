import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia } from 'pinia'
import { createI18n } from 'vue-i18n'
import Players from '../Players.vue'
import ja from '@/locales/ja.json'

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
import { stackedLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      settings: { rowActions: ja.settings.rowActions },
      asyncState: ja.asyncState,
      playerList: {
        title: '選手一覧',
        addPlayer: '選手追加',
        noData: 'データなし',
        fetchFailed: '取得失敗',
        deleteSuccess: '削除成功',
        deleteFailed: '削除失敗',
        deleteConfirmTitle: '削除確認',
        deleteConfirmMessage: '削除しますか？',
        filters: { searchPlaceholder: '検索', series: '所属作品', seriesAll: 'すべて' },
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

  // Test Basis: thbig-dugout-ui-unification-design.md §4 の見本（一覧系: ツールバー行＋縁つきの表カード＋状態の部品）
  describe('骨格（段 1）', () => {
    async function mountPlayers(getImpl: () => Promise<unknown>) {
      vi.mocked(axios.get).mockImplementation(getImpl as never)
      const router = createTestRouter()
      await router.push('/players')
      await router.isReady()
      const wrapper = mount(Players, {
        global: { plugins: [vuetify, router, i18n, createPinia()] },
      })
      await flushPromises()
      return wrapper
    }

    it('本文に画面タイトルを置かず（バーが出す）、検索・絞り込みは左、主操作は右の緑ボタン', async () => {
      const wrapper = await mountPlayers(() => Promise.resolve({ data: mockPlayers }))
      expect(wrapper.find('h1').exists()).toBe(false)
      expect(wrapper.text()).not.toContain('選手一覧')
      const toolbar = wrapper.find('[data-testid="page-toolbar"]')
      expect(toolbar.find('.page-layout__filters [data-testid="players-search"]').exists()).toBe(
        true,
      )
      expect(
        toolbar.find('.page-layout__filters [data-testid="players-series-filter"]').exists(),
      ).toBe(true)
      const add = toolbar.find('.page-layout__actions .v-btn')
      expect(add.text()).toBe('選手追加')
      expect(add.classes()).toContain('bg-action')
      expect(add.classes()).toContain('v-btn--variant-flat')
      expect(add.find('.mdi-plus').exists()).toBe(true)
      expect(wrapper.find('[data-testid="page-layout"]').classes()).toContain(
        'page-layout--default',
      )
    })

    it('行の操作は名前つきのアイコンボタン（編集=link、削除=danger-ink）', async () => {
      const wrapper = await mountPlayers(() => Promise.resolve({ data: mockPlayers }))
      const labels = wrapper.findAll('td button').map((b) => b.attributes('aria-label'))
      expect(labels).toEqual(
        expect.arrayContaining(['博麗霊夢を編集', '博麗霊夢を削除', '霧雨魔理沙を編集']),
      )
      const del = wrapper.find('td button[aria-label="博麗霊夢を削除"]')
      expect(del.classes()).toContain('text-danger-ink')
      expect(wrapper.find('td button[aria-label="博麗霊夢を編集"]').classes()).toContain(
        'text-link',
      )
    })

    it('所属作品で絞り込める。「すべて」で戻る', async () => {
      const wrapper = await mountPlayers(() => Promise.resolve({ data: mockPlayers }))
      expect(wrapper.text()).toContain('霧雨魔理沙')
      const vm = wrapper.vm as unknown as { seriesFilter: string }
      vm.seriesFilter = 'touhou'
      await flushPromises()
      expect(wrapper.text()).toContain('博麗霊夢')
      expect(wrapper.text()).not.toContain('霧雨魔理沙')
      vm.seriesFilter = ''
      await flushPromises()
      expect(wrapper.text()).toContain('霧雨魔理沙')
    })

    it('絞り込みの結果が 0 件でも、登録 0 件の空状態にはしない（表の「データなし」）', async () => {
      const wrapper = await mountPlayers(() => Promise.resolve({ data: mockPlayers }))
      ;(wrapper.vm as unknown as { seriesFilter: string }).seriesFilter = 'tamayomi'
      await flushPromises()
      expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
      expect(wrapper.text()).toContain('データなし')
    })

    it('読み込み中は空状態を出さずスケルトン、登録 0 件なら空状態', async () => {
      let release: (v: unknown) => void = () => {}
      const pending = new Promise((resolve) => (release = resolve))
      const wrapper = await mountPlayers(() => pending)
      expect(wrapper.find('[data-testid="state-loading"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
      release({ data: [] })
      await flushPromises()
      expect(wrapper.find('[data-testid="state-loading"]').exists()).toBe(false)
      expect(wrapper.find('[data-testid="state-empty"]').text()).toContain('データなし')
    })

    it('取得に失敗したらページ内のアラートと再読み込み（空状態は出さない）。再読み込みで取り直す', async () => {
      const get = vi
        .fn()
        .mockRejectedValueOnce(new Error('boom'))
        .mockResolvedValue({ data: mockPlayers })
      const wrapper = await mountPlayers(get)
      expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
      await wrapper.find('[data-testid="state-retry"]').trigger('click')
      await flushPromises()
      expect(get).toHaveBeenCalledTimes(2)
      expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
      expect(wrapper.text()).toContain('博麗霊夢')
    })
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（5 列以上の表は <600px で縦積み。1 行 = 名前＋要点 2 つ＋操作）/ §4.2 段 4
describe('Players 表のスマホ対応（段 4）', () => {
  it('600px 未満で縦積み。番号=lead・名前=title・作品=sub1・カード数=sub2・操作=act', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockPlayers })
    const router = createTestRouter()
    await router.push('/players')
    await router.isReady()
    const wrapper = mount(Players, { global: { plugins: [vuetify, router, i18n, createPinia()] } })
    await flushPromises()
    expect(stackedLayout(wrapper)).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: { number: 'lead', name: 'title', series: 'sub1', card_count: 'sub2', actions: 'act' },
    })
    // 行の操作は .row-actions に包んだアイコンボタン（名前つきの aria-label）
    const actions = wrapper.findAll('.row-actions')
    expect(actions).toHaveLength(2)
    expect(actions[0]!.findAll('button').map((b) => b.attributes('aria-label'))).toEqual([
      '博麗霊夢を編集',
      '博麗霊夢を削除',
    ])
  })
})
