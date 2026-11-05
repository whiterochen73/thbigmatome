import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'

// 試合日ページの登録・離脱の 3 段（選手登録・昇降格・負傷・出場停止）の操作範囲（cmd_1784 段2b）。
// GameResult.spec.ts は 1 ファイルで 4GB 近いヒープを使う（base でも RSS 約 5GB）ため、範囲の判定はこのファイルに分ける。
// 幅によって描き分ける部分（PC のステッパー / スマホの縦積み）は本題ではないので、PC 幅だけで確かめる。

const { mockGet, mockPut, mockPatch, mockPush, routeQuery } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPut: vi.fn(),
  mockPatch: vi.fn(),
  mockPush: vi.fn(),
  routeQuery: { value: {} as Record<string, string> },
}))

// 埋め込む 3 つの部品。渡された props（asOfDate / readonly）を data 属性で見えるようにする差し替え
const { embedStub } = vi.hoisted(() => {
  const embedStub = async (name: string) => {
    const { defineComponent, h } = await import('vue')
    return {
      default: defineComponent({
        name,
        props: {
          teamId: { type: Number, default: undefined },
          gameDayActions: { type: Boolean, default: false },
          asOfDate: { type: String, default: undefined },
          readonly: { type: Boolean, default: false },
        },
        setup(props) {
          return () =>
            h('div', {
              'data-embed': name,
              'data-as-of': props.asOfDate,
              'data-readonly': String(props.readonly),
            })
        },
      }),
    }
  }
  return { embedStub }
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
  onBeforeRouteLeave: vi.fn(),
  onBeforeRouteUpdate: vi.fn(),
}))

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

// サーバが返す試合日とみなす種別（SeasonSchedule::GAME_DATE_TYPES）
const GAME_DATE_TYPES = ['game_day', 'interleague_game_day', 'playoff_day']

const seasonResponse = {
  game_date_types: GAME_DATE_TYPES,
  current_date: '2026-06-10',
  // 今の範囲: 6/9 の結果の翌日〜次の試合日(6/10)。登録・離脱を操作できるのは 6/10 だけ
  current_range: { start_date: '2026-06-10', end_date: '2026-06-10' },
  season_schedules: [
    { id: 99, date: '2026-06-09', date_type: 'game_day' },
    { id: 100, date: '2026-06-10', date_type: 'game_day' },
    { id: 101, date: '2026-06-11', date_type: 'travel_day' },
    { id: 102, date: '2026-06-12', date_type: 'game_day' },
  ],
}

interface MountDayOptions {
  game?: Record<string, unknown>
  appearances?: unknown[]
  season?: Record<string, unknown> | Error
  // 指定すると、シーズンの取得がこの Promise の解決まで終わらない
  seasonGate?: Promise<void>
}

describe('GameResult 試合日ページ: 登録・離脱の操作範囲', () => {
  const mounted: Array<{ unmount: () => void }> = []

  beforeEach(() => {
    vi.clearAllMocks()
    routeQuery.value = {}
    Object.defineProperty(window, 'innerWidth', { configurable: true, writable: true, value: 1280 })
  })

  afterEach(() => {
    mounted.splice(0).forEach((w) => w.unmount())
  })

  async function mountDay(opts: MountDayOptions = {}) {
    const { game = {}, appearances = [], season = seasonResponse } = opts
    mockGet.mockImplementation((url: string) => {
      if (url === '/game/100') return Promise.resolve({ data: { ...gameResponse, ...game } })
      if (url === '/teams') return Promise.resolve({ data: [] })
      if (url === '/pitcher_appearances') return Promise.resolve({ data: appearances })
      if (url === '/player_absences') return Promise.resolve({ data: [] })
      if (url === '/teams/1/season') {
        if (season instanceof Error) return Promise.reject(season)
        const response = { data: season }
        return opts.seasonGate ? opts.seasonGate.then(() => response) : Promise.resolve(response)
      }
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = mount(GameResult, {
      attachTo: document.body,
      global: {
        plugins: [createVuetify({ components, directives }), i18n],
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

  type Wrapper = Awaited<ReturnType<typeof mountDay>>

  const body = (wrapper: Wrapper, id: string) => wrapper.find(`[data-testid="panel-${id}"]`)
  const openStep = async (wrapper: Wrapper, slug: string) => {
    await wrapper.find(`[data-testid="step-${slug}"]`).trigger('click')
    await flushPromises()
  }
  const appearanceRows = (n: number) =>
    Array.from({ length: n }, (_, i) => ({ id: i + 1, pitcher_id: 10 + i }))

  const EMBEDS = [
    { slug: 'members', component: 'TeamMembers' },
    { slug: 'roster', component: 'SeasonRosterTab' },
    { slug: 'absences', component: 'SeasonAbsenceTab' },
  ] as const

  // 登録・昇降格・負傷・出場停止（登録・離脱の 3 段）は、開いた日が今の範囲の日の時だけ操作できる。
  // 範囲 = 最後に結果が入った試合日の翌日〜次の試合日。範囲の外は見るだけにして、過去分の修正はシーズン画面へ案内する。
  // Test Basis: context/thbig-dugout-season-record-restructure-design.md の 2026-11-01 の追記 2 本、
  //   context/thbig-dugout-game-day-flow-design.md §5.1 の追記
  describe('操作範囲（今の範囲）', () => {
    const withRange = (range: { start_date: string; end_date: string } | null) => ({
      ...seasonResponse,
      current_range: range,
    })
    // Operator 決定 2026-11-01: 操作の仕組みを説明する文は足さない。「見るだけ」とわかる短い文だけ
    const OUTSIDE = 'この日は見るだけです'
    const embedded = (wrapper: Wrapper, slug: string) => body(wrapper, slug).find('[data-embed]')

    it.each(EMBEDS)('$slug: 範囲の中の日は操作でき、案内を出さない', async ({ slug }) => {
      const wrapper = await mountDay()
      await openStep(wrapper, slug)
      expect(embedded(wrapper, slug).attributes('data-readonly')).toBe('false')
      expect(embedded(wrapper, slug).attributes('data-as-of')).toBe('2026-06-10')
      expect(wrapper.find('[data-testid="range-note"]').exists()).toBe(false)
    })

    it.each(EMBEDS)(
      '$slug: 範囲の外の日は読み取り専用で、案内と「シーズン画面で修正する」リンクを部品の上に出す',
      async ({ slug }) => {
        const wrapper = await mountDay({
          season: withRange({ start_date: '2026-06-12', end_date: '2026-06-12' }),
        })
        await openStep(wrapper, slug)
        const panel = body(wrapper, slug)
        expect(embedded(wrapper, slug).attributes('data-readonly')).toBe('true')
        expect(panel.find('[data-testid="range-note"]').text()).toContain(OUTSIDE)
        expect(panel.find('[data-testid="range-note"]').text()).not.toContain('過去分の修正')
        expect(panel.find('[data-testid="range-note"]').text()).not.toContain('今の範囲')
        expect(panel.find('[data-testid="range-note-link"]').text()).toBe('シーズン画面で修正する')
        const html = panel.element.innerHTML
        expect(html.indexOf('data-testid="range-note"')).toBeLessThan(html.indexOf('data-embed'))
        // 古い「現在日として記録されます」の注記はやめた
        expect(wrapper.find('[data-testid="date-note"]').exists()).toBe(false)
        expect(wrapper.text()).not.toContain('現在日（')
      },
    )

    it('範囲の両端の日は操作でき、その外側 1 日は操作できない（境界）', async () => {
      // 試合日は 6/10。範囲 6/10〜6/12 は開始日、6/8〜6/10 は終了日が試合日
      for (const range of [
        { start_date: '2026-06-10', end_date: '2026-06-12' },
        { start_date: '2026-06-08', end_date: '2026-06-10' },
      ]) {
        const wrapper = await mountDay({ season: withRange(range) })
        await openStep(wrapper, 'roster')
        expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('false')
      }
      for (const range of [
        { start_date: '2026-06-11', end_date: '2026-06-12' },
        { start_date: '2026-06-08', end_date: '2026-06-09' },
      ]) {
        const wrapper = await mountDay({ season: withRange(range) })
        await openStep(wrapper, 'roster')
        expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('true')
      }
    })

    it('移動日などの試合の無い日でも、範囲の中なら操作できる（その日の日付で記録する）', async () => {
      // 5/7 試合（結果済み）→ 5/8 移動日 → 5/9 試合 の 5/8 を開いた状態
      const wrapper = await mountDay({
        game: { game_date: '2026-06-10' },
        season: {
          ...seasonResponse,
          current_range: { start_date: '2026-06-10', end_date: '2026-06-11' },
          season_schedules: seasonResponse.season_schedules.map((s) =>
            s.id === 100 ? { ...s, date_type: 'travel_day' } : s,
          ),
        },
      })
      expect(wrapper.vm.steps.map((step: { id: string }) => step.id)).toEqual([
        'members',
        'roster',
        'absences',
      ])
      await openStep(wrapper, 'roster')
      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('false')
      expect(embedded(wrapper, 'roster').attributes('data-as-of')).toBe('2026-06-10')
    })

    // Test Basis: cmd_1836（Operator 2026-11-05「最終試合日にも選手登録、昇降格、離脱の登録ができるように」）。
    // サーバは最終試合日に結果が入った後、今の範囲を最終試合日の 1 日にして返す（SeasonCurrentRange）
    describe('最終試合日（結果が入った後の範囲 = 最終試合日の 1 日）', () => {
      const finalDaySeason = {
        ...seasonResponse,
        current_date: '2026-06-10',
        current_range: { start_date: '2026-06-10', end_date: '2026-06-10' },
        season_schedules: [
          { id: 99, date: '2026-06-09', date_type: 'game_day' },
          { id: 100, date: '2026-06-10', date_type: 'game_day' },
          { id: 101, date: '2026-06-11', date_type: 'travel_day' },
        ],
      }

      it.each(EMBEDS)(
        '$slug: 最終試合日（結果が入った日）は操作でき、その日の日付で記録する',
        async ({ slug }) => {
          const wrapper = await mountDay({
            game: { score: 3, opponent_score: 1 },
            season: finalDaySeason,
          })
          await openStep(wrapper, slug)
          expect(embedded(wrapper, slug).attributes('data-readonly')).toBe('false')
          expect(embedded(wrapper, slug).attributes('data-as-of')).toBe('2026-06-10')
          expect(wrapper.find('[data-testid="range-note"]').exists()).toBe(false)
        },
      )

      it('最終試合日の前の日と後の日は読み取り専用で、「この日は見るだけです」を案内する', async () => {
        for (const date of ['2026-06-09', '2026-06-11']) {
          const wrapper = await mountDay({ game: { game_date: date }, season: finalDaySeason })
          await openStep(wrapper, 'roster')
          expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('true')
          expect(body(wrapper, 'roster').find('[data-testid="range-note"]').text()).toContain(
            OUTSIDE,
          )
        }
      })
    })

    // 範囲そのものが無いのは、試合日がひとつも無い日程など（最終試合日の後ではない）。どの日も見るだけ
    it('範囲が無い時は、どの日も読み取り専用で、「この日は見るだけです」を案内する', async () => {
      const wrapper = await mountDay({ season: withRange(null) })
      await openStep(wrapper, 'absences')
      expect(embedded(wrapper, 'absences').attributes('data-readonly')).toBe('true')
      expect(body(wrapper, 'absences').find('[data-testid="range-note"]').text()).toContain(OUTSIDE)
    })

    it('範囲の取得中は、読み取り専用のまま案内は出さない（「取れなかった」と誤って案内しない）', async () => {
      let release!: () => void
      const seasonGate = new Promise<void>((resolve) => {
        release = resolve
      })
      const wrapper = await mountDay({ seasonGate })
      await openStep(wrapper, 'roster')
      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('true')
      expect(wrapper.find('[data-testid="range-note"]').exists()).toBe(false)

      release()
      await flushPromises()

      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('false')
      expect(wrapper.find('[data-testid="range-note"]').exists()).toBe(false)
    })

    it('一度取れた範囲も、次の取得に失敗したら取れなかった扱いに戻す（古い範囲で操作させない）', async () => {
      const wrapper = await mountDay()
      await openStep(wrapper, 'roster')
      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('false')

      mockGet.mockImplementation((url: string) =>
        url === '/teams/1/season'
          ? Promise.reject(new Error('500'))
          : Promise.resolve({ data: [] }),
      )
      await wrapper.vm.fetchSeasonInfo()
      await flushPromises()

      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('true')
      expect(body(wrapper, 'roster').find('[data-testid="range-note"]').text()).toContain(
        '範囲を取得できないので、見るだけです',
      )
    })

    it('範囲が取れない時（シーズンの取得に失敗）は、読み取り専用にして、その旨を案内する', async () => {
      const wrapper = await mountDay({ season: new Error('500') })
      await openStep(wrapper, 'members')
      expect(embedded(wrapper, 'members').attributes('data-readonly')).toBe('true')
      expect(body(wrapper, 'members').find('[data-testid="range-note"]').text()).toContain(
        '範囲を取得できないので、見るだけです',
      )
    })

    it('範囲の外でも、試合設定・試合結果・登板記録は入力・修正できる（案内も出さない）', async () => {
      const wrapper = await mountDay({
        season: withRange({ start_date: '2026-06-12', end_date: '2026-06-12' }),
        appearances: appearanceRows(1),
      })
      for (const slug of ['setup', 'result', 'pitchers']) await openStep(wrapper, slug)
      expect(wrapper.find('[data-testid="save-setup"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="save-result"]').exists()).toBe(true)
      expect(
        body(wrapper, 'pitchers').findComponent({ name: 'PitcherAppearanceTab' }).exists(),
      ).toBe(true)
      expect(body(wrapper, 'setup').find('[data-testid="range-note"]').exists()).toBe(false)
      expect(body(wrapper, 'result').find('[data-testid="range-note"]').exists()).toBe(false)
    })

    // Test Basis: subtask_1810a（Operator 2026-11-02）投手状態は登録・離脱のグループに置くが、見るだけなので範囲に従わない
    it.each([
      { label: '範囲の外', range: { start_date: '2026-06-12', end_date: '2026-06-12' } },
      { label: '範囲が無い（試合日の無い日程など）', range: null },
    ])('投手状態の段は、$label の日でも表示し、案内も出さない', async ({ range }) => {
      const wrapper = await mountDay({ season: withRange(range) })
      await openStep(wrapper, 'pitcher-status')
      const panel = body(wrapper, 'pitcher-status')
      expect(panel.isVisible()).toBe(true)
      expect(panel.find('pitcher-status-tab-stub').exists()).toBe(true)
      expect(panel.find('[data-testid="range-note"]').exists()).toBe(false)
      expect(panel.find('[data-testid="link-pitcher-status"]').exists()).toBe(false)
    })

    it('別の日へ移ると、その日の日付と範囲で判定し直す', async () => {
      const wrapper = await mountDay({
        season: withRange({ start_date: '2026-06-12', end_date: '2026-06-12' }),
      })
      await openStep(wrapper, 'roster')
      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('true')

      wrapper.vm.gameData.game_date = '2026-06-12'
      await flushPromises()

      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('false')
      expect(embedded(wrapper, 'roster').attributes('data-as-of')).toBe('2026-06-12')
    })

    // リンク先は、開いた日の日付を ?date= で渡してシーズン画面の該当タブを開く
    it.each(EMBEDS)(
      '$slug: 「シーズン画面で修正する」は開いた日の日付とタブでシーズン画面へ向かう',
      async ({ slug }) => {
        // 現在日（6/12）と開いた日（6/10）を違えておく。現在日を渡す取り違えを見分けるため
        const wrapper = await mountDay({
          season: {
            ...withRange({ start_date: '2026-06-12', end_date: '2026-06-12' }),
            current_date: '2026-06-12',
          },
        })
        await openStep(wrapper, slug)
        const link = body(wrapper, slug).findComponent('[data-testid="range-note-link"]')
        expect(link.props('to')).toEqual({
          name: 'SeasonPortal',
          params: { teamId: '1' },
          query: { tab: slug, date: '2026-06-10' },
        })
      },
    )

    // 結果の保存で今の範囲が進む。保存後に取り直さないと、範囲を出た日の 3 段が操作可能のまま残る
    it('結果を保存して範囲が進んだら、範囲を取り直して 3 段を読み取り専用にし、案内を出す', async () => {
      const wrapper = await mountDay()
      await openStep(wrapper, 'roster')
      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('false')
      const seasonGets = () =>
        mockGet.mock.calls.filter(([url]) => url === '/teams/1/season').length
      expect(seasonGets()).toBe(1)

      // 6/10 の結果が入り、今の範囲は 6/11〜6/12 に進む
      mockGet.mockImplementation((url: string) => {
        if (url === '/teams/1/season') {
          return Promise.resolve({
            data: {
              ...seasonResponse,
              current_range: { start_date: '2026-06-11', end_date: '2026-06-12' },
            },
          })
        }
        return Promise.resolve({ data: [] })
      })
      mockPut.mockResolvedValue({ data: {} })
      await openStep(wrapper, 'result')
      await wrapper.find('[data-testid="save-result"]').trigger('click')
      await flushPromises()

      expect(mockPut).toHaveBeenCalledTimes(1)
      expect(seasonGets()).toBe(2)
      await openStep(wrapper, 'roster')
      expect(embedded(wrapper, 'roster').attributes('data-readonly')).toBe('true')
      expect(body(wrapper, 'roster').find('[data-testid="range-note"]').text()).toContain(
        'この日は見るだけです',
      )
    })

    it('保存に失敗した時は、範囲を取り直さない', async () => {
      const wrapper = await mountDay()
      mockPut.mockRejectedValue(new Error('500'))
      await openStep(wrapper, 'result')
      await wrapper.find('[data-testid="save-result"]').trigger('click')
      await flushPromises()

      expect(mockPut).toHaveBeenCalledTimes(1)
      expect(mockGet.mock.calls.filter(([url]) => url === '/teams/1/season')).toHaveLength(1)
    })
  })

  // Operator 決定 2026-11-02: 各段の中身の先頭にあった小さな補足（段の説明）を消す。件数・状態は残す
  describe('段の先頭の補足', () => {
    const NOTES = ['新規登録・契約変更', '1軍・2軍の入れ替え', '負傷・出場停止の登録・編集']

    it.each([
      { slug: 'members', note: NOTES[0] },
      { slug: 'roster', note: NOTES[1] },
    ])('$slug: 段の説明を出さず、シーズンポータルへのリンクだけを置く', async ({ slug, note }) => {
      const wrapper = await mountDay()
      await openStep(wrapper, slug)
      const panel = wrapper.find(`[data-testid="panel-${slug}"]`)
      expect(panel.text()).not.toContain(note)
      expect(panel.find(`[data-testid="link-${slug}"]`).exists()).toBe(true)
    })

    it('負傷・出場停止: 件数は出し、説明文は出さない', async () => {
      const wrapper = await mountDay()
      await openStep(wrapper, 'absences')
      const panel = wrapper.find('[data-testid="panel-absences"]')
      expect(panel.text()).toContain('試合前 0 件・試合中 0 件')
      expect(panel.text()).not.toContain(NOTES[2])
    })

    it('不要になった文言キーは ja.json に残さない', () => {
      for (const key of ['members', 'roster', 'absences']) {
        expect(ja.gameDay.summary).not.toHaveProperty(key)
      }
      expect(ja.gameDay.summary).toHaveProperty('absencesByPhase')
    })
  })

  // Operator 決定 2026-11-01: 画面に操作の仕組みを説明する文を足さない。
  // ノーゲームのチェックに付けていた常時表示のヒント（休養の計算・勝敗投手の説明）をやめた
  describe('ノーゲームのチェック', () => {
    it('ラベルだけを出し、常時表示のヒント（仕組みの説明）は出さない', async () => {
      const wrapper = await mountDay()
      await openStep(wrapper, 'result')
      const checkbox = wrapper.find('[data-testid="no-game-checkbox"]')
      expect(checkbox.exists()).toBe(true)
      expect(checkbox.text()).toBe('ノーゲーム')
      expect(checkbox.find('.v-messages__message').exists()).toBe(false)
      expect(wrapper.text()).not.toContain('試合が成立しなかった場合に選ぶ')
      expect(wrapper.text()).not.toContain('KO・ノーゲームの表')
      expect(ja.gameResult).not.toHaveProperty('noGameHint')
    })
  })
})
