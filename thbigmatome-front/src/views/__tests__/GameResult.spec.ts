import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameResult from '../GameResult.vue'

const { mockGet, mockPut } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPut: vi.fn() }))

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

async function mountView() {
  mockGet.mockImplementation((url: string) => {
    if (url === '/game/100') return Promise.resolve({ data: gameResponse })
    if (url === '/teams') return Promise.resolve({ data: [] })
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
