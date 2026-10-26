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
