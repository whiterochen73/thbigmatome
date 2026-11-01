import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'
import DateTypeDialog from '@/components/gameDay/DateTypeDialog.vue'

// 試合日ページの日付種類の変更（cmd_1791 手直し。Operator 2026-11-01「セレクトボックスではなく、
// アイコンをクリックした時に変更ダイアログが出るように」）。GameResult.spec.ts は 1 ファイルでヒープを
// 大きく使うため、ダイアログの振る舞いはこのファイルに分ける。

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

type Wrapper = Awaited<ReturnType<typeof mountDay>>

const mounted: Array<{ unmount: () => void }> = []

async function mountDay(opts: { game?: Record<string, unknown>; appearances?: unknown[] } = {}) {
  const { game = {}, appearances = [] } = opts
  const season = { value: seasonResponse as Record<string, unknown> }
  mockGet.mockImplementation((url: string) => {
    if (url === '/game/100') return Promise.resolve({ data: { ...gameResponse, ...game } })
    if (url === '/teams') return Promise.resolve({ data: [] })
    if (url === '/pitcher_appearances') return Promise.resolve({ data: appearances })
    if (url === '/player_absences') return Promise.resolve({ data: [] })
    if (url === '/teams/1/season') return Promise.resolve({ data: season.value })
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
  return { wrapper, season }
}

const seasonGets = () => mockGet.mock.calls.filter(([url]) => url === '/teams/1/season').length
const dayHead = (wrapper: Wrapper) => wrapper.find('[data-testid="game-day-head"]')
const trigger = (wrapper: Wrapper) => wrapper.find('[data-testid="date-type-trigger"]')
const dialogOpen = (wrapper: Wrapper) => wrapper.findComponent(DateTypeDialog).props('modelValue')
const inBody = (selector: string) => document.body.querySelector<HTMLElement>(selector)
const option = (type: string) => inBody(`[data-testid="date-type-option-${type}"]`)!
const pick = async (type: string) => {
  option(type).querySelector('input')!.click()
  await flushPromises()
}
const press = async (testid: string) => {
  inBody(`[data-testid="${testid}"]`)!.click()
  await flushPromises()
}
const openDialog = async (wrapper: Wrapper) => {
  await trigger(wrapper).trigger('click')
  await flushPromises()
}
/** サーバ側で日程 100 の種類と今の範囲が変わった状態にする（PATCH の後の GET が映す） */
const serverChanges = (
  season: { value: Record<string, unknown> },
  dateType: string,
  range: { start_date: string; end_date: string },
) => {
  season.value = {
    ...seasonResponse,
    current_range: range,
    season_schedules: seasonResponse.season_schedules.map((s) =>
      s.id === 100 ? { ...s, date_type: dateType } : s,
    ),
  }
}

describe('GameResult 試合日ページ: 日付種類の変更ダイアログ', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    routeQuery.value = {}
    Object.defineProperty(window, 'innerWidth', { configurable: true, writable: true, value: 1280 })
  })

  afterEach(() => {
    mounted.splice(0).forEach((w) => w.unmount())
  })

  it('セレクトボックスは無く、日付種類のチップがボタンとして押せる（名前・title つき、説明文なし）', async () => {
    const { wrapper } = await mountDay()
    expect(wrapper.find('[data-testid="date-type-select"]').exists()).toBe(false)
    expect(dayHead(wrapper).findComponent({ name: 'VSelect' }).exists()).toBe(false)
    const button = trigger(wrapper)
    expect(button.element.tagName).toBe('BUTTON')
    expect(button.attributes('type')).toBe('button')
    expect(button.attributes('aria-label')).toBe('日付種類を変更')
    expect(button.attributes('title')).toBe('日付種類を変更')
    expect(button.attributes('disabled')).toBeUndefined()
    // 中身は今の種類の色・アイコン・名前のチップ（開く前は何も出さない）
    const chip = button.find('[data-testid="date-type-headline"]')
    expect(chip.classes()).toContain('bg-date-game')
    expect(chip.html()).toContain('mdi-baseball-diamond')
    expect(chip.text()).toBe('試合日')
    expect(chip.html()).toContain('mdi-chevron-down')
    expect(dialogOpen(wrapper)).toBe(false)
    expect(inBody('[data-testid="date-type-dialog"]')).toBeNull()
  })

  it('チップを押すと変更ダイアログが開く。8 種（種別 no_game は選べない）を色・アイコンつきで並べ、今の種類だけに印を付ける', async () => {
    const { wrapper } = await mountDay()
    await openDialog(wrapper)
    expect(dialogOpen(wrapper)).toBe(true)
    const dialog = inBody('[data-testid="date-type-dialog"]')!
    expect(dialog).not.toBeNull()
    const items = wrapper.findComponent(DateTypeDialog).props('items')
    expect(items).toHaveLength(8)
    expect(items.map((item: { value: string }) => item.value)).not.toContain('no_game')
    for (const item of items) {
      const row = option(item.value)
      expect(row.textContent).toContain(item.title)
      const chip = row.querySelector('.v-chip')!
      expect(chip.classList.contains(`bg-${item.color}`)).toBe(true)
      expect(chip.innerHTML).toContain(item.icon)
    }
    expect(option('travel_day').textContent).toContain('移動日')
    // 今の種類（試合日）にだけ印
    const marks = dialog.querySelectorAll('[data-testid="date-type-current"]')
    expect(marks).toHaveLength(1)
    expect(option('game_day').contains(marks[0]!)).toBe(true)
    expect(marks[0]!.getAttribute('aria-label')).toBe('今の種類')
    const checked = Array.from(dialog.querySelectorAll<HTMLInputElement>('input[type="radio"]'))
      .filter((i) => i.checked)
      .map((i) => i.value)
    expect(checked).toEqual(['game_day'])
    // 今の種類のままでは「変更」を押せない
    expect(inBody('[data-testid="date-type-confirm"]')!.hasAttribute('disabled')).toBe(true)
  })

  it('確定ボタンは緑（action）の塗り、キャンセルは文字ボタン', async () => {
    const { wrapper } = await mountDay()
    await openDialog(wrapper)
    const confirm = inBody('[data-testid="date-type-confirm"]')!
    expect(confirm.classList.contains('bg-action')).toBe(true)
    expect(confirm.classList.contains('v-btn--variant-flat')).toBe(true)
    expect(confirm.textContent?.trim()).toBe('変更')
    const cancel = inBody('[data-testid="date-type-cancel"]')!
    expect(cancel.classList.contains('v-btn--variant-text')).toBe(true)
    expect(cancel.textContent?.trim()).toBe('キャンセル')
  })

  it('選んで「変更」を押すと PATCH し、今の範囲を取り直す（日程の種類が変わると範囲が動く）', async () => {
    const { wrapper, season } = await mountDay({ game: { score: null, opponent_score: null } })
    expect(seasonGets()).toBe(1)
    expect(wrapper.vm.currentRange).toEqual({ start_date: '2026-06-10', end_date: '2026-06-10' })
    mockPatch.mockResolvedValueOnce({ data: {} })
    // 移動日に変えると、試合日の集合が変わって範囲が 6/12 へ動く
    serverChanges(season, 'travel_day', { start_date: '2026-06-12', end_date: '2026-06-12' })
    await openDialog(wrapper)
    await pick('travel_day')
    expect(inBody('[data-testid="date-type-confirm"]')!.hasAttribute('disabled')).toBe(false)
    await press('date-type-confirm')

    expect(mockPatch).toHaveBeenCalledTimes(1)
    expect(mockPatch).toHaveBeenCalledWith('/teams/1/season/season_schedules/100', {
      season_schedule: { date_type: 'travel_day' },
    })
    expect(dialogOpen(wrapper)).toBe(false)
    expect(seasonGets()).toBe(2)
    expect(wrapper.vm.currentRange).toEqual({ start_date: '2026-06-12', end_date: '2026-06-12' })
    expect(wrapper.vm.currentDateType).toBe('travel_day')
    expect(trigger(wrapper).find('[data-testid="date-type-headline"]').text()).toBe('移動日')
    expect(document.body.textContent).not.toContain('データは消えず')
  })

  it('キャンセルでは何もしない（PATCH も範囲の取得もしない）。開き直すと今の種類から始まる', async () => {
    const { wrapper } = await mountDay()
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-cancel')
    expect(dialogOpen(wrapper)).toBe(false)
    expect(mockPatch).not.toHaveBeenCalled()
    expect(seasonGets()).toBe(1)
    expect(wrapper.vm.currentDateType).toBe('game_day')

    await openDialog(wrapper)
    const checked = Array.from(
      document.body.querySelectorAll<HTMLInputElement>('[data-testid="date-type-dialog"] input'),
    )
      .filter((i) => i.checked)
      .map((i) => i.value)
    expect(checked).toEqual(['game_day'])
    expect(inBody('[data-testid="date-type-confirm"]')!.hasAttribute('disabled')).toBe(true)
  })

  it('選び直して今の種類へ戻すと「変更」は押せない。押しても何もしない', async () => {
    const { wrapper } = await mountDay()
    await openDialog(wrapper)
    await pick('travel_day')
    await pick('game_day')
    expect(inBody('[data-testid="date-type-confirm"]')!.hasAttribute('disabled')).toBe(true)
    inBody('[data-testid="date-type-confirm"]')!.click()
    await flushPromises()
    expect(mockPatch).not.toHaveBeenCalled()
  })

  it('未保存の編集がある間はチップを押せず、ダイアログも開かない。「保存してから変更」を出す', async () => {
    const { wrapper } = await mountDay()
    expect(wrapper.text()).not.toContain('保存してから変更')
    wrapper.vm.gameData.score = 9
    await flushPromises()
    expect(trigger(wrapper).attributes('disabled')).toBeDefined()
    expect(wrapper.text()).toContain('保存してから変更')
    await trigger(wrapper).trigger('click')
    await flushPromises()
    expect(dialogOpen(wrapper)).toBe(false)
    expect(inBody('[data-testid="date-type-dialog"]')).toBeNull()
    // 戻しても保存はされない
    await wrapper.vm.updateDateType('travel_day')
    expect(mockPatch).not.toHaveBeenCalled()
  })

  it('PATCH に失敗したら元の種類のまま、エラーを出し、範囲は取り直さない', async () => {
    const { wrapper } = await mountDay({ game: { score: null, opponent_score: null } })
    mockPatch.mockRejectedValueOnce(new Error('500'))
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')
    expect(mockPatch).toHaveBeenCalledTimes(1)
    expect(wrapper.vm.currentDateType).toBe('game_day')
    expect(wrapper.vm.snackbarColor).toBe('error')
    expect(wrapper.vm.snackbarText).toBe('日付種類の変更に失敗しました')
    expect(seasonGets()).toBe(1)
    expect(trigger(wrapper).find('[data-testid="date-type-headline"]').text()).toBe('試合日')
  })

  // 閉じた後に focus が BODY へ落ちると、キーボードの利用者がどこにいたか分からなくなる
  it.each([
    [
      'Esc',
      async () => {
        inBody('[data-testid="date-type-dialog"]')!.dispatchEvent(
          new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }),
        )
        await flushPromises()
      },
    ],
    ['キャンセル', () => press('date-type-cancel')],
    [
      '変更',
      async () => {
        await pick('travel_day')
        await press('date-type-confirm')
      },
    ],
  ])('%s で閉じた後は、focus が日付種類のチップへ戻る', async (_label, close) => {
    const { wrapper } = await mountDay({ game: { score: null, opponent_score: null } })
    mockPatch.mockResolvedValue({ data: {} })
    await openDialog(wrapper)
    expect(dialogOpen(wrapper)).toBe(true)
    expect(document.activeElement).not.toBe(trigger(wrapper).element)
    await close()
    expect(dialogOpen(wrapper)).toBe(false)
    expect(document.activeElement).toBe(trigger(wrapper).element)
  })

  // 「変更」で確定した時に立てるフラグを戻し忘れると、次に開いて Esc で閉じた時だけ focus が BODY へ落ちる。
  // 各 it が新規マウントだと戻し忘れは見えないので、同じインスタンスで 2 回開いて確かめる
  it('変更を 1 度確定した後、同じインスタンスで開き直して Esc で閉じても、focus がチップへ戻る', async () => {
    const { wrapper } = await mountDay({ game: { score: null, opponent_score: null } })
    mockPatch.mockResolvedValue({ data: {} })
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')
    expect(dialogOpen(wrapper)).toBe(false)
    expect(document.activeElement).toBe(trigger(wrapper).element)

    // フォーカスを外してから、もう一度開く（戻り先が前回の名残でないことを確かめる）
    ;(document.activeElement as HTMLElement).blur()
    await openDialog(wrapper)
    expect(dialogOpen(wrapper)).toBe(true)
    expect(document.activeElement).not.toBe(trigger(wrapper).element)
    inBody('[data-testid="date-type-dialog"]')!.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }),
    )
    await flushPromises()
    expect(dialogOpen(wrapper)).toBe(false)
    expect(document.activeElement).toBe(trigger(wrapper).element)
    expect(mockPatch).toHaveBeenCalledTimes(1)
  })

  it('保存の間に利用者が別の場所へ focus を移していたら、保存後もそこから奪わない', async () => {
    const { wrapper } = await mountDay({ game: { score: null, opponent_score: null } })
    let release!: () => void
    mockPatch.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          release = () => resolve({ data: {} })
        }),
    )
    const other = document.createElement('input')
    document.body.appendChild(other)
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')
    other.focus()
    release()
    await flushPromises()
    expect(document.activeElement).toBe(other)
    other.remove()
  })

  it('変更は成功したが範囲の取り直しに失敗しても、変更した種類のチップは残す（範囲は取得できなかった扱い）', async () => {
    const { wrapper } = await mountDay({ game: { score: null, opponent_score: null } })
    mockPatch.mockResolvedValueOnce({ data: {} })
    const original = mockGet.getMockImplementation()!
    mockGet.mockImplementation((url: string) =>
      url === '/teams/1/season' ? Promise.reject(new Error('500')) : original(url),
    )
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')

    expect(mockPatch).toHaveBeenCalledTimes(1)
    expect(seasonGets()).toBe(2)
    expect(wrapper.vm.currentDateType).toBe('travel_day')
    expect(trigger(wrapper).exists()).toBe(true)
    expect(trigger(wrapper).find('[data-testid="date-type-headline"]').text()).toBe('移動日')
    expect(wrapper.vm.currentRange).toBeUndefined()
    // 保存は成功しているので、失敗のエラーは出さない
    expect(wrapper.vm.snackbarColor).not.toBe('error')
    // 保存後はチップへ focus が戻り、もう一度開ける
    expect(document.activeElement).toBe(trigger(wrapper).element)
    await openDialog(wrapper)
    expect(dialogOpen(wrapper)).toBe(true)
  })

  it('確認ダイアログが挟まる間はチップへ focus を戻さず、確認を終えて保存が済んだら戻す', async () => {
    const { wrapper } = await mountDay({ game: { score: 3, opponent_score: 1 } })
    mockPatch.mockResolvedValueOnce({ data: {} })
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')
    expect(document.body.textContent).toContain('データは消えず、隠れるだけ')
    expect(document.activeElement).not.toBe(trigger(wrapper).element)
    const ok = Array.from(document.body.querySelectorAll('button')).find(
      (b) => b.textContent?.trim() === 'OK' && !b.hasAttribute('data-testid'),
    )
    ok!.click()
    await flushPromises()
    expect(mockPatch).toHaveBeenCalledTimes(1)
    expect(document.activeElement).toBe(trigger(wrapper).element)
  })

  it('保存済みの試合データがある試合日を移動日へ変える時は確認が挟まり、キャンセルなら PATCH しない', async () => {
    const { wrapper } = await mountDay({ game: { score: 3, opponent_score: 1 } })
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')
    expect(document.body.textContent).toContain('データは消えず、隠れるだけ')
    expect(mockPatch).not.toHaveBeenCalled()
    const cancel = Array.from(document.body.querySelectorAll('button')).find(
      (b) => b.textContent?.trim() === 'キャンセル' && !b.hasAttribute('data-testid'),
    )
    cancel!.click()
    await flushPromises()
    expect(mockPatch).not.toHaveBeenCalled()
    expect(seasonGets()).toBe(1)
    expect(wrapper.vm.currentDateType).toBe('game_day')
  })

  it('保存中は押せない（二重送信を防ぐ）', async () => {
    const { wrapper } = await mountDay({ game: { score: null, opponent_score: null } })
    let release!: () => void
    mockPatch.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          release = () => resolve({ data: {} })
        }),
    )
    await openDialog(wrapper)
    await pick('travel_day')
    await press('date-type-confirm')
    expect(trigger(wrapper).attributes('disabled')).toBeDefined()
    await wrapper.vm.updateDateType('reserve_day')
    expect(mockPatch).toHaveBeenCalledTimes(1)
    release()
    await flushPromises()
    expect(trigger(wrapper).attributes('disabled')).toBeUndefined()
  })
})
