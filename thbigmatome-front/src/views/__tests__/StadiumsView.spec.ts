import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import StadiumsView from '../commissioner/StadiumsView.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
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
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))

import axios from 'axios'
import { stackedLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

describe('StadiumsView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(StadiumsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面タイトルはヘッダーバーが持つ。本文に置かない）
  it('画面タイトルを本文に持たず、骨格（PageLayout）で描く', async () => {
    const wrapper = mount(StadiumsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('球場管理')
  })

  it('fetches stadiums on mount', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [{ id: 1, name: '甲子園', code: 'koushien', indoor: false, up_table_ids: [] }],
    })
    mount(StadiumsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/stadiums')
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（<600px は縦積み。1 行 = 名前＋要点 2 つ＋操作）/ §4.2 段 4
describe('StadiumsView 表のスマホ対応（段 4）', () => {
  it('縦積み: ID=lead・球場名=title・コード=sub1・屋内=sub2・操作=act。編集は .row-actions のアイコンボタン', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [{ id: 1, name: '甲子園', code: 'koushien', indoor: false, up_table_ids: [] }],
    })
    const wrapper = mount(StadiumsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(stackedLayout(wrapper)).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: { id: 'lead', name: 'title', code: 'sub1', indoor: 'sub2', actions: 'act' },
    })
    expect(wrapper.find('.row-actions button').attributes('aria-label')).toBe('甲子園を編集')
  })
})
