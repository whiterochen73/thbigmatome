import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import PitcherAppearanceTab from '../PitcherAppearanceTab.vue'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

const basePitcher = {
  id: 10,
  name: '幽々子',
  position: 'pitcher',
  is_pitcher: true,
}

const otherPitcher = {
  id: 11,
  name: '紫',
  position: 'pitcher',
  is_pitcher: true,
}

const defaultProps = {
  teamId: 1,
  gameDate: '2026-04-11',
  gameResult: 'win' as const,
  scheduleId: 100,
  announcedStarterId: null,
  competitionId: null,
}

interface PreGameStateMock {
  player_id: number
  rest_days: number | null
  cumulative_innings: number
  last_role: string | null
  is_injured: boolean
}

interface MockPitcherRequestOptions {
  state: PreGameStateMock | null
  pitchers?: (typeof basePitcher)[]
  statesReject?: boolean
  savedAppearances?: unknown[]
  savedReject?: boolean
  memberships?: Array<{ id: number; player_id: number }>
}

function mockPitcherRequests(options: PreGameStateMock | null | MockPitcherRequestOptions) {
  const config =
    options && 'state' in options
      ? options
      : ({
          state: options,
        } satisfies MockPitcherRequestOptions)

  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url === '/teams/1/team_players') {
      return Promise.resolve({ data: config.pitchers ?? [basePitcher] })
    }
    if (url === '/teams/1/pitcher_game_states') {
      if (config.statesReject) {
        return Promise.reject(new Error('states error'))
      }
      return Promise.resolve({ data: config.state ? [config.state] : [] })
    }
    if (url === '/pitcher_appearances') {
      if (config.savedReject) {
        return Promise.reject(new Error('saved error'))
      }
      return Promise.resolve({ data: config.savedAppearances ?? [] })
    }
    if (url === '/teams/1/team_memberships') {
      return Promise.resolve({ data: config.memberships ?? [] })
    }
    if (url === '/teams/1/pitcher_game_states/fatigue_summary') {
      return Promise.resolve({ data: [] })
    }
    return Promise.reject(new Error(`Unexpected GET ${url}`))
  })
}

async function mountComponent(state: PreGameStateMock | null, gameDate = '2026-04-11') {
  mockPitcherRequests(state)
  const wrapper = mount(PitcherAppearanceTab, {
    props: { ...defaultProps, gameDate },
    global: {
      plugins: [vuetify],
    },
  })
  await flushPromises()
  return wrapper
}

function getPitcherItem(wrapper: ReturnType<typeof mount>) {
  const autocomplete = wrapper.findComponent({ name: 'VAutocomplete' })
  const items = autocomplete.props('items') as Array<{
    id: number
    label: string
    disabled: boolean
    statusBadge: string
    preGameInfo: string
  }>
  return items[0]
}

describe('PitcherAppearanceTab', () => {
  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b4-10, b4-15〜b4-26
  it('試合結果・責任投手・結果区分を役割色の flat チップで表示する', async () => {
    for (const [result, color] of [
      ['win', 'result-win'],
      ['lose', 'result-loss'],
      ['draw', 'result-draw'],
      ['no_game', 'result-nogame'],
    ] as const) {
      mockPitcherRequests(null)
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult: result },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      const chip = wrapper.findAllComponents(components.VChip)[0]!
      expect(chip.props('color')).toBe(color)
      expect(chip.props('variant')).toBe('flat')
      wrapper.unmount()
    }
    const wrapper = await mountComponent(null)
    const row = wrapper.vm.pitcherRows[0]
    for (const [decision, color] of [
      ['W', 'result-win'],
      ['L', 'result-loss'],
      ['S', 'state-info'],
      ['H', 'state-neutral'],
    ] as const) {
      row.decision = decision
      await flushPromises()
      const chips = wrapper
        .findAllComponents(components.VChip)
        .filter((chip) => chip.text() === decision)
      expect(chips.length, decision).toBeGreaterThan(0)
      for (const chip of chips) {
        expect(chip.props('color')).toBe(color)
        expect(chip.props('variant')).toBe('flat')
      }
    }
    for (const [category, color] of [
      ['ko', 'state-warn'],
      ['no_game', 'result-nogame'],
      ['long_loss', 'state-todo'],
      ['normal', 'state-done'],
      ['pending', 'state-neutral'],
    ]) {
      expect(wrapper.vm.resultCategoryColor(category), category).toBe(color)
    }
    expect(
      wrapper.findAllComponents(components.VChip).some((chip) => chip.props('variant') === 'flat'),
    ).toBe(true)
  })
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('怪我中は投手選択をdisabledにし、負傷中表示にすること', async () => {
    const wrapper = await mountComponent(
      {
        player_id: 10,
        rest_days: null,
        cumulative_innings: 0,
        last_role: null,
        is_injured: true,
      },
      '2026-04-10',
    )

    const item = getPitcherItem(wrapper)
    expect(item.disabled).toBe(true)
    expect(item.statusBadge).toBe('🏥')
    expect(item.preGameInfo).toBe('🏥 負傷中')
  })

  it('復帰当日はバックエンドのis_injured=falseに従って選択可能にすること', async () => {
    const wrapper = await mountComponent({
      player_id: 10,
      rest_days: 0,
      cumulative_innings: 0,
      last_role: 'starter',
      is_injured: false,
    })

    const item = getPitcherItem(wrapper)
    expect(item.disabled).toBe(false)
    expect(item.statusBadge).toBe('🟢')
    expect(item.preGameInfo).toBe('中0日')
  })

  it('復帰後はバックエンドのis_injured=falseに従って選択可能にすること', async () => {
    const wrapper = await mountComponent(
      {
        player_id: 10,
        rest_days: 4,
        cumulative_innings: 0,
        last_role: 'starter',
        is_injured: false,
      },
      '2026-04-15',
    )

    const item = getPitcherItem(wrapper)
    expect(item.disabled).toBe(false)
    expect(item.statusBadge).toBe('🟢')
    expect(item.preGameInfo).toBe('中4日')
  })

  it('状態情報がない投手は安全側でdisabledにし、player_absencesを取得しないこと', async () => {
    const wrapper = await mountComponent(null)

    const item = getPitcherItem(wrapper)
    expect(item.disabled).toBe(true)
    expect(item.statusBadge).toBe('⚠️')
    expect(item.preGameInfo).toBe('状態未取得')
    expect(vi.mocked(axios.get).mock.calls.map(([url]) => url)).not.toContain(
      '/player_absences?team_id=1',
    )
  })

  it('statesRes reject時は全投手をdisabledにして明示エラーを表示すること', async () => {
    mockPitcherRequests({
      state: null,
      statesReject: true,
      pitchers: [basePitcher, otherPitcher],
    })
    const wrapper = mount(PitcherAppearanceTab, {
      props: defaultProps,
      global: {
        plugins: [vuetify],
      },
    })
    await flushPromises()

    const autocomplete = wrapper.findComponent({ name: 'VAutocomplete' })
    const items = autocomplete.props('items') as Array<{ disabled: boolean; preGameInfo: string }>
    expect(items).toHaveLength(2)
    expect(items.every((item) => item.disabled)).toBe(true)
    expect(items.every((item) => item.preGameInfo === '状態未取得')).toBe(true)
    expect(wrapper.text()).toContain('投手状態の取得に失敗しました')
  })

  it('team_playersにいるがstateが欠損した投手はdisabledにすること', async () => {
    mockPitcherRequests({
      state: {
        player_id: 10,
        rest_days: 0,
        cumulative_innings: 0,
        last_role: 'starter',
        is_injured: false,
      },
      pitchers: [basePitcher, otherPitcher],
    })
    const wrapper = mount(PitcherAppearanceTab, {
      props: defaultProps,
      global: {
        plugins: [vuetify],
      },
    })
    await flushPromises()

    const autocomplete = wrapper.findComponent({ name: 'VAutocomplete' })
    const items = autocomplete.props('items') as Array<{
      id: number
      disabled: boolean
      preGameInfo: string
    }>
    expect(items.find((item) => item.id === 10)?.disabled).toBe(false)
    expect(items.find((item) => item.id === 11)).toMatchObject({
      disabled: true,
      preGameInfo: '状態未取得',
    })
  })

  it('saveAll後の保存済み登板記録再読込失敗時は既存行を保持してwarningを表示すること', async () => {
    let savedFetchCount = 0
    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (url === '/teams/1/team_players') {
        return Promise.resolve({ data: [basePitcher] })
      }
      if (url === '/teams/1/pitcher_game_states') {
        return Promise.resolve({
          data: [
            {
              player_id: 10,
              rest_days: 0,
              cumulative_innings: 0,
              last_role: 'starter',
              is_injured: false,
            },
          ],
        })
      }
      if (url === '/pitcher_appearances') {
        savedFetchCount += 1
        return savedFetchCount === 1
          ? Promise.resolve({ data: [] })
          : Promise.reject(new Error('reload failed'))
      }
      if (url === '/teams/1/team_memberships') {
        return Promise.resolve({ data: [] })
      }
      if (url === '/teams/1/pitcher_game_states/fatigue_summary') {
        return Promise.resolve({ data: [] })
      }
      return Promise.reject(new Error(`Unexpected GET ${url}`))
    })
    vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
    const wrapper = mount(PitcherAppearanceTab, {
      props: defaultProps,
      global: {
        plugins: [vuetify],
      },
    })
    await flushPromises()
    wrapper.vm.pitcherRows[0].pitcher_id = 10
    wrapper.vm.pitcherRows[0].innings_int = 5

    await wrapper.vm.saveAll()
    await flushPromises()

    expect(wrapper.vm.pitcherRows[0].pitcher_id).toBe(10)
    expect(wrapper.vm.pitcherRows[0].innings_int).toBe(5)
    expect(wrapper.text()).toContain('保存済み登板記録の再読込に失敗しました')
  })

  it('保存済み登板記録なしでannouncedStarterIdがあればteam_membershipから先発を復元すること', async () => {
    mockPitcherRequests({
      state: {
        player_id: 10,
        rest_days: 0,
        cumulative_innings: 0,
        last_role: 'starter',
        is_injured: false,
      },
      savedAppearances: [],
      memberships: [{ id: 99, player_id: 10 }],
    })
    const wrapper = mount(PitcherAppearanceTab, {
      props: { ...defaultProps, announcedStarterId: 99 },
      global: {
        plugins: [vuetify],
      },
    })
    await flushPromises()

    expect(wrapper.vm.pitcherRows[0].pitcher_id).toBe(10)
  })

  // cmd_1775 E7: 結果区分チップはサーバの値を表示し、サーバと同じ条件に揃える
  describe('結果区分チップ（computeResultCategory）', () => {
    const idleState: PreGameStateMock = {
      player_id: 10,
      rest_days: null,
      cumulative_innings: 0,
      last_role: null,
      is_injured: false,
    }

    async function mountWith(gameResult: 'win' | 'lose' | 'draw', saved: unknown[] = []) {
      mockPitcherRequests({ state: idleState, savedAppearances: saved })
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      return wrapper
    }

    function savedStarter(resultCategory: string | null) {
      return {
        id: 1,
        pitcher_id: 10,
        role: 'starter',
        innings_pitched: 9.0,
        earned_runs: 0,
        fatigue_p_used: 0,
        decision: null,
        is_opener: false,
        no_out_exit: false,
        consecutive_short_rest_count: 0,
        pre_injury_days_excluded: 0,
        result_category: resultCategory,
      }
    }

    // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b4-21〜b4-26
    it('保存済み結果区分の全チップを対応する役割色の flat で表示する', async () => {
      for (const [category, label, color] of [
        ['ko', 'KO', 'state-warn'],
        ['no_game', 'ノーゲーム', 'result-nogame'],
        ['long_loss', '長イニング敗戦', 'state-todo'],
        ['normal', '通常', 'state-done'],
        ['pending', '保存後に確定', 'state-neutral'],
      ]) {
        const wrapper = await mountWith('lose', [savedStarter(category!)])
        const chips = wrapper
          .findAllComponents(components.VChip)
          .filter((chip) => chip.text() === label)
        expect(chips.length, category).toBeGreaterThan(0)
        for (const chip of chips) {
          expect(chip.props('color')).toBe(color)
          expect(chip.props('variant')).toBe('flat')
        }
        wrapper.unmount()
      }
    })

    it('保存済みの先発はサーバの result_category を表示する（画面の fatigue_p_used=0 に引きずられない）', async () => {
      const wrapper = await mountWith('lose', [savedStarter('long_loss')])
      expect(wrapper.vm.computeResultCategory(0)).toBe('long_loss')
    })

    it('保存済みで result_category が null（判定保留）なら判定保留と表示する', async () => {
      const wrapper = await mountWith('lose', [savedStarter(null)])
      expect(wrapper.vm.computeResultCategory(0)).toBeNull()
      expect(wrapper.text()).toContain('判定保留')
    })

    it('未保存の先発が負け試合で5回投げた場合は、疲労Pが要るので保存後に確定と表示する', async () => {
      const wrapper = await mountWith('lose')
      const row = wrapper.vm.pitcherRows[0]
      row.pitcher_id = 10
      row.innings_int = 5
      row.innings_frac = ''
      await flushPromises()
      expect(wrapper.vm.computeResultCategory(0)).toBe('pending')
    })

    it('未保存の先発が勝ち・引き分けなら9回でも normal', async () => {
      for (const gameResult of ['win', 'draw'] as const) {
        const wrapper = await mountWith(gameResult)
        const row = wrapper.vm.pitcherRows[0]
        row.pitcher_id = 10
        row.innings_int = 9
        row.innings_frac = ''
        await flushPromises()
        expect(wrapper.vm.computeResultCategory(0)).toBe('normal')
      }
    })

    it('KO: 負け・decision=L・後続あり・4回0アウト降板でも ko（+1 しない）。勝ちなら normal', async () => {
      const wrapper = await mountWith('lose')
      wrapper.vm.addRow()
      const row = wrapper.vm.pitcherRows[0]
      row.pitcher_id = 10
      row.innings_int = 4
      row.innings_frac = ''
      row.no_out_exit = true
      row.decision = 'L'
      await flushPromises()
      expect(wrapper.vm.computeResultCategory(0)).toBe('ko')

      row.decision = null // 敗戦投手でなければ KO ではない（サーバと同じ）
      expect(wrapper.vm.computeResultCategory(0)).not.toBe('ko')

      const winWrapper = await mountWith('win')
      winWrapper.vm.addRow()
      const winRow = winWrapper.vm.pitcherRows[0]
      winRow.pitcher_id = 10
      winRow.innings_int = 4
      winRow.innings_frac = ''
      winRow.decision = 'L'
      await flushPromises()
      expect(winWrapper.vm.computeResultCategory(0)).toBe('normal')
    })

    // AMB-20 追補（Operator 裁定 2026-10-25）: 1つもアウトを取れず降板した先発（0.0回・0アウト降板）も KO
    it('KO: 0.0回・0アウト降板（no_out_exit）・負け・decision=L・後続あり → ko。勝ち・L なし・no_out_exit なしは ko にならない', async () => {
      const wrapper = await mountWith('lose')
      wrapper.vm.addRow()
      const row = wrapper.vm.pitcherRows[0]
      row.pitcher_id = 10
      row.innings_int = 0
      row.innings_frac = ''
      row.no_out_exit = true
      row.decision = 'L'
      await flushPromises()
      expect(wrapper.vm.computeResultCategory(0)).toBe('ko')

      row.decision = null
      expect(wrapper.vm.computeResultCategory(0)).toBe('normal')

      row.decision = 'L'
      row.no_out_exit = false // 0.0回で 0アウト降板でない記録は登板したとみなさない
      expect(wrapper.vm.computeResultCategory(0)).not.toBe('ko')

      // 境界: 6イニング目のマウンドに上がっていた（5.0回）なら 0アウト降板でも KO は付かない。4.2回は ko
      row.no_out_exit = true
      row.innings_int = 5
      expect(wrapper.vm.computeResultCategory(0)).not.toBe('ko')
      row.innings_int = 4
      row.innings_frac = '2'
      expect(wrapper.vm.computeResultCategory(0)).toBe('ko')

      const winWrapper = await mountWith('win')
      winWrapper.vm.addRow()
      const winRow = winWrapper.vm.pitcherRows[0]
      winRow.pitcher_id = 10
      winRow.innings_int = 0
      winRow.innings_frac = ''
      winRow.no_out_exit = true
      winRow.decision = 'L'
      await flushPromises()
      expect(winWrapper.vm.computeResultCategory(0)).toBe('normal')
    })
  })

  // cmd_1775 第2段 E3・E6・E7
  describe('第二先発・連続中4日カウント・結果区分チップの関与イニング', () => {
    const thirdPitcher = { id: 12, name: '妖夢', position: 'pitcher', is_pitcher: true }
    const idleState = (id: number): PreGameStateMock => ({
      player_id: id,
      rest_days: null,
      cumulative_innings: 0,
      last_role: null,
      is_injured: false,
    })

    function saved(
      pitcherId: number,
      role: string,
      innings: number,
      extra: Record<string, unknown> = {},
    ) {
      return {
        id: pitcherId,
        pitcher_id: pitcherId,
        role,
        innings_pitched: innings,
        earned_runs: 0,
        fatigue_p_used: 0,
        decision: null,
        is_opener: false,
        no_out_exit: false,
        consecutive_short_rest_count: 2,
        pre_injury_days_excluded: 0,
        result_category: null,
        ...extra,
      }
    }

    async function mountRows(
      savedAppearances: unknown[],
      gameResult: 'win' | 'lose' | 'draw' = 'lose',
    ) {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if (url === '/teams/1/team_players') {
          return Promise.resolve({ data: [basePitcher, otherPitcher, thirdPitcher] })
        }
        if (url === '/teams/1/pitcher_game_states') {
          return Promise.resolve({ data: [10, 11, 12].map(idleState) })
        }
        if (url === '/pitcher_appearances') return Promise.resolve({ data: savedAppearances })
        if (url === '/teams/1/team_memberships') return Promise.resolve({ data: [] })
        if (url === '/teams/1/pitcher_game_states/fatigue_summary')
          return Promise.resolve({ data: [] })
        return Promise.reject(new Error(`Unexpected GET ${url}`))
      })
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      return wrapper
    }

    function postedAppearances() {
      const call = vi.mocked(axios.post).mock.calls[0]
      expect(call[0]).toBe('/pitcher_appearances/bulk_save')
      const payload = call[1] as {
        pitcher_appearances_bulk: { appearances: Array<Record<string, unknown>> }
      }
      return payload.pitcher_appearances_bulk.appearances
    }

    describe('E6: 第二先発（2番手）は role=starter で保存し、開き直しても復元する', () => {
      it('2番手で第二先発を選ぶと role=starter で送る（1番手はオープナー、3番手はリリーフのまま）', async () => {
        const wrapper = await mountRows([])
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
        const rows = wrapper.vm.pitcherRows
        rows[0].role = 'opener'
        rows[0].pitcher_id = 10
        rows[0].innings_int = 1
        wrapper.vm.addRow()
        wrapper.vm.addRow()
        rows[1].pitcher_id = 11
        rows[1].is_second_starter = true
        rows[1].innings_int = 6
        rows[2].pitcher_id = 12
        rows[2].innings_int = 2

        await wrapper.vm.saveAll()

        expect(postedAppearances().map((a) => [a.pitcher_id, a.role])).toEqual([
          [10, 'opener'],
          [11, 'starter'],
          [12, 'reliever'],
        ])
      })

      it('2番手がリリーフのままなら role=reliever で送る', async () => {
        const wrapper = await mountRows([])
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
        const rows = wrapper.vm.pitcherRows
        rows[0].pitcher_id = 10
        wrapper.vm.addRow()
        rows[1].pitcher_id = 11

        await wrapper.vm.saveAll()

        expect(postedAppearances().map((a) => a.role)).toEqual(['starter', 'reliever'])
      })

      it('3番手以降に第二先発フラグが残っていても先発にしない（選択欄が出るのは2番手だけ）', async () => {
        const wrapper = await mountRows([])
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
        const rows = wrapper.vm.pitcherRows
        rows[0].pitcher_id = 10
        wrapper.vm.addRow()
        wrapper.vm.addRow()
        rows[1].pitcher_id = 11
        rows[2].pitcher_id = 12
        rows[2].is_second_starter = true

        await wrapper.vm.saveAll()

        expect(postedAppearances().map((a) => a.role)).toEqual(['starter', 'reliever', 'reliever'])
      })

      it('保存済みで2番手が role=starter なら、開き直した時に第二先発として復元し、保存し直しても starter のまま', async () => {
        const wrapper = await mountRows([
          saved(10, 'opener', 1.0),
          saved(11, 'starter', 6.0),
          saved(12, 'reliever', 2.0),
        ])
        const rows = wrapper.vm.pitcherRows
        expect(rows.map((r) => r.is_second_starter)).toEqual([false, true, false])
        expect(rows[0].role).toBe('opener')

        vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
        await wrapper.vm.saveAll()
        expect(postedAppearances().map((a) => a.role)).toEqual(['opener', 'starter', 'reliever'])
      })

      it('保存済みで2番手が reliever なら第二先発にならない', async () => {
        const wrapper = await mountRows([saved(10, 'starter', 6.0), saved(11, 'reliever', 3.0)])
        expect(wrapper.vm.pitcherRows.map((r) => r.is_second_starter)).toEqual([false, false])
      })

      it('第二先発は先発として扱うので S（セーブ）・H（ホールド）は選べない', async () => {
        const wrapper = await mountRows(
          [saved(10, 'opener', 1.0), saved(11, 'starter', 6.0)],
          'win',
        )
        const options = wrapper.vm.getDecisionChipOptions(1)
        expect(options.find((o) => o.label === 'S')?.disabled).toBe(true)
        expect(options.find((o) => o.label === 'H')?.disabled).toBe(true)
        const reliefOptions = wrapper.vm.getDecisionChipOptions(0)
        expect(reliefOptions.find((o) => o.label === 'H')?.disabled).toBe(false)
      })

      it('結果区分チップ: 未保存の第二先発（負け・L・後続あり・3.0回）は先発として KO と表示する', async () => {
        const wrapper = await mountRows([])
        const rows = wrapper.vm.pitcherRows
        rows[0].role = 'opener'
        rows[0].pitcher_id = 10
        rows[0].innings_int = 1
        wrapper.vm.addRow()
        wrapper.vm.addRow()
        rows[1].pitcher_id = 11
        rows[1].is_second_starter = true
        rows[1].innings_int = 3
        rows[1].decision = 'L'
        rows[2].pitcher_id = 12
        await flushPromises()
        expect(wrapper.vm.computeResultCategory(1)).toBe('ko')
        rows[1].is_second_starter = false
        expect(wrapper.vm.computeResultCategory(1)).toBe('normal')
      })
    })

    describe('E3: 連続中4日カウントは画面から送らない（サーバが決める）', () => {
      it('保存済みの値（2）が復元されていても、送信内容に consecutive_short_rest_count を含めない', async () => {
        const wrapper = await mountRows([saved(10, 'starter', 6.0), saved(11, 'reliever', 2.0)])
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
        await wrapper.vm.saveAll()
        for (const a of postedAppearances()) {
          expect(a).not.toHaveProperty('consecutive_short_rest_count')
        }
      })

      it('新規行でも送らない', async () => {
        const wrapper = await mountRows([])
        vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
        wrapper.vm.pitcherRows[0].pitcher_id = 10
        await wrapper.vm.saveAll()
        expect(postedAppearances()[0]).not.toHaveProperty('consecutive_short_rest_count')
      })
    })

    describe('E7: 結果区分チップの関与イニング（サーバの PitcherInnings.involvement と揃える）', () => {
      function setStarter(
        wrapper: Awaited<ReturnType<typeof mountRows>>,
        int: number,
        frac: '' | '1' | '2',
        noOut = false,
      ) {
        const row = wrapper.vm.pitcherRows[0]
        row.pitcher_id = 10
        row.innings_int = int
        row.innings_frac = frac
        row.no_out_exit = noOut
        return row
      }

      it('負け試合の先発 1.0回: 関与1 → normal / 0アウト降板あり（関与2）→ 保存後に確定（疲労P0 なら long_loss になりうる）', async () => {
        const wrapper = await mountRows([])
        const row = setStarter(wrapper, 1, '')
        expect(wrapper.vm.computeResultCategory(0)).toBe('normal')
        row.no_out_exit = true
        expect(wrapper.vm.computeResultCategory(0)).toBe('pending')
      })

      it('0.0回 + 0アウト降板（関与1）で後続なし・L なし → normal', async () => {
        const wrapper = await mountRows([])
        setStarter(wrapper, 0, '', true)
        expect(wrapper.vm.computeResultCategory(0)).toBe('normal')
      })

      it('先発 1.1回（4アウト）は 2 つの回に跨るので関与2 → 保存後に確定', async () => {
        const wrapper = await mountRows([])
        setStarter(wrapper, 1, '1')
        expect(wrapper.vm.computeResultCategory(0)).toBe('pending')
      })

      it('第二先発: 前の投手が 1回1/3（4アウト）の後に入って 1.0回は 2 つの回に跨り関与2 → 保存後に確定。前の投手が 1.0回（3アウト）なら関与1 → normal', async () => {
        const wrapper = await mountRows([])
        const rows = wrapper.vm.pitcherRows
        rows[0].role = 'opener'
        rows[0].pitcher_id = 10
        rows[0].innings_int = 1
        rows[0].innings_frac = '1'
        wrapper.vm.addRow()
        rows[1].pitcher_id = 11
        rows[1].is_second_starter = true
        rows[1].innings_int = 1
        rows[1].innings_frac = ''
        // prior 4 アウト → 入った回 2、4+3-1=6 → 終了回 3 → 関与 2
        expect(wrapper.vm.computeResultCategory(1)).toBe('pending')
        // 前の投手が 3 アウト(1.0回)なら prior 3 → 入った回 2、終了回 floor((3+3-1)/3)+1 = 2 → 関与 1
        rows[0].innings_frac = ''
        expect(wrapper.vm.computeResultCategory(1)).toBe('normal')
      })

      it('勝ち・引き分けは関与イニングに関わらず normal', async () => {
        for (const result of ['win', 'draw'] as const) {
          const wrapper = await mountRows([], result)
          setStarter(wrapper, 9, '', true)
          expect(wrapper.vm.computeResultCategory(0)).toBe('normal')
        }
      })
    })
  })

  // cmd_1806 / subtask_1806a（Operator 2026-11-02）: 投手状態の一覧は試合前の段（PitcherStatusTab）へ移した。
  // 登板記録の段は、登板した投手ごとに「その日（試合前）の状態」と「登板による変化」だけを出す。
  // 先発は結果区分（KO・長イニング敗戦のペナルティ）、リリーフ・オープナーは翌日時点の累積イニング（サーバの保存値から）。
  describe('その日の状態と登板による変化（投手状態一覧は試合前の段へ移した）', () => {
    const thirdPitcher = { id: 12, name: '妖夢', position: 'pitcher', is_pitcher: true }
    const idleState = (id: number): PreGameStateMock => ({
      player_id: id,
      rest_days: null,
      cumulative_innings: 0,
      last_role: null,
      is_injured: false,
    })

    const summaryRow = (over: Record<string, unknown>) => ({
      player_id: 10,
      player_name: '幽々子',
      last_role: null,
      rest_days: null,
      cumulative_innings: null,
      last_result_category: null,
      is_injured: false,
      is_unavailable: false,
      projected_status: 'full',
      as_starter: { status: 'full', notes: [] },
      as_reliever: { status: 'full', notes: [] },
      as_opener: null,
      ...over,
    })

    const savedRow = (pitcherId: number, role: string, extra: Record<string, unknown> = {}) => ({
      id: pitcherId,
      pitcher_id: pitcherId,
      role,
      innings_pitched: role === 'starter' ? 5.0 : 1.0,
      earned_runs: 0,
      fatigue_p_used: 0,
      decision: null,
      is_opener: false,
      no_out_exit: false,
      consecutive_short_rest_count: 0,
      pre_injury_days_excluded: 0,
      result_category: role === 'starter' ? 'normal' : 'normal',
      next_day_cumulative_innings: null,
      ...extra,
    })

    async function mountDay(
      saved: unknown[],
      summary: unknown[] = [],
      gameResult: 'win' | 'lose' | 'draw' | 'no_game' = 'lose',
    ) {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if (url === '/teams/1/team_players') {
          return Promise.resolve({ data: [basePitcher, otherPitcher, thirdPitcher] })
        }
        if (url === '/teams/1/pitcher_game_states') {
          return Promise.resolve({ data: [10, 11, 12].map(idleState) })
        }
        if (url === '/pitcher_appearances') return Promise.resolve({ data: saved })
        if (url === '/teams/1/team_memberships') return Promise.resolve({ data: [] })
        if (url === '/teams/1/pitcher_game_states/fatigue_summary')
          return Promise.resolve({ data: summary })
        return Promise.reject(new Error(`Unexpected GET ${url}`))
      })
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      return wrapper
    }

    const before = (wrapper: Awaited<ReturnType<typeof mountDay>>, idx: number) =>
      wrapper.find(`[data-testid="day-state-before-${idx}"]`)
    const after = (wrapper: Awaited<ReturnType<typeof mountDay>>, idx: number) =>
      wrapper.find(`[data-testid="day-state-after-${idx}"]`)

    it('登板記録の段に投手状態の一覧（表）を出さない（試合前の段にある）', async () => {
      const wrapper = await mountDay(
        [savedRow(10, 'starter')],
        [summaryRow({ last_role: 'starter', rest_days: 5 })],
      )
      expect(wrapper.text()).not.toContain('投手状態一覧')
      expect(wrapper.find('table').exists()).toBe(false)
      expect(wrapper.find('[data-testid="as-starter-10"]').exists()).toBe(false)
      expect(wrapper.find('[data-testid="opener-column-header"]').exists()).toBe(false)
    })

    describe('先発: 登板による変化は結果区分（KO・長イニング敗戦のペナルティ）', () => {
      it('KO あり: 「KO」を出す。ペナルティの「長イニング敗戦」は出ない', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter', { result_category: 'ko' })])
        expect(after(wrapper, 0).text()).toContain('KO')
        expect(after(wrapper, 0).text()).not.toContain('長イニング敗戦')
        expect(after(wrapper, 0).text()).not.toContain('累積')
      })

      it('KO なし（通常）: 「KO」を出さない', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter', { result_category: 'normal' })])
        expect(after(wrapper, 0).text()).toContain('通常')
        expect(after(wrapper, 0).text()).not.toContain('KO')
      })

      it('ペナルティあり（長イニング敗戦）: 「長イニング敗戦」を出す', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter', { result_category: 'long_loss' })])
        expect(after(wrapper, 0).text()).toContain('長イニング敗戦')
        expect(after(wrapper, 0).text()).not.toContain('KO')
      })

      it('ペナルティなし: 「長イニング敗戦」を出さない', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter', { result_category: 'normal' })])
        expect(after(wrapper, 0).text()).not.toContain('長イニング敗戦')
      })

      it('判定保留（result_category が null）は判定保留と出す', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter', { result_category: null })])
        expect(after(wrapper, 0).text()).toContain('判定保留')
      })

      it('先発の「その日の状態」はサーバが返す「先発なら」の状態と中日数（補正後の疲労P・負傷チェック）', async () => {
        const wrapper = await mountDay(
          [savedRow(10, 'starter')],
          [
            summaryRow({
              last_role: 'starter',
              rest_days: 4,
              last_result_category: 'ko',
              as_starter: { status: 'reduced_3', notes: [] },
            }),
          ],
        )
        const text = before(wrapper, 0).text()
        expect(text).toContain('⚡ P-3')
        expect(text).toContain('中4日')
        expect(before(wrapper, 0).find('[data-testid="day-state-role-0"]').exists()).toBe(true)
      })

      it('先発には翌日の累積を出さない（累積はリリーフ・オープナーのもの）', async () => {
        const wrapper = await mountDay([
          savedRow(10, 'starter', { next_day_cumulative_innings: 2 }),
        ])
        expect(after(wrapper, 0).text()).not.toContain('翌日の累積')
      })
    })

    describe('リリーフ・オープナー: 登板による変化は翌日時点の累積イニング', () => {
      const pair = (next: number | null | undefined, relieverExtra = {}) => [
        savedRow(10, 'starter'),
        savedRow(11, 'reliever', { next_day_cumulative_innings: next, ...relieverExtra }),
      ]

      it('保存された翌日の累積を「翌日の累積 N」で出す', async () => {
        const wrapper = await mountDay(pair(3))
        expect(after(wrapper, 1).text()).toContain('翌日の累積 3')
      })

      it('境界: 翌日の累積が 0（登板しても休養で全快する）でも出す（0 を空扱いにしない）', async () => {
        const wrapper = await mountDay(pair(0))
        expect(after(wrapper, 1).text()).toContain('翌日の累積 0')
      })

      it('境界: 累積が 3（負傷チェックの閾値）をまたぐ 2 → 3 → 4 をそのまま出す', async () => {
        for (const n of [2, 3, 4]) {
          const wrapper = await mountDay(pair(n))
          expect(after(wrapper, 1).text(), String(n)).toContain(`翌日の累積 ${n}`)
          wrapper.unmount()
        }
      })

      it('リリーフには結果区分（通常）を出さない。ノーゲームの日だけ「ノーゲーム」も出す', async () => {
        const normal = await mountDay(pair(1))
        expect(after(normal, 1).text()).not.toContain('通常')
        const noGame = await mountDay(pair(1), [], 'no_game')
        expect(after(noGame, 1).text()).toContain('ノーゲーム')
        expect(after(noGame, 1).text()).toContain('翌日の累積 1')
      })

      it('オープナー（1番手 role=opener）にも翌日の累積を出す', async () => {
        const wrapper = await mountDay([
          savedRow(10, 'opener', { next_day_cumulative_innings: 1 }),
          savedRow(11, 'starter'),
        ])
        expect(after(wrapper, 0).text()).toContain('翌日の累積 1')
      })

      it('サーバが値を返さない（古い応答・日付不明）時は「保存後に確定」と出し、数字を作らない', async () => {
        const wrapper = await mountDay(pair(undefined))
        expect(after(wrapper, 1).text()).toContain('保存後に確定')
        expect(after(wrapper, 1).text()).not.toContain('翌日の累積')
      })

      it('保存後に入力を変えると、保存した時点の累積は古いので出さず「保存後に確定」にする', async () => {
        const wrapper = await mountDay(pair(2))
        expect(after(wrapper, 1).text()).toContain('翌日の累積 2')
        wrapper.vm.pitcherRows[1].innings_int = 3
        await flushPromises()
        expect(after(wrapper, 1).text()).toContain('保存後に確定')
        expect(after(wrapper, 1).text()).not.toContain('翌日の累積')
      })

      it('未保存の行を追加した直後も「保存後に確定」', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter')])
        wrapper.vm.pitcherRows.push({
          pitcher_id: 11,
          role: 'reliever',
          innings_pitched: null,
          earned_runs: 0,
          fatigue_p_used: 0,
          decision: null,
          is_opener: false,
          is_second_starter: false,
          no_out_exit: false,
          pre_injury_days_excluded: 0,
          appearance_order: 1,
          innings_int: 1,
          innings_frac: '',
        })
        await flushPromises()
        expect(after(wrapper, 1).text()).toContain('保存後に確定')
      })

      it('リリーフの「その日の状態」は「リリーフなら」の状態と累積（最初から疲労・負傷CK）', async () => {
        const wrapper = await mountDay(pair(4), [
          summaryRow({
            player_id: 11,
            player_name: '紫',
            last_role: 'reliever',
            cumulative_innings: 3,
            as_reliever: { status: 'fatigued_start_check', notes: [] },
          }),
        ])
        const text = before(wrapper, 1).text()
        expect(text).toContain('最初から疲労')
        expect(text).toContain('負傷CK')
        expect(text).toContain('累積3')
      })

      it('オープナーの「その日の状態」は「オープナーなら」の状態（注記つき）を出す', async () => {
        const wrapper = await mountDay(
          [savedRow(10, 'opener', { next_day_cumulative_innings: 2 }), savedRow(11, 'starter')],
          [
            summaryRow({
              last_role: 'reliever',
              cumulative_innings: 1,
              as_reliever: { status: 'reduced_0', notes: [] },
              as_opener: { status: 'reduced_0', notes: ['opener_check_cumulative'] },
            }),
          ],
        )
        expect(before(wrapper, 0).text()).toContain('累積1以上のため負傷チェック')
      })
    })

    describe('登板のない日・状態が取れない時', () => {
      it('登板なしの日: 投手が選ばれていない行には状態も変化も出さない', async () => {
        const wrapper = await mountDay([])
        expect(before(wrapper, 0).text()).toBe('')
        expect(after(wrapper, 0).text()).toBe('')
      })

      it('投手を選んだが未保存の先発: 結果区分は従来どおり（負け・L・後続ありの 4 回は KO）', async () => {
        const wrapper = await mountDay([])
        wrapper.vm.pitcherRows[0].pitcher_id = 10
        wrapper.vm.pitcherRows[0].innings_int = 4
        wrapper.vm.pitcherRows[0].decision = 'L'
        wrapper.vm.pitcherRows.push({
          ...wrapper.vm.pitcherRows[0],
          pitcher_id: 11,
          role: 'reliever',
          decision: null,
        })
        await flushPromises()
        expect(after(wrapper, 0).text()).toContain('KO')
      })

      it('試合前の状態（fatigue_summary）に載らない投手（2軍など）は、状態の欄に「—」を出す', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter')], [])
        expect(before(wrapper, 0).text()).toContain('—')
      })

      it('試合前の状態の取得に失敗しても登板記録（結果区分）は出る。状態の欄は「—」', async () => {
        const wrapper = await mountDay([savedRow(10, 'starter', { result_category: 'ko' })])
        const base = vi.mocked(axios.get).getMockImplementation()!
        vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) =>
          url === '/teams/1/pitcher_game_states/fatigue_summary'
            ? Promise.reject(new Error('boom'))
            : base(url, config as never),
        )
        await wrapper.vm.refreshSavedResultCategories()
        await flushPromises()
        expect(before(wrapper, 0).text()).toContain('—')
        expect(after(wrapper, 0).text()).toContain('KO')
      })
    })

    it('保存済みの結果区分を取り直すと翌日の累積も最新になる（得点の保存後）', async () => {
      const wrapper = await mountDay([savedRow(10, 'starter'), savedRow(11, 'reliever')])
      expect(after(wrapper, 1).text()).toContain('保存後に確定')
      const base = vi.mocked(axios.get).getMockImplementation()!
      vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) =>
        url === '/pitcher_appearances'
          ? Promise.resolve({
              data: [
                savedRow(10, 'starter'),
                savedRow(11, 'reliever', { next_day_cumulative_innings: 2 }),
              ],
            })
          : base(url, config as never),
      )
      await wrapper.vm.refreshSavedResultCategories()
      await flushPromises()
      expect(after(wrapper, 1).text()).toContain('翌日の累積 2')
    })
  })

  // cmd_1775 第3段 E12: ノーゲームを試合結果で選べる
  describe('ノーゲーム', () => {
    it('gameResult が no_game なら試合結果に「ノーゲーム」と出し、結果区分チップは全員ノーゲーム', async () => {
      mockPitcherRequests({ state: null })
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult: 'no_game' as const },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      expect(wrapper.text()).toContain('試合結果:')
      expect(wrapper.text()).toContain('ノーゲーム')
      expect(wrapper.vm.computeResultCategory(0)).toBe('no_game')
    })

    it('ノーゲームの保存は game_result: no_game を送る', async () => {
      mockPitcherRequests({ state: null })
      vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult: 'no_game' as const },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      wrapper.vm.pitcherRows[0].pitcher_id = 10
      await wrapper.vm.saveAll()
      const payload = vi.mocked(axios.post).mock.calls[0][1] as {
        pitcher_appearances_bulk: { game_result: string }
      }
      expect(payload.pitcher_appearances_bulk.game_result).toBe('no_game')
    })

    it('ノーゲームでは W / L / S の責任投手チップを選べない', async () => {
      mockPitcherRequests({ state: null })
      const wrapper = mount(PitcherAppearanceTab, {
        props: { ...defaultProps, gameResult: 'no_game' as const },
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      const options = wrapper.vm.getDecisionChipOptions(0)
      const disabled = Object.fromEntries(
        options.map((o: { label: string; disabled: boolean }) => [o.label, o.disabled]),
      )
      expect(disabled.W).toBe(true)
      expect(disabled.L).toBe(true)
      expect(disabled.S).toBe(true)
    })

    it('保存済みの結果区分だけを再取得できる（得点・ノーゲームの保存で作り直された区分を反映する。入力中の行は消さない）', async () => {
      mockPitcherRequests({ state: null })
      const wrapper = mount(PitcherAppearanceTab, {
        props: defaultProps,
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      wrapper.vm.pitcherRows[0].pitcher_id = 10
      wrapper.vm.pitcherRows[0].innings_int = 6
      const base = vi.mocked(axios.get).getMockImplementation()!
      vi.mocked(axios.get).mockImplementation((url: string) =>
        url === '/pitcher_appearances'
          ? Promise.resolve({ data: [{ pitcher_id: 10, result_category: 'no_game' }] })
          : base(url),
      )
      await wrapper.vm.refreshSavedResultCategories()
      expect(wrapper.vm.savedResultCategories).toEqual({ 10: 'no_game' })
      expect(wrapper.vm.pitcherRows[0].innings_int).toBe(6)
    })
  })
  // cmd_1783 段A: 未保存の入力を試合日ページへ知らせる（離脱ガード・「編集中」の表示）／保存したことを知らせる（状態の取り直し）
  describe('未保存の入力と保存の通知', () => {
    async function mountWithEvents() {
      mockPitcherRequests({ state: null })
      const wrapper = mount(PitcherAppearanceTab, {
        props: defaultProps,
        global: { plugins: [vuetify] },
      })
      await flushPromises()
      return wrapper
    }
    const dirtyEvents = (wrapper: Awaited<ReturnType<typeof mountWithEvents>>) =>
      (wrapper.emitted('dirty-change') ?? []).map((e) => e[0])

    it('読み込んだだけでは未保存にならない（通知も出さない）', async () => {
      const wrapper = await mountWithEvents()
      expect(wrapper.vm.isDirty).toBe(false)
      expect(dirtyEvents(wrapper)).toEqual([])
    })

    // cmd_1844: 開いたまま gameDate が変わった時（試合データの取得待ちで前の日の日付が渡っていた場合）の保険
    const savedReads = () =>
      vi
        .mocked(axios.get)
        .mock.calls.filter((c) => c[0] === '/pitcher_appearances')
        .map((c) => (c[1] as { params: { schedule_date: string } }).params.schedule_date)

    it('gameDate が変わったら、未保存の入力が無ければ新しい日で読み直す', async () => {
      const wrapper = await mountWithEvents()
      await wrapper.setProps({ gameDate: '2026-04-12' })
      await flushPromises()
      expect(savedReads()).toEqual(['2026-04-11', '2026-04-12'])
    })

    it('gameDate が変わっても、未保存の入力がある間は読み直して入力を消さない', async () => {
      const wrapper = await mountWithEvents()
      wrapper.vm.pitcherRows[0].innings_int = 6
      await flushPromises()
      await wrapper.setProps({ gameDate: '2026-04-12' })
      await flushPromises()
      expect(savedReads()).toEqual(['2026-04-11'])
      expect(wrapper.vm.pitcherRows[0].innings_int).toBe(6)
    })

    it('行を編集すると未保存になり、元の値に戻すと未保存でなくなる', async () => {
      const wrapper = await mountWithEvents()
      wrapper.vm.pitcherRows[0].innings_int = 6
      await flushPromises()
      expect(dirtyEvents(wrapper)).toEqual([true])
      wrapper.vm.pitcherRows[0].innings_int = null
      await flushPromises()
      expect(dirtyEvents(wrapper)).toEqual([true, false])
    })

    it('投手の追加・削除も未保存として扱う', async () => {
      const wrapper = await mountWithEvents()
      wrapper.vm.addRow()
      await flushPromises()
      expect(wrapper.vm.isDirty).toBe(true)
      wrapper.vm.removeRow(1)
      await flushPromises()
      expect(wrapper.vm.isDirty).toBe(false)
    })

    it('保存に成功したら未保存でなくなり、saved を通知する', async () => {
      const wrapper = await mountWithEvents()
      wrapper.vm.pitcherRows[0].pitcher_id = 10
      wrapper.vm.pitcherRows[0].innings_int = 6
      await flushPromises()
      expect(wrapper.vm.isDirty).toBe(true)
      vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })

      await wrapper.vm.saveAll()
      await flushPromises()

      expect(wrapper.vm.isDirty).toBe(false)
      expect(dirtyEvents(wrapper)).toEqual([true, false])
      expect(wrapper.emitted('saved')).toHaveLength(1)
    })

    it('保存に成功した後の再読み込みが失敗しても、未保存には戻らない（保存した内容が今の行。離脱ガードを出さない）', async () => {
      const wrapper = await mountWithEvents()
      wrapper.vm.pitcherRows[0].pitcher_id = 10
      wrapper.vm.pitcherRows[0].innings_int = 6
      await flushPromises()
      expect(dirtyEvents(wrapper)).toEqual([true])
      // 保存後の取り直し（GET /pitcher_appearances）だけ失敗させる。画面の行は入力のまま残る
      mockPitcherRequests({ state: null, savedReject: true })
      vi.mocked(axios.post).mockResolvedValueOnce({ data: { warnings: [] } })

      await wrapper.vm.saveAll()
      await flushPromises()

      expect(wrapper.vm.pitcherRows[0].innings_int).toBe(6)
      expect(wrapper.vm.isDirty).toBe(false)
      expect(dirtyEvents(wrapper)).toEqual([true, false])
      expect(wrapper.emitted('saved')).toHaveLength(1)
    })

    it('保存に失敗したら未保存のまま残り、saved は通知しない', async () => {
      const wrapper = await mountWithEvents()
      wrapper.vm.pitcherRows[0].pitcher_id = 10
      wrapper.vm.pitcherRows[0].innings_int = 6
      vi.mocked(axios.post).mockRejectedValueOnce({ response: { data: { errors: ['NG'] } } })

      await wrapper.vm.saveAll()
      await flushPromises()

      expect(wrapper.vm.isDirty).toBe(true)
      expect(wrapper.emitted('saved')).toBeUndefined()
    })
  })
})
