import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'

// 試合日ページの「要確認の帯」: 1軍にいなかった投手の登板（cmd_1784 段3。設計書 §7 判断 5）。
// 登板の保存は止めず、保存した上で帯と登板記録の段の状態（要確認・赤）に出す。
// GameResult.spec.ts は 1 ファイルで 4GB 近いヒープを使う（base でも RSS 約 5GB）ため、別ファイルに分ける。PC 幅だけで確かめる。

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

const seasonResponse = {
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
  appearances?: unknown[] | Error
  season?: Record<string, unknown> | Error
  // 指定すると、シーズンの取得がこの Promise の解決まで終わらない
  seasonGate?: Promise<void>
}

describe('GameResult 試合日ページ: 1軍でない投手の登板の要確認', () => {
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
      if (url === '/pitcher_appearances') {
        return appearances instanceof Error
          ? Promise.reject(appearances)
          : Promise.resolve({ data: appearances })
      }
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

  const banner = (wrapper: Wrapper) => wrapper.find('[data-testid="roster-banner"]')
  const pitcherState = (wrapper: Wrapper) =>
    wrapper.find('[data-testid="step-pitchers"]').attributes('data-state')
  const row = (id: number, rosterStatus: string | null, name: string | null = `投手${id}`) => ({
    id,
    pitcher_id: 10 + id,
    pitcher_name: name,
    roster_status: rosterStatus,
  })

  it('全員 1軍なら帯を出さず、登板記録の段は済', async () => {
    const wrapper = await mountDay({ appearances: [row(1, 'first'), row(2, 'first')] })
    expect(banner(wrapper).exists()).toBe(false)
    expect(pitcherState(wrapper)).toBe('done')
  })

  it('2軍の投手がいれば、名前と状態を書いた帯を出し、登板記録の段を要確認（赤）にする。登板は保存済みと伝える', async () => {
    const wrapper = await mountDay({
      appearances: [row(1, 'first'), row(2, 'second', '東風谷早苗')],
    })
    expect(banner(wrapper).text()).toContain('東風谷早苗（2軍）')
    expect(banner(wrapper).text()).toContain('登板は保存してあります')
    expect(banner(wrapper).text()).not.toContain('投手1')
    expect(pitcherState(wrapper)).toBe('warn')
  })

  it('帯は役割色 state-warn の flat（tonal や error 色ではない。文字は on-state-warn で読める）', async () => {
    const wrapper = await mountDay({ appearances: [row(1, 'second')] })
    const classes = banner(wrapper).classes()
    expect(classes).toContain('bg-state-warn')
    expect(classes).toContain('v-alert--variant-flat')
    expect(classes).not.toContain('v-alert--variant-tonal')
    expect(classes).not.toContain('bg-error')
  })

  it('在籍なし・チームの登録なしの投手も、それぞれの言い方で帯に並べる（複数は読点区切り）', async () => {
    const wrapper = await mountDay({
      appearances: [
        row(1, 'not_on_team', '放出された投手'),
        row(2, 'no_membership', '登録のない投手'),
      ],
    })
    expect(banner(wrapper).text()).toContain(
      '放出された投手（チームに在籍していない）、登録のない投手（チームの登録なし）',
    )
  })

  it('投手の名前が返らない時は ID で出す', async () => {
    const wrapper = await mountDay({ appearances: [row(3, 'second', null)] })
    expect(banner(wrapper).text()).toContain('ID 13（2軍）')
  })

  it('roster_status が取れていない（null・項目なし）登板は要確認にしない', async () => {
    const wrapper = await mountDay({
      appearances: [row(1, null), { id: 2, pitcher_id: 12 }],
    })
    expect(banner(wrapper).exists()).toBe(false)
    expect(pitcherState(wrapper)).toBe('done')
  })

  it('帯の「登板記録を開く」で登板記録の段へ移る', async () => {
    const wrapper = await mountDay({ appearances: [row(1, 'second')] })
    await wrapper.find('[data-testid="step-result"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="panel-pitchers"]').isVisible()).toBe(false)
    await banner(wrapper).find('button').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="panel-pitchers"]').isVisible()).toBe(true)
  })

  it('登板が無ければ帯は出ない（得点の食い違いの帯とは別）', async () => {
    const wrapper = await mountDay({ appearances: [] })
    expect(banner(wrapper).exists()).toBe(false)
  })

  it('試合のない日（移動日）に開いた日は、登板があっても帯を出さない（得点の食い違いの帯と同じ扱い）', async () => {
    const wrapper = await mountDay({
      season: {
        ...seasonResponse,
        season_schedules: [{ id: 100, date: '2026-06-10', date_type: 'travel_day' }],
      },
      appearances: [row(1, 'second')],
    })
    expect(banner(wrapper).exists()).toBe(false)
  })

  it('登板記録の取得に失敗した時は帯を出さず、段は状態なし（info）のまま', async () => {
    const wrapper = await mountDay({ appearances: new Error('boom') })
    expect(banner(wrapper).exists()).toBe(false)
    expect(pitcherState(wrapper)).toBe('info')
  })

  it('登板記録を保存し直した後の再取得で、2軍の登板が無くなれば帯は消え、取得に失敗すれば帯を残さない', async () => {
    const wrapper = await mountDay({ appearances: [row(1, 'second')] })
    expect(banner(wrapper).exists()).toBe(true)
    const tab = wrapper.findComponent({ name: 'PitcherAppearanceTab' })

    mockGet.mockImplementation((url: string) =>
      url === '/pitcher_appearances'
        ? Promise.resolve({ data: [row(1, 'first')] })
        : Promise.resolve({ data: seasonResponse }),
    )
    tab.vm.$emit('saved')
    await flushPromises()
    expect(banner(wrapper).exists()).toBe(false)

    mockGet.mockImplementation((url: string) =>
      url === '/pitcher_appearances'
        ? Promise.resolve({ data: [row(1, 'second')] })
        : Promise.resolve({ data: seasonResponse }),
    )
    tab.vm.$emit('saved')
    await flushPromises()
    expect(banner(wrapper).exists()).toBe(true)

    mockGet.mockImplementation((url: string) =>
      url === '/pitcher_appearances'
        ? Promise.reject(new Error('boom'))
        : Promise.resolve({ data: seasonResponse }),
    )
    tab.vm.$emit('saved')
    await flushPromises()
    expect(banner(wrapper).exists()).toBe(false)
  })

  it('得点の食い違いの帯と同時に出せる（どちらも赤い帯）', async () => {
    const wrapper = await mountDay({
      game: { score: null, opponent_score: null },
      appearances: [row(1, 'second')],
    })
    expect(wrapper.find('[data-testid="mismatch-banner"]').exists()).toBe(true)
    expect(banner(wrapper).exists()).toBe(true)
  })
})
