import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia } from 'pinia'
import PlayerCardsView from '../PlayerCardsView.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

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
import { dataTables, stackedLayout } from '@/components/shared/__tests__/tableLayout'

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

  // Test Basis: subtask_1791r 追加指示（ManagerList と同型。Vuetify 4 に server-items-length は無く、総数が手元の行数になる）
  describe('サーバページング（総数 > 1 ページの行数）', () => {
    const manyCards = Array.from({ length: 50 }, (_, i) => ({
      id: i + 1,
      card_set_id: 1,
      player_id: i + 1,
      card_type: 'pitcher',
      player_name: `選手${i + 1}`,
      player_number: String(i + 1),
      card_set_name: 'ハチナイ2024',
      speed: 3,
      steal_start: 1,
      steal_end: 1,
      injury_rate: 1,
      card_image_path: null,
    }))

    beforeEach(() => {
      vi.mocked(axios.get).mockImplementation(
        (url: string, config?: { params?: { page?: number } }) => {
          if (url === '/card_sets') return Promise.resolve({ data: mockCardSetsResponse })
          if (url === '/player_cards') {
            const page = config?.params?.page ?? 1
            return Promise.resolve({
              data: {
                player_cards: page === 1 ? manyCards : manyCards.slice(0, 20),
                meta: { total: 120, page, per_page: 50 },
              },
            })
          }
          return Promise.resolve({ data: [] })
        },
      )
    })

    const mountMany = async () => {
      const wrapper = mount(PlayerCardsView, {
        attachTo: document.body,
        global: { plugins: [i18n, vuetify, createTestRouter(), createPinia()] },
      })
      await flushPromises()
      return wrapper
    }

    it('件数表示が総数（120）になる。手元の行数（50）で打ち切らない', async () => {
      const wrapper = await mountMany()
      const info = wrapper.find('.v-data-table-footer__info').text()
      expect(info).toContain('120')
      expect(info).toContain('1-50')
      wrapper.unmount()
    })

    it('次ページを押せて、押すとページ 2 を取りにいく', async () => {
      const wrapper = await mountMany()
      const next = wrapper.find('.v-data-table-footer__pagination button[aria-label="Next page"]')
      expect(next.exists()).toBe(true)
      expect(next.attributes('disabled')).toBeUndefined()
      await next.trigger('click')
      await flushPromises()
      expect(axios.get).toHaveBeenCalledWith(
        '/player_cards',
        expect.objectContaining({ params: expect.objectContaining({ page: 2 }) }),
      )
      expect(wrapper.find('.v-data-table-footer__info').text()).toContain('51-100')
      wrapper.unmount()
    })

    it('2 ページ目で名前検索すると 1 ページ目へ戻して取り直す（絞った後の件数より後ろのページで空にならない）', async () => {
      const wrapper = await mountMany()
      await wrapper
        .find('.v-data-table-footer__pagination button[aria-label="Next page"]')
        .trigger('click')
      await flushPromises()
      expect(wrapper.find('.v-data-table-footer__info').text()).toContain('51-100')
      await wrapper.find('[data-testid="player-cards-search"] input').setValue('霊夢')
      vi.mocked(axios.get).mockClear()
      await wrapper.find('[data-testid="player-cards-search"] input').trigger('keyup.enter')
      await flushPromises()
      expect(axios.get).toHaveBeenCalledWith(
        '/player_cards',
        expect.objectContaining({ params: expect.objectContaining({ page: 1, name: '霊夢' }) }),
      )
      expect(wrapper.find('.v-data-table-footer__info').text()).toContain('1-50')
      wrapper.unmount()
    })
  })

  it('コンポーネントがマウントされること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, router, createPinia()] },
    })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面タイトルはヘッダーバーが持つ。本文に置かない）
  it('画面タイトルを本文に持たず、骨格（PageLayout）で描く', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, router, createPinia()] },
    })
    await flushPromises()
    expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('選手カード一覧')
  })

  it('マウント時にcard_setsとplayer_cardsを取得すること', async () => {
    const router = createTestRouter()
    mount(PlayerCardsView, { global: { plugins: [i18n, vuetify, router, createPinia()] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/card_sets')
    expect(axios.get).toHaveBeenCalledWith('/player_cards', expect.any(Object))
  })

  it('選手カード一覧が表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, router, createPinia()] },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('博麗霊夢')
    expect(wrapper.text()).toContain('霧雨魔理沙')
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b5-19〜b5-21 / subtask_1790c §3
  it('カード種別の全チップを投手・野手トークンで区別する', async () => {
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, createTestRouter(), createPinia()] },
    })
    await flushPromises()
    const typeChips = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => ['投手', '野手'].includes(chip.text()))
    expect(typeChips).toHaveLength(2)
    expect(typeChips.map((chip) => chip.props('color'))).toEqual(['tag-pitcher', 'tag-fielder'])
    expect(typeChips.map((chip) => chip.props('prependIcon'))).toEqual([
      'mdi-baseball',
      'mdi-baseball-bat',
    ])
    typeChips.forEach((chip) => expect(chip.props('variant')).toBe('flat'))
    wrapper.findAllComponents(components.VBtnToggle).forEach((toggle) => {
      expect(toggle.props('color')).toBeUndefined()
      expect(toggle.props('selectedClass')).toBe('bg-primary')
      expect(toggle.findAll('.v-btn--active.bg-primary')).toHaveLength(1)
      expect(toggle.findAll('.v-btn:not(.v-btn--active).bg-primary')).toHaveLength(0)
    })
  })

  it('合計件数が表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, router, createPinia()] },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('2件')
  })

  it('フィルターセクションが存在すること', async () => {
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, router, createPinia()] },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('カードセット')
    expect(wrapper.text()).toContain('選手名')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, router, createPinia()] },
    })
    await flushPromises()
    expect(wrapper.text()).toContain('選手カードの取得に失敗しました')
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（<600px は縦積み。1 行 = 名前＋要点 2 つ＋操作）/ §4.2 段 4
describe('PlayerCardsView 表のスマホ対応（段 4）', () => {
  beforeEach(() => {
    vi.mocked(axios.get).mockImplementation((url: string) =>
      Promise.resolve({
        data: url === '/player_cards' ? mockPlayerCardsResponse : mockCardSetsResponse,
      }),
    )
  })

  it('縦積み: 背番号=lead・選手名=title・種別=sub1・ポジション=sub2・カードセット=note・コスト=note2（見出し付き。画像・走力は出さない）', async () => {
    const wrapper = mount(PlayerCardsView, {
      global: { plugins: [i18n, vuetify, createTestRouter(), createPinia()] },
    })
    await flushPromises()
    expect(stackedLayout(wrapper)).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: {
        player_number: 'lead',
        player_name: 'title',
        card_type: 'sub1',
        primary_position: 'sub2',
        cost: 'note2',
        card_set_name: 'note',
      },
    })
    const cost = (
      dataTables(wrapper)[0]!.props('headers') as { key: string; cellProps?: { class: string } }[]
    ).find((h) => h.key === 'cost')
    expect(cost?.cellProps?.class).toContain('ui-cell--labeled')
  })
})
