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

function mockPitcherRequests(state: PreGameStateMock | null) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url === '/teams/1/team_players') {
      return Promise.resolve({ data: [basePitcher] })
    }
    if (url === '/teams/1/pitcher_game_states') {
      return Promise.resolve({ data: state ? [state] : [] })
    }
    if (url === '/pitcher_appearances') {
      return Promise.resolve({ data: [] })
    }
    if (url === '/teams/1/team_memberships') {
      return Promise.resolve({ data: [] })
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

  it('健康で状態情報がない投手は選択可能にし、player_absencesを取得しないこと', async () => {
    const wrapper = await mountComponent(null)

    const item = getPitcherItem(wrapper)
    expect(item.disabled).toBe(false)
    expect(item.statusBadge).toBe('🟢')
    expect(item.preGameInfo).toBe('')
    expect(vi.mocked(axios.get).mock.calls.map(([url]) => url)).not.toContain(
      '/player_absences?team_id=1',
    )
  })
})
