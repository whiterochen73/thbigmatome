import { describe, it, expect, vi, beforeEach } from 'vitest'
import { ref } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
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

// Stub CommissionerDashboard
vi.mock('@/components/commissioner/CommissionerDashboard.vue', () => ({
  default: {
    name: 'CommissionerDashboard',
    template: '<div class="commissioner-dashboard-stub" />',
  },
}))

// Mock useAuth
const mockIsCommissioner = ref(false)
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    isCommissioner: mockIsCommissioner,
    user: { value: null },
    login: vi.fn(),
    logout: vi.fn(),
    checkAuth: vi.fn(),
  }),
}))

import { useTeamSelectionStore } from '@/stores/teamSelection'

const vuetify = createVuetify({ components, directives })

// AsyncState（読み込み・空・失敗の出し方）が文言を引く
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

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
    mockIsCommissioner.value = false
  })

  it('チーム1件時: SeasonPortalがインライン表示されること', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, i18n, router, pinia] } })
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
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, i18n, router, pinia] } })
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
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, i18n, router, pinia] } })
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
    mount(HomePortalView, { global: { plugins: [vuetify, i18n, router, pinia] } })
    await flushPromises()

    // HomePortalViewはaxiosを直接呼ばない（useAuthが処理済み）
    const { default: axiosPlugin } = await import('@/plugins/axios')
    const mockAxios = axiosPlugin as unknown as { get: ReturnType<typeof vi.fn> }
    expect(mockAxios.get).not.toHaveBeenCalled()
  })

  it('コミッショナー時: CommissionerDashboardが直接表示されること（タブ非表示）', async () => {
    mockIsCommissioner.value = true
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, i18n, router, pinia] } })
    await flushPromises()

    // リリース向けUI整理: タブは非表示、ダッシュボードを直接表示
    expect(wrapper.find('.commissioner-dashboard-stub').exists()).toBe(true)
    expect(wrapper.text()).not.toContain('自チーム')
    expect(wrapper.text()).not.toContain('全チーム管理')
  })

  it('非コミッショナーにはCommissionerDashboardが表示されないこと', async () => {
    mockIsCommissioner.value = false
    const pinia = createPinia()
    setActivePinia(pinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([teamA])

    const router = createTestRouter()
    const wrapper = mount(HomePortalView, { global: { plugins: [vuetify, i18n, router, pinia] } })
    await flushPromises()

    expect(wrapper.find('.commissioner-dashboard-stub').exists()).toBe(false)
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（本文に画面タイトルを置かない）・§4.3（埋め込みの SeasonPortal は自分の骨格を持つ）
  describe('骨格', () => {
    async function mountHome(teams: (typeof teamA)[], commissioner = false) {
      mockIsCommissioner.value = commissioner
      const pinia = createPinia()
      setActivePinia(pinia)
      useTeamSelectionStore().setMyTeams(teams)
      const router = createTestRouter()
      const wrapper = mount(HomePortalView, {
        global: { plugins: [vuetify, i18n, router, pinia] },
      })
      await flushPromises()
      return wrapper
    }

    it('コミッショナー: 骨格（PageLayout）の中にダッシュボードを置き、h1 は持たない', async () => {
      const wrapper = await mountHome([teamA], true)
      const layouts = wrapper.findAll('[data-testid="page-layout"]')
      expect(layouts).toHaveLength(1)
      expect(layouts[0].find('.commissioner-dashboard-stub').exists()).toBe(true)
      expect(wrapper.find('h1').exists()).toBe(false)
      expect(wrapper.find('.v-container').exists()).toBe(false)
    })

    it('チーム1件: SeasonPortal が自分の骨格を持つので、ホームは骨格で二重に包まない', async () => {
      const wrapper = await mountHome([teamA])
      expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
      expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(false)
    })

    it('チーム2件: タブだけの帯（骨格）の下に SeasonPortal を置く', async () => {
      const wrapper = await mountHome([teamA, teamB])
      const layout = wrapper.find('[data-testid="page-layout"]')
      expect(layout.find('[data-testid="page-tabs"]').exists()).toBe(true)
      expect(layout.find('.season-portal-stub').exists()).toBe(false)
      expect(wrapper.find('.season-portal-stub').exists()).toBe(true)
    })

    it('チーム0件: 空状態（EmptyState）で次の一手（コミッショナーへの問い合わせ）を示す', async () => {
      const wrapper = await mountHome([])
      expect(wrapper.find('[data-testid="state-empty"]').text()).toContain(
        'チームが割り当てられていません',
      )
      expect(wrapper.find('[data-testid="state-empty"]').text()).toContain(
        'コミッショナーにお問い合わせください',
      )
    })
  })
})
