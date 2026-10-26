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
vi.mock('@/components/season/PromotionHistoryTab.vue', () => ({
  default: { name: 'PromotionHistoryTab', template: '<div />' },
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
          promotionHistory: '昇降格履歴',
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
      {
        path: '/teams/:teamId/season/schedules/:scheduleId/game',
        name: 'GameResult',
        component: { template: '<div />' },
      },
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

  // Test Basis: 台帳 D-11 再確認（2026-10-26 Operator）「ノーゲームは勝敗・成績に入れない」。
  //   サーバが game_result.result = 'no_game'（score なし）を返した日は、勝ち・負け・引き分けの印を出さずノーゲームと分かる表示にする
  describe('ノーゲームの表示（勝敗の印を出さない）', () => {
    const gameResult = (result: string, score: string | null) => ({
      opponent_short_name: '相手',
      score,
      result,
    })
    const season = {
      id: 1,
      name: '2026シーズン',
      current_date: '2026-04-10',
      season_schedules: [
        {
          id: 1,
          date: '2026-04-05',
          date_type: 'game_day',
          game_result: gameResult('win', '3 - 1'),
        },
        {
          id: 2,
          date: '2026-04-06',
          date_type: 'game_day',
          game_result: gameResult('no_game', null),
        },
        {
          id: 3,
          date: '2026-04-07',
          date_type: 'game_day',
          game_result: gameResult('lose', '0 - 2'),
        },
        {
          id: 4,
          date: '2026-04-08',
          date_type: 'game_day',
          game_result: gameResult('draw', '1 - 1'),
        },
      ],
    }
    const texts = (wrapper: Awaited<ReturnType<typeof mountSeasonPortal>>, testid: string) =>
      wrapper.findAll(`[data-testid="${testid}"]`).map((e) => e.text())

    beforeEach(() => {
      localStorage.removeItem('sp_view')
    })

    it('カレンダー: 勝ち・負け・引き分けは W / L / D、ノーゲームは NG（勝敗の印にならない）', async () => {
      const wrapper = await mountSeasonPortal({ season })
      expect(texts(wrapper, 'calendar-result-mark')).toEqual(['W', 'NG', 'L', 'D'])
      expect(wrapper.find('[data-testid="calendar-result-mark"].result-no_game').exists()).toBe(
        true,
      )
    })

    it('カレンダー: ノーゲームの日はスコアを出さない（得点を成績として見せない）', async () => {
      const wrapper = await mountSeasonPortal({ season })
      expect(texts(wrapper, 'calendar-score')).toEqual(['3 - 1', '0 - 2', '1 - 1'])
    })

    it('カレンダー: ノーゲームの日に勝ち・負け・引き分けのクラスが付かない', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const marks = wrapper.findAll('[data-testid="calendar-result-mark"]')
      const ng = marks[1]
      expect(ng.classes()).not.toContain('result-win')
      expect(ng.classes()).not.toContain('result-lose')
      expect(ng.classes()).not.toContain('result-draw')
    })

    it('凡例にノーゲームがある', async () => {
      const wrapper = await mountSeasonPortal({ season })
      expect(wrapper.find('[data-testid="legend-no-game"]').exists()).toBe(true)
    })

    it('表形式: 勝敗の列はノーゲームだけ NG、スコアの列は「—」', async () => {
      localStorage.setItem('sp_view', 'table')
      const wrapper = await mountSeasonPortal({ season })
      expect(texts(wrapper, 'table-result-badge')).toEqual(['W', 'NG', 'L', 'D'])
      expect(texts(wrapper, 'table-score')).toContain('—')
      expect(texts(wrapper, 'table-score')).not.toContain('null')
    })

    it('日付詳細: ノーゲームの日は結果を「ノーゲーム」と出し、勝ち・負け・引分の語を出さない', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const cells = wrapper.findAll('.day-cell')
      const ngCell = cells.find((c) =>
        c.find('[data-testid="calendar-result-mark"].result-no_game').exists(),
      )
      expect(ngCell).toBeTruthy()
      await ngCell!.trigger('click')
      await flushPromises()
      const dialogResult = document.body.querySelector('[data-testid="detail-result"]')
      expect(dialogResult?.textContent).toContain('NG')
      expect(dialogResult?.textContent).toContain('detailDialog.noGame')
      expect(dialogResult?.textContent).not.toMatch(/win|lose|draw/)
      expect(document.body.querySelector('[data-testid="detail-score"]')).toBeNull()
    })
  })
})
