import { describe, it, expect, vi, beforeEach } from 'vitest'
import { nextTick } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import HomePortalView from '../HomePortalView.vue'

// Mock @/plugins/axios (unused by HomePortalView after refactor, kept for safety)
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
import { useTeamSelectionStore } from '@/stores/teamSelection'

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
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
    expect(wrapper.find('.season-portal-stub').attributes('data-team-id')).toBe('1')
  })

  it('チーム2件時: タブが表示されてチーム切り替えができること', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA, teamB])

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    // タブが表示される
    expect(wrapper.text()).toContain('チームA')
    expect(wrapper.text()).toContain('チームB')
    // SeasonPortalが表示される
    expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
  })

  it('チーム0件時: EmptyStateが表示されること', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([])

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    expect(wrapper.find('.season-portal-stub').exists()).toBe(false)
    expect(wrapper.text()).toContain('コミッショナーにお問い合わせください')
  })

  it('チームデータはuseAuth(initializeUserState)がロード済み想定でstoreから読む', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])

    const router = createTestRouter()
    mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    // HomePortalViewはaxiosを直接呼ばない（useAuthが処理済み）
    const { default: axiosPlugin } = await import('@/plugins/axios')
    const mockAxios = axiosPlugin as unknown as { get: ReturnType<typeof vi.fn> }
    expect(mockAxios.get).not.toHaveBeenCalled()
  })

  it('コミッショナーモードON時: リダイレクトせず全チームが表示されること', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])
    teamStore.setAllTeams([teamA, teamB])

    const cmStore = useCommissionerModeStore()
    cmStore.setMode(true)

    const router = createTestRouter()
    const pushSpy = vi.spyOn(router, 'push')
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    // リダイレクトしない
    expect(pushSpy).not.toHaveBeenCalled()
    // SeasonPortalが表示される
    expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
  })

  it('コミッショナーモードON + チーム2件以上: v-selectで切り替えUIが表示されること', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])
    teamStore.setAllTeams([teamA, teamB])

    const cmStore = useCommissionerModeStore()
    cmStore.setMode(true)

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    // v-selectが存在する（タブではない）
    expect(wrapper.find('.v-select').exists()).toBe(true)
    expect(wrapper.find('.v-tabs').exists()).toBe(false)
  })

  it('コミッショナーモードが遅延でtrueになった場合: チーム一覧が再読み込みされること', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])
    teamStore.setAllTeams([teamA, teamB])

    const router = createTestRouter()
    const pushSpy = vi.spyOn(router, 'push')
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, router, pinia] } })
    await flushPromises()

    // 通常モード: リダイレクトされていない、チームAのSeasonPortal表示
    expect(pushSpy).not.toHaveBeenCalled()

    // commissionerModeをtrueに変更（watch経由でチーム再読み込み）
    const store = useCommissionerModeStore()
    store.setMode(true)
    await nextTick()

    // リダイレクトしない
    expect(pushSpy).not.toHaveBeenCalled()
    // v-selectで全チーム表示
    expect(wrapper.find('.v-select').exists()).toBe(true)
  })
})
