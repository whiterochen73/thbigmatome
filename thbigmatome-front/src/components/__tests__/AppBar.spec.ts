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
import { appBarBreadcrumbs } from '@/composables/useAppBarBreadcrumbs'

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

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      seasonPortal: { title: 'シーズンポータル' },
      gameDay: { breadcrumbs: { label: 'ぱんくず' } },
    },
    en: {
      seasonPortal: { title: 'Season Portal' },
      gameDay: { breadcrumbs: { label: 'Breadcrumbs' } },
    },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/login', component: { template: '<div />' } },
      { path: '/settings', component: { template: '<div />' } },
      { path: '/season/:teamId', name: 'SeasonPortal', component: { template: '<div />' } },
    ],
  })
}

// v-app-bar requires layout context — wrap in v-app
function mountWithLayout(options: Record<string, unknown> = {}) {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = createTestRouter()

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
    appBarBreadcrumbs.value = null
    i18n.global.locale.value = 'ja'
  })

  it('マウントに成功する', async () => {
    const wrapper = mountWithLayout()
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('一般ユーザーはコミッショナーモードトグルが表示されない', async () => {
    const wrapper = mountWithLayout()
    await flushPromises()
    // isCommissioner=false なので shield-crown アイコンなし
    expect(wrapper.html()).not.toContain('mdi-shield-crown')
  })

  // Test Basis: subtask_1783p Operator 要望 1（2026-10-31）
  it('ぱんくずのないページは従来のロゴと操作だけを出し、登録時はリンク・チーム・Game N・日付を出す', async () => {
    const wrapper = mountWithLayout()
    await flushPromises()
    expect(wrapper.find('[data-testid="app-bar-breadcrumbs"]').exists()).toBe(false)
    expect(wrapper.find('.header-logo').exists()).toBe(true)
    appBarBreadcrumbs.value = {
      seasonPortalRoute: { name: 'SeasonPortal', params: { teamId: '1' } },
      teamName: '豊玉',
      gameNumber: 5,
      date: '6月10日(水)',
    }
    await flushPromises()
    const crumbs = wrapper.find('[data-testid="app-bar-breadcrumbs"]')
    expect(crumbs.text()).toContain('シーズンポータル')
    expect(crumbs.text()).toContain('豊玉')
    expect(crumbs.text()).toContain('Game 5')
    expect(crumbs.text()).toContain('6月10日(水)')
    expect(crumbs.find('a').attributes('href')).toBe('/season/1')
    expect(crumbs.attributes('aria-label')).toBe('ぱんくず')
    expect(crumbs.find('a').attributes('aria-label')).toBe('シーズンポータル')
    expect(crumbs.find('.app-bar-breadcrumbs__back').exists()).toBe(true)
    i18n.global.locale.value = 'en'
    await flushPromises()
    expect(crumbs.attributes('aria-label')).toBe('Breadcrumbs')
    i18n.global.locale.value = 'ja'
    await flushPromises()
    appBarBreadcrumbs.value = { ...appBarBreadcrumbs.value!, gameNumber: null }
    await flushPromises()
    expect(crumbs.text()).not.toContain('Game 5')
    expect(crumbs.text()).toContain('6月10日(水)')
    appBarBreadcrumbs.value = null
    await flushPromises()
    expect(wrapper.find('[data-testid="app-bar-breadcrumbs"]').exists()).toBe(false)
    wrapper.unmount()
  })
})
