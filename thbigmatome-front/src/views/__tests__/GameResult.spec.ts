import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'

const { mockGet, mockPut, mockPush, routeGuards } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPut: vi.fn(),
  mockPush: vi.fn(),
  // 画面が登録した離脱ガード（onBeforeRouteLeave / onBeforeRouteUpdate）。テストから直接呼ぶ
  routeGuards: {
    leave: null as null | (() => Promise<boolean> | boolean),
    update: null as null | (() => Promise<boolean> | boolean),
  },
}))

vi.mock('axios', () => ({
  default: {
    get: mockGet,
    put: mockPut,
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { teamId: '1', scheduleId: '100' }, query: {} }),
  useRouter: () => ({ push: mockPush }),
  onBeforeRouteLeave: (guard: () => Promise<boolean> | boolean) => {
    routeGuards.leave = guard
  },
  onBeforeRouteUpdate: (guard: () => Promise<boolean> | boolean) => {
    routeGuards.update = guard
  },
}))

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const gameResponse = {
  team_id: 1,
  team_name: '豊玉',
  season_id: 1,
  game_date: '2026-06-10',
  game_number: 5,
  announced_starter_id: null,
  stadium: '',
  home_away: null,
  designated_hitter_enabled: null,
  opponent_team_id: null,
  opponent_team: '',
  score: 6,
  opponent_score: 5,
  starting_lineup: null,
}

const seasonResponse = {
  current_date: '2026-06-10',
  season_schedules: [
    { id: 99, date: '2026-06-09', date_type: 'game_day' },
    { id: 100, date: '2026-06-10', date_type: 'game_day' },
    { id: 101, date: '2026-06-11', date_type: 'travel_day' },
    { id: 102, date: '2026-06-12', date_type: 'game_day' },
  ],
}

async function mountView() {
  mockGet.mockImplementation((url: string) => {
    if (url === '/game/100') return Promise.resolve({ data: gameResponse })
    if (url === '/teams') return Promise.resolve({ data: [] })
    if (url === '/pitcher_appearances') return Promise.resolve({ data: [] })
    if (url === '/teams/1/season') return Promise.resolve({ data: seasonResponse })
    return Promise.reject(new Error(`Unexpected GET ${url}`))
  })
  const wrapper = mount(GameResult, {
    global: {
      plugins: [vuetify, i18n],
      stubs: {
        TeamMemberSelect: true,
        TeamSelect: true,
        PitcherAppearanceTab: true,
        PitcherStatusTab: true,
        RouterLink: true,
      },
    },
  })
  await flushPromises()
  return wrapper
}

// cmd_1775 第1段 QC の残り(2): 得点は保存できたが投手の判定の作り直しに失敗した時、画面で分かるようにする
describe('GameResult 得点の保存', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('通常の保存は「保存しました」を success で表示する', async () => {
    const wrapper = await mountView()
    mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })

    await wrapper.vm.saveGame()

    expect(mockPut).toHaveBeenCalledWith(
      '/game/100',
      expect.objectContaining({ score: 6, opponent_score: 5 }),
    )
    expect(wrapper.vm.snackbarText).toBe('保存しました')
    expect(wrapper.vm.snackbarColor).toBe('success')
  })

  it('応答に warnings があれば、判定の作り直しに失敗し後で作り直しが必要と warning で表示する（長めに出す）', async () => {
    const wrapper = await mountView()
    mockPut.mockResolvedValueOnce({
      data: {
        id: 100,
        warnings: [
          '得点は保存しましたが、投手の判定の作り直しに失敗しました。後で作り直しが必要です',
        ],
      },
    })

    await wrapper.vm.saveGame()

    expect(wrapper.vm.snackbarText).toContain('判定の作り直しに失敗')
    expect(wrapper.vm.snackbarText).toContain('後で作り直しが必要')
    expect(wrapper.vm.snackbarColor).toBe('warning')
    expect(wrapper.vm.snackbarTimeout).toBeGreaterThan(3000)
  })

  it('warnings キーが無い応答（旧サーバ）でも通常の成功として扱う', async () => {
    const wrapper = await mountView()
    mockPut.mockResolvedValueOnce({ data: { id: 100 } })

    await wrapper.vm.saveGame()

    expect(wrapper.vm.snackbarText).toBe('保存しました')
  })

  it('保存自体が失敗したら従来どおりエラー表示', async () => {
    const wrapper = await mountView()
    mockPut.mockRejectedValueOnce(new Error('500'))
    vi.spyOn(console, 'error').mockImplementation(() => {})

    await wrapper.vm.saveGame()

    expect(wrapper.vm.snackbarText).toBe('保存に失敗しました')
    expect(wrapper.vm.snackbarColor).toBe('error')
  })
})

// cmd_1775 第3段 E12: 試合結果でノーゲームを選べる（精神疲労・精神崩壊は入れない — Operator 決定 2026-10-26）
describe('GameResult ノーゲーム', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  async function mountWith(extra: Record<string, unknown> = {}) {
    mockGet.mockImplementation((url: string) => {
      if (url === '/game/100') return Promise.resolve({ data: { ...gameResponse, ...extra } })
      if (url === '/teams') return Promise.resolve({ data: [] })
      if (url === '/pitcher_appearances') return Promise.resolve({ data: [] })
      if (url === '/teams/1/season') return Promise.resolve({ data: seasonResponse })
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    const wrapper = mount(GameResult, {
      global: {
        plugins: [vuetify, i18n],
        stubs: {
          TeamMemberSelect: true,
          TeamSelect: true,
          PitcherAppearanceTab: true,
          PitcherStatusTab: true,
          RouterLink: true,
        },
      },
    })
    await flushPromises()
    return wrapper
  }

  it('既定はノーゲームでない。勝敗は得点から決まる（6-5 は win、5-6 は lose、同点は draw）', async () => {
    const wrapper = await mountWith()
    expect(wrapper.vm.pitcherGameResult).toBe('win')
    wrapper.vm.gameData.score = 5
    wrapper.vm.gameData.opponent_score = 6
    expect(wrapper.vm.pitcherGameResult).toBe('lose')
    wrapper.vm.gameData.opponent_score = 5
    expect(wrapper.vm.pitcherGameResult).toBe('draw')
  })

  it('ノーゲームのチェックを入れると、得点に依らず投手へ渡す結果が no_game になる', async () => {
    const wrapper = await mountWith()
    const input = wrapper.find('[data-testid="no-game-checkbox"] input')
    expect(input.exists()).toBe(true)
    await input.setValue(true)
    expect(wrapper.vm.gameData.no_game).toBe(true)
    expect(wrapper.vm.pitcherGameResult).toBe('no_game')
  })

  it('チェックを外すと得点から決める結果に戻る', async () => {
    const wrapper = await mountWith({ no_game: true })
    expect(wrapper.vm.pitcherGameResult).toBe('no_game')
    await wrapper.find('[data-testid="no-game-checkbox"] input').setValue(false)
    expect(wrapper.vm.pitcherGameResult).toBe('win')
  })

  it('保存済みのノーゲーム（API の no_game: true）はチェックが入った状態で開く', async () => {
    const wrapper = await mountWith({ no_game: true })
    const input = wrapper.find('[data-testid="no-game-checkbox"] input')
    expect((input.element as HTMLInputElement).checked).toBe(true)
  })

  it('保存は no_game を PUT /game に含める', async () => {
    const wrapper = await mountWith()
    await wrapper.find('[data-testid="no-game-checkbox"] input').setValue(true)
    mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
    await wrapper.vm.saveGame()
    expect(mockPut).toHaveBeenCalledWith('/game/100', expect.objectContaining({ no_game: true }))
  })

  it('得点が無い（未入力）ときも no_game を選べる', async () => {
    const wrapper = await mountWith({ score: null, opponent_score: null })
    expect(wrapper.vm.pitcherGameResult).toBe('draw')
    await wrapper.find('[data-testid="no-game-checkbox"] input').setValue(true)
    expect(wrapper.vm.pitcherGameResult).toBe('no_game')
  })

  it('保存の成功後、登板記録タブの保存済み結果区分を再取得させる（判定が作り直されるため）。失敗時・タブ未表示でも保存は成功扱い', async () => {
    const refresh = vi.fn().mockResolvedValue(undefined)
    mockGet.mockImplementation((url: string) => {
      if (url === '/game/100') return Promise.resolve({ data: gameResponse })
      if (url === '/teams') return Promise.resolve({ data: [] })
      if (url === '/pitcher_appearances') return Promise.resolve({ data: [] })
      if (url === '/teams/1/season') return Promise.resolve({ data: seasonResponse })
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    const wrapper = mount(GameResult, {
      global: {
        plugins: [vuetify, i18n],
        stubs: {
          TeamMemberSelect: true,
          TeamSelect: true,
          PitcherAppearanceTab: {
            props: ['gameResult'],
            methods: { refreshSavedResultCategories: refresh },
            template: '<div data-testid="tab-stub">{{ gameResult }}</div>',
          },
          PitcherStatusTab: true,
          RouterLink: true,
        },
      },
    })
    await flushPromises()
    wrapper.vm.activeTab = 'pitchers'
    await flushPromises()
    expect(wrapper.find('[data-testid="tab-stub"]').text()).toBe('win')
    mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })

    await wrapper.vm.saveGame()

    expect(refresh).toHaveBeenCalledTimes(1)
    expect(wrapper.vm.snackbarText).toBe('保存しました')
  })

  it('登板記録タブがまだ開かれていなくても、保存は成功する（再取得の対象がいない）', async () => {
    const wrapper = await mountWith()
    mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
    await wrapper.vm.saveGame()
    expect(wrapper.vm.snackbarText).toBe('保存しました')
  })
})

// cmd_1783 段A・段B: 試合日ページ（段の並び・状態・要確認の帯・離脱ガード・前後の試合日）
describe('GameResult 試合日ページ', () => {
  // body に取り付けるので、テストごとに外す（ダイアログ・beforeunload の受け手が前のテストから残らないように）
  const mounted: Array<{ unmount: () => void }> = []

  beforeEach(() => {
    vi.clearAllMocks()
    routeGuards.leave = null
    routeGuards.update = null
  })

  afterEach(() => {
    mounted.splice(0).forEach((w) => w.unmount())
  })

  async function mountDay(
    opts: {
      game?: Record<string, unknown>
      appearances?: unknown[] | Error
      season?: Record<string, unknown> | Error
    } = {},
  ) {
    const { game = {}, appearances = [], season = seasonResponse } = opts
    mockGet.mockImplementation((url: string) => {
      if (url === '/game/100') return Promise.resolve({ data: { ...gameResponse, ...game } })
      if (url === '/teams') return Promise.resolve({ data: [] })
      if (url === '/pitcher_appearances') {
        return appearances instanceof Error
          ? Promise.reject(appearances)
          : Promise.resolve({ data: appearances })
      }
      if (url === '/teams/1/season') {
        return season instanceof Error ? Promise.reject(season) : Promise.resolve({ data: season })
      }
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = mount(GameResult, {
      attachTo: document.body,
      global: {
        plugins: [vuetify, i18n],
        stubs: {
          TeamMemberSelect: true,
          TeamSelect: true,
          PitcherAppearanceTab: true,
          PitcherStatusTab: true,
          RouterLink: true,
        },
      },
    })
    await flushPromises()
    mounted.push(wrapper)
    return wrapper
  }

  const state = (wrapper: Awaited<ReturnType<typeof mountDay>>, testId: string) =>
    wrapper.find(`[data-testid="${testId}"]`).attributes('data-state')

  const appearanceRows = (n: number) =>
    Array.from({ length: n }, (_, i) => ({ id: i + 1, pitcher_id: 10 + i }))

  it('段が 試合前（選手登録・契約変更 → 昇降格 → 負傷 → 予告先発・対戦設定）→ 試合後（結果 → 登板記録 → 試合中の負傷）の順に並ぶ', async () => {
    const wrapper = await mountDay()
    const ids = wrapper.findAll('[data-testid^="section-"]').map((e) => e.attributes('data-testid'))
    expect(ids).toEqual([
      'section-members',
      'section-roster',
      'section-absences',
      'section-setup',
      'section-result',
      'section-pitchers',
      'section-pitcher-status',
      'section-in-game-absences',
    ])
    const text = wrapper.find('[data-testid="section-members"]').text()
    expect(text).toContain('選手登録・契約変更')
  })

  it('ロスター・離脱・チーム編成は埋め込まず、シーズンポータルの該当タブへのリンクにする', async () => {
    const wrapper = await mountDay()
    expect(wrapper.vm.membersRoute).toEqual({
      name: 'SeasonPortal',
      params: { teamId: '1' },
      query: { tab: 'members' },
    })
    expect(wrapper.vm.rosterRoute.query).toEqual({ tab: 'roster' })
    expect(wrapper.vm.absencesRoute.query).toEqual({ tab: 'absences' })
    expect(wrapper.find('[data-testid="link-members"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="link-roster"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="link-absences"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="link-in-game-absences"]').exists()).toBe(true)
  })

  it('得点あり・登板なし → 赤い帯（登板記録を入力してください）と、登板記録の段が要確認', async () => {
    const wrapper = await mountDay({ appearances: [] })
    expect(wrapper.find('[data-testid="mismatch-banner"]').text()).toContain('登板記録がありません')
    expect(state(wrapper, 'section-pitchers')).toBe('warn')
    expect(state(wrapper, 'section-result')).toBe('done')
    // 赤い帯の行き先が閉じたままにならない
    expect(wrapper.vm.openSections.pitchers).toBe(true)
  })

  it('登板あり・得点なし → 赤い帯（得点が保存されていません）と、結果・登板記録の段が要確認', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null },
      appearances: appearanceRows(2),
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').text()).toContain(
      '得点が保存されていません',
    )
    expect(state(wrapper, 'section-result')).toBe('warn')
    expect(state(wrapper, 'section-pitchers')).toBe('warn')
  })

  it('ノーゲーム + 登板あり + 得点なし → 帯は出ず、結果・登板記録とも済', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null, no_game: true },
      appearances: appearanceRows(2),
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'section-result')).toBe('done')
    expect(state(wrapper, 'section-pitchers')).toBe('done')
  })

  it('ノーゲーム + 登板なし → 帯は出ず、登板記録は「なし」', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null, no_game: true },
      appearances: [],
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'section-pitchers')).toBe('none')
  })

  it('得点あり・登板あり → 帯なし、結果・登板記録とも済、進み具合は 登板記録まで点灯', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(3) })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'section-result')).toBe('done')
    expect(state(wrapper, 'section-pitchers')).toBe('done')
    expect(wrapper.find('[data-testid="section-pitchers"]').text()).toContain('登板 3 人')
    // 予告先発・対戦設定は未設定だが、結果が保存済みなので「なし」（急かさない）
    expect(state(wrapper, 'section-setup')).toBe('none')
    expect(wrapper.find('[data-testid="game-day-progress-text"]').text()).toBe('3 / 3 済')
  })

  it('両方なし・試合日が来ている → 結果・登板記録とも未入力（黄）', async () => {
    const wrapper = await mountDay({ game: { score: null, opponent_score: null } })
    expect(state(wrapper, 'section-result')).toBe('todo')
    expect(state(wrapper, 'section-pitchers')).toBe('todo')
    expect(state(wrapper, 'section-setup')).toBe('todo')
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
  })

  it('両方なし・試合日が来ていない → 黄にしない（試合日前）', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null, game_date: '2026-06-20' },
    })
    expect(state(wrapper, 'section-result')).toBe('upcoming')
    expect(state(wrapper, 'section-pitchers')).toBe('upcoming')
    expect(state(wrapper, 'section-setup')).toBe('upcoming')
  })

  it('シーズンの現在日が取れない時も、急かさない（試合日前扱い）', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null },
      season: new Error('500'),
    })
    expect(state(wrapper, 'section-result')).toBe('upcoming')
    expect(wrapper.vm.prevGameDay).toBeNull()
    expect(wrapper.vm.nextGameDay).toBeNull()
  })

  it('登板記録の件数が取れない時は、登板なしの赤を出さない（件数不明）', async () => {
    const wrapper = await mountDay({ appearances: new Error('500') })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'section-pitchers')).toBe('info')
  })

  it('予告先発と相手が保存済みなら予告先発・対戦設定は済', async () => {
    const wrapper = await mountDay({
      game: { announced_starter_id: 5, opponent_team_id: 2 },
      appearances: appearanceRows(1),
    })
    expect(state(wrapper, 'section-setup')).toBe('done')
  })

  it('得点を 0 - 0 で保存済みでも「得点あり」として扱う（0 を未入力にしない）', async () => {
    const wrapper = await mountDay({ game: { score: 0, opponent_score: 0 }, appearances: [] })
    expect(wrapper.find('[data-testid="mismatch-banner"]').text()).toContain('登板記録がありません')
  })

  it('得点を編集すると結果の段が編集中になり、保存すると保存済みの値で判定し直す', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(1) })
    expect(state(wrapper, 'section-result')).toBe('done')
    wrapper.vm.gameData.score = 9
    await flushPromises()
    expect(state(wrapper, 'section-result')).toBe('editing')
    expect(wrapper.vm.hasUnsavedChanges).toBe(true)

    mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
    await wrapper.vm.saveGame()
    await flushPromises()
    expect(state(wrapper, 'section-result')).toBe('done')
    expect(wrapper.vm.hasUnsavedChanges).toBe(false)
  })

  it('保存済みの得点を空欄に戻して保存前なら、判定は保存済み（得点あり）のまま・編集中が出る', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(1) })
    wrapper.vm.gameData.score = ''
    await flushPromises()
    expect(state(wrapper, 'section-result')).toBe('editing')
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
  })

  it('空文字の得点と null の得点は同じ「未入力」で、編集中にならない', async () => {
    const wrapper = await mountDay({ game: { score: null, opponent_score: null } })
    wrapper.vm.gameData.score = ''
    await flushPromises()
    expect(wrapper.vm.resultDirty).toBe(false)
  })

  it('登板記録の段が未保存の編集を知らせたら、編集中になり離脱ガードの対象になる', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(1) })
    wrapper.vm.pitcherDirty = true
    await flushPromises()
    expect(state(wrapper, 'section-pitchers')).toBe('editing')
    expect(wrapper.vm.hasUnsavedChanges).toBe(true)
  })

  it('登板記録を保存したら件数を取り直し、状態が済になる', async () => {
    const wrapper = await mountDay({ appearances: [] })
    expect(state(wrapper, 'section-pitchers')).toBe('warn')
    mockGet.mockImplementation((url: string) => {
      if (url === '/pitcher_appearances') return Promise.resolve({ data: appearanceRows(2) })
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    await wrapper.vm.fetchAppearanceCount()
    await flushPromises()
    expect(state(wrapper, 'section-pitchers')).toBe('done')
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
  })

  describe('離脱ガード', () => {
    const clickDialogButton = async (label: string) => {
      const button = Array.from(document.body.querySelectorAll('button')).find(
        (b) => b.textContent?.trim() === label,
      )
      expect(button).toBeTruthy()
      button!.click()
      await flushPromises()
    }

    it('未保存の入力が無ければ、確認なしで離れられる', async () => {
      await mountDay()
      expect(routeGuards.leave).not.toBeNull()
      expect(await routeGuards.leave!()).toBe(true)
    })

    it('未保存の入力があれば確認を出し、キャンセルなら離れない', async () => {
      const wrapper = await mountDay()
      wrapper.vm.gameData.score = 9
      await flushPromises()
      const result = routeGuards.leave!()
      await flushPromises()
      expect(document.body.textContent).toContain('未保存の変更があります')
      await clickDialogButton('キャンセル')
      expect(await result).toBe(false)
    })

    it('未保存の入力があっても、OK なら離れる', async () => {
      const wrapper = await mountDay()
      wrapper.vm.gameData.score = 9
      await flushPromises()
      const result = routeGuards.leave!()
      await flushPromises()
      await clickDialogButton('OK')
      expect(await result).toBe(true)
    })

    it('前後の試合日へ移る（params だけが変わる）時にも同じガードが効く', async () => {
      const wrapper = await mountDay()
      wrapper.vm.gameData.score = 9
      await flushPromises()
      expect(routeGuards.update).not.toBeNull()
      const result = routeGuards.update!()
      await flushPromises()
      await clickDialogButton('キャンセル')
      expect(await result).toBe(false)
    })

    it('保存した後は確認を出さない', async () => {
      const wrapper = await mountDay()
      wrapper.vm.gameData.score = 9
      await flushPromises()
      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.vm.saveGame()
      expect(await routeGuards.leave!()).toBe(true)
    })

    it('タブを閉じる・再読み込みも、未保存の入力がある時だけ止める', async () => {
      // 他のテストが残した画面の listener と混ざらないよう、この画面が登録した listener を直接呼ぶ
      const addSpy = vi.spyOn(window, 'addEventListener')
      const wrapper = await mountDay()
      const call = addSpy.mock.calls.find(([type]) => type === 'beforeunload')
      expect(call).toBeTruthy()
      const handler = call![1] as (e: BeforeUnloadEvent) => void

      const clean = { preventDefault: vi.fn(), returnValue: 'x' } as unknown as BeforeUnloadEvent
      handler(clean)
      expect(clean.preventDefault).not.toHaveBeenCalled()

      wrapper.vm.gameData.score = 9
      await flushPromises()
      const dirty = { preventDefault: vi.fn(), returnValue: 'x' } as unknown as BeforeUnloadEvent
      handler(dirty)
      expect(dirty.preventDefault).toHaveBeenCalled()
      addSpy.mockRestore()
    })
  })

  describe('前後の試合日', () => {
    it('試合日だけをたどる（移動日 101 を飛ばして 99 ←→ 102）', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      expect(wrapper.vm.prevGameDay.id).toBe(99)
      expect(wrapper.vm.nextGameDay.id).toBe(102)
      await wrapper.find('[data-testid="next-game-day"]').trigger('click')
      await flushPromises()
      expect(mockPush).toHaveBeenCalledWith({
        name: 'GameResult',
        params: { teamId: '1', scheduleId: '102' },
      })
    })

    it('最初・最後の試合日では、該当側のボタンが押せない', async () => {
      const wrapper = await mountDay({
        season: {
          current_date: '2026-06-10',
          season_schedules: [{ id: 100, date: '2026-06-10', date_type: 'game_day' }],
        },
      })
      expect(wrapper.find('[data-testid="prev-game-day"]').attributes('disabled')).toBeDefined()
      expect(wrapper.find('[data-testid="next-game-day"]').attributes('disabled')).toBeDefined()
    })

    it('要確認が残ったまま次の試合日へ移る時は、同じ理由を出して確認し、キャンセルなら移らない', async () => {
      const wrapper = await mountDay({ appearances: [] })
      await wrapper.find('[data-testid="next-game-day"]').trigger('click')
      await flushPromises()
      expect(document.body.textContent).toContain('要確認が残っています')
      expect(document.body.textContent).toContain('登板記録がありません')
      const cancel = Array.from(document.body.querySelectorAll('button')).find(
        (b) => b.textContent?.trim() === 'キャンセル',
      )
      cancel!.click()
      await flushPromises()
      expect(mockPush).not.toHaveBeenCalled()
    })

    it('要確認が無ければ、確認なしで移る', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      await wrapper.find('[data-testid="prev-game-day"]').trigger('click')
      await flushPromises()
      expect(mockPush).toHaveBeenCalledWith({
        name: 'GameResult',
        params: { teamId: '1', scheduleId: '99' },
      })
    })
  })

  describe('旧 URL のタブ名', () => {
    it('既定（overview）は予告先発・対戦設定と結果の段を開く', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      expect(wrapper.vm.openSections.setup).toBe(true)
      expect(wrapper.vm.openSections.result).toBe(true)
      expect(wrapper.vm.openSections.pitchers).toBe(false)
    })

    it('pitcher_status は投手状態の段を開く', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      wrapper.vm.activeTab = 'pitcher_status'
      await flushPromises()
      expect(wrapper.vm.openSections.pitcherStatus).toBe(true)
    })

    it('知らないタブ名は overview と同じ扱い', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      wrapper.vm.activeTab = 'unknown'
      await flushPromises()
      expect(wrapper.vm.openSections.result).toBe(true)
    })
  })
})
