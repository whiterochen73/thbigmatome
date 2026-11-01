import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GameDetailView from '../GameDetailView.vue'
import { appBarTitle } from '@/composables/useAppBarTitle'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
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
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '1' } }),
  useRouter: () => ({ back: vi.fn() }),
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

// AsyncState（読み込み・空・失敗の出し方）が文言を引く
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

const mockGame = {
  id: 1,
  competition_id: 10,
  home_team_id: 2,
  visitor_team_id: 3,
  real_date: '2026-04-01',
  status: 'confirmed',
  source: 'test',
  at_bats: [
    {
      id: 1,
      game_id: 1,
      inning: 1,
      half: 'top',
      seq: 1,
      batter_id: 101,
      pitcher_id: 201,
      result_code: '1B',
      play_type: 'normal',
      rolls: [3, 5],
      rbi: 1,
      runners: [],
      runners_after: [],
      outs_after: 0,
      scored: true,
    },
  ],
}

describe('GameDetailView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: mockGame })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(GameDetailView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays game detail header', async () => {
    const wrapper = mount(GameDetailView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    // 題はヘッダーバー: タイトル=試合の見出し、サブタイトル=日付、戻り先=試合記録
    expect(appBarTitle.value).toEqual({
      title: '試合 #1',
      subtitle: '2026-04-01',
      back: { to: '/games', label: '試合記録' },
    })
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('戻る')
    expect(wrapper.text()).toContain('オーダー確認')
    wrapper.unmount()
    expect(appBarTitle.value).toBeNull()
  })

  it('fetches game on mount', async () => {
    mount(GameDetailView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/games/1')
  })

  it('取得に失敗してもバーの戻り先は残り、ページ内のアラートから再読み込みできる', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error('boom'))
    const wrapper = mount(GameDetailView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
      '試合データの取得に失敗しました',
    )
    expect(appBarTitle.value).toEqual({
      title: '試合 #1',
      subtitle: null,
      back: { to: '/games', label: '試合記録' },
    })
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('スコアボード')
    wrapper.unmount()
  })
})
