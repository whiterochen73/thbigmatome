import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import { defineComponent, h } from 'vue'
import AppBar from '../AppBar.vue'

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

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/login', component: { template: '<div />' } },
      { path: '/settings', component: { template: '<div />' } },
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
    global: { plugins: [vuetify, router, pinia], ...options },
  })
}

describe('AppBar', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setActivePinia(createPinia())
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
})
