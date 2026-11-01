import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'
import SeasonPortal from '../SeasonPortal.vue'
import { appBarTitle } from '@/composables/useAppBarTitle'
import realJa from '@/locales/ja.json'

// サーバが返す試合日とみなす種別（SeasonSchedule::GAME_DATE_TYPES）
const GAME_DATE_TYPES = ['game_day', 'interleague_game_day', 'playoff_day']

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
// 過去分の修正の 3 タブ。渡された日付・区分を data 属性で見えるようにする
vi.mock('@/components/season/SeasonRosterTab.vue', () => ({
  default: {
    name: 'SeasonRosterTab',
    props: ['teamId', 'asOfDate', 'phase', 'readonly'],
    template:
      '<div data-stub="roster" :data-as-of="asOfDate" :data-phase="phase" :data-readonly="String(!!readonly)" />',
  },
}))
vi.mock('@/components/season/SeasonAbsenceTab.vue', () => ({
  default: {
    name: 'SeasonAbsenceTab',
    props: ['teamId', 'asOfDate', 'phase', 'readonly'],
    template: '<div data-stub="absences" :data-as-of="asOfDate" :data-phase="phase" />',
  },
}))
vi.mock('@/views/TeamMembers.vue', () => ({
  default: {
    name: 'TeamMembers',
    props: ['teamId', 'asOfDate', 'phase', 'readonly'],
    template: '<div data-stub="members" :data-as-of="asOfDate" :data-phase="phase" />',
  },
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
      asOfBar: realJa.asOfBar,
      seasonPortal: {
        shortTitle: 'シーズン',
        goToGameResult: '今日の試合へ',
        gameResultInput: '試合結果入力',
        openSchedule: '日程を開く',
        currentDate: '現在の日付',
        noSeasonData: 'シーズンデータが見つかりません',
        tabs: {
          calendar: 'カレンダー',
          roster: 'ロスター',
          absences: '離脱者',
          members: 'メンバー',
          lineup: 'オーダー',
          promotionHistory: '昇降格履歴',
        },
        calendarMark: {
          warn: '要確認',
          todo: '未入力',
          warnTitle: '得点と登板記録が食い違っています',
          todoTitle: '結果が未入力です',
        },
        initForm: {
          title: 'シーズン開始',
          selectScheduleLabel: '日程表を選択',
          startButton: 'シーズン開始',
          noSchedules: '日程表が登録されていません。先に日程表を作成してください。',
        },
      },
      common: { close: '閉じる' },
      settings: { schedule: { dateTypes: { travel_day: '移動日', game_day: '試合日' } } },
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

async function mountSeasonPortal(
  options: { season?: object | null; schedules?: object[]; query?: string } = {},
) {
  const { season = null, schedules = [], query = '' } = options

  mockGet.mockImplementation((url: string) => {
    // game_date_types はサーバが返す試合日とみなす種別（SeasonSchedule::GAME_DATE_TYPES）
    if (url.includes('/season'))
      return Promise.resolve({ data: season && { game_date_types: GAME_DATE_TYPES, ...season } })
    if (url.includes('/schedules')) return Promise.resolve({ data: schedules })
    if (url.includes('/teams/')) return Promise.resolve({ data: { id: 1, name: 'チームA' } })
    return Promise.reject(new Error(`Unexpected GET: ${url}`))
  })

  const router = createTestRouter()
  await router.push(`/teams/1/season${query}`)

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

  // Test Basis: cmd_1783 A（全日程から試合日ページを開く）
  it('移動日にも一覧・詳細から日程を開くリンクが出る（カレンダーのセルは詳細を開く）', async () => {
    localStorage.setItem('sp_view', 'calendar')
    const season = {
      id: 1,
      current_date: '2026-04-10',
      season_schedules: [{ id: 8, date: '2026-04-11', date_type: 'travel_day', game_result: null }],
    }
    const calendar = await mountSeasonPortal({ season })
    const day = calendar
      .findAll('.day-cell')
      .find(
        (cell) =>
          cell.find('.day-number').text() === '11' && !cell.classes().includes('not-current-month'),
      )!
    // セル全体が押せるので、セル内の文字リンクは置かない（詳細ダイアログから開く）
    expect(day.find('.entry-btn').exists()).toBe(false)
    expect(day.text()).not.toContain('日程を開く')
    await day.trigger('click')
    await flushPromises()
    expect(
      document.body.querySelector('[data-testid="detail-open-schedule"]')?.textContent,
    ).toContain('日程を開く')
    calendar.unmount()
    mountedWrappers.splice(mountedWrappers.indexOf(calendar), 1)

    localStorage.setItem('sp_view', 'table')
    const table = await mountSeasonPortal({ season })
    const row = table.findAll('tr').find((tr) => tr.text().includes('移動日'))!
    expect(row.text()).toContain('日程を開く')
    table.unmount()
    mountedWrappers.splice(mountedWrappers.indexOf(table), 1)
    localStorage.removeItem('sp_view')
  })

  // Test Basis: cmd_1784 段4。試合日とみなす種別はサーバが返す game_date_types（プレーオフ日・交流戦を含む）。画面は一覧を持たない
  it('一覧の「試合結果入力」は、サーバが返した試合日の種別（交流戦・プレーオフ日を含む）の日にだけ出る', async () => {
    localStorage.setItem('sp_view', 'table')
    const season = {
      id: 1,
      current_date: '2026-04-10',
      season_schedules: [
        { id: 1, date: '2026-04-11', date_type: 'game_day', game_result: null },
        { id: 2, date: '2026-04-12', date_type: 'interleague_game_day', game_result: null },
        { id: 3, date: '2026-04-13', date_type: 'playoff_day', game_result: null },
        { id: 4, date: '2026-04-14', date_type: 'reserve_day', game_result: null },
        { id: 5, date: '2026-04-15', date_type: 'travel_day', game_result: null },
      ],
    }
    const table = await mountSeasonPortal({ season })
    const rowOf = (label: string) => table.findAll('tr').find((tr) => tr.text().includes(label))!
    expect(rowOf('4/11').text()).toContain('試合結果入力')
    expect(rowOf('4/12').text()).toContain('試合結果入力')
    expect(rowOf('4/13').text()).toContain('試合結果入力')
    expect(rowOf('4/14').text()).toContain('日程を開く')
    expect(rowOf('4/15').text()).toContain('日程を開く')
    table.unmount()
    mountedWrappers.splice(mountedWrappers.indexOf(table), 1)

    // サーバが返す集合が変われば判定も変わる（画面に種別の一覧は無い）
    const narrowed = await mountSeasonPortal({
      season: { ...season, game_date_types: ['game_day'] },
    })
    expect(
      narrowed
        .findAll('tr')
        .find((tr) => tr.text().includes('4/13'))!
        .text(),
    ).toContain('日程を開く')
    narrowed.unmount()
    mountedWrappers.splice(mountedWrappers.indexOf(narrowed), 1)
    localStorage.removeItem('sp_view')
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

    // Test Basis: Operator 2026-11-01「シーズンに題を付けるのは廃止。カレンダー画面等ではチーム名をタイトルにする」
    it('日程表を選ぶだけで開始でき、シーズン名の入力欄は無い', async () => {
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

      // 入力欄は日程表の選択だけ（v-select も内部では text の input を持つので、ラベルで数える）
      expect([...new Set(wrapper.findAll('.v-field-label').map((l) => l.text()))]).toEqual([
        '日程表を選択',
      ])
      expect(wrapper.text()).not.toContain('シーズン名')
      const vm = wrapper.vm as unknown as { selectedScheduleId: number | null }
      vm.selectedScheduleId = 1
      await flushPromises()
      const start = wrapper.findAll('button').find((b) => b.text() === 'シーズン開始')!
      expect(start.attributes('disabled')).toBeUndefined()
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
        createSeason: () => Promise<void>
      }
      vm.selectedScheduleId = 1
      await wrapper.vm.$nextTick()

      await vm.createSeason()
      await flushPromises()

      expect(mockPost).toHaveBeenCalledWith('/seasons', {
        team_id: 1,
        schedule_id: 1,
      })
    })
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.2 B 型（タイトル=チーム名、サブタイトル=画面名。本文に h1 は置かない）
  describe('画面のタイトルはチーム名（ヘッダーバーへ渡す）', () => {
    it('シーズンに name が付いて返ってきても、バーのタイトルにはチーム名、サブタイトルに「シーズン」', async () => {
      const season = {
        id: 1,
        name: '旧題のシーズン',
        current_date: '2026-04-01',
        season_schedules: [],
      }
      const wrapper = await mountSeasonPortal({ season })

      expect(appBarTitle.value).toEqual({ title: 'チームA', subtitle: 'シーズン' })
      expect(wrapper.text()).not.toContain('旧題のシーズン')
      expect(wrapper.find('h1').exists()).toBe(false)
    })

    it('シーズン未作成でもタイトルはチーム名', async () => {
      const wrapper = await mountSeasonPortal({ season: null, schedules: [] })

      expect(appBarTitle.value).toEqual({ title: 'チームA', subtitle: 'シーズン' })
      expect(wrapper.find('h1').exists()).toBe(false)
    })

    it('画面を離れるとバーの宣言を消す', async () => {
      const wrapper = await mountSeasonPortal({ season: null, schedules: [] })
      mountedWrappers.splice(mountedWrappers.indexOf(wrapper), 1)
      wrapper.unmount()
      expect(appBarTitle.value).toBeNull()
    })
  })

  describe('シーズン作成済み時', () => {
    it('タブを表示し、初期化フォームを表示しない', async () => {
      const season = {
        id: 1,
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

    it('日付詳細ダイアログ: 印と理由、試合日ページへの入口を出す', async () => {
      const wrapper = await mountSeasonPortal({ season })
      await dayCellOf(wrapper, 5).trigger('click')
      await flushPromises()
      const note = document.body.querySelector('[data-testid="detail-day-mark"]')
      expect(note?.textContent).toContain('要確認')
      expect(note?.textContent).toContain('得点と登板記録が食い違っています')
      expect(document.body.textContent).toContain('試合結果入力')
    })

    // Test Basis: Operator 2026-11-01「日付をクリックした時の余計な説明は不要。投手登板記録リンクボタンを削除する」
    it('日付詳細ダイアログ: 作業の順番の説明と「投手登板」のリンクボタンを出さない。試合結果入力のボタンは残る', async () => {
      const wrapper = await mountSeasonPortal({ season })
      await dayCellOf(wrapper, 5).trigger('click')
      await flushPromises()
      const text = document.body.textContent ?? ''
      expect(document.body.querySelector('[data-testid="detail-day-flow"]')).toBeNull()
      expect(text).not.toContain('作業の順番')
      expect(text).not.toContain('選手登録・契約変更')
      expect(text).not.toContain('投手登板')
      const links = Array.from(
        document.body.querySelectorAll<HTMLAnchorElement>('.v-overlay__content a[href]'),
      ).map((a) => a.getAttribute('href'))
      expect(links.some((href) => href?.includes('tab=pitchers'))).toBe(false)
      expect(
        document.body.querySelector('[data-testid="detail-open-schedule"]')?.textContent,
      ).toContain('試合結果入力')
      expect(document.body.querySelectorAll('.v-overlay__content .v-btn')).toHaveLength(2) // 試合結果入力と閉じる
    })

    it('実ロケールにも、作業の順番の文言とシーズン名のラベルは残っていない', () => {
      const portal = realJa.seasonPortal as Record<string, unknown>
      expect(portal.dayFlow).toBeUndefined()
      expect(portal.initForm).not.toHaveProperty('seasonNameLabel')
      expect(realJa.topMenu.seasonInitialization).not.toHaveProperty('seasonNameLabel')
    })

    it('日付詳細ダイアログ: 印の無い日は印の帯を出さない', async () => {
      const wrapper = await mountSeasonPortal({ season })
      await dayCellOf(wrapper, 7).trigger('click')
      await flushPromises()
      expect(document.body.querySelector('[data-testid="detail-day-mark"]')).toBeNull()
      expect(document.body.querySelector('[data-testid="detail-open-schedule"]')).not.toBeNull()
    })
  })

  // 現在日は日程の結果から自動で決まる（cmd_1784 段2b）。◀ ▶ はなく、動かす API は呼ばない
  // Test Basis: context/thbig-dugout-season-record-restructure-design.md の 2026-11-01 の追記（Operator 決定）
  describe('現在日の自動化と過去分の修正', () => {
    const season = {
      id: 1,
      current_date: '2026-05-09',
      current_range: { start_date: '2026-05-08', end_date: '2026-05-09' },
      start_date: '2026-04-01',
      end_date: '2026-10-31',
      season_schedules: [],
    }

    afterEach(() => {
      mountedWrappers.splice(0).forEach((w) => w.unmount())
    })

    it('「いま」の帯に現在日（範囲の最後の試合日・曜日つき）を出し、◀ ▶ のボタンは無い', async () => {
      const wrapper = await mountSeasonPortal({ season })

      const date = wrapper.find('[data-testid="current-date"]')
      expect(date.find('.now-strip__label').text()).toBe('現在の日付')
      expect(date.find('.now-strip__value').text()).toBe('5月9日(土)')
      const strip = wrapper.find('[data-testid="now-strip"]')
      expect(strip.find('.mdi-chevron-left').exists()).toBe(false)
      expect(strip.find('.mdi-chevron-right').exists()).toBe(false)
      expect(wrapper.find('.v-toolbar').exists()).toBe(false)
    })

    it('現在日を動かす PATCH を呼ばない（月送りでも現在日は変わらない）', async () => {
      const wrapper = await mountSeasonPortal({ season })

      const monthNav = wrapper.findAll('.month-nav .v-btn')
      await monthNav[1].trigger('click')
      await monthNav[1].trigger('click')
      await monthNav[0].trigger('click')
      await flushPromises()

      expect(mockPatch).not.toHaveBeenCalled()
      expect(wrapper.find('.now-strip__value').text()).toBe('5月9日(土)')
      expect(wrapper.find('.month-label').text()).toBe('2026年6月')
    })

    it('ロスターのタブ: 日付の既定は現在日、区分は試合前。部品へ同じ値を渡す', async () => {
      const wrapper = await mountSeasonPortal({ season, query: '?tab=roster' })

      const stub = wrapper.find('[data-stub="roster"]')
      expect(stub.attributes('data-as-of')).toBe('2026-05-09')
      expect(stub.attributes('data-phase')).toBe('pre_game')
      expect(wrapper.find('[data-testid="as-of-date"] input').element).toHaveProperty(
        'value',
        '2026-05-09',
      )
    })

    it('日付を選ぶと、部品へ渡す日付が変わる。区分も渡る。現在日に戻すボタンは日付が違う時だけ', async () => {
      const wrapper = await mountSeasonPortal({ season, query: '?tab=roster' })
      expect(wrapper.find('[data-testid="as-of-reset"]').exists()).toBe(false)

      await wrapper.find('[data-testid="as-of-date"] input').setValue('2026-05-01')
      await wrapper.find('[data-testid="as-of-phase-post"]').trigger('click')
      await flushPromises()

      const stub = wrapper.find('[data-stub="roster"]')
      expect(stub.attributes('data-as-of')).toBe('2026-05-01')
      expect(stub.attributes('data-phase')).toBe('post_game')

      await wrapper.find('[data-testid="as-of-reset"]').trigger('click')
      await flushPromises()
      expect(wrapper.find('[data-stub="roster"]').attributes('data-as-of')).toBe('2026-05-09')
    })

    it('シーズンの外の日付や空の日付は取り込まない', async () => {
      const wrapper = await mountSeasonPortal({ season, query: '?tab=roster' })
      const input = wrapper.find('[data-testid="as-of-date"] input')

      await input.setValue('2027-01-01')
      await input.setValue('2026-03-31')
      await input.setValue('')
      await flushPromises()

      expect(wrapper.find('[data-stub="roster"]').attributes('data-as-of')).toBe('2026-05-09')
    })

    it('チーム編成のタブも同じ日付と区分を渡す。離脱者のタブは日付だけ（区分の選択は出さない）', async () => {
      const members = await mountSeasonPortal({ season, query: '?tab=members' })
      expect(members.find('[data-stub="members"]').attributes('data-as-of')).toBe('2026-05-09')
      expect(members.find('[data-stub="members"]').attributes('data-phase')).toBe('pre_game')
      expect(members.find('[data-testid="as-of-phase"]').exists()).toBe(true)

      const absences = await mountSeasonPortal({ season, query: '?tab=absences' })
      expect(absences.find('[data-stub="absences"]').attributes('data-as-of')).toBe('2026-05-09')
      expect(absences.find('[data-testid="as-of-phase"]').exists()).toBe(false)
    })

    it('試合日ページからのリンク（?date=）で、その日付から開く', async () => {
      const wrapper = await mountSeasonPortal({ season, query: '?tab=roster&date=2026-05-03' })

      expect(wrapper.find('[data-stub="roster"]').attributes('data-as-of')).toBe('2026-05-03')
    })

    it('?date= が日付の形でなければ現在日', async () => {
      const wrapper = await mountSeasonPortal({ season, query: '?tab=roster&date=abc' })

      expect(wrapper.find('[data-stub="roster"]').attributes('data-as-of')).toBe('2026-05-09')
    })
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.4 / §2.6 / §3（「いま」帯・主操作は緑 1 つ・土日の赤字をやめる）
  describe('骨格（段 1）', () => {
    const gameDay = {
      id: 7,
      date: '2026-05-09',
      date_type: 'game_day',
      game_result: null,
      pitcher_appearance_count: 0,
    }
    const season = {
      id: 1,
      current_date: '2026-05-09',
      start_date: '2026-04-01',
      end_date: '2026-10-31',
      season_schedules: [
        gameDay,
        { ...gameDay, id: 8, date: '2026-05-10', date_type: 'travel_day' },
      ],
    }

    beforeEach(() => {
      localStorage.removeItem('sp_view')
    })

    afterEach(() => {
      mountedWrappers.splice(0).forEach((w) => w.unmount())
    })

    it('「いま」の帯: 現在日が試合日なら、試合日の種別と未入力の印を出し、「今日の試合へ」は緑の主ボタンで試合日ページへ向かう', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const strip = wrapper.find('[data-testid="now-strip"]')
      expect(strip.find('[data-testid="now-type"]').text()).toContain('試合日')
      expect(strip.find('[data-testid="now-mark"]').text()).toBe('未入力')
      const go = strip.find('[data-testid="go-to-game"]')
      expect(go.text()).toContain('今日の試合へ')
      expect(go.classes()).toContain('bg-action')
      expect(go.classes()).toContain('v-btn--variant-flat')
      expect(go.attributes('disabled')).toBeUndefined()
      expect(go.attributes('href')).toBe('/teams/1/season/schedules/7/game')
    })

    // Test Basis: Operator 決定 2026-11-01（画面の緑の塗りは 1 つまで。チーム編成タブでは「保存」が主操作）
    it('「今日の試合へ」はカレンダーのタブだけ緑の塗り。ほかのタブでは枠だけの副ボタン（border-strong）', async () => {
      const calendar = await mountSeasonPortal({ season })
      const calendarGo = calendar.find('[data-testid="go-to-game"]')
      expect(calendarGo.classes()).toContain('bg-action')
      expect(calendarGo.classes()).toContain('v-btn--variant-flat')
      expect(calendarGo.classes()).not.toContain('v-btn--variant-outlined')

      for (const tab of ['members', 'roster', 'absences', 'promotion_history']) {
        const wrapper = await mountSeasonPortal({ season, query: `?tab=${tab}` })
        const go = wrapper.find('[data-testid="go-to-game"]')
        expect(go.classes(), tab).toContain('v-btn--variant-outlined')
        expect(go.classes(), tab).not.toContain('bg-action')
        expect(go.classes(), tab).not.toContain('v-btn--variant-flat')
        expect(go.attributes('style'), tab).toContain('--v-theme-border-strong')
        // 動作は同じ（押せる・遷移先も変わらない）
        expect(go.attributes('disabled'), tab).toBeUndefined()
        expect(go.attributes('href'), tab).toBe('/teams/1/season/schedules/7/game')
      }
    })

    it('タブを切り替えると「今日の試合へ」の塗りも追従する（カレンダー→メンバー→カレンダー）', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const go = () => wrapper.find('[data-testid="go-to-game"]')
      expect(go().classes()).toContain('bg-action')
      const tabs = wrapper.findAll('.v-tab')
      await tabs.find((t) => t.text().includes('メンバー'))!.trigger('click')
      await flushPromises()
      expect(go().classes()).toContain('v-btn--variant-outlined')
      expect(go().classes()).not.toContain('bg-action')
      await tabs.find((t) => t.text().includes('カレンダー'))!.trigger('click')
      await flushPromises()
      expect(go().classes()).toContain('bg-action')
    })

    it('「いま」の帯: 現在日が試合日でなければ「今日の試合へ」は押せない', async () => {
      const wrapper = await mountSeasonPortal({
        season: { ...season, current_date: '2026-05-10' },
      })
      const go = wrapper.find('[data-testid="go-to-game"]')
      expect(go.attributes('disabled')).toBeDefined()
      expect(wrapper.find('[data-testid="now-mark"]').exists()).toBe(false)
    })

    it('「いま」の帯はシーズンがある時だけ。タブより前に置く', async () => {
      const none = await mountSeasonPortal({ season: null, schedules: [] })
      expect(none.find('[data-testid="now-strip"]').exists()).toBe(false)
      expect(none.find('.v-tabs').exists()).toBe(false)

      const wrapper = await mountSeasonPortal({ season })
      const html = wrapper.find('[data-testid="page-layout"]').html()
      expect(html.indexOf('data-testid="now-strip"')).toBeGreaterThan(-1)
      expect(html.indexOf('data-testid="now-strip"')).toBeLessThan(html.indexOf('v-tabs'))
    })

    it('タブは全部アイコンつき。幅は wide', async () => {
      const wrapper = await mountSeasonPortal({ season })
      const tabs = wrapper.findAll('.v-tab')
      expect(tabs).toHaveLength(5)
      for (const tab of tabs) expect(tab.find('.v-icon').exists()).toBe(true)
      expect(wrapper.find('[data-testid="page-layout"]').classes()).toContain('page-layout--wide')
    })

    it('土日は赤・青の文字クラスを付けず、地色のクラス（weekend）だけで区別する。移動日などの平日には付けない', async () => {
      localStorage.setItem('sp_view', 'calendar')
      const wrapper = await mountSeasonPortal({ season })
      const cells = wrapper
        .findAll('.day-cell')
        .filter((c) => !c.classes().includes('not-current-month'))
      // 2026-05-09 は土曜、05-10 は日曜、05-11 は月曜
      const cell = (n: number) => cells.find((c) => c.find('.day-number').text() === String(n))!
      expect(cell(9).classes()).toContain('weekend')
      expect(cell(10).classes()).toContain('weekend')
      expect(cell(11).classes()).not.toContain('weekend')
      expect(wrapper.html()).not.toMatch(/sat-|sun-|saturday|sunday/)
      const source = (await import('../SeasonPortal.vue?raw')).default as string
      expect(source).not.toMatch(/\.(sat|sun)-(header|num|text)|\.saturday|\.sunday/)
    })

    it('カレンダーの日程種別チップは、文字を span に分けて title に名前を持つ（スマホ幅は文字を省きアイコンだけにする）', async () => {
      localStorage.setItem('sp_view', 'calendar')
      const wrapper = await mountSeasonPortal({ season })
      const chip = wrapper
        .findAll('.day-cell')
        .find(
          (c) =>
            !c.classes().includes('not-current-month') && c.find('.day-number').text() === '10',
        )!
        .find('.type-chip')
      expect(chip.find('.type-chip__text').text()).toBe('移動日')
      expect(chip.attributes('title')).toBe('移動日')
      expect(chip.find('.v-icon').exists()).toBe(true)
    })

    it('表形式: 曜日の列にも赤・青の文字クラスを付けない', async () => {
      localStorage.setItem('sp_view', 'table')
      const wrapper = await mountSeasonPortal({ season })
      const dows = wrapper.findAll('.dow-cell')
      expect(dows.length).toBeGreaterThan(0)
      for (const d of dows) expect(d.classes()).toEqual(['dow-cell'])
    })
  })
})
