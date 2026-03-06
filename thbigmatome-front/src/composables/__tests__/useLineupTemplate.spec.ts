import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { ref } from 'vue'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
  },
}))

import axios from 'axios'
import { useLineupTemplate } from '../useLineupTemplate'
import type { RosterPlayer } from '@/types/rosterPlayer'

function makePlayer(overrides: Partial<RosterPlayer>): RosterPlayer {
  return {
    team_membership_id: 1,
    player_id: 1,
    number: '1',
    player_name: 'テスト選手',
    squad: 'first',
    cost: 0,
    selected_cost_type: 'normal',
    position: 'RF',
    throwing_hand: 'right',
    batting_hand: 'right',
    player_types: [],
    is_absent: false,
    ...overrides,
  }
}

describe('useLineupTemplate', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('loadFromTemplate: APIを呼び出してバリデーション結果を返す', async () => {
    const player = makePlayer({ player_id: 42, position: 'RF' })
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: {
        id: 1,
        dh_enabled: true,
        opponent_pitcher_hand: 'right',
        entries: [
          {
            batting_order: 1,
            player_id: 42,
            position: 'RF',
            player_name: 'テスト選手',
            player_number: 'F10',
          },
        ],
      },
    })

    const teamId = ref(5)
    const { loadFromTemplate } = useLineupTemplate(teamId)
    const results = await loadFromTemplate(1, [player], [])

    expect(axios.get).toHaveBeenCalledWith('/teams/5/lineup_templates/1')
    expect(results[0].status).toBe('ok')
    expect(results[0].playerId).toBe(42)
  })

  it('loadFromTemplate: API失敗時にエラーをスロー', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('Network error'))

    const teamId = ref(5)
    const { loadFromTemplate, error } = useLineupTemplate(teamId)
    await expect(loadFromTemplate(1, [], [])).rejects.toThrow()
    expect(error.value).toBe('テンプレートの読み込みに失敗しました')
  })

  it('loadFromPrevious: 前回データを正常に読み込む', async () => {
    const player = makePlayer({ player_id: 10, position: '1B' })
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: {
        id: 1,
        lineup_data: {
          dh_enabled: false,
          opponent_pitcher_hand: 'left',
          starting_lineup: [{ batting_order: 1, player_id: 10, position: '1B' }],
          bench_players: [],
          off_players: [],
          relief_pitcher_ids: [],
          starter_bench_pitcher_ids: [],
        },
        updated_at: '2026-03-07T00:00:00+09:00',
      },
    })

    const teamId = ref(3)
    const { loadFromPrevious } = useLineupTemplate(teamId)
    const results = await loadFromPrevious([player], [])

    expect(axios.get).toHaveBeenCalledWith('/teams/3/game_lineup')
    expect(results).not.toBeNull()
    expect(results![0].status).toBe('ok')
  })

  it('loadFromPrevious: 404のときnullを返す', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce({ response: { status: 404 } })

    const teamId = ref(3)
    const { loadFromPrevious } = useLineupTemplate(teamId)
    const result = await loadFromPrevious([], [])

    expect(result).toBeNull()
  })
})
