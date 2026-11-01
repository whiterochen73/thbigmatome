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
