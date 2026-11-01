import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createMemoryHistory, createRouter } from 'vue-router'
import { createPinia } from 'pinia'
import Settings from '../Settings.vue'
import ja from '@/locales/ja.json'

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock('@/plugins/axios', () => ({
  default: {
    get: mockGet,
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const wrappers: VueWrapper[] = []
async function mountSettings(query = '') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/settings', component: Settings }],
  })
  await router.push(`/settings${query}`)
  await router.isReady()
  const wrapper = mount(Settings, { global: { plugins: [vuetify, i18n, router, createPinia()] } })
  await flushPromises()
  wrappers.push(wrapper as VueWrapper)
  return wrapper
}

beforeEach(() => {
  mockGet.mockImplementation((url: string) =>
    Promise.resolve({
      data:
        url === '/pitching-styles'
          ? [{ id: 1, name: '先発完投型', description: '最後まで投げ切る' }]
          : url === '/biorhythms'
            ? [{ id: 1, name: 'A', start_date: '2026-01-01', end_date: '2026-02-01' }]
            : [],
    }),
  )
})
afterEach(() => wrappers.splice(0).forEach((w) => w.unmount()))

// Test Basis: thbig-dugout-ui-unification-design.md §3 設定 / §2.2（タイトルはバー、本文に見出し・説明文を置かない）
describe('Settings（段 1 の見本）', () => {
  it('本文に画面タイトル（h1）と説明文を置かない。骨格は default 幅', async () => {
    const wrapper = await mountSettings()
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain(ja.settings.description)
    expect(wrapper.text()).not.toContain(ja.settings.player.description)
    expect(wrapper.find('[data-testid="page-layout"]').classes()).toContain('page-layout--default')
  })

  it('タブは全部アイコンつきで、「その他」は「コスト・日程」に改まっている', async () => {
    const wrapper = await mountSettings()
    const tabs = wrapper.findAll('.v-tab')
    expect(tabs.map((t) => t.text())).toEqual(['選手設定', 'コスト・日程', 'アカウント'])
    for (const tab of tabs) expect(tab.find('.v-icon').exists()).toBe(true)
    expect(ja.settings.tabs.squad).toBe('コスト・日程')
  })

  it('選手設定は 投手・打者・共通 の 3 つに分け、各マスタを同じ枠（MasterPanel）で出す', async () => {
    const wrapper = await mountSettings()
    const titles = (group: string) =>
      wrapper
        .find(`[data-testid="settings-group-${group}"]`)
        .findAll('[data-testid="master-panel"] h3')
        .map((h) => h.text())
    expect(titles('pitcher')).toEqual(['投手特徴', '投手特殊能力'])
    expect(titles('batter')).toEqual(['打者特徴', '打者特殊能力'])
    expect(titles('common')).toEqual(['選手タイプ設定', 'バイオリズム'])
    expect(wrapper.find('[data-testid="settings-group-pitcher"]').text()).toContain('投手')
    expect(wrapper.find('[data-testid="settings-group-common"]').text()).toContain('共通')
  })

  it('マスタの行は件数チップを持ち、閉じた状態から始まる', async () => {
    const wrapper = await mountSettings()
    const style = wrapper.find(
      '[data-testid="settings-group-pitcher"] [data-testid="master-panel"]',
    )
    expect(style.find('[data-testid="master-panel-count"]').text()).toBe('1件')
    expect(style.find('.master-panel__body').attributes('style')).toContain('display: none')
  })

  it('追加ボタンは枠（outlined）で、画面に塗りの緑を置かない（選手設定・コスト・日程）', async () => {
    for (const query of ['', '?tab=squad']) {
      const wrapper = await mountSettings(query)
      const adds = wrapper.findAll('[data-testid="master-add"]')
      expect(adds.length).toBeGreaterThan(0)
      for (const add of adds) {
        expect(add.classes()).toContain('v-btn--variant-outlined')
        expect(add.classes()).not.toContain('bg-action')
      }
      expect(wrapper.find('.bg-action').exists()).toBe(false)
    }
  })

  it('読み取り専用のマスタ（設定ファイル管理）には追加ボタンを出さない。バイオリズムだけ追加できる', async () => {
    const wrapper = await mountSettings()
    const withAdd = wrapper
      .findAll('[data-testid="master-panel"]')
      .filter((p) => p.find('[data-testid="master-add"]').exists())
      .map((p) => p.find('h3').text())
    expect(withAdd).toEqual(['バイオリズム'])
  })

  it('コスト・日程タブは 2 つのマスタを縦に並べ、最初から開いている。操作はアイコンボタン（名前つき）', async () => {
    mockGet.mockImplementation((url: string) =>
      Promise.resolve({
        data:
          url === '/costs'
            ? [{ id: 1, name: '2026コスト', start_date: null, end_date: null }]
            : url === '/schedules'
              ? [{ id: 1, name: '2026日程' }]
              : [],
      }),
    )
    const wrapper = await mountSettings('?tab=squad')
    const panels = wrapper.findAll('[data-testid="master-panel"]')
    expect(panels.map((p) => p.find('h3').text())).toEqual([
      ja.settings.cost.title,
      ja.settings.schedule.title,
    ])
    for (const p of panels) {
      expect(p.find('.master-panel__body').attributes('style') ?? '').not.toContain('display: none')
    }
    const labels = wrapper
      .findAll('.master-panel__body button[aria-label]')
      .map((b) => b.attributes('aria-label'))
    expect(labels).toEqual(
      expect.arrayContaining([
        '2026コストを編集',
        '2026コストを複製',
        '2026コストを削除',
        '2026日程を編集',
        '2026日程の日程を編集',
        '2026日程を削除',
      ]),
    )
    // 素の v-icon クリック（名前なし）を残さない
    expect(wrapper.find('.master-panel__body i.v-icon[role="button"]').exists()).toBe(false)
  })

  it('?tab= で開くタブを選ぶ', async () => {
    const wrapper = await mountSettings('?tab=account')
    expect(wrapper.find('.v-tab--selected').text()).toBe('アカウント')
  })
})
