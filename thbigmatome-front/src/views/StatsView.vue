<template>
  <v-container>
    <v-card>
      <v-card-title>成績集計</v-card-title>
      <v-card-text>
        <v-select
          v-model="selectedCompetitionId"
          :items="competitions"
          item-title="name"
          item-value="id"
          label="大会"
          density="compact"
          clearable
          class="mb-4"
          @update:model-value="fetchStats"
        ></v-select>

        <v-tabs v-model="activeTab">
          <v-tab value="batting">打撃成績</v-tab>
          <v-tab value="pitching">投手成績</v-tab>
          <v-tab value="team">チーム成績</v-tab>
        </v-tabs>

        <v-tabs-window v-model="activeTab">
          <v-tabs-window-item value="batting">
            <v-data-table
              :headers="battingHeaders"
              :items="battingStats"
              :loading="loading"
              density="compact"
            />
          </v-tabs-window-item>
          <v-tabs-window-item value="pitching">
            <v-data-table
              :headers="pitchingHeaders"
              :items="pitchingStats"
              :loading="loading"
              density="compact"
            />
          </v-tabs-window-item>
          <v-tabs-window-item value="team">
            <v-data-table
              :headers="teamHeaders"
              :items="teamStats"
              :loading="loading"
              density="compact"
            />
          </v-tabs-window-item>
        </v-tabs-window>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

interface Competition {
  id: number
  name: string
}

interface BattingStat {
  player_name: string
  games_played: number
  at_bat_count: number
  batting_average: string
  hits: number
  doubles: number
  triples: number
  home_runs: number
  rbi: number
  strikeouts: number
  walks: number
  ops: string
}

interface PitchingStat {
  player_name: string
  wins: number
  losses: number
  saves: number
  era: string
  innings_pitched: string
  strikeouts: number
  walks: number
  whip: string
}

interface TeamStat {
  team_name: string
  wins: number
  losses: number
  draws: number
  runs_scored: number
  runs_allowed: number
}

const selectedCompetitionId = ref<number | null>(null)
const competitions = ref<Competition[]>([])
const activeTab = ref('batting')
const loading = ref(false)

const battingStats = ref<BattingStat[]>([])
const pitchingStats = ref<PitchingStat[]>([])
const teamStats = ref<TeamStat[]>([])

const battingHeaders = [
  { title: '選手名', key: 'player_name' },
  { title: '試合', key: 'games_played' },
  { title: '打数', key: 'at_bat_count' },
  { title: '打率', key: 'batting_average' },
  { title: '安打', key: 'hits' },
  { title: '二塁打', key: 'doubles' },
  { title: '三塁打', key: 'triples' },
  { title: '本塁打', key: 'home_runs' },
  { title: '打点', key: 'rbi' },
  { title: '三振', key: 'strikeouts' },
  { title: '四球', key: 'walks' },
  { title: 'OPS', key: 'ops' },
]

const pitchingHeaders = [
  { title: '選手名', key: 'player_name' },
  { title: '勝', key: 'wins' },
  { title: '敗', key: 'losses' },
  { title: 'S', key: 'saves' },
  { title: '防御率', key: 'era' },
  { title: '投球回', key: 'innings_pitched' },
  { title: '奪三振', key: 'strikeouts' },
  { title: '与四球', key: 'walks' },
  { title: 'WHIP', key: 'whip' },
]

const teamHeaders = [
  { title: 'チーム名', key: 'team_name' },
  { title: '勝', key: 'wins' },
  { title: '敗', key: 'losses' },
  { title: '分', key: 'draws' },
  { title: '得点', key: 'runs_scored' },
  { title: '失点', key: 'runs_allowed' },
]

onMounted(() => {
  fetchCompetitions()
})

async function fetchCompetitions() {
  try {
    const response = await axios.get<Competition[]>('/competitions')
    competitions.value = response.data
  } catch (error) {
    console.error('Error fetching competitions:', error)
  }
}

async function fetchStats() {
  if (selectedCompetitionId.value === null) return
  loading.value = true
  try {
    const params = { competition_id: selectedCompetitionId.value }
    const [battingRes, pitchingRes, teamRes] = await Promise.all([
      axios.get<{ batting_stats: BattingStat[] }>('/stats/batting', { params }),
      axios.get<{ pitching_stats: PitchingStat[] }>('/stats/pitching', { params }),
      axios.get<{ team_stats: TeamStat[] }>('/stats/team', { params }),
    ])
    battingStats.value = battingRes.data.batting_stats
    pitchingStats.value = pitchingRes.data.pitching_stats
    teamStats.value = teamRes.data.team_stats
  } catch (error) {
    console.error('Error fetching stats:', error)
  } finally {
    loading.value = false
  }
}

defineExpose({ fetchStats, selectedCompetitionId })
</script>
