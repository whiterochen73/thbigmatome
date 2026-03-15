import { describe, it, expect, vi, beforeEach } from 'vitest'
import { nextTick } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import HomePortalView from '../HomePortalView.vue'

// Mock @/plugins/axios
vi.mock('@/plugins/axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  }
  return { default: mockAxios }
})

// Stub SeasonPortal to avoid its complex dependencies
vi.mock('../SeasonPortal.vue', () => ({
  default: {
    name: 'SeasonPortal',
    props: ['teamId'],
    template: '<div class="season-portal-stub" :data-team-id="teamId" />',
  },
}))

import { useCommissionerModeStore } from '@/stores/commissionerMode'
import axiosPlugin from '@/plugins/axios'
const mockAxios = axiosPlugin as unknown as { get: ReturnType<typeof vi.fn> }

const vuetify = createVuetify({ components, directives })

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      {
        path: '/commissioner/dashboard',
        name: 'CommissionerDashboard',
        component: { template: '<div />' },
      },
    ],
  })
}

const teamA = {
  id: 1,
  name: 'チームA',
  short_name: 'A',
  is_active: true,
  has_season: true,
  team_type: 'normal' as const,
}
const teamB = {
  id: 2,
  name: 'チームB',
  short_name: 'B',
  is_active: true,
  has_season: true,
  team_type: 'normal' as const,
}

describe('HomePortalView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('チーム1件時: SeasonPortalがインライン表示されること', async () => {
    mockAxios.get.mockResolvedValueOnce({ data: [teamA] })
    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, createPinia()] } })
    await flushPromises()

    expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
    expect(wrapper.find('.season-portal-stub').attributes('data-team-id')).toBe('1')
  })

  it('チーム2件時: タブが表示されてチーム切り替えができること', async () => {
    mockAxios.get.mockResolvedValueOnce({ data: [teamA, teamB] })
    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, createPinia()] } })
    await flushPromises()

    // タブが表示される
    expect(wrapper.text()).toContain('チームA')
    expect(wrapper.text()).toContain('チームB')
    // SeasonPortalが表示される
    expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
  })

  it('チーム0件時: EmptyStateが表示されること', async () => {
    mockAxios.get.mockResolvedValueOnce({ data: [] })
    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, createPinia()] } })
    await flushPromises()

    expect(wrapper.find('.season-portal-stub').exists()).toBe(false)
    expect(wrapper.text()).toContain('コミッショナーにお問い合わせください')
  })

  it('my_teamsが/users/me/teamsで取得されること（二重プレフィックスなし）', async () => {
    mockAxios.get.mockResolvedValueOnce({ data: [teamA] })
    const router = createTestRouter()
    mount(HomePortalView, { global: { plugins: [vuetify, router, createPinia()] } })
    await flushPromises()

    expect(mockAxios.get).toHaveBeenCalledWith('/users/me/teams')
    expect(mockAxios.get).not.toHaveBeenCalledWith('/api/v1/users/me/teams')
  })

  it('コミッショナーモードON時: my_teamsを取得せずリダイレクトされること', async () => {
    localStorage.setItem('commissionerMode', 'true')
    const router = createTestRouter()
    const pushSpy = vi.spyOn(router, 'push')
    mount(HomePortalView, { global: { plugins: [vuetify, router, createPinia()] } })
    await flushPromises()

    expect(pushSpy).toHaveBeenCalledWith('/commissioner/dashboard')
    expect(mockAxios.get).not.toHaveBeenCalled()
  })

  it('コミッショナーモードが遅延でtrueになった場合もリダイレクトされること', async () => {
    // チーム0件のコミッショナーユーザー: API応答後にAppBarのwatchEffectがcommissionerModeをtrueにするケース
    mockAxios.get.mockResolvedValueOnce({ data: [] })
    const router = createTestRouter()
    const pushSpy = vi.spyOn(router, 'push')
    const pinia = createPinia()
    setActivePinia(pinia)
    mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    // API応答後もcommissionerModeがfalseのためリダイレクトされていない
    expect(pushSpy).not.toHaveBeenCalled()

    // AppBarのwatchEffectをシミュレート: commissionerModeをtrueに変更
    const store = useCommissionerModeStore()
    store.setMode(true)
    await nextTick()

    expect(pushSpy).toHaveBeenCalledWith('/commissioner/dashboard')
  })
})
