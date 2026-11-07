import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'

// 不具合（本番 2026-11-07, cmd_1844）: 試合日ページで別の日へ移った直後、試合データの取得が終わる前に
// 登板タブが前の日の日付で読み、その画面のまま保存すると新しい日の勝敗が前の日の並びで上書きされた。
const { mockGet, mockPost, mockPut, mockPatch, route } = await vi.hoisted(async () => {
  const { reactive } = await import('vue')
  return {
    mockGet: vi.fn(),
    mockPost: vi.fn(),
    mockPut: vi.fn(),
    mockPatch: vi.fn(),
    route: reactive({
      params: { teamId: '1', scheduleId: '100' },
      query: {} as Record<string, string>,
    }),
  }
})

vi.mock('axios', () => ({
  default: {
    get: mockGet,
    post: mockPost,
    put: mockPut,
    patch: mockPatch,
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))
vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push: vi.fn() }),
  onBeforeRouteLeave: vi.fn(),
  onBeforeRouteUpdate: vi.fn(),
}))
vi.mock('@/views/TeamMembers.vue', () => ({ default: { render: () => null } }))
vi.mock('@/components/season/SeasonRosterTab.vue', () => ({ default: { render: () => null } }))
vi.mock('@/components/season/SeasonAbsenceTab.vue', () => ({ default: { render: () => null } }))
vi.mock('@/stores/teamSelection', () => ({
  useTeamSelectionStore: () => ({ selectTeam: vi.fn() }),
}))

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const game = (date: string, score: number) => ({
  team_id: 1,
  team_name: '豊玉',
  season_id: 1,
  game_date: date,
  game_number: 5,
  announced_starter_id: null,
  stadium: '',
  home_away: null,
  designated_hitter_enabled: null,
  opponent_team_id: null,
  opponent_team: '',
  score,
  opponent_score: 1,
  starting_lineup: null,
})

const seasonResponse = {
  game_date_types: ['game_day'],
  current_date: '2016-05-17',
  current_range: { start_date: '2016-05-17', end_date: '2016-05-18' },
  season_schedules: [
    { id: 100, date: '2016-05-18', date_type: 'game_day' },
    { id: 99, date: '2016-05-17', date_type: 'game_day' },
  ],
}

describe('GameResult 別の試合日へ移った直後の登板タブ', () => {
  let resolveGame99: (v: unknown) => void
  beforeEach(() => {
    vi.clearAllMocks()
    route.params.scheduleId = '100'
    mockGet.mockImplementation((url: string, opts?: { params?: Record<string, string> }) => {
      if (url === '/game/100') return Promise.resolve({ data: game('2016-05-18', 5) })
      if (url === '/game/99')
        return new Promise((resolve) => {
          resolveGame99 = resolve
        })
      if (url === '/teams') return Promise.resolve({ data: [] })
      if (url === '/teams/1/season') return Promise.resolve({ data: seasonResponse })
      if (url === '/teams/1/team_players')
        return Promise.resolve({
          data: [{ id: 10, name: '幽々子', position: 'pitcher', is_pitcher: true }],
        })
      if (url === '/teams/1/team_memberships')
        return Promise.resolve({ data: [{ id: 1, player_id: 10 }] })
      if (url === '/pitcher_appearances') {
        // 5/18 の日だけ登板済みの行を返す
        const date = opts?.params?.schedule_date
        return Promise.resolve({
          data:
            date === '2016-05-18'
              ? [
                  {
                    id: 1,
                    pitcher_id: 10,
                    schedule_date: date,
                    role: 'starter',
                    innings_pitched: 9,
                    decision: 'win',
                    is_opener: false,
                    appearance_order: 0,
                  },
                ]
              : [],
        })
      }
      return Promise.resolve({ data: [] })
    })
  })

  it('新しい日の試合データが届くまで、前の日の日付で登板記録を読まない・描かない', async () => {
    const wrapper = mount(GameResult, {
      global: { plugins: [vuetify, i18n], stubs: { RouterLink: true } },
      attachTo: document.body,
    })
    await flushPromises()
    // 登板記録・投手状態の段を開いて、タブを描かせる
    wrapper.vm.pickStep('pitcherStatus')
    wrapper.vm.pickStep('pitchers')
    await flushPromises()
    const readDates = () =>
      mockGet.mock.calls
        .filter((c) => c[0] === '/pitcher_appearances')
        .map((c) => c[1]?.params?.schedule_date)
    expect(mockGet.mock.calls.some((c) => c[0] === '/teams/1/team_players')).toBe(true)
    expect(readDates()).toContain('2016-05-18')

    // 5/17 の日へ移る。/game/99 の応答は遅れる
    mockGet.mockClear()
    route.params.scheduleId = '99'
    await flushPromises()
    // 試合データが届く前に、登板タブが新しい scheduleId のまま前の日（5/18）を読み直してはならない
    // （登板タブは作り直されるので、届く前の描画自体を許さない）
    expect(readDates().filter((d) => d !== '2016-05-17')).toEqual([])
    const stateDates = () =>
      mockGet.mock.calls
        .filter((c) => String(c[0]).includes('pitcher_game_states'))
        .map((c) => c[1]?.params?.date)
    expect(stateDates().filter((d) => d !== '2016-05-17')).toEqual([])

    resolveGame99({ data: game('2016-05-17', 0) })
    await flushPromises()
    // 届いた後は 5/17 の日付で読む
    expect(readDates()).toContain('2016-05-17')
    expect(readDates()).not.toContain('2016-05-18')
    expect(stateDates()).toContain('2016-05-17')
    expect(stateDates()).not.toContain('2016-05-18')

    // 保存しても、5/18 の登板の並びが 5/17 の日付で送られない（5/17 には登板が無いので行は空）
    mockPost.mockResolvedValue({ data: { warnings: [] } })
    const save = wrapper.findAll('button').find((b) => b.text().includes('登板記録を保存'))
    await save?.trigger('click')
    await flushPromises()
    for (const call of mockPost.mock.calls) {
      const body = call[1].pitcher_appearances_bulk
      expect(body.schedule_date).toBe('2016-05-17')
      expect(body.appearances).toEqual([])
    }
    wrapper.unmount()
  })

  async function mountOn100() {
    const wrapper = mount(GameResult, {
      global: { plugins: [vuetify, i18n], stubs: { RouterLink: true } },
      attachTo: document.body,
    })
    await flushPromises()
    return wrapper
  }

  it('新しい日の試合データが届く前は、保存ボタンも saveGame も何も送らない', async () => {
    const wrapper = await mountOn100()
    route.params.scheduleId = '99'
    await flushPromises()
    expect(wrapper.vm.gameLoaded).toBe(false)
    await wrapper.vm.saveGame()
    expect(mockPut).not.toHaveBeenCalled()
    resolveGame99({ data: game('2016-05-17', 0) })
    await flushPromises()
    expect(wrapper.vm.gameLoaded).toBe(true)
    mockPut.mockResolvedValue({ data: { warnings: [] } })
    await wrapper.vm.saveGame()
    expect(mockPut).toHaveBeenCalledWith('/game/99', expect.objectContaining({ score: 0 }))
    wrapper.unmount()
  })

  it('速く移った時、前の日の後続の取得（登板数・離脱）が遅れて届いても新しい日の値を上書きしない', async () => {
    let resolveOld: (v: unknown) => void = () => {}
    const base = mockGet.getMockImplementation()!
    mockGet.mockImplementation((url: string, opts?: { params?: Record<string, string> }) => {
      if (url === '/pitcher_appearances' && opts?.params?.schedule_date === '2016-05-18')
        return new Promise((resolve) => {
          resolveOld = resolve
        })
      return base(url, opts)
    })
    const wrapper = await mountOn100()
    route.params.scheduleId = '99'
    await flushPromises()
    resolveGame99({ data: game('2016-05-17', 0) })
    await flushPromises()
    expect(wrapper.vm.appearanceCount).toBe(0)
    resolveOld({ data: [{ id: 1, pitcher_id: 10, roster_status: 'active' }] })
    await flushPromises()
    expect(wrapper.vm.appearanceCount).toBe(0)
    wrapper.unmount()
  })

  it('日付種類の変更は、変更を始めた日に送る（確認中に別の日へ移っても）', async () => {
    const wrapper = await mountOn100()
    let accept: (v: boolean) => void = () => {}
    vi.spyOn(wrapper.vm.confirmDialog!, 'open').mockReturnValue(
      new Promise<boolean>((resolve) => {
        accept = resolve
      }),
    )
    mockPatch.mockResolvedValue({ data: {} })
    const pending = wrapper.vm.updateDateType('travel_day')
    route.params.scheduleId = '99'
    await flushPromises()
    accept(true)
    await pending
    await flushPromises()
    for (const call of mockPatch.mock.calls) {
      expect(call[0]).toBe('/teams/1/season/season_schedules/100')
    }
    wrapper.unmount()
  })

  it('別の日へ移ると読み込み表示が出て、読み終わると消える。読み込み中は保存・日付種類変更ができない', async () => {
    const wrapper = await mountOn100()
    expect(wrapper.find('[data-testid="game-day-loading"]').exists()).toBe(false)
    route.params.scheduleId = '99'
    await flushPromises()
    expect(wrapper.find('[data-testid="game-day-loading"]').exists()).toBe(true)
    expect(wrapper.vm.pageLoading).toBe(true)
    await wrapper.vm.updateDateType('travel_day')
    expect(mockPatch).not.toHaveBeenCalled()
    resolveGame99({ data: game('2016-05-17', 0) })
    await flushPromises()
    expect(wrapper.find('[data-testid="game-day-loading"]').exists()).toBe(false)
    expect(wrapper.vm.pageLoading).toBe(false)
    wrapper.unmount()
  })
})
