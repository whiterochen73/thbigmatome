import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GameLineupView from '../GameLineupView.vue'
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
  useRoute: () => ({ params: { id: '42' } }),
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

const mockLineupData = {
  lineup: [
    {
      id: 1,
      player_card_id: 101,
      player_name: '博麗霊夢',
      batting_order: 1,
      position: 'CF',
      role: 'starter',
      is_dh_pitcher: false,
      is_reliever: false,
    },
    {
      id: 2,
      player_card_id: 102,
      player_name: '霧雨魔理沙',
      batting_order: 2,
      position: 'P',
      role: 'starter',
      is_dh_pitcher: true,
      is_reliever: false,
    },
    {
      id: 3,
      player_card_id: 103,
      player_name: '十六夜咲夜',
      batting_order: null,
      position: 'RP',
      role: 'bench',
      is_dh_pitcher: false,
      is_reliever: true,
    },
    {
      id: 4,
      player_card_id: 104,
      player_name: '古明地こいし',
      batting_order: null,
      position: 'SS',
      role: 'off',
      is_dh_pitcher: false,
      is_reliever: false,
    },
    {
      id: 5,
      player_card_id: 105,
      player_name: '東風谷早苗',
      batting_order: null,
      position: 'SP',
      role: 'designated_player',
      is_dh_pitcher: false,
      is_reliever: false,
    },
  ],
}

async function mountView() {
  ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: mockLineupData })
  const wrapper = mount(GameLineupView, {
    global: {
      plugins: [vuetify, i18n],
    },
  })
  await flushPromises()
  return wrapper
}

describe('GameLineupView.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('コンポーネントがマウントできる', async () => {
    const wrapper = await mountView()
    expect(wrapper.exists()).toBe(true)
  })

  it('正しいURLにAPIコールが行われる', async () => {
    await mountView()
    expect(axios.get).toHaveBeenCalledWith('/games/42/lineup')
  })

  it('スタメン選手が表示される', async () => {
    const wrapper = await mountView()
    const text = wrapper.text()
    expect(text).toContain('博麗霊夢')
    expect(text).toContain('霧雨魔理沙')
  })

  it('is_dh_pitcher=trueの選手にP/DHチップが表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('P/DH')
    // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b3-15
    const chips = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text() === 'P/DH')
    expect(chips.length).toBeGreaterThan(0)
    for (const chip of chips) {
      expect(chip.props('color')).toBe('tag-pitcher')
      expect(chip.props('variant')).toBe('flat')
    }
  })

  it('ベンチ選手が表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('十六夜咲夜')
  })

  it('is_reliever=trueのベンチ選手に（中継）が表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('（中継）')
  })

  it('オフの選手が表示される', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('古明地こいし')
  })

  it('指定選手が表示され（指定）ラベルが付く', async () => {
    const wrapper = await mountView()
    expect(wrapper.text()).toContain('東風谷早苗')
    expect(wrapper.text()).toContain('（指定）')
  })

  it('ヘッダーバー: タイトル=オーダー確認、サブタイトル=試合 #ID、戻り先=試合詳細（行き先固定）', async () => {
    const wrapper = await mountView()
    expect(appBarTitle.value).toEqual({
      title: 'オーダー確認',
      subtitle: '試合 #42',
      back: { to: { name: '試合詳細', params: { id: '42' } }, label: '試合詳細' },
    })
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('試合詳細へ戻る')
    wrapper.unmount()
    expect(appBarTitle.value).toBeNull()
  })

  it('取得に失敗した時はページ内のアラートを出し、再読み込みで取り直す', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error('boom'))
    const wrapper = mount(GameLineupView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
      'オーダーデータの取得に失敗しました',
    )
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: mockLineupData })
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('博麗霊夢')
    wrapper.unmount()
  })
})
