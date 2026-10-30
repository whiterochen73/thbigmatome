import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
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
        gameResultInput: '試合結果入力',
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
        calendarMark: {
          warn: '要確認',
          todo: '未入力',
          warnTitle: '得点と登板記録が食い違っています',
          todoTitle: '結果が未入力です',
        },
        dayFlow: {
          heading: 'この試合日の作業の順番',
          steps: '選手登録・契約変更 → 昇降格 → 負傷 → 結果 → 登板記録',
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

// 日付詳細ダイアログは body に出るので、テストごとに外して前のテストの残りと混ざらないようにする
const mountedWrappers: Array<{ unmount: () => void }> = []

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
  mountedWrappers.push(wrapper)
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
  // cmd_1783 段B: カレンダーの入力漏れの印（得点と登板記録の食い違い・結果の未入力）と、日付詳細ダイアログの並び
  describe('入力漏れの印', () => {
    const win = { opponent_short_name: '相手', score: '3 - 1', result: 'win' }
    const noGame = { opponent_short_name: '相手', score: null, result: 'no_game' }
    const sched = (
      id: number,
      date: string,
      game_result: object | null,
      pitcher_appearance_count?: number,
    ) => ({ id, date, date_type: 'game_day', game_result, pitcher_appearance_count })
    const season = {
      id: 1,
      name: '2026シーズン',
      current_date: '2026-04-10',
      season_schedules: [
        sched(1, '2026-04-02', win), // 件数の項目が無い（古いサーバ）→ 印なし
        sched(2, '2026-04-05', win, 0), // 得点あり・登板なし → 要確認
        sched(3, '2026-04-06', null, 2), // 得点なし・登板あり → 要確認
        sched(4, '2026-04-07', win, 2), // 両方あり → 印なし
        sched(5, '2026-04-08', noGame, 2), // ノーゲーム + 登板あり → 印なし
        sched(6, '2026-04-09', null, 0), // 試合日が来ていて結果なし → 未入力
        sched(7, '2026-04-20', null, 0), // 試合日が来ていない → 印なし
        {
          id: 8,
          date: '2026-04-11',
          date_type: 'travel_day',
          game_result: null,
          pitcher_appearance_count: 0,
        },
      ],
    }

    beforeEach(() => {
      localStorage.removeItem('sp_view')
    })

    afterEach(() => {
      mountedWrappers.splice(0).forEach((w) => w.unmount())
    })

    const dayCellOf = (wrapper: Awaited<ReturnType<typeof mountSeasonPortal>>, n: number) =>
      wrapper
        .findAll('.day-cell')
        .find(
          (c) =>
            !c.classes().includes('not-current-month') &&
            c.find('.day-number').text() === String(n),
        )!

    it('カレンダー: 食い違いは「要確認」、結果の未入力は「未入力」を出し、他の日には出さない', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const marks = (n: number) =>
        dayCellOf(wrapper, n)
          .findAll('[data-testid="calendar-day-mark"]')
          .map((m) => m.text())
      expect(marks(2)).toEqual([])
      expect(marks(5)).toEqual(['要確認'])
      expect(marks(6)).toEqual(['要確認'])
      expect(marks(7)).toEqual([])
      expect(marks(8)).toEqual([])
      expect(marks(9)).toEqual(['未入力'])
      expect(marks(20)).toEqual([])
      expect(marks(11)).toEqual([]) // 移動日には出さない
    })

    it('印の色クラスは種別ごとに分かれ、理由を title に持つ', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const warn = dayCellOf(wrapper, 5).find('[data-testid="calendar-day-mark"]')
      expect(warn.classes()).toContain('day-mark--warn')
      expect(warn.attributes('title')).toBe('得点と登板記録が食い違っています')
      const todo = dayCellOf(wrapper, 9).find('[data-testid="calendar-day-mark"]')
      expect(todo.classes()).toContain('day-mark--todo')
      expect(todo.attributes('title')).toBe('結果が未入力です')
    })

    it('表形式でも同じ印が出る', async () => {
      localStorage.setItem('sp_view', 'table')
      const wrapper = await mountSeasonPortal({ season })
      const texts = wrapper.findAll('[data-testid="table-day-mark"]').map((m) => m.text())
      expect(texts).toEqual(['要確認', '要確認', '未入力'])
    })

    it('日付詳細ダイアログ: 印と理由、作業の順番（選手登録・契約変更 → 昇降格 → 負傷 → 結果 → 登板記録）、試合日ページへの入口を出す', async () => {
      const wrapper = await mountSeasonPortal({ season })
      await dayCellOf(wrapper, 5).trigger('click')
      await flushPromises()
      const note = document.body.querySelector('[data-testid="detail-day-mark"]')
      expect(note?.textContent).toContain('要確認')
      expect(note?.textContent).toContain('得点と登板記録が食い違っています')
      const flow = document.body.querySelector('[data-testid="detail-day-flow"]')
      expect(flow?.textContent).toContain('選手登録・契約変更 → 昇降格 → 負傷 → 結果 → 登板記録')
      expect(document.body.textContent).toContain('試合結果入力')
    })

    it('日付詳細ダイアログ: 印の無い日は印の帯を出さない（作業の順番は出す）', async () => {
      const wrapper = await mountSeasonPortal({ season })
      await dayCellOf(wrapper, 7).trigger('click')
      await flushPromises()
      expect(document.body.querySelector('[data-testid="detail-day-mark"]')).toBeNull()
      expect(document.body.querySelector('[data-testid="detail-day-flow"]')).not.toBeNull()
    })
  })
})
