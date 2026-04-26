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
})
