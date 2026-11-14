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

// 実機（八雲 紫・5 枚）のレスポンスの形。カードごとの版の印・画像・コスト行の対象を持つ（cmd_1902）
function card142(
  id: number,
  set: string,
  label: string | null,
  over: Record<string, unknown> = {},
) {
  return {
    id,
    card_type: 'pitcher',
    handedness: 'right_throw/right_bat',
    speed: 1,
    bunt: 1,
    injury_rate: 5,
    is_pitcher: true,
    is_relief_only: false,
    starter_stamina: null,
    relief_stamina: 1,
    variant: label,
    card_set: { id: 1, name: set, is_current: set === 'PM2027' },
    card_set_name: set,
    card_set_current: set === 'PM2027',
    version_label: label,
    image_url: null,
    ...over,
  }
}

function cost142(
  name: string,
  normal: number,
  target: { id: number; set: string; label: string | null } | null,
  isCurrent: boolean,
) {
  return {
    cost_id: isCurrent ? 2 : 1,
    cost_name: name,
    is_current: isCurrent,
    player_card_id: target?.id ?? null,
    card_set_name: target?.set ?? null,
    version_label: target?.label ?? null,
    normal_cost: normal,
    pitcher_only_cost: null,
    fielder_only_cost: null,
    relief_only_cost: null,
    two_way_cost: null,
  }
}

describe('PlayerDetailView カードとコストの見分け（cmd_1902）', () => {
  async function mountWith(player: unknown) {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: player })
    const router = createTestRouter('142')
    await router.isReady()
    const wrapper = mount(PlayerDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    return wrapper
  }

  const hanno = { id: 517, set: 'PM2027', label: '飯能' }
  const tsukushino = { id: 530, set: 'PM2027', label: '筑紫野' }

  it('カード 5 枚（同じセットに版違い 3 枚）は、行ごとにセット名と版の印が出て、見分けがつく', async () => {
    const wrapper = await mountWith({
      id: 142,
      name: '八雲 紫',
      number: '18',
      series: 'touhou',
      player_cards: [
        card142(498, 'PM2027', 'エイプリル', { card_type: 'batter' }),
        card142(517, 'PM2027', '飯能'),
        card142(530, 'PM2027', '筑紫野'),
        card142(375, 'PM2026', '筑紫野'),
        card142(142, '2025THBIG', null),
      ],
      costs: [],
    })
    const rows = wrapper.findAll('tr.card-row').map((r) => r.findAll('td')[1]!.text())
    expect(rows).toEqual([
      'PM2027 / エイプリル',
      'PM2027 / 飯能',
      'PM2027 / 筑紫野',
      'PM2026 / 筑紫野',
      '2025THBIG',
    ])
    wrapper.unmount()
  })

  it('画像があるカードは画像、無いカードは枠だけ（行の数は変わらない）', async () => {
    const wrapper = await mountWith({
      id: 142,
      name: '八雲 紫',
      player_cards: [
        card142(517, 'PM2027', '飯能', { image_url: 'http://x/blob/517' }),
        card142(142, '2025THBIG', null),
      ],
      costs: [],
    })
    const rows = wrapper.findAll('tr.card-row')
    expect(rows).toHaveLength(2)
    expect(rows[0]!.find('.thumb-box .v-img').exists()).toBe(true)
    expect(rows[1]!.find('.thumb-box .v-img').exists()).toBe(false)
    expect(rows[1]!.find('.thumb-box').text()).toContain('IMG')
    wrapper.unmount()
  })

  it('カードが 1 枚だけ・版の印なしでもセット名が出る', async () => {
    const wrapper = await mountWith({
      id: 1,
      name: 'テスト選手',
      player_cards: [card142(101, '2025THBIG', null)],
      costs: [],
    })
    expect(wrapper.find('tr.card-row').findAll('td')[1]!.text()).toBe('2025THBIG')
    wrapper.unmount()
  })

  it('カード一覧の見出しのすぐ下にカード表があり、コスト表はその後に来る', async () => {
    const wrapper = await mountWith({
      id: 142,
      name: '八雲 紫',
      player_cards: [card142(517, 'PM2027', '飯能')],
      costs: [cost142('2025年12月コスト改定', 6, null, true)],
    })
    const text = wrapper.text()
    expect(text.indexOf('選手カード一覧')).toBeLessThan(text.indexOf('PM2027 / 飯能'))
    expect(text.indexOf('PM2027 / 飯能')).toBeLessThan(text.indexOf('コスト'))
    wrapper.unmount()
  })

  it('コスト表は、行がどのカードの値かを出す（カードの行はセット・版、既定の行は「選手の既定」）', async () => {
    const wrapper = await mountWith({
      id: 142,
      name: '八雲 紫',
      player_cards: [card142(517, 'PM2027', '飯能'), card142(530, 'PM2027', '筑紫野')],
      costs: [
        cost142('2025年12月コスト改定', 6, null, true),
        cost142('2025年12月コスト改定', 5, hanno, true),
        cost142('2025年12月コスト改定', 10, tsukushino, true),
        cost142('2024年12月コスト改定', 6, null, false),
      ],
    })
    const table = wrapper.findAll('table')[1]!
    const cells = table.findAll('tbody tr').map((r) => {
      const tds = r.findAll('td')
      return [tds[0]!.text(), tds[1]!.text(), tds[2]!.text()]
    })
    expect(cells).toEqual([
      ['2025年12月コスト改定', '選手の既定', '6'],
      ['2025年12月コスト改定', 'PM2027 / 飯能', '5'],
      ['2025年12月コスト改定', 'PM2027 / 筑紫野', '10'],
      ['2024年12月コスト改定', '選手の既定', '6'],
    ])
    expect(table.findAll('tbody tr')[0]!.classes()).toContain('cost-row-current')
    expect(table.findAll('tbody tr')[3]!.classes()).not.toContain('cost-row-current')
    wrapper.unmount()
  })

  it('古い形のレスポンス（card_set だけ・コスト行に対象なし）でも落ちずに出る', async () => {
    const wrapper = await mountWith({
      id: 1,
      name: '旧形式',
      player_cards: [{ ...mockPlayer.player_cards[0] }],
      costs: [{ cost_name: '旧', normal_cost: 3 }],
    })
    expect(wrapper.find('tr.card-row').findAll('td')[1]!.text()).toBe('2025年版')
    expect(wrapper.text()).toContain('選手の既定')
    wrapper.unmount()
  })
})
