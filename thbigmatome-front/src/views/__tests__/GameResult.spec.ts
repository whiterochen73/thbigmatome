import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { onBeforeUnmount } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'
import { appBarBreadcrumbs } from '@/composables/useAppBarBreadcrumbs'

const { mockGet, mockPut, mockPatch, mockPush, routeGuards, routeQuery } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPut: vi.fn(),
  mockPatch: vi.fn(),
  mockPush: vi.fn(),
  // ?tab= などの URL クエリ（テストごとに差し替える）
  routeQuery: { value: {} as Record<string, string> },
  // 画面が登録した離脱ガード（onBeforeRouteLeave / onBeforeRouteUpdate）。テストから直接呼ぶ
  routeGuards: {
    leave: null as null | (() => Promise<boolean> | boolean),
    update: null as null | (() => Promise<boolean> | boolean),
  },
}))

// 埋め込む 3 つの部品（シーズンポータルのタブと同じ部品）。中身は別のスペックで検証しているので、ここでは
// 「いつ描画されるか」「何を渡されるか」を見る差し替え（マウント・アンマウント回数を数える）
const { embedLog, embedStub } = vi.hoisted(() => {
  const embedLog = {
    mounts: {} as Record<string, number>,
    unmounts: {} as Record<string, number>,
  }
  const embedStub = async (name: string) => {
    const { defineComponent, h, onBeforeUnmount } = await import('vue')
    return {
      default: defineComponent({
        name,
        props: {
          teamId: { type: Number, default: undefined },
          gameDayActions: { type: Boolean, default: false },
          // SeasonAbsenceTab の区分の既定値（他の埋め込みは受け取らない）
          defaultPhase: { type: String, default: undefined },
        },
        setup(props) {
          embedLog.mounts[name] = (embedLog.mounts[name] ?? 0) + 1
          onBeforeUnmount(() => {
            embedLog.unmounts[name] = (embedLog.unmounts[name] ?? 0) + 1
          })
          return () => h('div', { 'data-embed': name, 'data-default-phase': props.defaultPhase })
        },
      }),
    }
  }
  return { embedLog, embedStub }
})
vi.mock('@/views/TeamMembers.vue', () => embedStub('TeamMembers'))
vi.mock('@/components/season/SeasonRosterTab.vue', () => embedStub('SeasonRosterTab'))
vi.mock('@/components/season/SeasonAbsenceTab.vue', () => embedStub('SeasonAbsenceTab'))

vi.mock('axios', () => ({
  default: {
    get: mockGet,
    put: mockPut,
    patch: mockPatch,
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { teamId: '1', scheduleId: '100' }, query: routeQuery.value }),
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

// cmd_1783 試合日ページ: 同じ状態・同じ判定から、幅によって 2 つの形で描く。
//   PC 幅（md 以上 = 960px〜）: 上部のステッパー + タブ切り替え（順番は強制しない）
//   スマホ幅（960px 未満）    : 段を縦に積んで折りたたむ
// 状態表示・赤い帯・離脱ガード・前後の試合日は両方の形で同じ振る舞いを確かめる。
const PHONE_WIDTH = 390
const PC_WIDTH = 1280
const DEFAULT_WIDTH = 1024

// Vuetify の useDisplay は window.innerWidth から幅区分を決める（createVuetify の時点で読む）
function setViewportWidth(width: number) {
  Object.defineProperty(window, 'innerWidth', { configurable: true, writable: true, value: width })
}

interface MountDayOptions {
  game?: Record<string, unknown>
  appearances?: unknown[] | Error
  season?: Record<string, unknown> | Error
  width?: number
  query?: Record<string, string>
  // 登板記録タブの差し替え（マウント回数を数えるなど）
  pitcherStub?: unknown
  // 指定すると、シーズンの取得がこの Promise の解決まで終わらない（読み込み中の操作を再現する）
  seasonGate?: Promise<void>
}

const LAYOUTS = [
  { name: 'スマホ幅（縦積み・折りたたみ）', width: PHONE_WIDTH, kind: 'section' },
  { name: 'PC 幅（ステッパー + タブ）', width: PC_WIDTH, kind: 'step' },
] as const

describe.each(LAYOUTS)('GameResult 試合日ページ: $name', ({ width, kind }) => {
  // body に取り付けるので、テストごとに外す（ダイアログ・beforeunload の受け手が前のテストから残らないように）
  const mounted: Array<{ unmount: () => void }> = []

  beforeEach(() => {
    vi.clearAllMocks()
    routeGuards.leave = null
    routeGuards.update = null
    routeQuery.value = {}
    embedLog.mounts = {}
    embedLog.unmounts = {}
  })

  afterEach(() => {
    mounted.splice(0).forEach((w) => w.unmount())
    setViewportWidth(DEFAULT_WIDTH)
  })

  async function mountDay(opts: MountDayOptions = {}) {
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
        if (season instanceof Error) return Promise.reject(season)
        const response = { data: season }
        return opts.seasonGate ? opts.seasonGate.then(() => response) : Promise.resolve(response)
      }
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    vi.spyOn(console, 'error').mockImplementation(() => {})
    routeQuery.value = opts.query ?? {}
    setViewportWidth(opts.width ?? width)
    const wrapper = mount(GameResult, {
      attachTo: document.body,
      global: {
        plugins: [createVuetify({ components, directives }), i18n],
        stubs: {
          TeamMemberSelect: true,
          TeamSelect: true,
          PitcherAppearanceTab: (opts.pitcherStub as never) ?? true,
          PitcherStatusTab: true,
          RouterLink: true,
        },
      },
    })
    await flushPromises()
    mounted.push(wrapper)
    return wrapper
  }

  type Wrapper = Awaited<ReturnType<typeof mountDay>>

  // 段（スマホ幅）・ステップ（PC 幅）の状態。どちらの形でも同じ data-state を持つ
  const state = (wrapper: Wrapper, id: string) =>
    wrapper.find(`[data-testid="${kind}-${id}"]`).attributes('data-state')

  // 段・ステップの中身の入れ物（要約の文字を含む）
  const body = (wrapper: Wrapper, id: string) =>
    wrapper.find(`[data-testid="${kind === 'section' ? 'section' : 'panel'}-${id}"]`)

  // 行き先が見える状態か（スマホ幅 = 段が開いている、PC 幅 = そのステップが選ばれている）
  const isShown = (wrapper: Wrapper, id: string) =>
    kind === 'section'
      ? !!wrapper.vm.openSections[id === 'in-game-absences' ? 'inGameAbsences' : id]
      : body(wrapper, id).isVisible()

  const appearanceRows = (n: number) =>
    Array.from({ length: n }, (_, i) => ({ id: i + 1, pitcher_id: 10 + i }))

  // 画面幅を変える（Vuetify の useDisplay は resize を間引いて反映する）
  const resizeTo = async (newWidth: number) => {
    setViewportWidth(newWidth)
    window.dispatchEvent(new Event('resize'))
    await new Promise((r) => setTimeout(r, 200))
    await flushPromises()
  }

  // 「未保存の編集がある」と知らせてくる登板記録タブの差し替え（ボタンを押すと dirty-change を出す）
  const dirtyPitcherStub = {
    emits: ['dirty-change', 'saved'],
    template: '<button data-testid="make-dirty" @click="$emit(\'dirty-change\', true)" />',
  }

  it('補助として、シーズンポータルの該当タブへのリンクも残す', async () => {
    const wrapper = await mountDay()
    expect(wrapper.vm.membersRoute).toEqual({
      name: 'SeasonPortal',
      params: { teamId: '1' },
      query: { tab: 'members' },
    })
    expect(wrapper.vm.rosterRoute.query).toEqual({ tab: 'roster' })
    expect(wrapper.vm.absencesRoute.query).toEqual({ tab: 'absences' })
    expect(wrapper.find('[data-testid="link-members"]').text()).toBe('シーズンポータルで開く')
    expect(wrapper.find('[data-testid="link-roster"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="link-absences"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="link-in-game-absences"]').exists()).toBe(true)
  })

  // ───────── 埋め込んだ画面（選手登録・契約変更 / 登録・昇降格 / 負傷・出場停止 / 試合中の負傷） ─────────
  describe('埋め込んだ画面', () => {
    const EMBEDS = [
      { slug: 'members', component: 'TeamMembers' },
      { slug: 'roster', component: 'SeasonRosterTab' },
      { slug: 'absences', component: 'SeasonAbsenceTab' },
      { slug: 'in-game-absences', component: 'SeasonAbsenceTab' },
    ] as const

    // 段・ステップを開く（スマホ幅 = 段の見出しを押す、PC 幅 = ステップを選ぶ）
    const openStep = async (wrapper: Wrapper, slug: string) => {
      await wrapper
        .find(
          kind === 'section'
            ? `[data-testid="section-${slug}"] .game-day-section__title`
            : `[data-testid="step-${slug}"]`,
        )
        .trigger('click')
      await flushPromises()
    }
    // 開いた段・選んだステップから離れる（スマホ幅 = 同じ段を閉じる、PC 幅 = 結果のステップへ移る）
    const leaveStep = async (wrapper: Wrapper, slug: string) => {
      await wrapper
        .find(
          kind === 'section'
            ? `[data-testid="section-${slug}"] .game-day-section__title`
            : '[data-testid="step-result"]',
        )
        .trigger('click')
      await flushPromises()
    }

    it.each(EMBEDS)(
      '$slug: 開くまで描画せず、開くと $component が試合日用操作色の props で描画される',
      async ({ slug, component }) => {
        const wrapper = await mountDay({ appearances: appearanceRows(1) })
        expect(embedLog.mounts).toEqual({})
        expect(body(wrapper, slug).find('[data-embed]').exists()).toBe(false)

        await openStep(wrapper, slug)

        const embedded = body(wrapper, slug).find('[data-embed]')
        expect(embedded.attributes('data-embed')).toBe(component)
        // 他の部品は描画されない
        expect(embedLog.mounts).toEqual({ [component]: 1 })
        // Test Basis: thbig-dugout-visual-refresh-design.md §7 段2。
        // 試合日だけ action を使う。試合中の負傷だけ default-phase も渡す（AMB-25）。
        const inGame = slug === 'in-game-absences'
        expect(body(wrapper, slug).findComponent({ name: component }).props()).toEqual(
          inGame
            ? { teamId: 1, defaultPhase: 'in_game', gameDayActions: true }
            : { teamId: 1, gameDayActions: true },
        )
        // team-id（と上記の default-phase）以外の props・属性（asOfDate など）を足していない（scoped style の識別子は除く）
        expect(Object.keys(embedded.attributes()).filter((k) => !k.startsWith('data-v-'))).toEqual(
          inGame ? ['data-embed', 'data-default-phase'] : ['data-embed'],
        )
        expect(isShown(wrapper, slug)).toBe(true)
      },
    )

    it('離れて戻っても、チーム編成とロスターは作り直さない（入力中の値を保つ）', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      for (const slug of ['members', 'roster']) {
        await openStep(wrapper, slug)
        await leaveStep(wrapper, slug)
        await openStep(wrapper, slug)
      }
      expect(embedLog.mounts).toEqual({ TeamMembers: 1, SeasonRosterTab: 1 })
      expect(embedLog.unmounts).toEqual({})
    })

    it('離脱者の画面は 2 か所（離脱者・試合中の負傷）にあるので、開くたびに作り直して取り直す', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      await openStep(wrapper, 'absences')
      expect(embedLog.mounts.SeasonAbsenceTab).toBe(1)
      await leaveStep(wrapper, 'absences')
      await openStep(wrapper, 'in-game-absences')
      expect(embedLog.mounts.SeasonAbsenceTab).toBe(2)
      await leaveStep(wrapper, 'in-game-absences')
      await openStep(wrapper, 'absences')
      expect(embedLog.mounts.SeasonAbsenceTab).toBe(3)
      expect(body(wrapper, 'absences').find('[data-embed]').exists()).toBe(true)
    })

    it('試合中の負傷の段だけ、離脱の区分の既定値が試合中になる（離脱者の段は既定のまま）', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      await openStep(wrapper, 'absences')
      expect(body(wrapper, 'absences').find('[data-embed]').attributes('data-default-phase')).toBe(
        undefined,
      )
      await leaveStep(wrapper, 'absences')
      await openStep(wrapper, 'in-game-absences')
      expect(
        body(wrapper, 'in-game-absences').find('[data-embed]').attributes('data-default-phase'),
      ).toBe('in_game')
    })

    describe('現在日と試合日が違う時の注記', () => {
      const NOTE = 'この画面の操作は現在日（6/8）として記録されます。試合日は 6/10 です'
      const withCurrent = (current: string) => ({ ...seasonResponse, current_date: current })

      it.each(EMBEDS)('$slug: 現在日が試合日と違えば、画面の上に注記を出す', async ({ slug }) => {
        const wrapper = await mountDay({ season: withCurrent('2026-06-08') })
        await openStep(wrapper, slug)
        const panel = body(wrapper, slug)
        expect(panel.find('[data-testid="date-note"]').text()).toBe(NOTE)
        const html = panel.element.innerHTML
        expect(html.indexOf('data-testid="date-note"')).toBeGreaterThan(-1)
        expect(html.indexOf('data-testid="date-note"')).toBeLessThan(html.indexOf('data-embed'))
      })

      it.each(EMBEDS)('$slug: 同じ日なら注記を出さない', async ({ slug }) => {
        const wrapper = await mountDay()
        await openStep(wrapper, slug)
        expect(body(wrapper, slug).find('[data-embed]').exists()).toBe(true)
        expect(wrapper.find('[data-testid="date-note"]').exists()).toBe(false)
      })

      it('時刻つきの現在日（同じ日）でも出さない。1 日でも違えば出す（現在日が試合日より後でも）', async () => {
        const same = await mountDay({ season: withCurrent('2026-06-10T00:00:00.000Z') })
        await openStep(same, 'roster')
        expect(same.find('[data-testid="date-note"]').exists()).toBe(false)

        const after = await mountDay({ season: withCurrent('2026-06-11') })
        await openStep(after, 'roster')
        expect(after.find('[data-testid="date-note"]').text()).toBe(
          'この画面の操作は現在日（6/11）として記録されます。試合日は 6/10 です',
        )
      })

      it('現在日が取れない時は、何も出さない（日付の食い違いを断定しない）', async () => {
        const wrapper = await mountDay({ season: new Error('500') })
        await openStep(wrapper, 'members')
        expect(wrapper.find('[data-testid="date-note"]').exists()).toBe(false)
      })

      it('埋め込んだ画面以外（予告先発・結果・登板記録）には出さない', async () => {
        const wrapper = await mountDay({
          season: withCurrent('2026-06-08'),
          appearances: appearanceRows(1),
        })
        await openStep(wrapper, 'setup')
        await openStep(wrapper, 'result')
        expect(body(wrapper, 'setup').find('[data-testid="date-note"]').exists()).toBe(false)
        expect(body(wrapper, 'result').find('[data-testid="date-note"]').exists()).toBe(false)
      })
    })
  })

  it('得点あり・登板なし → 赤い帯（登板記録を入力してください）と、登板記録が要確認', async () => {
    const wrapper = await mountDay({ appearances: [] })
    expect(wrapper.find('[data-testid="mismatch-banner"]').text()).toContain('登板記録がありません')
    expect(state(wrapper, 'pitchers')).toBe('warn')
    expect(state(wrapper, 'result')).toBe('done')
    // 赤い帯の行き先が閉じたまま・隠れたままにならない
    expect(isShown(wrapper, 'pitchers')).toBe(true)
  })

  it('登板あり・得点なし → 赤い帯（得点が保存されていません）と、結果・登板記録が要確認', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null },
      appearances: appearanceRows(2),
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').text()).toContain(
      '得点が保存されていません',
    )
    expect(state(wrapper, 'result')).toBe('warn')
    expect(state(wrapper, 'pitchers')).toBe('warn')
    expect(isShown(wrapper, 'result')).toBe(true)
  })

  it('ノーゲーム + 登板あり + 得点なし → 帯は出ず、結果・登板記録とも済', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null, no_game: true },
      appearances: appearanceRows(2),
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'result')).toBe('done')
    expect(state(wrapper, 'pitchers')).toBe('done')
  })

  it('ノーゲーム + 登板なし → 帯は出ず、登板記録は「未入力」（D-11: ノーゲームでも疲労は計算する）', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null, no_game: true },
      appearances: [],
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'pitchers')).toBe('todo')
  })

  it('得点あり・登板あり → 帯なし、結果・登板記録とも済、進み具合は 登板記録まで点灯', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(3) })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'result')).toBe('done')
    expect(state(wrapper, 'pitchers')).toBe('done')
    expect(body(wrapper, 'pitchers').text()).toContain('登板 3 人')
    // 予告先発・対戦設定は未設定だが、結果が保存済みなので「なし」（急かさない）
    expect(state(wrapper, 'setup')).toBe('none')
    expect(wrapper.find('[data-testid="game-day-progress-text"]').text()).toBe('3 / 3 済')
  })

  it('両方なし・試合日が来ている → 結果・登板記録とも未入力（黄）', async () => {
    const wrapper = await mountDay({ game: { score: null, opponent_score: null } })
    expect(state(wrapper, 'result')).toBe('todo')
    expect(state(wrapper, 'pitchers')).toBe('todo')
    expect(state(wrapper, 'setup')).toBe('todo')
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
  })

  it('両方なし・試合日が来ていない → 黄にしない（試合日前）', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null, game_date: '2026-06-20' },
    })
    expect(state(wrapper, 'result')).toBe('upcoming')
    expect(state(wrapper, 'pitchers')).toBe('upcoming')
    expect(state(wrapper, 'setup')).toBe('upcoming')
  })

  it('シーズンの現在日が取れない時も、急かさない（試合日前扱い）', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null },
      season: new Error('500'),
    })
    expect(state(wrapper, 'result')).toBe('upcoming')
    expect(wrapper.vm.prevSchedule).toBeNull()
    expect(wrapper.vm.nextSchedule).toBeNull()
  })

  it('登板記録の件数が取れない時は、登板なしの赤を出さない（件数不明）', async () => {
    const wrapper = await mountDay({ appearances: new Error('500') })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
    expect(state(wrapper, 'pitchers')).toBe('info')
  })

  it('予告先発と相手が保存済みなら予告先発・対戦設定は済', async () => {
    const wrapper = await mountDay({
      game: { announced_starter_id: 5, opponent_team_id: 2 },
      appearances: appearanceRows(1),
    })
    expect(state(wrapper, 'setup')).toBe('done')
  })

  it('得点を 0 - 0 で保存済みでも「得点あり」として扱う（0 を未入力にしない）', async () => {
    const wrapper = await mountDay({ game: { score: 0, opponent_score: 0 }, appearances: [] })
    expect(wrapper.find('[data-testid="mismatch-banner"]').text()).toContain('登板記録がありません')
  })

  it('得点を編集すると結果が編集中になり、保存すると保存済みの値で判定し直す', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(1) })
    expect(state(wrapper, 'result')).toBe('done')
    wrapper.vm.gameData.score = 9
    await flushPromises()
    expect(state(wrapper, 'result')).toBe('editing')
    expect(wrapper.vm.hasUnsavedChanges).toBe(true)

    mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
    await wrapper.vm.saveGame()
    await flushPromises()
    expect(state(wrapper, 'result')).toBe('done')
    expect(wrapper.vm.hasUnsavedChanges).toBe(false)
  })

  it('保存済みの得点を空欄に戻して保存前なら、判定は保存済み（得点あり）のまま・編集中が出る', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(1) })
    wrapper.vm.gameData.score = ''
    await flushPromises()
    expect(state(wrapper, 'result')).toBe('editing')
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
  })

  it('空文字の得点と null の得点は同じ「未入力」で、編集中にならない', async () => {
    const wrapper = await mountDay({ game: { score: null, opponent_score: null } })
    wrapper.vm.gameData.score = ''
    await flushPromises()
    expect(wrapper.vm.resultDirty).toBe(false)
  })

  it('登板記録が未保存の編集を知らせたら、編集中になり離脱ガードの対象になる', async () => {
    const wrapper = await mountDay({ appearances: appearanceRows(1) })
    wrapper.vm.pitcherDirty = true
    await flushPromises()
    expect(state(wrapper, 'pitchers')).toBe('editing')
    expect(wrapper.vm.hasUnsavedChanges).toBe(true)
  })

  it('登板記録を保存したら件数を取り直し、状態が済になる', async () => {
    const wrapper = await mountDay({ appearances: [] })
    expect(state(wrapper, 'pitchers')).toBe('warn')
    mockGet.mockImplementation((url: string) => {
      if (url === '/pitcher_appearances') return Promise.resolve({ data: appearanceRows(2) })
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    await wrapper.vm.fetchAppearanceCount()
    await flushPromises()
    expect(state(wrapper, 'pitchers')).toBe('done')
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
  })

  it('要確認の帯のボタンで、該当の段・ステップへ移る（別のステップを開いていても）', async () => {
    // 登板あり・得点なし → 行き先は結果
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null },
      appearances: appearanceRows(1),
    })
    if (kind === 'step') {
      await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
      expect(body(wrapper, 'result').isVisible()).toBe(false)
    } else {
      wrapper.vm.openSections.result = false
      await flushPromises()
    }
    await wrapper.find('[data-testid="mismatch-banner"] button').trigger('click')
    await flushPromises()
    expect(isShown(wrapper, 'result')).toBe(true)
  })

  // ───────── 実日付・開始時刻・開催球場（cmd_1783 subtask_1783j 要望 1） ─────────
  describe('実日付・開始時刻・開催球場', () => {
    const panelSetup = (wrapper: Wrapper) => body(wrapper, 'setup')
    // ゲーム内の球場の入力欄。ラベル「球場」の完全一致で引く（「TLB球場」など他の欄の表示と取り違えない）
    const stadiumInput = (wrapper: Wrapper) =>
      panelSetup(wrapper)
        .findAll('.v-input')
        .find((e) => e.find('.v-field-label').text() === '球場')!
        .find('input')
    const field = (wrapper: Wrapper, id: string) => wrapper.findComponent(`[data-testid="${id}"]`)
    const pick = async (wrapper: Wrapper, id: string, value: string | null) => {
      field(wrapper, id).vm.$emit('update:modelValue', value)
      await flushPromises()
    }

    it('3 欄が出る。ゲーム内の球場は「球場」、リアルの開催は「チャンネル」で、名前がぶつからない', async () => {
      const wrapper = await mountDay()
      const setup = body(wrapper, 'setup')
      expect(setup.find('[data-testid="real-date"] input').attributes('type')).toBe('date')
      expect(setup.text()).toContain('試合日（リアルの日付）')
      expect(setup.text()).toContain('開始時刻（目安）')
      // ラベルは完全一致で見る（「TLB球場」などの選択肢の表示名とは別）
      const labels = setup.findAll('.v-input').map((e) => e.find('.v-field-label').text())
      expect(labels.filter((l) => l === '球場')).toHaveLength(1)
      expect(labels.filter((l) => l === 'チャンネル')).toHaveLength(1)
      expect(labels).not.toContain('球場（ゲーム内）')
      expect(labels).not.toContain('開催球場')
    })

    // 要望（Operator 2026-10-31）: 1 行目は従来の欄だけ、その下の別の行に今回足した 3 欄
    it('欄の並び: 1 行目は 予告先発 / 対戦相手 / H/A / 球場 / DH制、2 行目は 試合日 / 開始時刻 / チャンネル', async () => {
      const wrapper = await mountDay()
      const rowLabels = (testid: string) =>
        body(wrapper, 'setup')
          .findAll(`[data-testid="${testid}"] > .v-col`)
          // TeamMemberSelect / TeamSelect はスタブなので、ラベルは属性から読む
          .map((c) =>
            c.find('.v-field-label').exists()
              ? c.find('.v-field-label').text()
              : (c.element.firstElementChild?.getAttribute('label') ?? ''),
          )

      const setup = body(wrapper, 'setup')
      const rows = setup.findAll('.v-row')
      expect(rows).toHaveLength(2)
      expect(rows[0].attributes('data-testid')).toBe('setup-row-main')
      expect(rows[1].attributes('data-testid')).toBe('setup-row-real')

      expect(rowLabels('setup-row-main')).toEqual([
        '予告先発',
        '対戦相手',
        'ホーム/ビジター',
        '球場',
        expect.stringContaining('DH'),
      ])
      expect(rowLabels('setup-row-real')).toEqual([
        '試合日（リアルの日付）',
        '開始時刻（目安）',
        'チャンネル',
      ])
      // 各欄が属する行（取り違えを防ぐため testid でも確かめる）
      expect(rows[0].find('[data-testid="stadium"]').exists()).toBe(true)
      for (const id of ['real-date', 'real-start-time', 'venue']) {
        expect(rows[1].find(`[data-testid="${id}"]`).exists()).toBe(true)
        expect(rows[0].find(`[data-testid="${id}"]`).exists()).toBe(false)
      }
    })

    it('開始時刻の選択肢は 00:00〜23:30 の 30 分刻み 48 個、開催球場は 6 択（表示名つき）', async () => {
      const wrapper = await mountDay()
      const times = field(wrapper, 'real-start-time').props('items') as string[]
      expect(times).toHaveLength(48)
      expect(times[0]).toBe('00:00')
      expect(times[1]).toBe('00:30')
      expect(times[47]).toBe('23:30')
      expect(times.every((v) => /^([01]\d|2[0-3]):(00|30)$/.test(v))).toBe(true)

      const venues = field(wrapper, 'venue').props('items') as Array<{
        name: string
        value: string
      }>
      expect(venues).toEqual([
        { name: 'チャンネル1', value: 'ch1' },
        { name: 'チャンネル2', value: 'ch2' },
        { name: 'チャンネル3', value: 'ch3' },
        { name: 'チャンネル4', value: 'ch4' },
        { name: 'チャンネル5', value: 'ch5' },
        { name: 'TLB球場', value: 'tlb' },
      ])
    })

    it('保存済みの値が欄に出る。サーバが 3 列を返さない（旧サーバ）時も落ちず、未保存にならない', async () => {
      const wrapper = await mountDay({
        game: { real_date: '2026-11-03', real_start_time: '21:30', venue: 'tlb' },
      })
      expect(
        (wrapper.find('[data-testid="real-date"] input').element as HTMLInputElement).value,
      ).toBe('2026-11-03')
      expect(field(wrapper, 'real-start-time').props('modelValue')).toBe('21:30')
      expect(field(wrapper, 'venue').props('modelValue')).toBe('tlb')
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)

      const old = await mountDay()
      expect(old.vm.hasUnsavedChanges).toBe(false)
    })

    it.each([
      [
        '実日付',
        async (w: Wrapper) => w.find('[data-testid="real-date"] input').setValue('2026-11-03'),
      ],
      ['開始時刻', async (w: Wrapper) => pick(w, 'real-start-time', '21:30')],
      ['チャンネル', async (w: Wrapper) => pick(w, 'venue', 'ch3')],
    ])('%sを選ぶと未保存（dirty）になり、保存で解除される', async (_name, act) => {
      const wrapper = await mountDay()
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)
      await act(wrapper)
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)
      expect(wrapper.vm.setupDirty).toBe(true)
      expect(state(wrapper, 'setup')).toBe('editing')

      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.find('[data-testid="save-setup"]').trigger('click')
      await flushPromises()
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)
      expect(wrapper.vm.setupDirty).toBe(false)
    })

    it('保存の PUT の body に 3 列が入り、ゲーム内の球場も従来どおり送られる', async () => {
      const wrapper = await mountDay()
      await wrapper.find('[data-testid="real-date"] input').setValue('2026-11-03')
      await pick(wrapper, 'real-start-time', '00:00')
      await pick(wrapper, 'venue', 'tlb')
      const stadium = stadiumInput(wrapper)
      await stadium.setValue('甲子園')

      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.find('[data-testid="save-setup"]').trigger('click')
      await flushPromises()

      expect(mockPut).toHaveBeenCalledTimes(1)
      expect(mockPut.mock.calls[0][0]).toBe('/game/100')
      expect(mockPut.mock.calls[0][1]).toMatchObject({
        stadium: '甲子園',
        real_date: '2026-11-03',
        real_start_time: '00:00',
        venue: 'tlb',
      })
    })

    it('ゲーム内の球場だけを変えて保存しても、3 列は変わらず送られる（互いに独立）', async () => {
      const wrapper = await mountDay({
        game: { real_date: '2026-11-03', real_start_time: '21:30', venue: 'ch2' },
      })
      const stadium = stadiumInput(wrapper)
      await stadium.setValue('神宮')
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)

      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.vm.saveGame()
      expect(mockPut.mock.calls[0][1]).toMatchObject({
        stadium: '神宮',
        real_date: '2026-11-03',
        real_start_time: '21:30',
        venue: 'ch2',
      })
    })

    it('選び直して元の値に戻すと未保存でなくなる。選択を外す（null）と未保存になり、null で送る', async () => {
      const wrapper = await mountDay({ game: { venue: 'ch1' } })
      await pick(wrapper, 'venue', 'ch2')
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)
      await pick(wrapper, 'venue', 'ch1')
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)

      await pick(wrapper, 'venue', null)
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)
      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.vm.saveGame()
      expect(mockPut.mock.calls[0][1]).toMatchObject({ venue: null })
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)
    })

    it('実日付を消す（空欄）と、未保存になる。null と空欄は同じ扱い（読み込み直後は未保存でない）', async () => {
      const wrapper = await mountDay({ game: { real_date: '2026-11-03' } })
      await wrapper.find('[data-testid="real-date"] input').setValue('')
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)

      const empty = await mountDay({ game: { real_date: '' } })
      expect(empty.vm.hasUnsavedChanges).toBe(false)
    })

    it('未入力の黄色（段の状態）の判定に、3 項目は含めない（任意項目）', async () => {
      const unset = await mountDay()
      const filled = await mountDay({
        game: { real_date: '2026-11-03', real_start_time: '21:30', venue: 'ch1' },
      })
      expect(state(filled, 'setup')).toBe(state(unset, 'setup'))
      expect(state(filled, 'result')).toBe(state(unset, 'result'))
      expect(state(filled, 'pitchers')).toBe(state(unset, 'pitchers'))
    })
  })

  // ───────── 試合ログ（cmd_1783 subtask_1783j 要望 2） ─────────
  describe('試合ログ', () => {
    const textarea = (wrapper: Wrapper) =>
      wrapper.find('[data-testid="game-log-textarea"] textarea')
    const counter = (wrapper: Wrapper) => wrapper.find('[data-testid="game-log-counter"]').text()
    const dialogButton = (label: string) =>
      Array.from(document.body.querySelectorAll('button')).find(
        (b) => b.textContent?.trim() === label,
      )

    // ブラウザのファイル選択を再現する（files を差し込んで change を起こす）
    const chooseFile = async (wrapper: Wrapper, file: File) => {
      const input = wrapper.find('[data-testid="game-log-file-input"]')
      Object.defineProperty(input.element, 'files', { configurable: true, value: [file] })
      await input.trigger('change')
      await flushPromises()
    }
    const sjis = new Uint8Array([142, 142, 141, 135, 138, 74, 142, 110]) // 試合開始
    const jis = new Uint8Array([27, 36, 66, 59, 110, 57, 103, 51, 43, 59, 79, 27, 40, 66]) // 試合開始

    it('結果の段に、等幅フォントの試合ログ欄（10 行・自動で伸びない）と読み込みボタンがある', async () => {
      const wrapper = await mountDay()
      const result = body(wrapper, 'result')
      expect(result.find('[data-testid="game-log"]').exists()).toBe(true)
      expect(result.text()).toContain('試合ログ')
      expect(result.text()).toContain('ファイルから読み込む')
      const area = wrapper.findComponent('[data-testid="game-log-textarea"]')
      expect(Number(area.props('rows'))).toBe(10)
      expect(area.props('autoGrow')).toBe(false)
      expect(area.classes()).toContain('game-log-textarea')
      expect(wrapper.find('[data-testid="game-log-file-input"]').attributes('accept')).toContain(
        '.log',
      )
      expect(wrapper.find('[data-testid="game-log-file-input"]').attributes('accept')).toContain(
        '.txt',
      )
    })

    it('保存済みのログが欄に出る。読み込み直後は未保存でない', async () => {
      const wrapper = await mountDay({ game: { game_log: '[21:30] 開始\n' } })
      expect((textarea(wrapper).element as HTMLTextAreaElement).value).toBe('[21:30] 開始\n')
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)
    })

    it('入力すると未保存（結果の段が編集中）になり、保存で PUT の body に入って解除される', async () => {
      const wrapper = await mountDay()
      await textarea(wrapper).setValue('[21:30] 試合開始\r\n[21:31] プレイボール')
      expect(wrapper.vm.resultDirty).toBe(true)
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)
      expect(state(wrapper, 'result')).toBe('editing')

      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.find('[data-testid="save-result"]').trigger('click')
      await flushPromises()

      expect(mockPut.mock.calls[0][1]).toMatchObject({
        game_log: '[21:30] 試合開始\r\n[21:31] プレイボール',
      })
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)
      expect(wrapper.vm.resultDirty).toBe(false)
    })

    it('ログだけの変更は、予告先発・対戦設定の段を未保存にしない', async () => {
      const wrapper = await mountDay()
      await textarea(wrapper).setValue('abc')
      expect(wrapper.vm.setupDirty).toBe(false)
    })

    it('全部消すと null で送る。null と空欄は同じ扱い', async () => {
      const wrapper = await mountDay({ game: { game_log: 'abc' } })
      await textarea(wrapper).setValue('')
      expect(wrapper.vm.hasUnsavedChanges).toBe(true)
      expect(wrapper.vm.gameData.game_log).toBeNull()
      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.vm.saveGame()
      expect(mockPut.mock.calls[0][1]).toMatchObject({ game_log: null })
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)

      const empty = await mountDay({ game: { game_log: '' } })
      expect(empty.vm.hasUnsavedChanges).toBe(false)
    })

    it('未入力の黄色（段の状態）の判定に、ログは含めない（任意項目）', async () => {
      const without = await mountDay()
      const withLog = await mountDay({ game: { game_log: 'abc' } })
      expect(state(withLog, 'result')).toBe(state(without, 'result'))
      expect(state(withLog, 'setup')).toBe(state(without, 'setup'))
    })

    // 運営が試合の正しさを検証する原文なので、画面も加工しない（前後の空白・空行・タブ・全角を保つ）
    it('入力した内容を加工せず保存する（前後の空白・空行・タブ・全角・空白だけ）', async () => {
      const raw = '  \n\n[21:30]\t＜芳乃＞　ホームラン！\n\n  '
      const wrapper = await mountDay()
      await textarea(wrapper).setValue(raw)
      expect(wrapper.vm.gameData.game_log).toBe(raw)
      mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
      await wrapper.vm.saveGame()
      expect(mockPut.mock.calls[0][1].game_log).toBe(raw)

      const blank = await mountDay()
      await textarea(blank).setValue('   \n\t ')
      expect(blank.vm.gameData.game_log).toBe('   \n\t ')
      expect(blank.vm.hasUnsavedChanges).toBe(true)
    })

    it('保存済みのログは加工せず欄に出す', async () => {
      const raw = '\n  [21:30]\t＜芳乃＞\r\n\n'
      const wrapper = await mountDay({ game: { game_log: raw } })
      expect(wrapper.vm.gameData.game_log).toBe(raw)
      expect(wrapper.vm.hasUnsavedChanges).toBe(false)
    })

    it('ファイルの内容も加工せず欄に入れる（前後の空白・空行・CRLF のまま）', async () => {
      const raw = '\n\n  [21:30]\t＜芳乃＞ 試合開始\r\n\r\n  '
      const wrapper = await mountDay()
      await chooseFile(wrapper, new File([raw], 'game.log'))
      expect(wrapper.vm.gameData.game_log).toBe(raw)
    })

    describe('文字数・バイト数と上限（1_048_576 バイト）', () => {
      it('文字数とバイト数の目安を出す（日本語は 1 文字 3 バイト）', async () => {
        const wrapper = await mountDay()
        expect(counter(wrapper)).toContain('0 文字 / 0 バイト')
        expect(counter(wrapper)).toContain('1,048,576')
        await textarea(wrapper).setValue('試合a')
        expect(counter(wrapper)).toContain('3 文字 / 7 バイト')
      })

      it('ちょうど 1_048_576 バイトはエラーにならず、保存できる', async () => {
        const wrapper = await mountDay()
        await textarea(wrapper).setValue('a'.repeat(1_048_576))
        expect(wrapper.vm.gameLogTooLarge).toBe(false)
        expect(wrapper.find('[data-testid="game-log-counter"]').classes()).not.toContain(
          'text-error',
        )
        mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
        await wrapper.vm.saveGame()
        expect(mockPut).toHaveBeenCalledTimes(1)
      })

      it('1_048_577 バイトはエラー表示になり、保存前に止める（PUT しない・未保存のまま）', async () => {
        const wrapper = await mountDay()
        await textarea(wrapper).setValue('a'.repeat(1_048_577))
        expect(wrapper.vm.gameLogTooLarge).toBe(true)
        expect(wrapper.find('[data-testid="game-log-counter"]').classes()).toContain('text-error')
        expect(body(wrapper, 'result').text()).toContain('上限（1,048,576 バイト）を超えています')

        await wrapper.find('[data-testid="save-result"]').trigger('click')
        await flushPromises()
        expect(mockPut).not.toHaveBeenCalled()
        expect(wrapper.vm.snackbarColor).toBe('error')
        expect(wrapper.vm.snackbarText).toContain('上限')
        expect(wrapper.vm.hasUnsavedChanges).toBe(true)
        // 設定の段の保存ボタンも同じ（ほかの項目の保存で、ログの超過が黙って通らない）
        await wrapper.find('[data-testid="save-setup"]').trigger('click')
        await flushPromises()
        expect(mockPut).not.toHaveBeenCalled()
      })

      it('文字数ではなくバイト数で数える（349_525 文字 = 1_048_575 バイトは通り、349_526 文字は超過）', async () => {
        const wrapper = await mountDay()
        await textarea(wrapper).setValue('あ'.repeat(349_525))
        expect(wrapper.vm.gameLogTooLarge).toBe(false)
        await textarea(wrapper).setValue('あ'.repeat(349_526))
        expect(wrapper.vm.gameLogTooLarge).toBe(true)
      })

      it('短くすればエラーが消え、保存できる', async () => {
        const wrapper = await mountDay()
        await textarea(wrapper).setValue('a'.repeat(1_048_577))
        await textarea(wrapper).setValue('a'.repeat(10))
        expect(wrapper.vm.gameLogTooLarge).toBe(false)
        mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
        await wrapper.vm.saveGame()
        expect(mockPut).toHaveBeenCalledTimes(1)
      })
    })

    describe('ファイルから読み込む', () => {
      it('ボタンはファイル選択を開く', async () => {
        const wrapper = await mountDay()
        const click = vi
          .spyOn(
            wrapper.find('[data-testid="game-log-file-input"]').element as HTMLInputElement,
            'click',
          )
          .mockImplementation(() => {})
        await wrapper.find('[data-testid="game-log-load"]').trigger('click')
        expect(click).toHaveBeenCalledTimes(1)
      })

      it('UTF-8 のファイルを読み、欄に入れる（未保存になる）。確認は出さない（欄が空のため）', async () => {
        const wrapper = await mountDay()
        await chooseFile(wrapper, new File(['[21:30] 試合開始\n'], 'game.log'))
        expect(wrapper.vm.gameData.game_log).toBe('[21:30] 試合開始\n')
        expect((textarea(wrapper).element as HTMLTextAreaElement).value).toBe('[21:30] 試合開始\n')
        expect(wrapper.vm.hasUnsavedChanges).toBe(true)
        expect(document.body.textContent).not.toContain('試合ログを置き換えますか')
      })

      it('Shift_JIS のファイルを読める', async () => {
        const wrapper = await mountDay()
        await chooseFile(wrapper, new File([sjis], 'game.txt'))
        expect(wrapper.vm.gameData.game_log).toBe('試合開始')
      })

      it('ISO-2022-JP のファイルを読める', async () => {
        const wrapper = await mountDay()
        await chooseFile(wrapper, new File([jis], 'game.txt'))
        expect(wrapper.vm.gameData.game_log).toBe('試合開始')
      })

      it('読み込んだログを保存すると PUT の body に入る', async () => {
        const wrapper = await mountDay()
        await chooseFile(wrapper, new File([sjis], 'game.txt'))
        mockPut.mockResolvedValueOnce({ data: { id: 100, warnings: [] } })
        await wrapper.vm.saveGame()
        expect(mockPut.mock.calls[0][1]).toMatchObject({ game_log: '試合開始' })
        expect(wrapper.vm.hasUnsavedChanges).toBe(false)
      })

      it('既に内容がある時は確認を出す。キャンセルなら置き換えない', async () => {
        const wrapper = await mountDay({ game: { game_log: '元のログ' } })
        await chooseFile(wrapper, new File(['新しいログ'], 'game.log'))
        expect(document.body.textContent).toContain('試合ログを置き換えますか')
        // 確認の間は、まだ置き換わっていない
        expect(wrapper.vm.gameData.game_log).toBe('元のログ')

        dialogButton('キャンセル')!.click()
        await flushPromises()
        expect(wrapper.vm.gameData.game_log).toBe('元のログ')
        expect(wrapper.vm.hasUnsavedChanges).toBe(false)
      })

      it('確認で OK なら、追記ではなく置き換える', async () => {
        const wrapper = await mountDay({ game: { game_log: '元のログ' } })
        await chooseFile(wrapper, new File(['新しいログ'], 'game.log'))
        dialogButton('OK')!.click()
        await flushPromises()
        expect(wrapper.vm.gameData.game_log).toBe('新しいログ')
        expect(wrapper.vm.hasUnsavedChanges).toBe(true)
      })

      it('文字コードを判別できないファイルはエラー表示にして、欄を変えない', async () => {
        const wrapper = await mountDay({ game: { game_log: '元のログ' } })
        await chooseFile(wrapper, new File([new Uint8Array([0x81, 0x20, 0xff])], 'bad.log'))
        expect(wrapper.vm.snackbarColor).toBe('error')
        expect(wrapper.vm.snackbarText).toContain('文字コード')
        expect(wrapper.vm.gameData.game_log).toBe('元のログ')
        expect(document.body.textContent).not.toContain('試合ログを置き換えますか')
      })

      it('大きすぎるファイル（8MB 超）は読まずにエラー表示にする', async () => {
        const wrapper = await mountDay()
        const big = new File(['a'], 'big.log')
        Object.defineProperty(big, 'size', { value: 8 * 1024 * 1024 + 1 })
        await chooseFile(wrapper, big)
        expect(wrapper.vm.snackbarColor).toBe('error')
        expect(wrapper.vm.snackbarText).toContain('大きすぎる')
        expect(wrapper.vm.gameData.game_log ?? null).toBeNull()
      })

      it('1MB を超えるファイルは欄に入るが、超過のエラー表示になり保存できない', async () => {
        const wrapper = await mountDay()
        await chooseFile(wrapper, new File(['a'.repeat(1_048_577)], 'large.log'))
        expect(wrapper.vm.gameLogTooLarge).toBe(true)
        await wrapper.vm.saveGame()
        expect(mockPut).not.toHaveBeenCalled()
      })

      it('ファイルを選ばずに閉じた（files が空）時は何もしない', async () => {
        const wrapper = await mountDay({ game: { game_log: '元のログ' } })
        const input = wrapper.find('[data-testid="game-log-file-input"]')
        Object.defineProperty(input.element, 'files', { configurable: true, value: [] })
        await input.trigger('change')
        await flushPromises()
        expect(wrapper.vm.gameData.game_log).toBe('元のログ')
        expect(document.body.textContent).not.toContain('試合ログを置き換えますか')
      })

      it('読み込みに失敗したら（読み取りエラー）エラー表示にして、欄を変えない', async () => {
        const wrapper = await mountDay({ game: { game_log: '元のログ' } })
        const broken = new File(['x'], 'broken.log')
        Object.defineProperty(broken, 'arrayBuffer', {
          value: () => Promise.reject(new Error('NotReadableError')),
        })
        await chooseFile(wrapper, broken)
        expect(wrapper.vm.snackbarColor).toBe('error')
        expect(wrapper.vm.snackbarText).toContain('読み込みに失敗')
        expect(wrapper.vm.gameData.game_log).toBe('元のログ')
      })
    })
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

    it('画面を離れる（アンマウント）時に、beforeunload の受け手を外す（他のページでタブを閉じる時に確認が出ないように）', async () => {
      const addSpy = vi.spyOn(window, 'addEventListener')
      const removeSpy = vi.spyOn(window, 'removeEventListener')
      const wrapper = await mountDay()
      const added = addSpy.mock.calls.find(([type]) => type === 'beforeunload')
      expect(added).toBeTruthy()
      // 取り付けた listener と同じ関数が、アンマウントの時に外される
      expect(removeSpy.mock.calls.some(([type]) => type === 'beforeunload')).toBe(false)

      // afterEach で二重に外さないよう、ここで外した分は管理対象から除く
      mounted.splice(mounted.indexOf(wrapper), 1)
      wrapper.unmount()

      const removed = removeSpy.mock.calls.filter(([type]) => type === 'beforeunload')
      expect(removed).toHaveLength(1)
      expect(removed[0][1]).toBe(added![1])
      addSpy.mockRestore()
      removeSpy.mockRestore()
    })
  })

  describe('前後の日程', () => {
    it('試合日と移動日を日付順にたどる（99 ← 100 → 101）', async () => {
      const wrapper = await mountDay({ appearances: appearanceRows(1) })
      expect(wrapper.vm.prevSchedule.id).toBe(99)
      expect(wrapper.vm.nextSchedule.id).toBe(101)
      await wrapper.find('[data-testid="next-game-day"]').trigger('click')
      await flushPromises()
      expect(mockPush).toHaveBeenCalledWith({
        name: 'GameResult',
        params: { teamId: '1', scheduleId: '101' },
      })
    })

    it('最初・最後の日程では、該当側のボタンを表示しない', async () => {
      const wrapper = await mountDay({
        season: {
          current_date: '2026-06-10',
          season_schedules: [{ id: 100, date: '2026-06-10', date_type: 'game_day' }],
        },
      })
      expect(wrapper.find('[data-testid="prev-game-day"]').exists()).toBe(false)
      expect(wrapper.find('[data-testid="next-game-day"]').exists()).toBe(false)
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

  // Test Basis: cmd_1783 A-E（試合日ページの改修）
  describe('cmd_1783 日程の移動と種類', () => {
    const schedule = (id: number, date: string, date_type: string) => ({ id, date, date_type })
    const scheduleWith = (...rows: ReturnType<typeof schedule>[]) => ({
      current_date: '2026-06-10',
      season_schedules: rows,
    })

    it('A: 種類が混在し取得順が逆でも日付順に隣へ移り、移動先の日付と種類を表示する', async () => {
      const wrapper = await mountDay({
        appearances: appearanceRows(1),
        season: scheduleWith(
          schedule(102, '2026-06-12', 'game_day'),
          schedule(101, '2026-06-11', 'travel_day'),
          schedule(100, '2026-06-10', 'game_day'),
          schedule(99, '2026-06-09', 'reserve_day'),
        ),
      })
      expect(wrapper.vm.prevSchedule.id).toBe(99)
      expect(wrapper.vm.nextSchedule.id).toBe(101)
      expect(wrapper.find('[data-testid="prev-game-day"]').text()).toContain('予備日')
      expect(wrapper.find('[data-testid="next-game-day"]').text()).toContain('移動日')
      expect(wrapper.find('[data-testid="next-game-day"]').text()).toContain('6/11')
      await wrapper.find('[data-testid="next-game-day"]').trigger('click')
      await flushPromises()
      expect(mockPush).toHaveBeenCalledWith({
        name: 'GameResult',
        params: { teamId: '1', scheduleId: '101' },
      })
    })

    it('A: 最初の日は前、最後の日は次のボタンが無い', async () => {
      const first = await mountDay({
        season: scheduleWith(
          schedule(100, '2026-06-10', 'travel_day'),
          schedule(101, '2026-06-11', 'game_day'),
        ),
      })
      expect(first.find('[data-testid="prev-game-day"]').exists()).toBe(false)
      const last = await mountDay({
        season: scheduleWith(
          schedule(99, '2026-06-09', 'game_day'),
          schedule(100, '2026-06-10', 'travel_day'),
        ),
      })
      expect(last.find('[data-testid="next-game-day"]').exists()).toBe(false)
    })

    it('A: 移動日を開いても前後の異なる種類の日へ移れる', async () => {
      const wrapper = await mountDay({
        appearances: appearanceRows(1),
        season: scheduleWith(
          schedule(99, '2026-06-09', 'reserve_day'),
          schedule(100, '2026-06-10', 'travel_day'),
          schedule(101, '2026-06-11', 'game_day'),
        ),
      })
      expect(wrapper.find('[data-testid="prev-game-day"]').text()).toContain('予備日')
      expect(wrapper.find('[data-testid="next-game-day"]').text()).toContain('試合日')
      await wrapper.find('[data-testid="next-game-day"]').trigger('click')
      await flushPromises()
      expect(mockPush).toHaveBeenCalledWith({
        name: 'GameResult',
        params: { teamId: '1', scheduleId: '101' },
      })
    })

    it('B: 9 種の選択肢を表示し、保存済みデータなしなら確認なしで PATCH する', async () => {
      const wrapper = await mountDay({
        game: { score: null, opponent_score: null },
        appearances: [],
      })
      const select = wrapper.find('[data-testid="date-type-select"]')
      expect(select.exists()).toBe(true)
      const items = wrapper.findComponent('[data-testid="date-type-select"]').props('items')
      expect(items).toHaveLength(9)
      expect(items).toContainEqual({ value: 'travel_day', title: '移動日' })
      mockPatch.mockResolvedValueOnce({ data: {} })
      wrapper
        .findComponent('[data-testid="date-type-select"]')
        .vm.$emit('update:modelValue', 'travel_day')
      await flushPromises()
      expect(mockPatch).toHaveBeenCalledWith('/teams/1/season/season_schedules/100', {
        season_schedule: { date_type: 'travel_day' },
      })
      expect(wrapper.vm.currentDateType).toBe('travel_day')
      expect(document.body.textContent).not.toContain('データは消えず')
    })

    it.each([
      { name: '得点', game: { score: 0, opponent_score: null }, appearances: [] },
      { name: '相手得点', game: { score: null, opponent_score: 0 }, appearances: [] },
      {
        name: 'ノーゲーム',
        game: { score: null, opponent_score: null, no_game: true },
        appearances: [],
      },
      {
        name: '登板記録',
        game: { score: null, opponent_score: null },
        appearances: appearanceRows(1),
      },
    ])(
      'B: 保存済み $name がある試合日から移動日へ変える時は確認し、キャンセルで PATCH しない',
      async ({ game, appearances }) => {
        const wrapper = await mountDay({ game, appearances })
        const pending = wrapper.vm.updateDateType('travel_day')
        await flushPromises()
        expect(document.body.textContent).toContain('データは消えず、隠れるだけ')
        const cancel = Array.from(document.body.querySelectorAll('button')).find(
          (b) => b.textContent?.trim() === 'キャンセル',
        )
        cancel!.click()
        await pending
        await flushPromises()
        expect(mockPatch).not.toHaveBeenCalled()
        expect(wrapper.vm.currentDateType).toBe('game_day')
      },
    )

    it('B: dirty 中は選択不可で、保存後に変更する案内を出す', async () => {
      const wrapper = await mountDay()
      wrapper.vm.gameData.score = 9
      await flushPromises()
      expect(wrapper.findComponent('[data-testid="date-type-select"]').props('disabled')).toBe(true)
      expect(wrapper.text()).toContain('保存してから変更')
    })

    it('B: PATCH 失敗時は元の種類に戻し、エラーを出す', async () => {
      const wrapper = await mountDay({ game: { score: null, opponent_score: null } })
      mockPatch.mockRejectedValueOnce(new Error('500'))
      await wrapper.vm.updateDateType('travel_day')
      await flushPromises()
      expect(wrapper.vm.currentDateType).toBe('game_day')
      expect(wrapper.vm.snackbarColor).toBe('error')
    })

    it('C: 移動日は試合の 4 段と要確認を隠し、tab=result でも members を開く', async () => {
      const wrapper = await mountDay({
        season: scheduleWith(schedule(100, '2026-06-10', 'travel_day')),
        query: { tab: 'result' },
      })
      for (const slug of ['setup', 'result', 'pitchers', 'in-game-absences']) {
        expect(wrapper.find(`[data-testid="${kind}-${slug}"]`).exists()).toBe(false)
      }
      expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(false)
      expect(wrapper.vm.activeStep).toBe('members')
      expect(wrapper.vm.openSections.members).toBe(true)
      expect(wrapper.find('[data-testid="game-day-progress-text"]').exists()).toBe(false)
      expect(appBarBreadcrumbs.value?.gameNumber).toBeNull()
    })

    it('C: no_game は試合日扱いで 4 段を出し、種類変更でその場で段が出入りする', async () => {
      const wrapper = await mountDay({
        game: { score: null, opponent_score: null },
        season: scheduleWith(schedule(100, '2026-06-10', 'no_game')),
      })
      for (const slug of ['setup', 'result', 'pitchers', 'in-game-absences']) {
        expect(wrapper.find(`[data-testid="${kind}-${slug}"]`).exists()).toBe(true)
      }
      mockPatch.mockResolvedValue({ data: {} })
      await wrapper.vm.updateDateType('travel_day')
      await flushPromises()
      expect(wrapper.find(`[data-testid="${kind}-result"]`).exists()).toBe(false)
      expect(wrapper.vm.activeStep).toBe('members')
      await wrapper.vm.updateDateType('game_day')
      await flushPromises()
      expect(wrapper.find(`[data-testid="${kind}-result"]`).exists()).toBe(true)
    })

    it('D: 登録・離脱の 3 段、試合日の 4 段を順に出す', async () => {
      const wrapper = await mountDay()
      const first = wrapper.find('[data-testid="step-group-registration"]')
      const second = wrapper.find('[data-testid="step-group-game"]')
      expect(first.attributes('aria-label')).toBe('登録・離脱')
      expect(second.attributes('aria-label')).toBe('試合日')
      const ids = (node: ReturnType<Wrapper['find']>) =>
        node
          .findAll(kind === 'step' ? '.v-stepper-item' : `[data-testid^="${kind}-"]`)
          .map((e) => e.attributes('data-testid'))
      if (kind === 'step') {
        expect(ids(first)).toEqual(['step-members', 'step-roster', 'step-absences'])
        expect(ids(second)).toEqual([
          'step-setup',
          'step-result',
          'step-pitchers',
          'step-in-game-absences',
        ])
      } else {
        expect(ids(first)).toEqual(['section-members', 'section-roster', 'section-absences'])
        expect(ids(second)).toEqual([
          'section-setup',
          'section-result',
          'section-pitchers',
          'section-pitcher-status',
          'section-in-game-absences',
        ])
      }
    })

    if (kind === 'step') {
      // Test Basis: subtask_1783p Operator 要望 1・2（2026-10-31）
      it('ページのツールバー保存を除き、AppBar 用ぱんくずを登録して離脱時に消す', async () => {
        const wrapper = await mountDay()
        expect(wrapper.find('.v-toolbar').exists()).toBe(false)
        expect(wrapper.find('[data-testid="save-setup"]').exists()).toBe(true)
        expect(wrapper.find('[data-testid="save-result"]').exists()).toBe(true)
        expect(appBarBreadcrumbs.value).toMatchObject({
          teamName: '豊玉',
          gameNumber: 5,
          seasonPortalRoute: { name: 'SeasonPortal', params: { teamId: '1' } },
        })
        expect(appBarBreadcrumbs.value?.date).toContain('6月10日')
        mounted.splice(mounted.indexOf(wrapper), 1)
        wrapper.unmount()
        expect(appBarBreadcrumbs.value).toBeNull()
      })

      it('E: 全段の指定アイコンは done と warn でも変わらず、読み上げから隠す', async () => {
        const wrapper = await mountDay({ appearances: [] })
        const icons = {
          members: 'mdi-account-multiple-plus-outline',
          roster: 'mdi-swap-vertical-bold',
          absences: 'mdi-bandage',
          setup: 'mdi-clipboard-list-outline',
          result: 'mdi-scoreboard-outline',
          pitchers: 'mdi-baseball',
          'in-game-absences': 'mdi-ambulance',
        }
        for (const [slug, icon] of Object.entries(icons)) {
          const step = wrapper.find(`[data-testid="step-${slug}"]`)
          expect(step.html()).toContain(icon)
          expect(step.find('.v-icon').attributes('aria-hidden')).toBe('true')
        }
        expect(wrapper.find('[data-testid="step-result"]').attributes('data-state')).toBe('done')
        expect(wrapper.find('[data-testid="step-pitchers"]').attributes('data-state')).toBe('warn')
      })
    }
  })

  // ───────── スマホ幅（縦積み）だけの振る舞い ─────────
  // 該当しない幅では describe 自体を登録しない（skip ではなく、そもそも存在しないテスト）
  if (kind === 'section') {
    describe('縦積み', () => {
      it('段が 登録・離脱（選手登録・契約変更 → 昇降格 → 負傷）→ 試合日（予告先発・対戦設定 → 結果 → 登板記録 → 試合中の負傷）の順に並ぶ', async () => {
        const wrapper = await mountDay()
        expect(wrapper.find('[data-testid="game-day-stepper"]').exists()).toBe(false)
        const ids = wrapper
          .findAll('[data-testid^="section-"]')
          .map((e) => e.attributes('data-testid'))
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

      // Test Basis: subtask_1783p Operator 要望 2（2026-10-31）
      it('縦積みでも試合（IRC）の区切りを消し、二つの背景色を区別する', async () => {
        const wrapper = await mountDay()
        expect(wrapper.find('.game-day-divider').exists()).toBe(false)
        expect(wrapper.find('[data-testid="step-group-registration"]').classes()).toContain(
          'game-day-stack__group--registration',
        )
        expect(wrapper.find('[data-testid="step-group-game"]').classes()).toContain(
          'game-day-stack__group--game',
        )
        expect(wrapper.find('[data-testid="section-result"]').text()).toContain('試合結果')
      })

      it('スマホ幅から PC 幅に変わると、登板記録の編集は描き直しで失われるので、未保存の印も戻す', async () => {
        const wrapper = await mountDay({
          appearances: appearanceRows(1),
          pitcherStub: dirtyPitcherStub,
        })
        await wrapper
          .find('[data-testid="section-pitchers"] .game-day-section__title')
          .trigger('click')
        await wrapper.find('[data-testid="make-dirty"]').trigger('click')
        expect(wrapper.vm.hasUnsavedChanges).toBe(true)

        await resizeTo(PC_WIDTH)

        expect(wrapper.find('[data-testid="game-day-stepper"]').exists()).toBe(true)
        expect(wrapper.vm.pitcherDirty).toBe(false)
        expect(wrapper.vm.hasUnsavedChanges).toBe(false)
      })

      describe('旧 URL のタブ名', () => {
        it('既定（overview）は予告先発・対戦設定と結果の段を開く', async () => {
          const wrapper = await mountDay({ appearances: appearanceRows(1) })
          expect(wrapper.vm.openSections.setup).toBe(true)
          expect(wrapper.vm.openSections.result).toBe(true)
          expect(wrapper.vm.openSections.pitchers).toBe(false)
        })

        it('pitchers は登板記録の段を開く', async () => {
          const wrapper = await mountDay({
            appearances: appearanceRows(1),
            query: { tab: 'pitchers' },
          })
          expect(wrapper.vm.openSections.pitchers).toBe(true)
          expect(wrapper.vm.openSections.pitcherStatus).toBe(false)
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
  }

  // ───────── PC 幅（ステッパー + タブ）だけの振る舞い ─────────
  // 該当しない幅では describe 自体を登録しない（skip ではなく、そもそも存在しないテスト）
  if (kind === 'step') {
    describe('ステッパー', () => {
      const visiblePanels = (wrapper: Wrapper) =>
        wrapper
          .findAll('[data-testid^="panel-"]')
          .filter((p) => p.isVisible())
          .map((p) => p.attributes('data-testid')!.replace('panel-', ''))

      it('登録・離脱と試合日の 7 段が見出しと区切りなしで一列に並ぶ', async () => {
        const wrapper = await mountDay()
        expect(wrapper.find('[data-testid="game-day-stack"]').exists()).toBe(false)
        const stepIds = (group: string) =>
          wrapper
            .find(`[data-testid="step-group-${group}"]`)
            .findAll('.v-stepper-item')
            .map((e) => e.attributes('data-testid'))
        expect(stepIds('registration')).toEqual(['step-members', 'step-roster', 'step-absences'])
        expect(stepIds('game')).toEqual([
          'step-setup',
          'step-result',
          'step-pitchers',
          'step-in-game-absences',
        ])
        const header = wrapper.find('.game-day-stepper__header')
        expect(header.text()).not.toContain('登録・離脱')
        expect(header.text()).not.toContain('試合日')
        expect(header.text()).not.toContain('試合（IRC）')
        expect(wrapper.find('[data-testid="step-group-registration"]').classes()).toContain(
          'game-day-stepper__group--registration',
        )
        expect(wrapper.find('[data-testid="step-group-game"]').classes()).toContain(
          'game-day-stepper__group--game',
        )
        expect(wrapper.find('[data-testid="step-result"]').text()).toContain('試合結果')
        expect(wrapper.find('[data-testid="step-members"]').text()).toContain('選手登録・契約変更')
      })

      it('各ステップに状態を文字で出す（済・要確認・未入力）。別画面で行うステップは状態を出さない', async () => {
        const wrapper = await mountDay({ appearances: [] })
        expect(wrapper.find('[data-testid="step-result"]').text()).toContain('済')
        expect(wrapper.find('[data-testid="step-pitchers"]').text()).toContain('要確認')
        expect(wrapper.find('[data-testid="step-members"]').find('.gd-state-chip').exists()).toBe(
          false,
        )
        const todo = await mountDay({ game: { score: null, opponent_score: null } })
        expect(todo.find('[data-testid="step-setup"]').text()).toContain('未入力')
      })

      // Test Basis: thbig-dugout-visual-refresh-design.md §6.5, §7 段2 (subtask_1787d)
      it('済・未入力・要確認だけに状態バッジを重ね、段アイコンは保つ', async () => {
        const warning = await mountDay({ appearances: [] })
        expect(
          warning.find('[data-testid="step-result"] [data-testid="step-state-badge"]').html(),
        ).toContain('mdi-check-circle')
        expect(
          warning.find('[data-testid="step-pitchers"] [data-testid="step-state-badge"]').html(),
        ).toContain('mdi-alert')
        expect(
          warning.find('[data-testid="step-members"] [data-testid="step-state-badge"]').exists(),
        ).toBe(false)
        const todo = await mountDay({ game: { score: null, opponent_score: null } })
        expect(
          todo.find('[data-testid="step-result"] [data-testid="step-state-badge"]').html(),
        ).toContain('mdi-circle-outline')
        expect(todo.find('[data-testid="step-result"] .v-stepper-item__avatar').html()).toContain(
          'mdi-scoreboard-outline',
        )
      })

      describe('初期ステップ', () => {
        it('?tab 指定なし: 要確認があればそのステップ（得点あり・登板なし → 登板記録）', async () => {
          const wrapper = await mountDay({ appearances: [] })
          expect(visiblePanels(wrapper)).toEqual(['pitchers'])
        })

        it('?tab 指定なし: 登板あり・得点なし → 結果', async () => {
          const wrapper = await mountDay({
            game: { score: null, opponent_score: null },
            appearances: appearanceRows(1),
          })
          expect(visiblePanels(wrapper)).toEqual(['result'])
        })

        it('?tab 指定なし: 要確認が無ければ、最初の未入力のステップ（予告先発・対戦設定）', async () => {
          const wrapper = await mountDay({ game: { score: null, opponent_score: null } })
          expect(visiblePanels(wrapper)).toEqual(['setup'])
        })

        it('?tab 指定なし: 全部済、または試合日前なら 結果', async () => {
          const done = await mountDay({ appearances: appearanceRows(1) })
          expect(visiblePanels(done)).toEqual(['result'])
          const upcoming = await mountDay({
            game: { score: null, opponent_score: null, game_date: '2026-06-20' },
          })
          expect(visiblePanels(upcoming)).toEqual(['result'])
        })

        it('?tab=pitchers は、要確認が別にあっても登板記録を開く', async () => {
          const wrapper = await mountDay({
            game: { score: null, opponent_score: null },
            appearances: appearanceRows(1),
            query: { tab: 'pitchers' },
          })
          expect(visiblePanels(wrapper)).toEqual(['pitchers'])
        })

        it('?tab=pitcher_status は登板記録を開き、その中の投手状態も開く', async () => {
          const wrapper = await mountDay({
            appearances: appearanceRows(1),
            query: { tab: 'pitcher_status' },
          })
          expect(visiblePanels(wrapper)).toEqual(['pitchers'])
          expect(wrapper.vm.openSections.pitcherStatus).toBe(true)
          expect(
            wrapper.find('[data-testid="panel-pitchers"] pitcher-status-tab-stub').exists(),
          ).toBe(true)
        })

        it('?tab=overview は、予告先発・対戦設定と結果のうち手の要る方（未入力があれば予告先発・対戦設定、無ければ結果）', async () => {
          const todo = await mountDay({
            game: { score: null, opponent_score: null },
            query: { tab: 'overview' },
          })
          expect(visiblePanels(todo)).toEqual(['setup'])
          // 登板だけが要確認でも、overview の範囲外なので結果
          const mismatch = await mountDay({ appearances: [], query: { tab: 'overview' } })
          expect(visiblePanels(mismatch)).toEqual(['result'])
        })

        it('知らないタブ名は overview と同じ扱い', async () => {
          const wrapper = await mountDay({ appearances: appearanceRows(1), query: { tab: 'x' } })
          expect(visiblePanels(wrapper)).toEqual(['result'])
        })

        it('読み込み後にタブ名が変わっても（activeTab の変更）、該当のステップへ移る', async () => {
          const wrapper = await mountDay({ appearances: appearanceRows(1) })
          wrapper.vm.activeTab = 'pitchers'
          await flushPromises()
          expect(visiblePanels(wrapper)).toEqual(['pitchers'])
        })
      })

      describe('ステップの切り替え', () => {
        it('順番に関係なく、どのステップへも直接移れる（URL は変えず、確認も出さない）', async () => {
          const wrapper = await mountDay({ appearances: appearanceRows(1) })
          expect(visiblePanels(wrapper)).toEqual(['result'])
          await wrapper.find('[data-testid="step-in-game-absences"]').trigger('click')
          expect(visiblePanels(wrapper)).toEqual(['in-game-absences'])
          await wrapper.find('[data-testid="step-members"]').trigger('click')
          expect(visiblePanels(wrapper)).toEqual(['members'])
          await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
          expect(visiblePanels(wrapper)).toEqual(['pitchers'])
          expect(mockPush).not.toHaveBeenCalled()
          expect(document.body.textContent).not.toContain('未保存の変更があります')
        })

        it('未保存の入力があっても、切り替えで確認を出さず、入力も失われない', async () => {
          const wrapper = await mountDay({ appearances: appearanceRows(1) })
          const scoreInput = () => wrapper.find('[data-testid="panel-result"] input[type="number"]')
          await scoreInput().setValue(9)
          const stadium = wrapper
            .findAll('[data-testid="panel-setup"] .v-input')
            .find((e) => e.find('.v-field-label').text() === '球場')!
            .find('input')
          await stadium.setValue('東京ドーム')
          expect(wrapper.vm.hasUnsavedChanges).toBe(true)

          await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
          await wrapper.find('[data-testid="step-setup"]').trigger('click')
          await wrapper.find('[data-testid="step-absences"]').trigger('click')
          await wrapper.find('[data-testid="step-result"]').trigger('click')

          expect(document.body.textContent).not.toContain('未保存の変更があります')
          expect((scoreInput().element as HTMLInputElement).value).toBe('9')
          expect(wrapper.vm.gameData.score).toBe(9)
          expect(wrapper.vm.gameData.stadium).toBe('東京ドーム')
          expect(wrapper.vm.hasUnsavedChanges).toBe(true)
          expect(state(wrapper, 'result')).toBe('editing')
          // ページ離脱のガードは、切り替え後もそのまま効く
          const left = routeGuards.leave!()
          await flushPromises()
          expect(document.body.textContent).toContain('未保存の変更があります')
          const cancel = Array.from(document.body.querySelectorAll('button')).find(
            (b) => b.textContent?.trim() === 'キャンセル',
          )
          cancel!.click()
          expect(await left).toBe(false)
        })

        it('登板記録は初めて開くまで描画せず、開いた後は切り替えても作り直さない（入力中の値を保つ）', async () => {
          let mountCount = 0
          let unmountCount = 0
          const pitcherStub = {
            props: ['gameResult'],
            emits: ['dirty-change', 'saved'],
            setup() {
              mountCount += 1
              onBeforeUnmount(() => {
                unmountCount += 1
              })
              return {}
            },
            template: '<div data-testid="tab-stub" />',
          }
          const wrapper = await mountDay({ appearances: appearanceRows(1), pitcherStub })
          expect(mountCount).toBe(0)
          await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
          expect(mountCount).toBe(1)
          await wrapper.find('[data-testid="step-result"]').trigger('click')
          await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
          expect(mountCount).toBe(1)
          expect(unmountCount).toBe(0)
          expect(wrapper.find('[data-testid="tab-stub"]').exists()).toBe(true)
        })

        it('自分で選んだステップは、読み込みの完了で上書きされない（読み込み中に選んだ場合）', async () => {
          let release!: () => void
          const seasonGate = new Promise<void>((resolve) => {
            release = resolve
          })
          const wrapper = await mountDay({
            game: { score: null, opponent_score: null },
            seasonGate,
          })
          // 読み込みの途中（シーズンの取得待ち）。初期ステップのまま
          expect(visiblePanels(wrapper)).toEqual(['result'])
          await wrapper.find('[data-testid="step-in-game-absences"]').trigger('click')

          release()
          await flushPromises()

          // 読み込みが終われば、選ばなければ最初の未入力（予告先発・対戦設定）に移るところ
          expect(state(wrapper, 'setup')).toBe('todo')
          expect(visiblePanels(wrapper)).toEqual(['in-game-absences'])
        })

        it('読み込み中に何も選ばなければ、読み込みの完了で最初の未入力のステップへ移る', async () => {
          let release!: () => void
          const seasonGate = new Promise<void>((resolve) => {
            release = resolve
          })
          const wrapper = await mountDay({
            game: { score: null, opponent_score: null },
            seasonGate,
          })
          expect(visiblePanels(wrapper)).toEqual(['result'])
          release()
          await flushPromises()
          expect(visiblePanels(wrapper)).toEqual(['setup'])
        })
      })

      describe('幅の変化', () => {
        it('PC 幅からスマホ幅に変わると縦積みに切り替わり、入力済みの値が引き継がれ、PC 幅で選んでいたステップの段が開く', async () => {
          const wrapper = await mountDay({ appearances: appearanceRows(1) })
          await wrapper.find('[data-testid="panel-result"] input[type="number"]').setValue(9)
          await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
          expect(wrapper.find('[data-testid="game-day-stepper"]').exists()).toBe(true)

          await resizeTo(PHONE_WIDTH)

          expect(wrapper.find('[data-testid="game-day-stepper"]').exists()).toBe(false)
          expect(wrapper.find('[data-testid="game-day-stack"]').exists()).toBe(true)
          expect(wrapper.vm.gameData.score).toBe(9)
          expect(
            (
              wrapper.find('[data-testid="section-result"] input[type="number"]')
                .element as HTMLInputElement
            ).value,
          ).toBe('9')
          expect(wrapper.vm.hasUnsavedChanges).toBe(true)
          // PC 幅で選んでいた登板記録の段が、縦積みで開いている（読み込み直後は結果の段だけが開いていた）
          const pitchers = wrapper.find('[data-testid="section-pitchers"]')
          expect(pitchers.classes()).toContain('game-day-section--open')
          expect(pitchers.find('.game-day-section__body').isVisible()).toBe(true)
        })

        it('幅が変わると登板記録の編集は描き直しで失われるので、未保存の印も戻す（ガードが空振りしない）', async () => {
          const wrapper = await mountDay({
            appearances: appearanceRows(1),
            pitcherStub: dirtyPitcherStub,
          })
          await wrapper.find('[data-testid="step-pitchers"]').trigger('click')
          await wrapper.find('[data-testid="make-dirty"]').trigger('click')
          expect(wrapper.vm.pitcherDirty).toBe(true)
          expect(wrapper.vm.hasUnsavedChanges).toBe(true)
          expect(state(wrapper, 'pitchers')).toBe('editing')

          await resizeTo(PHONE_WIDTH)

          expect(wrapper.vm.pitcherDirty).toBe(false)
          expect(wrapper.vm.hasUnsavedChanges).toBe(false)
          // 離脱ガードも確認を出さない
          expect(await routeGuards.leave!()).toBe(true)
          expect(document.body.textContent).not.toContain('未保存の変更があります')
        })

        it('得点など親が持つ未保存の入力は、幅が変わっても残り、ガードの対象のまま', async () => {
          const wrapper = await mountDay({
            appearances: appearanceRows(1),
            pitcherStub: dirtyPitcherStub,
          })
          await wrapper.find('[data-testid="panel-result"] input[type="number"]').setValue(9)
          await resizeTo(PHONE_WIDTH)
          expect(wrapper.vm.pitcherDirty).toBe(false)
          expect(wrapper.vm.hasUnsavedChanges).toBe(true)
        })
      })
    })
  }
})
