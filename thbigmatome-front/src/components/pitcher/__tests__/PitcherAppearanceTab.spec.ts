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
})
