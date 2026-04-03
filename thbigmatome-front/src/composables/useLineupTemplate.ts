import { ref } from 'vue'
import type { Ref } from 'vue'
import axios from 'axios'
import { useSquadTextStore } from '@/stores/squadText'
import type { LineupEntry, TemplateValidationResult } from '@/stores/squadText'
import type { RosterPlayer } from '@/types/rosterPlayer'

interface LineupTemplateEntryRaw {
  batting_order: number
  player_id: number
  position: string
  player_name?: string
  player_number?: string
}

interface LineupTemplateRaw {
  id: number
  dh_enabled: boolean
  opponent_pitcher_hand: 'left' | 'right'
  entries: LineupTemplateEntryRaw[]
}

interface GameLineupRaw {
  id: number
  lineup_data: {
    dh_enabled?: boolean
    opponent_pitcher_hand?: 'left' | 'right'
    starting_lineup?: Array<{ batting_order: number; player_id: number; position: string }>
    bench_players?: number[]
    off_players?: number[]
    relief_pitcher_ids?: number[]
    starter_bench_pitcher_ids?: number[]
  }
  updated_at: string
}

export function useLineupTemplate(teamId: Ref<number>) {
  const store = useSquadTextStore()
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function loadFromTemplate(
    templateId: number,
    firstSquadMembers: RosterPlayer[],
    absentPlayers: RosterPlayer[],
  ): Promise<TemplateValidationResult[]> {
    loading.value = true
    error.value = null
    try {
      const res = await axios.get<LineupTemplateRaw>(
        `/teams/${teamId.value}/lineup_templates/${templateId}`,
      )
      const entries: LineupEntry[] = res.data.entries.map((e) => ({
        battingOrder: e.batting_order,
        playerId: e.player_id,
        position: e.position,
        playerName: e.player_name,
        playerNumber: e.player_number,
      }))
      store.dhEnabled = res.data.dh_enabled
      store.opponentPitcherHand = res.data.opponent_pitcher_hand
      store.loadFromTemplate(entries, firstSquadMembers, absentPlayers)
      return store.validationResults
    } catch (e) {
      error.value = 'テンプレートの読み込みに失敗しました'
      throw e
    } finally {
      loading.value = false
    }
  }

  async function loadFromPrevious(
    firstSquadMembers: RosterPlayer[],
    absentPlayers: RosterPlayer[],
  ): Promise<TemplateValidationResult[] | null> {
    loading.value = true
    error.value = null
    try {
      const res = await axios.get<GameLineupRaw>(`/teams/${teamId.value}/game_lineup`)
      store.loadFromPrevious(res.data.lineup_data, firstSquadMembers, absentPlayers)
      return store.validationResults
    } catch (e: unknown) {
      if (
        e &&
        typeof e === 'object' &&
        'response' in e &&
        (e as { response?: { status?: number } }).response?.status === 404
      ) {
        return null
      }
      error.value = '前回データの読み込みに失敗しました'
      throw e
    } finally {
      loading.value = false
    }
  }

  return {
    loading,
    error,
    loadFromTemplate,
    loadFromPrevious,
  }
}
