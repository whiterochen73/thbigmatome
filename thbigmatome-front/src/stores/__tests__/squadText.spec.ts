import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useSquadTextStore } from '../squadText'
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

describe('useSquadTextStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('初期状態が正しい', () => {
    const store = useSquadTextStore()
    expect(store.mode).toBeNull()
    expect(store.startingLineup).toEqual([])
    expect(store.validationResults).toEqual([])
  })

  it('reset() で状態がクリアされる', () => {
    const store = useSquadTextStore()
    const entry = { battingOrder: 1, playerId: 42, position: 'RF' }
    store.loadFromTemplate([entry], [makePlayer({ player_id: 42 })], [])
    store.reset()
    expect(store.mode).toBeNull()
    expect(store.startingLineup).toEqual([])
    expect(store.validationResults).toEqual([])
  })

  it('loadFromTemplate: 1軍選手はok', () => {
    const store = useSquadTextStore()
    const player = makePlayer({ player_id: 42, position: 'RF' })
    const entry = { battingOrder: 1, playerId: 42, position: 'RF' }
    store.loadFromTemplate([entry], [player], [])
    expect(store.mode).toBe('template')
    expect(store.validationResults[0].status).toBe('ok')
  })

  it('loadFromTemplate: 2軍選手はnot_first_squad', () => {
    const store = useSquadTextStore()
    const entry = { battingOrder: 1, playerId: 99, position: 'RF' }
    // 1軍メンバーに player_id:99 は含まれない
    store.loadFromTemplate([entry], [], [])
    expect(store.validationResults[0].status).toBe('not_first_squad')
    expect(store.validationResults[0].reason).toBe('2軍')
  })

  it('loadFromTemplate: 離脱中の選手はabsent', () => {
    const store = useSquadTextStore()
    const player = makePlayer({
      player_id: 42,
      position: 'CF',
      is_absent: true,
      absence_info: {
        absence_type: 'injury',
        reason: '骨折',
        effective_end_date: null,
        remaining_days: null,
        duration_unit: 'days',
      },
    })
    const entry = { battingOrder: 3, playerId: 42, position: 'CF' }
    store.loadFromTemplate([entry], [player], [player])
    expect(store.validationResults[0].status).toBe('absent')
    expect(store.validationResults[0].reason).toBe('離脱中（骨折）')
  })

  it('loadFromTemplate: 候補選手が提示される', () => {
    const store = useSquadTextStore()
    const absent = makePlayer({ player_id: 42, position: 'RF', is_absent: true })
    const candidate = makePlayer({ player_id: 55, position: 'RF', player_name: '候補選手' })
    const entry = { battingOrder: 1, playerId: 42, position: 'RF' }
    store.loadFromTemplate([entry], [candidate], [absent])
    const result = store.validationResults[0]
    expect(result.status).toBe('absent')
    expect(result.candidates?.some((c) => c.player_id === 55)).toBe(true)
  })

  it('loadFromPrevious: 前回データを正しく読み込む', () => {
    const store = useSquadTextStore()
    const player = makePlayer({ player_id: 10, position: '1B' })
    const lineupData = {
      dh_enabled: true,
      opponent_pitcher_hand: 'right' as const,
      starting_lineup: [{ batting_order: 1, player_id: 10, position: '1B' }],
      bench_players: [20, 30],
      off_players: [40],
      relief_pitcher_ids: [101],
      starter_bench_pitcher_ids: [200],
    }
    store.loadFromPrevious(lineupData, [player], [])
    expect(store.mode).toBe('previous')
    expect(store.dhEnabled).toBe(true)
    expect(store.opponentPitcherHand).toBe('right')
    expect(store.startingLineup[0].playerId).toBe(10)
    expect(store.benchPlayers).toEqual([20, 30])
    expect(store.offPlayers).toEqual([40])
    expect(store.reliefPitcherIds).toEqual([101])
    expect(store.starterBenchPitcherIds).toEqual([200])
  })
})
