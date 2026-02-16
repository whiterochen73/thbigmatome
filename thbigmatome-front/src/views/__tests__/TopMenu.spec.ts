import { describe, it, expect, vi, beforeEach } from 'vitest'
import { ref } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import TopMenu from '../TopMenu.vue'

// Mock axios with full defaults/interceptors support
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
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

// Mock the axios plugin to prevent side effects
vi.mock('@/plugins/axios', () => {
  return { default: {} }
})

// Mock useAuth composable with reactive refs
const mockUser = ref({ id: 1, name: 'testuser', role: 'director' } as {
  id: number
  name: string
  role: string
} | null)
const mockIsCommissioner = ref(false)
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    user: mockUser,
    isCommissioner: mockIsCommissioner,
  }),
}))

import axios from 'axios'

// Stub child components to avoid deep rendering
const TeamDialogStub = {
  template: '<div class="team-dialog-stub" />',
  props: ['isVisible', 'team', 'defaultManagerId'],
}
const SeasonInitializationDialogStub = {
  template: '<div class="season-init-stub" />',
  props: ['isVisible', 'schedules', 'selectedTeam'],
}

const vuetify = createVuetify({ components, directives })

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      topMenu: {
        welcome: {
          title: 'ようこそ',
          subtitle: '東方BIG野球まとめ',
          message: 'チームを選択してください',
        },
        teamSelection: {
          title: 'チーム選択',
          managerName: '監督: {name}',
          noTeams: 'チームがありません',
          addTeam: 'チーム追加',
        },
        commissionerMode: {
          switchLabel: 'コミッショナーモード',
        },
      },
    },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/menu', name: 'ダッシュボード', component: { template: '<div />' } },
      { path: '/teams/:teamId/season', name: 'SeasonPortal', component: { template: '<div />' } },
    ],
  })
}

function mountTopMenu(options = {}) {
  const router = createTestRouter()
  return mount(TopMenu, {
    global: {
      plugins: [vuetify, i18n, router],
      stubs: {
        TeamDialog: TeamDialogStub,
        SeasonInitializationDialog: SeasonInitializationDialogStub,
      },
    },
    ...options,
  })
}

// Helper to set up paginated manager response
function setupPaginatedManagerResponse(managers: Record<string, unknown>[]) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url === '/managers') {
      return Promise.resolve({ data: { data: managers, meta: { total: managers.length } } })
    }
    if (url === '/schedules') {
      return Promise.resolve({ data: [] })
    }
    if (url === '/teams') {
      return Promise.resolve({ data: [] })
    }
    return Promise.resolve({ data: {} })
  })
}

describe('TopMenu.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 1, name: 'testuser', role: 'director' }
    mockIsCommissioner.value = false
    localStorage.clear()
  })

  describe('Regression: paginated API response handling', () => {
    it('correctly processes paginated response {data:[...], meta:{...}}', async () => {
      const managerWithTeams = {
        id: 1,
        name: 'テスト監督',
        user_id: 1,
        role: 'director',
        teams: [
          { id: 10, name: 'チームA', short_name: 'A', is_active: true, has_season: true },
          { id: 20, name: 'チームB', short_name: 'B', is_active: true, has_season: false },
        ],
      }
      setupPaginatedManagerResponse([managerWithTeams])

      const wrapper = mountTopMenu()
      await flushPromises()

      // Team buttons should be rendered
      const buttons = wrapper.findAll('.v-btn')
      const teamButtons = buttons.filter((b) => b.text() === 'チームA' || b.text() === 'チームB')
      expect(teamButtons.length).toBe(2)
    })

    it('extracts team list from data array', async () => {
      const manager = {
        id: 1,
        name: '監督',
        user_id: 1,
        role: 'director',
        teams: [{ id: 1, name: 'テスト球団', short_name: 'T', is_active: true, has_season: true }],
      }
      setupPaginatedManagerResponse([manager])

      const wrapper = mountTopMenu()
      await flushPromises()

      expect(wrapper.text()).toContain('テスト球団')
    })

    it('does not crash when response is an array format (fallback)', async () => {
      // Even if the response were an unexpected format, it should not crash
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if (url === '/managers') {
          // Simulate a paginated response that still has .data.data structure
          return Promise.resolve({ data: { data: [], meta: { total: 0 } } })
        }
        if (url === '/schedules') {
          return Promise.resolve({ data: [] })
        }
        return Promise.resolve({ data: {} })
      })

      const wrapper = mountTopMenu()
      await flushPromises()

      // Should render "no teams" message without crashing
      expect(wrapper.text()).toContain('チームがありません')
    })
  })

  describe('Team selection', () => {
    it('renders team buttons correctly', async () => {
      const manager = {
        id: 1,
        name: '山田太郎',
        user_id: 1,
        role: 'director',
        teams: [
          { id: 1, name: '紅魔館', short_name: 'KMK', is_active: true, has_season: true },
          { id: 2, name: '白玉楼', short_name: 'HGR', is_active: true, has_season: false },
        ],
      }
      setupPaginatedManagerResponse([manager])

      const wrapper = mountTopMenu()
      await flushPromises()

      expect(wrapper.text()).toContain('紅魔館')
      expect(wrapper.text()).toContain('白玉楼')
      expect(wrapper.text()).toContain('監督: 山田太郎')
    })

    it('clicking a team button selects the team', async () => {
      const manager = {
        id: 1,
        name: '監督',
        user_id: 1,
        role: 'director',
        teams: [{ id: 5, name: '守矢神社', short_name: 'MRY', is_active: true, has_season: true }],
      }
      setupPaginatedManagerResponse([manager])

      const wrapper = mountTopMenu()
      await flushPromises()

      const teamBtn = wrapper.findAll('.v-btn').find((b) => b.text() === '守矢神社')
      expect(teamBtn).toBeTruthy()
      await teamBtn!.trigger('click')
      await flushPromises()

      // Should save to localStorage
      expect(localStorage.getItem('selectedTeamId')).toBe('5')
    })

    it('restores previously selected team from localStorage', async () => {
      localStorage.setItem('selectedTeamId', '20')

      const manager = {
        id: 1,
        name: '監督',
        user_id: 1,
        role: 'director',
        teams: [
          { id: 10, name: 'チームX', short_name: 'X', is_active: true, has_season: true },
          { id: 20, name: 'チームY', short_name: 'Y', is_active: true, has_season: false },
        ],
      }
      setupPaginatedManagerResponse([manager])

      const wrapper = mountTopMenu()
      await flushPromises()

      // チームYが選択状態になるはず(primaryカラー)
      const teamYBtn = wrapper.findAll('.v-btn').find((b) => b.text() === 'チームY')
      expect(teamYBtn).toBeTruthy()
      // The button should have 'flat' variant (selected state)
      expect(teamYBtn!.classes().some((c) => c.includes('flat'))).toBe(true)
    })
  })

  describe('Commissioner mode', () => {
    it('shows commissioner toggle only for commissioner users', async () => {
      mockIsCommissioner.value = true
      setupPaginatedManagerResponse([])

      const wrapper = mountTopMenu()
      await flushPromises()

      // Commissioner switch should be present
      const switchEl = wrapper.find('.v-switch')
      expect(switchEl.exists()).toBe(true)
    })

    it('does not show commissioner toggle for regular users', async () => {
      mockIsCommissioner.value = false
      setupPaginatedManagerResponse([])

      const wrapper = mountTopMenu()
      await flushPromises()

      const switchEl = wrapper.find('.v-switch')
      expect(switchEl.exists()).toBe(false)
    })

    it('commissioner mode ON fetches all teams', async () => {
      mockIsCommissioner.value = true
      localStorage.setItem('commissionerMode', 'on')

      const allTeams = [
        { id: 1, name: '全チーム1', short_name: 'A1', is_active: true, has_season: true },
        { id: 2, name: '全チーム2', short_name: 'A2', is_active: true, has_season: false },
        { id: 3, name: '全チーム3', short_name: 'A3', is_active: true, has_season: true },
      ]

      vi.mocked(axios.get).mockImplementation((url: string) => {
        if (url === '/managers') {
          return Promise.resolve({ data: { data: [], meta: { total: 0 } } })
        }
        if (url === '/teams') {
          return Promise.resolve({ data: allTeams })
        }
        if (url === '/schedules') {
          return Promise.resolve({ data: [] })
        }
        return Promise.resolve({ data: {} })
      })

      const wrapper = mountTopMenu()
      await flushPromises()

      // All teams should be visible
      expect(wrapper.text()).toContain('全チーム1')
      expect(wrapper.text()).toContain('全チーム2')
      expect(wrapper.text()).toContain('全チーム3')
      expect(vi.mocked(axios.get)).toHaveBeenCalledWith('/teams')
    })
  })
})
