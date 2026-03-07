import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { RosterPlayer } from '@/types/rosterPlayer'

export interface LineupEntry {
  battingOrder: number
  playerId: number
  position: string
  playerName?: string
  playerNumber?: string
}

export interface TemplateValidationResult {
  battingOrder: number
  playerId: number
  status: 'ok' | 'not_first_squad' | 'absent'
  reason?: string
  candidates?: RosterPlayer[]
}

export const useSquadTextStore = defineStore('squadText', () => {
  const mode = ref<'template' | 'previous' | null>(null)
  const dhEnabled = ref<boolean>(false)
  const opponentPitcherHand = ref<'left' | 'right'>('right')
  const startingLineup = ref<LineupEntry[]>([])
  const benchPlayers = ref<number[]>([])
  const offPlayers = ref<number[]>([])
  const reliefPitcherIds = ref<number[]>([])
  const starterBenchPitcherIds = ref<number[]>([])
  const validationResults = ref<TemplateValidationResult[]>([])

  function reset() {
    mode.value = null
    dhEnabled.value = false
    opponentPitcherHand.value = 'right'
    startingLineup.value = []
    benchPlayers.value = []
    offPlayers.value = []
    reliefPitcherIds.value = []
    starterBenchPitcherIds.value = []
    validationResults.value = []
  }

  function loadFromTemplate(
    entries: LineupEntry[],
    firstSquadMembers: RosterPlayer[],
    absentPlayers: RosterPlayer[],
  ) {
    startingLineup.value = entries
    validationResults.value = validateLineupEntries(entries, firstSquadMembers, absentPlayers)
    mode.value = 'template'
  }

  function loadFromPrevious(
    lineupData: {
      dh_enabled?: boolean
      opponent_pitcher_hand?: 'left' | 'right'
      starting_lineup?: Array<{ batting_order: number; player_id: number; position: string }>
      bench_players?: number[]
      off_players?: number[]
      relief_pitcher_ids?: number[]
      starter_bench_pitcher_ids?: number[]
    },
    firstSquadMembers: RosterPlayer[],
    absentPlayers: RosterPlayer[],
  ) {
    if (lineupData.dh_enabled !== undefined) dhEnabled.value = lineupData.dh_enabled
    if (lineupData.opponent_pitcher_hand)
      opponentPitcherHand.value = lineupData.opponent_pitcher_hand

    const entries: LineupEntry[] = (lineupData.starting_lineup ?? []).map((e) => {
      const member = firstSquadMembers.find((m) => m.player_id === e.player_id)
      return {
        battingOrder: e.batting_order,
        playerId: e.player_id,
        position: e.position,
        playerName: member?.player_name,
        playerNumber: member?.number,
      }
    })
    startingLineup.value = entries
    benchPlayers.value = lineupData.bench_players ?? []
    offPlayers.value = lineupData.off_players ?? []
    reliefPitcherIds.value = lineupData.relief_pitcher_ids ?? []
    starterBenchPitcherIds.value = lineupData.starter_bench_pitcher_ids ?? []
    validationResults.value = validateLineupEntries(entries, firstSquadMembers, absentPlayers)
    mode.value = 'previous'
  }

  function validateLineupEntries(
    entries: LineupEntry[],
    firstSquadMembers: RosterPlayer[],
    absentPlayers: RosterPlayer[],
  ): TemplateValidationResult[] {
    const firstSquadIds = new Set(firstSquadMembers.map((p) => p.player_id))
    const absentIds = new Set(absentPlayers.map((p) => p.player_id))
    const absentMap = new Map(absentPlayers.map((p) => [p.player_id, p]))

    return entries.map((entry) => {
      if (absentIds.has(entry.playerId)) {
        const absentPlayer = absentMap.get(entry.playerId)
        const reason = absentPlayer?.absence_info?.reason
          ? `離脱中（${absentPlayer.absence_info.reason}）`
          : '離脱中'
        const candidates = firstSquadMembers.filter(
          (p) => p.position === entry.position && !absentIds.has(p.player_id),
        )
        return {
          battingOrder: entry.battingOrder,
          playerId: entry.playerId,
          status: 'absent',
          reason,
          candidates,
        }
      }
      if (!firstSquadIds.has(entry.playerId)) {
        const candidates = firstSquadMembers.filter(
          (p) => p.position === entry.position && !absentIds.has(p.player_id),
        )
        return {
          battingOrder: entry.battingOrder,
          playerId: entry.playerId,
          status: 'not_first_squad',
          reason: '2軍',
          candidates,
        }
      }
      return {
        battingOrder: entry.battingOrder,
        playerId: entry.playerId,
        status: 'ok',
      }
    })
  }

  return {
    mode,
    dhEnabled,
    opponentPitcherHand,
    startingLineup,
    benchPlayers,
    offPlayers,
    reliefPitcherIds,
    starterBenchPitcherIds,
    validationResults,
    reset,
    loadFromTemplate,
    loadFromPrevious,
  }
})
