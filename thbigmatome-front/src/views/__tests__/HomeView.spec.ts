import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import HomeView from '../HomeView.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'

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

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/home', component: { template: '<div />' } },
      { path: '/games/:id', name: '試合詳細', component: { template: '<div />' } },
    ],
  })
}

const mockSummary = {
  season_progress: { completed: 50, total: 143 },
  recent_games: [
    {
      id: 1,
      real_date: '2026-02-20',
      home_team: '博麗チーム',
      visitor_team: '霧雨チーム',
      home_score: 3,
      visitor_score: 2,
    },
    {
      id: 2,
      real_date: '2026-02-19',
      home_team: '紅魔チーム',
      visitor_team: '博麗チーム',
      home_score: 1,
      visitor_score: 4,
    },
  ],
  batting_top3: [
    { player_name: '博麗霊夢', batting_average: '.350', hits: 35, hr: 5, rbi: 20 },
    { player_name: '霧雨魔理沙', batting_average: '.320', hits: 32, hr: 8, rbi: 25 },
    { player_name: '十六夜咲夜', batting_average: '.290', hits: 29, hr: 2, rbi: 15 },
  ],
  pitching_top3: [
    { player_name: '博麗霊夢', era: '2.10', wins: 14, losses: 4, strikeouts: 180 },
    { player_name: 'アリス', era: '3.45', wins: 8, losses: 5, strikeouts: 95 },
    { player_name: '東風谷早苗', era: '3.80', wins: 6, losses: 7, strikeouts: 75 },
  ],
  team_summary: {
    team_name: '博麗チーム',
    wins: 30,
    losses: 18,
    draws: 2,
    runs_scored: 220,
    runs_allowed: 180,
  },
}

const mockMyTeams = [
  {
    id: 1,
    name: 'テストチーム',
    is_active: true,
    user_id: 1,
    short_name: 'TT',
    team_type: 'normal',
  },
]

// Piniaインスタンスをテスト間で共有（storeセットアップとmountで同じインスタンスを使う）
let testPinia: ReturnType<typeof createPinia>

describe('HomeView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    // チームデータはuseAuth(initializeUserState)がロード済み想定でstoreに直接セット
    testPinia = createPinia()
    setActivePinia(testPinia)
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams(mockMyTeams)

    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (url === '/competitions') {
        return Promise.resolve({
          data: [{ id: 1, name: '第3回Lペナ', competition_type: 'league_pennant' }],
        })
      }
      if (url === '/home/summary') {
        return Promise.resolve({ data: mockSummary })
      }
      return Promise.resolve({ data: [] })
    })
  })

  it('コンポーネントがレンダリングされること', async () => {
    const router = createTestRouter()
    const wrapper = mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('シーズン進行カードが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()

    const vm = wrapper.vm as unknown as {
      selectedCompetitionId: number
      fetchSummary: () => Promise<void>
    }
    vm.selectedCompetitionId = 1
    await vm.fetchSummary()
    await flushPromises()

    const text = wrapper.text()
    expect(text).toContain('シーズン進行')
    expect(text).toContain('143')
  })

  it('直近試合セクションが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()

    const vm = wrapper.vm as unknown as {
      selectedCompetitionId: number
      fetchSummary: () => Promise<void>
    }
    vm.selectedCompetitionId = 1
    await vm.fetchSummary()
    await flushPromises()

    const text = wrapper.text()
    expect(text).toContain('直近の試合結果')
    expect(text).toContain('博麗チーム')
  })

  it('成績サマリーセクションが表示されること', async () => {
    const router = createTestRouter()
    const wrapper = mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()

    const vm = wrapper.vm as unknown as {
      selectedCompetitionId: number
      fetchSummary: () => Promise<void>
    }
    vm.selectedCompetitionId = 1
    await vm.fetchSummary()
    await flushPromises()

    const text = wrapper.text()
    expect(text).toContain('成績サマリー')
    expect(text).toContain('打撃TOP3')
    expect(text).toContain('投手TOP3')
  })

  it('チーム0件時にEmptyStateが表示されること', async () => {
    // storeを空チームでリセット
    const teamStore = useTeamSelectionStore()
    teamStore.setMyTeams([])

    const router = createTestRouter()
    const wrapper = mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()
    expect(wrapper.text()).toContain('コミッショナーにお問い合わせください')
  })

  it('チームあり時に通常ダッシュボードが表示されること', async () => {
    const router = createTestRouter()
    mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()
    // チームが1件あるので大会選択APIが呼ばれる（チームAPIはuseAuthが担当）
    expect(axios.get).not.toHaveBeenCalledWith('/users/me/teams')
    expect(axios.get).toHaveBeenCalledWith('/competitions')
  })

  it('チームデータはuseAuth(initializeUserState)が取得済み（HomeViewはstoreから読む）', async () => {
    const router = createTestRouter()
    mount(HomeView, { global: { plugins: [vuetify, router, testPinia] } })
    await flushPromises()
    // HomeViewはもう/users/me/teamsを直接呼ばない
    expect(axios.get).not.toHaveBeenCalledWith('/users/me/teams')
    expect(axios.get).not.toHaveBeenCalledWith('/api/v1/users/me/teams')
  })
})
