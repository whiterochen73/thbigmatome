import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import PlayerCardDetailView from '../PlayerCardDetailView.vue'

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
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('タイトルが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('選手カード詳細')
  })

  it('選手名が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('博麗霊夢')
  })

  it('カードセット名が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('ハチナイ2024')
  })

  it('基本情報セクションが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('基本情報')
    expect(wrapper.text()).toContain('走力')
    expect(wrapper.text()).toContain('怪我レベル')
  })

  it('バイオリズムが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('バイオリズム')
    expect(wrapper.text()).toContain('小暑')
  })

  it('バントが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('バント')
  })

  it('利き腕/打席が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('利き腕/打席')
    expect(wrapper.text()).toContain('右')
  })

  it('クローザーチップが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('クローザー')
  })

  it('守備値セクションが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('守備値')
    expect(wrapper.text()).toContain('ポジション')
  })

  it('特徴セクションが表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('特徴')
    expect(wrapper.text()).toContain('変化球投手')
  })

  it('特徴に条件分岐（対左/変化球投手）が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('対左')
  })

  it('打撃結果表が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('打撃結果表')
    expect(wrapper.text()).toContain('出目')
  })

  it('投球P列が表示されること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('投球P列')
  })

  it('基本情報の編集ボタンが存在すること', async () => {
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    const editBtns = wrapper.findAll('.v-btn').filter((b) => b.text().includes('編集'))
    expect(editBtns.length).toBeGreaterThanOrEqual(1)
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('選手カードの取得に失敗しました')
  })

  it('batting_tableが空のとき打撃結果表セクションが表示されないこと', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: { ...mockCard, batting_table: [] },
    })
    const router = createTestRouter()
    await router.isReady()
    const wrapper = mount(PlayerCardDetailView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).not.toContain('打撃結果表')
  })
})
