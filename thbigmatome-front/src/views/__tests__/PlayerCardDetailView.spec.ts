import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import PlayerCardDetailView from '../PlayerCardDetailView.vue'
import { appBarTitle } from '@/composables/useAppBarTitle'

vi.mock('@/plugins/axios', () => {
  return {
    default: {
      get: vi.fn(),
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

// AsyncState（読み込み・空・失敗の出し方）が文言を引く
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

function createTestRouter(cardId = '1') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/player-cards', name: 'PlayerCards', component: { template: '<div />' } },
      {
        path: '/player-cards/:id',
        name: 'PlayerCardDetail',
        component: { template: '<div />' },
      },
    ],
  })
  router.push(`/player-cards/${cardId}`)
  return router
}

const mockCard = {
  id: 1,
  card_type: 'pitcher',
  handedness: '右',
  speed: 3,
  bunt: 5,
  steal_start: 10,
  steal_end: 10,
  injury_rate: 3,
  is_pitcher: true,
  is_relief_only: false,
  is_closer: true,
  is_switch_hitter: false,
  is_dual_wielder: false,
  starter_stamina: 6,
  relief_stamina: 2,
  biorhythm_period: '小暑',
  unique_traits: null,
  injury_traits: null,
  card_image_path: null,
  image_url: null,
  player: { id: 1, name: '博麗霊夢', number: '1' },
  card_set: { id: 1, name: 'ハチナイ2024' },
  defenses: [{ id: 10, position: 'p', range_value: 5, error_rank: 'A', throwing: null }],
  trait_list: [
    {
      id: 1,
      category: 'skill',
      name: '変化球投手',
      description: '変化球が得意',
      role: null,
      condition_name: '対左',
      condition_description: '左打者に対して',
    },
  ],
  ability_list: [],
  batting_table: [
    ['K', 'H7', '2B', 'HR'],
    ['BB', 'G3D', 'F9', 'UP'],
  ],
  pitching_table: ['1', '1', '2*', '2', '3P', '3', '3'],
}

describe('PlayerCardDetailView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(axios.get).mockResolvedValue({ data: mockCard })
  })

  it('コンポーネントがマウントされること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.2 C 型（タイトル=対象の名前、サブタイトル=補足、戻り先=「← 一覧名」）
  it('ヘッダーバーに選手名・背番号とカードセット・戻り先（選手カード）を宣言する', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(appBarTitle.value).toEqual({
      title: '博麗霊夢',
      subtitle: '#1 ・ ハチナイ2024',
      back: { to: '/player-cards', label: '選手カード' },
    })
    wrapper.unmount()
    expect(appBarTitle.value).toBeNull()
  })

  it('本文に画面独自の帯・戻るボタン・h1 を持たない（タイトルはバーだけ）', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.find('.detail-card-header').exists()).toBe(false)
    expect(wrapper.find('.detail-back-btn').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('一覧に戻る')
    expect(wrapper.find('[data-testid="card-type-chip"]').text()).toBe('投手')
    wrapper.unmount()
  })

  it('取得前・取得失敗でも戻り先は宣言され、失敗はページ内のアラート＋再読み込みで出す', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('Network Error'))
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    expect(appBarTitle.value?.back).toEqual({ to: '/player-cards', label: '選手カード' })
    await flushPromises()
    expect(appBarTitle.value?.title).toBe('選手カード詳細')
    expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
      '選手カードの取得に失敗しました',
    )
    // 再読み込みで取り直せる
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(appBarTitle.value?.title).toBe('博麗霊夢')
    wrapper.unmount()
  })

  // Test Basis: Operator 決定 2026-11-01（説明文を足さず、拡大できることはカーソルと名前で示す）
  it('カード画像: 「クリックで拡大」の文を出さず、拡大のカーソルと名前（aria-label / title）を持ち、クリックで拡大する', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: { ...mockCard, image_url: 'https://example.test/card.png' },
    })
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, {
      attachTo: document.body,
      global: { plugins: [vuetify, i18n, router] },
    })
    await flushPromises()

    expect(wrapper.text()).not.toContain('クリックで拡大')
    expect(wrapper.find('.card-img-hint').exists()).toBe(false)
    const img = wrapper.find('.card-img-clickable')
    expect(img.exists()).toBe(true)
    expect(img.attributes('aria-label')).toBe('拡大')
    expect(img.attributes('title')).toBe('拡大')
    expect(img.attributes('role')).toBe('button')
    expect(img.attributes('tabindex')).toBe('0')

    // カーソルは scoped CSS なので、ソースの宣言で固定する
    const css = readFileSync(resolve(__dirname, '../PlayerCardDetailView.vue'), 'utf-8').match(
      /\.card-img-clickable \{[^}]*\}/,
    )![0]
    expect(css).toContain('cursor: zoom-in')

    // クリックで拡大する動作はそのまま
    expect(document.body.querySelector('.v-dialog')).toBeNull()
    await img.trigger('click')
    await flushPromises()
    expect(document.body.querySelector('.v-dialog')).not.toBeNull()
    wrapper.unmount()
  })

  it('カード画像: キーボード（Enter / Space）でも拡大できる', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: { ...mockCard, image_url: 'https://example.test/card.png' },
    })
    const router = createTestRouter()
    await router.isReady()
    for (const key of ['Enter', ' ']) {
      const wrapper = mount(PlayerCardDetailView, {
        attachTo: document.body,
        global: { plugins: [vuetify, i18n, router] },
      })
      await flushPromises()
      expect(document.body.querySelector('.v-dialog .v-overlay__content')).toBeNull()
      await wrapper.find('.card-img-clickable').trigger('keydown', { key })
      await flushPromises()
      expect(document.body.querySelector('.v-dialog .v-overlay__content'), key).not.toBeNull()
      wrapper.unmount()
    }
  })

  it('基本情報セクションが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('基本情報')
    expect(wrapper.text()).toContain('走力')
    expect(wrapper.text()).toContain('怪我レベル')
  })

  it('バイオリズムが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('バイオリズム')
    expect(wrapper.text()).toContain('小暑')
  })

  it('バントが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('バント')
  })

  it('利き腕/打席が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('利き腕/打席')
    expect(wrapper.text()).toContain('右')
  })

  it('クローザーチップが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('クローザー')
  })

  it('守備値セクションが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('守備値')
    expect(wrapper.text()).toContain('ポジション')
  })

  it('特徴セクションが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('特徴')
    expect(wrapper.text()).toContain('変化球投手')
  })

  it('特徴に条件分岐（対左/変化球投手）が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('対左')
  })

  it('打撃結果表が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('打撃結果表')
    expect(wrapper.text()).toContain('出目')
  })

  it('投球P列が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('投球P列')
  })

  it('基本情報の編集ボタンが存在すること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    const editBtns = wrapper.findAll('.v-btn').filter((b) => b.text().includes('編集'))
    expect(editBtns.length).toBeGreaterThanOrEqual(1)
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('選手カードの取得に失敗しました')
  })

  it('batting_tableが空のとき打撃結果表セクションが表示されないこと', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: { ...mockCard, batting_table: [] },
    })
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, i18n, router] } })
    await flushPromises()
    expect(wrapper.text()).not.toContain('打撃結果表')
  })
})
