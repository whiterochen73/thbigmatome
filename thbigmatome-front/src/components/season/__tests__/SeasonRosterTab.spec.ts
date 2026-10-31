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
    roster[28]!.is_absent = true
    roster[28]!.absence_info = { ...roster[4]!.absence_info }
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
    // Test Basis: subtask_1787r 申し送り5
    const absentSecondRow = wrapper.findAll('tr').find((row) => row.text().includes('選手29'))!
    const promote = absentSecondRow.findComponent('.promote-btn')
    expect(promote.props('color')).toBeUndefined()
    expect(promote.props('variant')).toBe('outlined')
    expect(promote.attributes('style')).toContain('border-color')
    expect(promote.find('.on-absence-out').exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b1-15
  it('コスト上限未設定時の色は border-strong を返す', async () => {
    const wrapper = await mountTab()
    expect((wrapper.vm as unknown as { costBarColor: string }).costBarColor).toBe('border-strong')
  })
})

// 過去分の修正（cmd_1784 段2b）: 読む GET と保存する POST の両方に、同じ target_date と phase を渡す。
// GET を日付なしで呼ぶと最新の写し、POST を日付なしで呼ぶとカーソル時点の状態と比べるので、読んだ値を送り直すだけで余計な変更記録が増える。
// Test Basis: queue/reviews/subtask_1784i.yaml の warning、context/thbig-dugout-season-record-restructure-design.md の 2026-11-01 の追記
describe('SeasonRosterTab 日付つきの読み書きと操作範囲', () => {
  const player = (id: number, squad: 'first' | 'second'): RosterPlayer => ({
    team_membership_id: id,
    player_id: id,
    player_name: `選手${id}`,
    number: `${id}`,
    squad,
    cost: 3,
    selected_cost_type: 'normal_cost',
    handedness: null,
    position: null,
    player_types: [],
    is_outside_world: false,
  })

  const rosterResponse = (extra: Record<string, unknown> = {}) => ({
    data: {
      roster: [player(1, 'first'), player(2, 'second')],
      season_id: 1,
      current_date: '2026-05-07',
      season_start_date: '2026-04-01',
      key_player_id: null,
      key_player_selectable: false,
      ...extra,
    },
  })

  beforeEach(() => {
    vi.clearAllMocks()
    mockGet.mockImplementation((url: string) =>
      url === '/teams/1/roster' ? Promise.resolve(rosterResponse()) : Promise.resolve({ data: [] }),
    )
    mockPost.mockResolvedValue({ data: {} })
  })

  async function mountTab(props: Record<string, unknown> = {}) {
    const wrapper = mount(SeasonRosterTab, {
      props: { teamId: 1, ...props },
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

  const rosterGets = () => mockGet.mock.calls.filter(([url]) => url === '/teams/1/roster')

  it('asOfDate と phase を渡すと、GET も POST も同じ target_date と phase を送る', async () => {
    const wrapper = await mountTab({ asOfDate: '2026-05-07', phase: 'post_game' })

    expect(rosterGets()[0][1]).toEqual({
      params: { target_date: '2026-05-07', phase: 'post_game' },
    })

    await wrapper.vm.saveRoster()

    expect(mockPost).toHaveBeenCalledWith('/teams/1/roster', {
      roster_updates: [
        { team_membership_id: 1, squad: 'first' },
        { team_membership_id: 2, squad: 'second' },
      ],
      target_date: '2026-05-07',
      phase: 'post_game',
    })
  })

  it('asOfDate だけなら phase は pre_game を GET と POST の両方に送る', async () => {
    const wrapper = await mountTab({ asOfDate: '2026-05-07' })
    await wrapper.vm.saveRoster()

    expect(rosterGets()[0][1]).toEqual({ params: { target_date: '2026-05-07', phase: 'pre_game' } })
    expect(mockPost.mock.calls[0][1]).toMatchObject({
      target_date: '2026-05-07',
      phase: 'pre_game',
    })
  })

  it('asOfDate が無い時は、GET を日付なしで呼び、応答の current_date と pre_game を POST に送る', async () => {
    const wrapper = await mountTab()
    await wrapper.vm.saveRoster()

    expect(rosterGets()[0][1]).toEqual({ params: {} })
    expect(mockPost.mock.calls[0][1]).toMatchObject({
      target_date: '2026-05-07',
      phase: 'pre_game',
    })
  })

  it('asOfDate や phase が変わると、新しい日付で読み直す', async () => {
    const wrapper = await mountTab({ asOfDate: '2026-05-07' })

    await wrapper.setProps({ asOfDate: '2026-05-08', phase: 'post_game' })
    await flushPromises()

    expect(rosterGets()).toHaveLength(2)
    expect(rosterGets()[1][1]).toEqual({
      params: { target_date: '2026-05-08', phase: 'post_game' },
    })
  })

  it('後の日付の検査で止まった時（422 の violations）は、違反した日付・区分・内容を画面に出す', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = await mountTab({ asOfDate: '2026-05-07' })
    mockPost.mockRejectedValueOnce({
      response: {
        data: {
          error: '保存できません',
          violations: [
            {
              date: '2026-05-10',
              phase: 'pre_game',
              kind: 'first_squad_min',
              message: '1軍が 24 人です',
              severity: 'error',
              player_id: null,
            },
            {
              date: '2026-05-20',
              phase: 'post_game',
              kind: 'first_squad_cost',
              message: '1軍のコストが上限を超えます',
              severity: 'error',
              player_id: null,
            },
          ],
        },
      },
    })

    await wrapper.vm.saveRoster()
    await flushPromises()

    const list = wrapper.find('[data-testid="violation-list"]')
    expect(list.findAll('li')).toHaveLength(2)
    expect(list.text()).toContain('5/10（試合前）')
    expect(list.text()).toContain('1軍が 24 人です')
    expect(list.text()).toContain('5/20（試合後）')
    expect(list.text()).toContain('1軍のコストが上限を超えます')
  })

  it('違反の無い失敗では、違反の欄を出さない。次に読み直したら消える', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const wrapper = await mountTab({ asOfDate: '2026-05-07' })
    mockPost.mockRejectedValueOnce({
      response: {
        data: { violations: [{ date: '2026-05-10', phase: 'pre_game', kind: 'x', message: 'm' }] },
      },
    })
    await wrapper.vm.saveRoster()
    await flushPromises()
    expect(wrapper.find('[data-testid="violation-list"]').exists()).toBe(true)

    await wrapper.setProps({ asOfDate: '2026-05-08' })
    await flushPromises()
    expect(wrapper.find('[data-testid="violation-list"]').exists()).toBe(false)

    mockPost.mockRejectedValueOnce({ response: { data: { error: '失敗' } } })
    await wrapper.vm.saveRoster()
    await flushPromises()
    expect(wrapper.find('[data-testid="violation-list"]').exists()).toBe(false)
  })

  it('操作できる日: 昇格・降格のボタンと保存がある', async () => {
    const wrapper = await mountTab({ asOfDate: '2026-05-07' })

    expect(wrapper.find('.promote-btn').exists()).toBe(true)
    expect(wrapper.find('.demote-btn').exists()).toBe(true)
    expect(wrapper.find('[data-testid="save-roster"]').exists()).toBe(true)
  })

  it('readonly（操作できない日）: 昇格・降格・保存を出さず、選手の並びは見える', async () => {
    const wrapper = await mountTab({ asOfDate: '2026-05-07', readonly: true })

    expect(wrapper.find('.promote-btn').exists()).toBe(false)
    expect(wrapper.find('.demote-btn').exists()).toBe(false)
    expect(wrapper.find('[data-testid="save-roster"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('選手1')
    expect(wrapper.text()).toContain('選手2')
  })

  it('特例選手の欄は、サーバが設定できると返した時だけ。readonly では出さない', async () => {
    const selectable = async (flag: boolean, props: Record<string, unknown> = {}) => {
      mockGet.mockImplementation((url: string) =>
        url === '/teams/1/roster'
          ? Promise.resolve(rosterResponse({ key_player_selectable: flag }))
          : Promise.resolve({ data: [] }),
      )
      return (await mountTab(props)).find('[data-testid="key-player-card"]').exists()
    }
    expect(await selectable(true)).toBe(true)
    expect(await selectable(false)).toBe(false)
    expect(await selectable(true, { readonly: true })).toBe(false)
  })
})
