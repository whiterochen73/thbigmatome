import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import { defineComponent, h } from 'vue'
import { createI18n } from 'vue-i18n'
import AppBar from '../AppBar.vue'
import { appBarShownTitle, appBarTitle } from '@/composables/useAppBarTitle'

vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

vi.mock('@/composables/useAuth', () => ({
  useAuth: vi.fn(() => ({
    user: { value: { id: 1, name: 'testuser', role: 'player' } },
    isCommissioner: { value: false },
    isAuthenticated: { value: true },
    loading: { value: false },
    logout: vi.fn(),
    login: vi.fn(),
    checkAuth: vi.fn(),
  })),
}))

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: { appBar: { backTo: '{label}へ戻る' } },
    en: { appBar: { backTo: 'Back to {label}' } },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' }, meta: { title: 'ホーム' } },
      { path: '/nometa', component: { template: '<div />' } },
      { path: '/login', component: { template: '<div />' } },
      { path: '/settings', component: { template: '<div />' } },
      { path: '/season/:teamId', name: 'SeasonPortal', component: { template: '<div />' } },
    ],
  })
}

// v-app-bar requires layout context — wrap in v-app
async function mountWithLayout(options: Record<string, unknown> = {}, path = '/', width = 1280) {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = createTestRouter()
  await router.push(path)
  await router.isReady()
  // 画面幅で描き分けるので、幅を決めてから vuetify を作り直す
  window.innerWidth = width
  const vuetify = createVuetify({ components, directives })

  const Wrapper = defineComponent({
    render() {
      return h(components.VApp, {}, { default: () => h(AppBar) })
    },
  })

  return mount(Wrapper, {
    global: { plugins: [vuetify, router, pinia, i18n], ...options },
  })
}

describe('AppBar', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setActivePinia(createPinia())
    appBarTitle.value = null
    i18n.global.locale.value = 'ja'
    window.innerWidth = 1024
  })

  it('マウントに成功する', async () => {
    const wrapper = await mountWithLayout()
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('一般ユーザーはコミッショナーモードトグルが表示されない', async () => {
    const wrapper = await mountWithLayout()
    await flushPromises()
    // isCommissioner=false なので shield-crown アイコンなし
    expect(wrapper.html()).not.toContain('mdi-shield-crown')
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1 / §2.2 / §4.1（画面タイトルはバーが h1 として出す。無宣言なら route.meta.title）
  describe('タイトル', () => {
    it('宣言が無い画面は route.meta.title を h1 に出し、サブタイトルも戻り先も出さない', async () => {
      const wrapper = await mountWithLayout({}, '/')
      await flushPromises()
      const heading = wrapper.find('[data-testid="app-bar-heading"]')
      expect(heading.exists()).toBe(true)
      expect(heading.find('h1').text()).toBe('ホーム')
      expect(heading.find('[data-testid="app-bar-subtitle"]').exists()).toBe(false)
      expect(heading.find('[data-testid="app-bar-back"]').exists()).toBe(false)
      expect(wrapper.findAll('h1')).toHaveLength(1)
      wrapper.unmount()
    })

    it('meta.title も宣言も無い画面はタイトルを出さず、ロゴだけを出す', async () => {
      const wrapper = await mountWithLayout({}, '/nometa', 500)
      await flushPromises()
      expect(wrapper.find('[data-testid="app-bar-heading"]').exists()).toBe(false)
      expect(wrapper.find('h1').exists()).toBe(false)
      expect(wrapper.find('.header-logo').exists()).toBe(true)
      expect(appBarShownTitle.value).toBe('')
      wrapper.unmount()
    })

    it('宣言したタイトル・サブタイトル・戻り先を出し、meta.title より優先する', async () => {
      const wrapper = await mountWithLayout({}, '/')
      await flushPromises()
      appBarTitle.value = {
        title: '豊玉',
        subtitle: 'Game 5 ・ 6月10日(水)',
        back: { to: { name: 'SeasonPortal', params: { teamId: '1' } }, label: 'シーズン' },
      }
      await flushPromises()
      const heading = wrapper.find('[data-testid="app-bar-heading"]')
      expect(heading.find('h1').text()).toBe('豊玉')
      expect(heading.find('[data-testid="app-bar-subtitle"]').text()).toBe('Game 5 ・ 6月10日(水)')
      const back = heading.find('[data-testid="app-bar-back"]')
      expect(back.attributes('href')).toBe('/season/1')
      expect(back.attributes('aria-label')).toBe('シーズンへ戻る')
      expect(back.text()).toContain('シーズン')
      expect(wrapper.text()).not.toContain('ホーム')
      i18n.global.locale.value = 'en'
      await flushPromises()
      expect(back.attributes('aria-label')).toBe('Back to シーズン')
      i18n.global.locale.value = 'ja'
      appBarTitle.value = null
      await flushPromises()
      expect(wrapper.find('h1').text()).toBe('ホーム')
      wrapper.unmount()
    })

    it('バーが出している題を appBarShownTitle に公開する（PageHeader が二重に出さないため）', async () => {
      const wrapper = await mountWithLayout({}, '/')
      await flushPromises()
      expect(appBarShownTitle.value).toBe('ホーム')
      appBarTitle.value = { title: '豊玉' }
      await flushPromises()
      expect(appBarShownTitle.value).toBe('豊玉')
      wrapper.unmount()
    })

    it('ロゴは PC で残し、スマホ幅ではタイトルを優先して隠す。高さも変わる', async () => {
      const pc = await mountWithLayout({}, '/', 1280)
      await flushPromises()
      expect(pc.find('.header-logo').exists()).toBe(true)
      expect(pc.find('h1').exists()).toBe(true)
      expect(pc.find('.v-toolbar__content').attributes('style')).toContain('height: 64px')
      pc.unmount()

      const phone = await mountWithLayout({}, '/', 390)
      await flushPromises()
      expect(phone.find('.header-logo').exists()).toBe(false)
      expect(phone.find('h1').text()).toBe('ホーム')
      expect(phone.find('.v-toolbar__content').attributes('style')).toContain('height: 56px')
      phone.unmount()
    })

    it('アカウントメニューから設定画面へ入れる', async () => {
      const wrapper = await mountWithLayout({}, '/')
      await flushPromises()
      await wrapper
        .find('button[class*="mdi-account-circle"], .mdi-account-circle')
        .trigger('click')
      await flushPromises()
      const item = document.body.querySelector('[data-testid="menu-settings"]')
      expect(item?.getAttribute('href')).toBe('/settings')
      wrapper.unmount()
    })
  })
})
