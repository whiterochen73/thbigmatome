import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import CompetitionsView from '../commissioner/CompetitionsView.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
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
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))

const { mockPush } = vi.hoisted(() => ({ mockPush: vi.fn() }))
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush }),
  useRoute: () => ({ params: {}, query: {} }),
}))

import axios from 'axios'
import { chooseRowMenuItem, stackedLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

describe('CompetitionsView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(CompetitionsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（画面タイトルはヘッダーバーが持つ。本文に置かない）
  it('画面タイトルを本文に持たず、骨格（PageLayout）で描く', async () => {
    const wrapper = mount(CompetitionsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('大会管理')
  })

  it('fetches competitions on mount', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [
        { id: 1, name: '春季大会', year: 2026, competition_type: 'tournament', entry_count: 8 },
      ],
    })
    mount(CompetitionsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/competitions')
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（<600px は縦積み。1 行 = 名前＋要点 2 つ＋操作）/ §4.2 段 4
describe('CompetitionsView 表のスマホ対応（段 4）', () => {
  beforeEach(() => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [
        { id: 1, name: '春季大会', year: 2026, competition_type: 'tournament', entry_count: 8 },
      ],
    })
  })

  it('縦積み: ID=lead・大会名=title・年度=sub1・種別=sub2・操作=act', async () => {
    const wrapper = mount(CompetitionsView, { global: { plugins: [i18n, vuetify] } })
    await flushPromises()
    expect(stackedLayout(wrapper)).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: { id: 'lead', name: 'title', year: 'sub1', competition_type: 'sub2', actions: 'act' },
    })
  })

  it('操作が 3 つあるので、PC はアイコン 3 つ（スマホでは隠す印つき）、スマホは同じ 3 操作の操作メニュー', async () => {
    const wrapper = mount(CompetitionsView, {
      attachTo: document.body,
      global: { plugins: [i18n, vuetify] },
    })
    await flushPromises()
    const full = wrapper.find('.row-actions.row-actions--full')
    expect(full.findAll('button').map((b) => b.attributes('aria-label'))).toEqual([
      '春季大会を編集',
      '春季大会のロスター管理',
      '春季大会を削除',
    ])
    const menu = wrapper.find('.row-menu [data-testid="row-menu"]')
    expect(menu.attributes('aria-label')).toBe('春季大会の操作')
    await menu.trigger('click')
    await flushPromises()
    const items = [...document.body.querySelectorAll('.v-list-item')].map((i) =>
      i.textContent?.trim(),
    )
    expect(items).toEqual(['編集', 'ロスター管理', '削除'])
    wrapper.unmount()
  })
})

// Test Basis: 操作メニューの各項目は、PC のアイコンボタンと同じ操作を呼ぶ（項目の取り違えを固定する。subtask_1791u の warning）
describe('CompetitionsView 操作メニューの各項目', () => {
  const mountMenu = async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [
        { id: 7, name: '春季大会', year: 2026, competition_type: 'tournament', entry_count: 8 },
      ],
    })
    ;(axios.delete as ReturnType<typeof vi.fn>).mockResolvedValue({ data: {} })
    return mount(CompetitionsView, {
      attachTo: document.body,
      global: { plugins: [i18n, vuetify] },
    })
  }

  beforeEach(() => {
    vi.clearAllMocks()
    vi.stubGlobal(
      'confirm',
      vi.fn(() => true),
    )
  })
  afterEach(() => {
    document.body.innerHTML = ''
    vi.unstubAllGlobals()
  })

  it('編集 → 大会編集のダイアログを開く（削除・ロスターは呼ばない）', async () => {
    const wrapper = await mountMenu()
    await flushPromises()
    await chooseRowMenuItem(wrapper, '編集')
    expect(document.body.textContent).toContain('大会編集')
    expect(axios.delete).not.toHaveBeenCalled()
    expect(mockPush).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it('ロスター管理 → 大会ロスターへ遷移する（その大会の id で）', async () => {
    const wrapper = await mountMenu()
    await flushPromises()
    await chooseRowMenuItem(wrapper, 'ロスター管理')
    expect(mockPush).toHaveBeenCalledWith({
      name: 'CompetitionRoster',
      params: { id: 7, teamId: 7 },
    })
    expect(axios.delete).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it('削除 → 確認のあとその大会を DELETE する（ダイアログ・遷移は呼ばない）', async () => {
    const wrapper = await mountMenu()
    await flushPromises()
    await chooseRowMenuItem(wrapper, '削除')
    expect(axios.delete).toHaveBeenCalledWith('/competitions/7')
    expect(document.body.textContent).not.toContain('大会編集')
    expect(mockPush).not.toHaveBeenCalled()
    wrapper.unmount()
  })
})
