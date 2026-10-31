import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import SeasonRosterTab from '../SeasonRosterTab.vue'
import { useSnackbar } from '@/composables/useSnackbar'
import type { RosterPlayer } from '@/types/rosterPlayer'

const { mockGet, mockPost } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn() }))

vi.mock('axios', () => ({
  default: {
    get: mockGet,
    post: mockPost,
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

// cmd_1783 段A: 保存結果を alert()（ブロッキング）ではなく、アプリ共通のスナックバーで知らせる
describe('SeasonRosterTab 保存結果の通知', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  beforeEach(() => {
    vi.clearAllMocks()
    mockGet.mockImplementation((url: string) =>
      url === '/teams/1/roster'
        ? Promise.resolve({
            data: { roster: [], season_id: 1, current_date: '2026-05-07', key_player_id: null },
          })
        : Promise.resolve({ data: [] }),
    )
  })

  async function mountTab() {
    const wrapper = mount(SeasonRosterTab, {
      props: { teamId: 1 },
      global: {
        plugins: [vuetify, i18n],
        stubs: {
          AbsenceInfo: true,
          PromotionCooldownInfo: true,
          PlayerNameLink: { props: ['playerName'], template: '<span>{{ playerName }}</span>' },
        },
      },
    })
    await flushPromises()
    return wrapper
  }

  it('ロスターの保存に成功したら、スナックバー（success）で知らせ、alert は使わない', async () => {
    const alertSpy = vi.fn()
    vi.stubGlobal('alert', alertSpy)
    const wrapper = await mountTab()
    mockPost.mockResolvedValueOnce({ data: {} })

    await wrapper.vm.saveRoster()

    const { message, color } = useSnackbar()
    expect(message.value).toBe(ja.activeRoster.saveSuccess)
    expect(color.value).toBe('success')
    expect(alertSpy).not.toHaveBeenCalled()
  })

  it('ロスターの保存に失敗したら、サーバのエラー文を添えてスナックバー（error）で知らせる', async () => {
    const alertSpy = vi.fn()
    vi.stubGlobal('alert', alertSpy)
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = await mountTab()
    mockPost.mockRejectedValueOnce({ response: { data: { error: '1軍が上限を超えています' } } })

    await wrapper.vm.saveRoster()

    const { message, color } = useSnackbar()
    expect(message.value).toBe(`${ja.activeRoster.saveFailed}: 1軍が上限を超えています`)
    expect(color.value).toBe('error')
    expect(alertSpy).not.toHaveBeenCalled()
  })

  it('特例選手の保存も同じスナックバーで知らせる（成功・失敗）', async () => {
    const alertSpy = vi.fn()
    vi.stubGlobal('alert', alertSpy)
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = await mountTab()
    const { message, color } = useSnackbar()

    mockPost.mockResolvedValueOnce({ data: {} })
    await wrapper.vm.saveKeyPlayer()
    expect(message.value).toBe(ja.activeRoster.keyPlayerSaveSuccess)
    expect(color.value).toBe('success')

    mockPost.mockRejectedValueOnce(new Error('network'))
    await wrapper.vm.saveKeyPlayer()
    expect(message.value).toBe(`${ja.activeRoster.keyPlayerSaveFailed}: network`)
    expect(color.value).toBe('error')
    expect(alertSpy).not.toHaveBeenCalled()
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b1-3〜b1-21
  it('契約、外の世界、特例とコストバーを役割色で表示する', async () => {
    const costTypes = [
      'relief_only_cost',
      'pitcher_only_cost',
      'fielder_only_cost',
      'two_way_cost',
    ] as const
    const roster: RosterPlayer[] = Array.from({ length: 29 }, (_, index) => ({
      team_membership_id: index + 1,
      player_id: index + 1,
      player_name: `選手${index + 1}`,
      number: `${index + 1}`,
      squad: index === 28 ? 'second' : 'first',
      cost: 1,
      selected_cost_type: costTypes[index % 4]!,
      handedness: null,
      position: index % 4 < 2 ? 'pitcher' : null,
      player_types: [],
      is_outside_world: index === 1 || index === 28,
    }))
    roster[4]!.is_absent = true
    roster[4]!.absence_info = {
      absence_type: 'injury',
      reason: 'テスト',
      effective_end_date: '2026-05-10',
      remaining_days: 3,
      duration_unit: 'days',
    }
    mockGet.mockImplementation((url: string) =>
      url === '/teams/1/roster'
        ? Promise.resolve({
            data: {
              roster,
              season_id: 1,
              current_date: '2026-05-07',
              key_player_id: 1,
            },
          })
        : Promise.resolve({ data: [] }),
    )
    const wrapper = await mountTab()
    const chips = wrapper.findAllComponents(components.VChip)
    for (const [costType, color] of [
      ['relief_only_cost', 'tag-pitcher'],
      ['pitcher_only_cost', 'tag-pitcher'],
      ['fielder_only_cost', 'tag-fielder'],
      ['two_way_cost', 'state-neutral'],
    ] as const) {
      const matching = chips.filter((item) => item.text() === ja.baseball.construction[costType])
      expect(matching.length, costType).toBeGreaterThan(0)
      for (const chip of matching) {
        expect(chip.props('color')).toBe(color)
        expect(chip.props('variant')).toBe('flat')
      }
    }
    expect(chips.filter((chip) => chip.props('color') === 'state-info').length).toBeGreaterThan(1)
    expect(wrapper.find('tr.key-player-row').exists()).toBe(true)
    expect(wrapper.findComponent(components.VProgressLinear).props('color')).toBe('success')
    // Test Basis: subtask_1787o 申し送り5 / thbig-dugout-visual-stage5-mapping.md §2 R2, R5
    const absentRow = wrapper.findAll('tr').find((row) => row.text().includes('選手5'))!
    const demote = absentRow.findComponent('.demote-btn')
    expect(demote.props('color')).toBeUndefined()
    expect(demote.props('variant')).toBe('outlined')
    expect(demote.attributes('style')).toContain('border-color')
    expect(demote.find('.on-absence-out').exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b1-15
  it('コスト上限未設定時の色は border-strong を返す', async () => {
    const wrapper = await mountTab()
    expect((wrapper.vm as unknown as { costBarColor: string }).costBarColor).toBe('border-strong')
  })
})
