import { ref, computed, type Ref } from 'vue'
import axios from 'axios'
import { useSquadTextStore } from '@/stores/squadText'
import type { RosterPlayer } from '@/types/rosterPlayer'

interface RosterChange {
  type: 'promote' | 'demote'
  player_id: number
  player_name: string
  number: string
  date: string
}

interface ImportedStatRecord {
  player_id: number
  stat_type: 'batting' | 'pitching'
  stats: Record<string, number | null>
}

interface SquadTextSettingData {
  position_format: string
  handedness_format: string
  section_header_format: string
  show_number_prefix: boolean
  batting_stats_config: Record<string, boolean>
  pitching_stats_config: Record<string, boolean>
}

const POSITION_MAP: Record<string, Record<string, string>> = {
  english: {
    C: 'C',
    '1B': '1B',
    '2B': '2B',
    '3B': '3B',
    SS: 'SS',
    LF: 'LF',
    CF: 'CF',
    RF: 'RF',
    P: 'P',
    DH: 'DH',
  },
  japanese: {
    C: '捕',
    '1B': '一',
    '2B': '二',
    '3B': '三',
    SS: '遊',
    LF: '左',
    CF: '中',
    RF: '右',
    P: '投',
    DH: 'DH',
  },
}

const HANDEDNESS_MAP: Record<string, Record<string, string>> = {
  alphabet: {
    right_throw: 'R',
    left_throw: 'L',
    right_bat: 'R',
    left_bat: 'L',
    switch_hitter: 'S',
  },
  kanji: {
    right_throw: '右',
    left_throw: '左',
    right_bat: '右',
    left_bat: '左',
    switch_hitter: '両',
  },
}

const DEFAULT_SETTINGS: SquadTextSettingData = {
  position_format: 'english',
  handedness_format: 'alphabet',
  section_header_format: 'bracket',
  show_number_prefix: true,
  batting_stats_config: {
    avg: true,
    hr: true,
    rbi: true,
    sb: false,
    obp: false,
    ops: false,
  },
  pitching_stats_config: {
    w_l: true,
    games: true,
    era: true,
    so: true,
    ip: true,
    hold: false,
    save: false,
  },
}

interface PitcherPreGameState {
  player_id: number
  rest_days: number | null
  cumulative_innings: number
  last_role: string | null
  is_injured: boolean
}

export function useSquadTextGenerator(teamId: Ref<number>) {
  const store = useSquadTextStore()

  const battingStats = ref<Record<number, Record<string, number | null>>>({})
  const pitchingStats = ref<Record<number, Record<string, number | null>>>({})
  const pitcherPreGameStates = ref<Record<number, PitcherPreGameState>>({})
  const settings = ref<SquadTextSettingData>({
    ...DEFAULT_SETTINGS,
    batting_stats_config: { ...DEFAULT_SETTINGS.batting_stats_config },
    pitching_stats_config: { ...DEFAULT_SETTINGS.pitching_stats_config },
  })
  const rosterPlayers = ref<RosterPlayer[]>([])
  const loading = ref(false)
  const rosterChangesText = ref<string>('')

  function getPlayer(playerId: number): RosterPlayer | undefined {
    return rosterPlayers.value.find((p) => p.player_id === playerId)
  }

  function sectionHeader(name: string): string {
    return settings.value.section_header_format === 'bracket' ? `【${name}】` : name
  }

  function formatPos(pos: string): string {
    return POSITION_MAP[settings.value.position_format]?.[pos] ?? pos
  }

  function formatHand(handedness: string | null | undefined): string {
    if (!handedness) return ''
    const [throwing, batting] = handedness.split('/')
    const map = HANDEDNESS_MAP[settings.value.handedness_format] ?? HANDEDNESS_MAP.alphabet
    return `${map[throwing] ?? throwing}${map[batting] ?? batting}`
  }

  function formatNum(number: string): string {
    if (!number) return ''
    return settings.value.show_number_prefix ? number : number.replace(/^[A-Za-z]+/, '')
  }

  function fmtAvg(val: number | null | undefined): string {
    if (val == null) return '-'
    return `.${String(Math.round(val * 1000)).padStart(3, '0')}`
  }

  function fmtEra(val: number | null | undefined): string {
    if (val == null) return '-'
    return Number(val).toFixed(2)
  }

  function battingLine(playerId: number): string {
    const stat = battingStats.value[playerId]
    const cfg = settings.value.batting_stats_config
    const parts: string[] = []
    if (cfg.avg) parts.push(stat ? fmtAvg(stat.avg) : '-')
    if (cfg.hr) parts.push(stat?.hr != null ? `${stat.hr}本` : '-')
    if (cfg.rbi) parts.push(stat?.rbi != null ? `${stat.rbi}打点` : '-')
    if (cfg.sb) parts.push(stat?.sb != null ? `${stat.sb}盗` : '-')
    if (cfg.obp) parts.push(stat ? fmtAvg(stat.obp) : '-')
    if (cfg.ops) parts.push(stat ? fmtAvg(stat.ops) : '-')
    return parts.join(' ')
  }

  function pitchingLine(playerId: number): string {
    const stat = pitchingStats.value[playerId]
    const cfg = settings.value.pitching_stats_config
    const parts: string[] = []
    if (cfg.era) parts.push(stat ? fmtEra(stat.era) : '-')
    if (cfg.games) parts.push(stat?.games != null ? `${stat.games}登板` : '-')
    if (cfg.w_l) {
      if (stat?.w != null && stat?.l != null) parts.push(`${stat.w}勝${stat.l}敗`)
      else parts.push('-')
    }
    if (cfg.ip) parts.push(stat?.ip != null ? `${stat.ip}回` : '-')
    if (cfg.so) parts.push(stat?.so != null ? `${stat.so}奪` : '-')
    if (cfg.hold && stat?.hold != null) parts.push(`${stat.hold}H`)
    if (cfg.save && stat?.save != null) parts.push(`${stat.save}S`)
    return parts.filter(Boolean).join(' ')
  }

  function formatDate(date: Date): string {
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, '0')
    const d = String(date.getDate()).padStart(2, '0')
    return `${y}/${m}/${d}`
  }

  const headerText = computed(() => {
    return formatDate(new Date())
  })

  const starterText = computed(() => {
    if (store.startingLineup.length === 0) return ''
    const lines = [sectionHeader('スタメン')]
    for (const entry of store.startingLineup) {
      const p = getPlayer(entry.playerId)
      if (!p) continue
      const parts = [
        String(entry.battingOrder),
        formatPos(entry.position),
        formatNum(p.number),
        p.player_name,
        formatHand(p.handedness),
      ]
      const bLine = battingLine(entry.playerId)
      if (bLine) parts.push(bLine)
      lines.push(parts.join(' '))
    }
    return lines.join('\n')
  })

  const benchHitterText = computed(() => {
    if (store.benchPlayers.length === 0) return ''
    const lines = [sectionHeader('控え野手')]
    for (const id of store.benchPlayers) {
      const p = getPlayer(id)
      if (!p) continue
      const parts = [formatNum(p.number), p.player_name, formatHand(p.handedness)]
      const bLine = battingLine(id)
      if (bLine) parts.push(bLine)
      lines.push(parts.join(' '))
    }
    return lines.join('\n')
  })

  const reliefPitcherText = computed(() => {
    if (store.reliefPitcherIds.length === 0) return ''
    const lines = [sectionHeader('中継ぎ')]
    for (const id of store.reliefPitcherIds) {
      const p = getPlayer(id)
      if (!p) continue
      const isRelief = p.player_types.some((t) => t.includes('中継'))
      const prefix = isRelief ? '(中継)' : ''
      const parts = [`${prefix}${formatNum(p.number)}`, p.player_name, formatHand(p.handedness)]
      const pLine = pitchingLine(id)
      if (pLine) parts.push(pLine)
      const state = pitcherPreGameStates.value[id]
      if (state && state.cumulative_innings > 0) parts.push(`累積${state.cumulative_innings}`)
      lines.push(parts.join(' '))
    }
    return lines.join('\n')
  })

  const starterBenchText = computed(() => {
    if (store.starterBenchPitcherIds.length === 0) return ''
    const lines = [sectionHeader('先発ベンチ')]
    for (const id of store.starterBenchPitcherIds) {
      const p = getPlayer(id)
      if (!p) continue
      const parts = [formatNum(p.number), p.player_name, formatHand(p.handedness)]
      const pLine = pitchingLine(id)
      if (pLine) parts.push(pLine)
      const state = pitcherPreGameStates.value[id]
      if (state && state.rest_days != null) parts.push(`中${state.rest_days}日`)
      lines.push(parts.join(' '))
    }
    return lines.join('\n')
  })

  const offText = computed(() => {
    if (store.offPlayers.length === 0) return ''
    const lines = [sectionHeader('オフ')]
    for (const id of store.offPlayers) {
      const p = getPlayer(id)
      if (!p) continue
      const parts = [formatNum(p.number), p.player_name, formatHand(p.handedness)]
      const statLine = p.position === 'pitcher' ? pitchingLine(id) : battingLine(id)
      if (statLine) parts.push(statLine)
      lines.push(parts.join(' '))
    }
    return lines.join('\n')
  })

  const generatedText = computed(() => {
    return [
      headerText.value,
      rosterChangesText.value,
      starterText.value,
      benchHitterText.value,
      reliefPitcherText.value,
      starterBenchText.value,
      offText.value,
    ]
      .filter(Boolean)
      .join('\n\n')
  })

  async function fetchStats(playerIds: number[]) {
    if (playerIds.length === 0) return
    try {
      const res = await axios.get<ImportedStatRecord[]>(`/teams/${teamId.value}/imported_stats`, {
        params: { player_ids: playerIds },
      })
      for (const stat of res.data) {
        if (stat.stat_type === 'batting') {
          battingStats.value[stat.player_id] = stat.stats
        } else if (stat.stat_type === 'pitching') {
          pitchingStats.value[stat.player_id] = stat.stats
        }
      }
    } catch {
      // API unavailable — stats will show "-"
    }
  }

  async function fetchPitcherGameStates(pitcherIds: number[]) {
    if (pitcherIds.length === 0) return
    try {
      const res = await axios.get<PitcherPreGameState[]>(
        `/teams/${teamId.value}/pitcher_game_states`,
        { params: { player_ids: pitcherIds } },
      )
      for (const item of res.data) {
        pitcherPreGameStates.value[item.player_id] = item
      }
    } catch {
      // API unavailable — pre-game state will not be shown
    }
  }

  async function fetchSettings() {
    try {
      const res = await axios.get<SquadTextSettingData>(
        `/teams/${teamId.value}/squad_text_settings`,
      )
      settings.value = res.data
    } catch {
      // Use defaults
    }
  }

  async function fetchRosterChanges(sinceDate: string, seasonId: number) {
    try {
      const res = await axios.get<{ changes: RosterChange[]; text: string }>(
        `/teams/${teamId.value}/roster_changes`,
        { params: { since: sinceDate, season_id: seasonId } },
      )
      rosterChangesText.value = res.data.text ?? ''
    } catch {
      rosterChangesText.value = ''
    }
  }

  async function saveAsGameLineup() {
    const lineupData = {
      dh_enabled: store.dhEnabled,
      opponent_pitcher_hand: store.opponentPitcherHand,
      starting_lineup: store.startingLineup.map((e) => ({
        batting_order: e.battingOrder,
        player_id: e.playerId,
        position: e.position,
      })),
      bench_players: store.benchPlayers,
      off_players: store.offPlayers,
      relief_pitcher_ids: store.reliefPitcherIds,
      starter_bench_pitcher_ids: store.starterBenchPitcherIds,
    }
    await axios.put(`/teams/${teamId.value}/game_lineup`, {
      game_lineup: { lineup_data: lineupData },
    })
  }

  async function init(players: RosterPlayer[]) {
    loading.value = true
    rosterPlayers.value = players
    const allIds = players.map((p) => p.player_id)
    const pitcherIds = players.filter((p) => p.position === 'pitcher').map((p) => p.player_id)
    try {
      await Promise.all([fetchSettings(), fetchStats(allIds), fetchPitcherGameStates(pitcherIds)])
      // 投手の初期振り分け（未設定時のみ）
      if (store.reliefPitcherIds.length === 0 && store.starterBenchPitcherIds.length === 0) {
        const reliefIds: number[] = []
        const starterBenchIds: number[] = []
        for (const p of players) {
          if (p.position !== 'pitcher') continue
          if (p.is_starter_pitcher) {
            starterBenchIds.push(p.player_id)
          } else {
            reliefIds.push(p.player_id)
          }
        }
        store.reliefPitcherIds = reliefIds
        store.starterBenchPitcherIds = starterBenchIds
      }
    } finally {
      loading.value = false
    }
  }

  return {
    loading,
    settings,
    generatedText,
    headerText,
    rosterChangesText,
    starterText,
    benchHitterText,
    reliefPitcherText,
    starterBenchText,
    offText,
    pitcherPreGameStates,
    fetchStats,
    fetchPitcherGameStates,
    fetchSettings,
    fetchRosterChanges,
    saveAsGameLineup,
    init,
  }
}
