import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import CostAssignment from '../CostAssignment.vue'
import ja from '@/locales/ja.json'
import { appBarTitle } from '@/composables/useAppBarTitle'

const { mockShowSnackbar } = vi.hoisted(() => ({ mockShowSnackbar: vi.fn() }))

vi.mock('@/plugins/axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: mockShowSnackbar }),
}))

import axios from '@/plugins/axios'
import { scrollLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState, costAssignment: ja.costAssignment } },
})

const costs = [{ id: 100, name: 'コスト表1', start_date: '2020-01-01', end_date: null }]
const assignments = [
  {
    id: 1,
    number: '10',
    name: '博麗霊夢',
    player_types: [],
    available_cost_types: ['normal_cost'],
    normal_cost: 5,
  },
]

function mockApi(playersImpl: () => Promise<{ data: unknown }>) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url === '/costs') return Promise.resolve({ data: costs })
    if (url.startsWith('/cost_assignments')) return playersImpl()
    return Promise.resolve({ data: [] })
  })
}

async function mountView() {
  const wrapper = mount(CostAssignment, { global: { plugins: [vuetify, i18n] } })
  await flushPromises()
  return wrapper
}

describe('CostAssignment', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    appBarTitle.value = null
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1・§2.2 A 型（題はバーの route.meta.title。本文に題を置かない）
  it('骨格（PageLayout wide）の中にカードを置き、本文に題の見出しを持たない', async () => {
    mockApi(() => Promise.resolve({ data: assignments }))
    const wrapper = await mountView()
    expect(wrapper.find('[data-testid="page-layout"]').classes()).toContain('page-layout--wide')
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.find('.v-card-title').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('コスト登録')
    // A 型はバーに宣言しない（route.meta.title がバーに出る）
    expect(appBarTitle.value).toBeNull()
    expect(wrapper.text()).toContain('博麗霊夢')
    expect(wrapper.text()).toContain('保存')
  })

  // cmd_1902: variant が無く帯のチーム名だけの完走カードも、カード別の行には版の印が出る
  it('カード別の行には version_label（無ければ variant）の印が出て、既定の行には出ない', async () => {
    mockApi(() =>
      Promise.resolve({
        data: [
          { ...assignments[0], player_card_id: null, variant: null, version_label: null },
          { ...assignments[0], player_card_id: 11, variant: null, version_label: '永山' },
          { ...assignments[0], player_card_id: 12, variant: '飯能', version_label: '飯能' },
          { ...assignments[0], player_card_id: 13, variant: 'エイプリル' },
        ],
      }),
    )
    const wrapper = await mountView()
    const chips = wrapper.findAll('tbody tr').map((r) => r.findAll('.v-chip').map((c) => c.text()))
    expect(chips).toEqual([[], ['永山'], ['飯能'], ['エイプリル']])
  })

  it('選手の取得に失敗した時はページ内のアラートを出し（スナックバーでなく）、再読み込みで取り直す', async () => {
    let fail = true
    mockApi(() => {
      if (fail) {
        fail = false
        return Promise.reject(new Error('boom'))
      }
      return Promise.resolve({ data: assignments })
    })
    const wrapper = await mountView()
    expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
      '選手情報の取得に失敗しました',
    )
    expect(mockShowSnackbar).not.toHaveBeenCalled()
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('博麗霊夢')
  })

  it('保存の成否はスナックバーで出す', async () => {
    mockApi(() => Promise.resolve({ data: assignments }))
    vi.mocked(axios.post).mockResolvedValueOnce({ data: {} })
    const wrapper = await mountView()
    const save = wrapper.findAllComponents(components.VBtn).find((b) => b.text() === '保存')!
    expect(save.props('color')).toBe('action')
    expect(save.props('variant')).toBe('flat')
    await save.trigger('click')
    await flushPromises()
    expect(axios.post).toHaveBeenCalledTimes(1)
    expect(mockShowSnackbar).toHaveBeenCalledWith('コスト一覧を保存しました', 'success')
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（列を落とせない表は縦積みにせず横スクロール、先頭の名前列を固定）/ §2.7（状態）/ §4.2 段 4
describe('CostAssignment 表のスマホ対応と状態（段 4）', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('入力欄の並ぶ 9 列の表なので縦積みにせず、選手名の列を固定して横スクロール', async () => {
    mockApi(() => Promise.resolve({ data: assignments }))
    const wrapper = await mountView()
    expect(scrollLayout(wrapper, 'name')).toEqual({
      mobileBreakpoint: undefined,
      rows: false,
      fixedKeys: ['name'],
      allHaveMinWidth: true,
    })
  })

  it('取得中はスケルトン（空状態を出さない）、0 件なら空状態', async () => {
    mockApi(() => new Promise(() => {}))
    const loading = await mountView()
    expect(loading.find('[data-testid="state-loading"]').exists()).toBe(true)
    expect(loading.find('[data-testid="state-empty"]').exists()).toBe(false)

    mockApi(() => Promise.resolve({ data: [] }))
    const empty = await mountView()
    expect(empty.find('[data-testid="state-empty"]').text()).toContain('選手がいません')
  })
})
