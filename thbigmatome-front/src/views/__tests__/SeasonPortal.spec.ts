import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import SeasonPortal from '../SeasonPortal.vue'

// Mock axios using vi.hoisted to avoid hoisting issues
const { mockGet, mockPost, mockPatch } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPost: vi.fn(),
  mockPatch: vi.fn(),
}))

vi.mock('axios', () => ({
  default: {
    get: mockGet,
    post: mockPost,
    patch: mockPatch,
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  },
}))

// Stub heavy child components
vi.mock('@/components/season/SeasonRosterTab.vue', () => ({
  default: { name: 'SeasonRosterTab', template: '<div />' },
}))
vi.mock('@/components/season/SeasonAbsenceTab.vue', () => ({
  default: { name: 'SeasonAbsenceTab', template: '<div />' },
}))
vi.mock('@/views/TeamMembers.vue', () => ({
  default: { name: 'TeamMembers', template: '<div />' },
}))
vi.mock('@/components/squad/LineupTemplateEditor.vue', () => ({
  default: { name: 'LineupTemplateEditor', template: '<div />' },
}))
vi.mock('@/components/squad/SquadTextGenerator.vue', () => ({
  default: { name: 'SquadTextGenerator', template: '<div />' },
}))

const vuetify = createVuetify({ components, directives })

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      seasonPortal: {
        goToGameResult: '今日の試合へ',
        currentDate: '現在の日付',
        noSeasonData: 'シーズンデータが見つかりません',
        tabs: {
          calendar: 'カレンダー',
          roster: 'ロスター',
          absences: '離脱者',
          members: 'メンバー',
          lineup: 'オーダー',
          stats: '成績',
        },
        initForm: {
          title: 'シーズン開始',
          seasonNameLabel: 'シーズン名',
          selectScheduleLabel: '日程表を選択',
          startButton: 'シーズン開始',
          noSchedules: '日程表が登録されていません。先に日程表を作成してください。',
        },
      },
      common: { close: '閉じる' },
    },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      { path: '/teams/:teamId/season', name: 'SeasonPortal', component: { template: '<div />' } },
    ],
  })
}

async function mountSeasonPortal(options: { season?: object | null; schedules?: object[] } = {}) {
  const { season = null, schedules = [] } = options

  mockGet.mockImplementation((url: string) => {
    if (url.includes('/season')) return Promise.resolve({ data: season })
    if (url.includes('/schedules')) return Promise.resolve({ data: schedules })
    if (url.includes('/teams/')) return Promise.resolve({ data: { id: 1, name: 'チームA' } })
    return Promise.reject(new Error(`Unexpected GET: ${url}`))
  })

  const router = createTestRouter()
  await router.push('/teams/1/season')

  setActivePinia(createPinia())

  const wrapper = mount(SeasonPortal, {
    props: { teamId: 1 },
    global: {
      plugins: [vuetify, i18n, router],
    },
  })

  await flushPromises()
  return wrapper
}

describe('SeasonPortal', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('シーズン未作成時', () => {
    it('日程表がある場合、初期化フォームを表示する', async () => {
      const schedules = [
        {
          id: 1,
          name: '2026日程表',
          start_date: '2026-04-01',
          end_date: '2026-09-30',
          effective_date: null,
        },
      ]
      const wrapper = await mountSeasonPortal({ season: null, schedules })

      expect(wrapper.find('[data-testid="season-init-form"]').exists() || wrapper.text()).toContain(
        'シーズン開始',
      )
    })

    it('日程表が空の場合、案内メッセージを表示する', async () => {
      const wrapper = await mountSeasonPortal({ season: null, schedules: [] })

      expect(wrapper.text()).toContain('日程表が登録されていません')
    })

    it('シーズン開始ボタンクリックでPOSTリクエストを送信する', async () => {
      const scheduleList = [
        {
          id: 1,
          name: '2026日程表',
          start_date: '2026-04-01',
          end_date: '2026-09-30',
          effective_date: null,
        },
      ]

      const createdSeason = {
        id: 1,
        name: 'テストシーズン',
        current_date: '2026-04-01',
        season_schedules: [],
      }
      mockPost.mockResolvedValue({ data: { season: createdSeason, schedule_count: 10 } })

      let getCallCount = 0
      mockGet.mockImplementation((url: string) => {
        if (url.includes('/schedules')) return Promise.resolve({ data: scheduleList })
        if (url.includes('/season')) {
          getCallCount++
          return getCallCount === 1
            ? Promise.resolve({ data: null })
            : Promise.resolve({ data: createdSeason })
        }
        if (url.includes('/teams/')) return Promise.resolve({ data: { id: 1, name: 'チームA' } })
        return Promise.reject(new Error(`Unexpected GET: ${url}`))
      })

      const router = createTestRouter()
      await router.push('/teams/1/season')
      setActivePinia(createPinia())

      const wrapper = mount(SeasonPortal, {
        props: { teamId: 1 },
        global: { plugins: [vuetify, i18n, router] },
      })
      await flushPromises()

      // Set internal state directly via vm
      const vm = wrapper.vm as unknown as {
        selectedScheduleId: number | null
        newSeasonName: string
        createSeason: () => Promise<void>
      }
      vm.selectedScheduleId = 1
      vm.newSeasonName = 'テストシーズン'
      await wrapper.vm.$nextTick()

      await vm.createSeason()
      await flushPromises()

      expect(mockPost).toHaveBeenCalledWith('/seasons', {
        team_id: 1,
        schedule_id: 1,
        name: 'テストシーズン',
      })
    })
  })

  describe('シーズン作成済み時', () => {
    it('タブを表示し、初期化フォームを表示しない', async () => {
      const season = {
        id: 1,
        name: '2026シーズン',
        current_date: '2026-04-01',
        season_schedules: [],
      }
      const wrapper = await mountSeasonPortal({ season, schedules: [] })

      // タブが表示される
      expect(wrapper.find('.v-tabs').exists()).toBe(true)
      // 初期化フォームは非表示
      expect(wrapper.text()).not.toContain('日程表が登録されていません')
    })
  })
})
