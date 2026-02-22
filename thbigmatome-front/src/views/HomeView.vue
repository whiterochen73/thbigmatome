<template>
  <v-container>
    <!-- 大会選択 -->
    <v-select
      v-model="selectedCompetitionId"
      :items="competitions"
      item-title="name"
      item-value="id"
      label="大会"
      density="compact"
      clearable
      class="mb-4"
      @update:model-value="fetchSummary"
    />

    <!-- シーズン進行カード -->
    <v-card class="mb-4" elevation="1">
      <v-card-title class="text-h6">シーズン進行</v-card-title>
      <v-card-text>
        <div v-if="summary" class="mb-2">
          <div class="text-body-2 mb-1">
            {{ summary.season_progress.completed }} / {{ summary.season_progress.total }} 試合消化
          </div>
          <v-progress-linear
            :model-value="progressPercent"
            color="primary"
            height="12"
            rounded
            class="mb-3"
          />
          <div v-if="summary.team_summary" class="text-body-2">
            <span class="font-weight-bold">{{ summary.team_summary.team_name }}</span>
            &nbsp;
            <span class="text-success">{{ summary.team_summary.wins }}勝</span>
            <span> - </span>
            <span class="text-error">{{ summary.team_summary.losses }}敗</span>
            <span> - </span>
            <span>{{ summary.team_summary.draws }}分</span>
          </div>
        </div>
        <div v-else class="text-caption text-medium-emphasis">大会を選択してください</div>
      </v-card-text>
    </v-card>

    <!-- 直近の試合結果 -->
    <v-card class="mb-4" elevation="1">
      <v-card-title class="text-h6">直近の試合結果</v-card-title>
      <v-card-text class="pa-0">
        <v-list density="compact" v-if="summary && summary.recent_games.length > 0">
          <v-list-item
            v-for="game in summary.recent_games"
            :key="game.id"
            :to="`/games/${game.id}`"
            link
          >
            <template v-slot:prepend>
              <span class="text-caption text-medium-emphasis mr-3">{{ game.real_date }}</span>
            </template>
            <v-list-item-title class="text-body-2">
              {{ game.home_team }}
              <span class="font-weight-bold mx-1"
                >{{ game.home_score }} - {{ game.visitor_score }}</span
              >
              {{ game.visitor_team }}
            </v-list-item-title>
            <template v-slot:append>
              <v-icon size="x-small">mdi-chevron-right</v-icon>
            </template>
          </v-list-item>
        </v-list>
        <div v-else class="pa-4 text-caption text-medium-emphasis">試合データがありません</div>
      </v-card-text>
    </v-card>

    <!-- 成績サマリー -->
    <v-card class="mb-4" elevation="1">
      <v-card-title class="text-h6">成績サマリー</v-card-title>
      <v-card-text>
        <div v-if="summary && summary.team_summary" class="mb-4">
          <div class="text-caption text-medium-emphasis mb-1">チーム成績</div>
          <div class="text-body-2">
            得点 {{ summary.team_summary.runs_scored }} / 失点
            {{ summary.team_summary.runs_allowed }} / 得失点差
            {{ summary.team_summary.runs_scored - summary.team_summary.runs_allowed }}
          </div>
        </div>

        <v-row>
          <!-- 打撃TOP3 -->
          <v-col cols="12" md="6">
            <div class="text-caption text-medium-emphasis mb-1">打撃TOP3（打率順）</div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>選手名</th>
                  <th class="text-right">打率</th>
                  <th class="text-right">安打</th>
                  <th class="text-right">HR</th>
                  <th class="text-right">打点</th>
                </tr>
              </thead>
              <tbody>
                <template v-if="summary">
                  <tr v-for="p in summary.batting_top3" :key="p.player_name">
                    <td>{{ p.player_name }}</td>
                    <td class="text-right">{{ p.batting_average }}</td>
                    <td class="text-right">{{ p.hits }}</td>
                    <td class="text-right">{{ p.hr }}</td>
                    <td class="text-right">{{ p.rbi }}</td>
                  </tr>
                </template>
                <tr v-if="!summary || summary.batting_top3.length === 0">
                  <td colspan="5" class="text-caption text-medium-emphasis">データなし</td>
                </tr>
              </tbody>
            </v-table>
          </v-col>

          <!-- 投手TOP3 -->
          <v-col cols="12" md="6">
            <div class="text-caption text-medium-emphasis mb-1">投手TOP3（防御率順）</div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>選手名</th>
                  <th class="text-right">防御率</th>
                  <th class="text-right">勝</th>
                  <th class="text-right">敗</th>
                  <th class="text-right">奪三振</th>
                </tr>
              </thead>
              <tbody>
                <template v-if="summary">
                  <tr v-for="p in summary.pitching_top3" :key="p.player_name">
                    <td>{{ p.player_name }}</td>
                    <td class="text-right">{{ p.era }}</td>
                    <td class="text-right">{{ p.wins }}</td>
                    <td class="text-right">{{ p.losses }}</td>
                    <td class="text-right">{{ p.strikeouts }}</td>
                  </tr>
                </template>
                <tr v-if="!summary || summary.pitching_top3.length === 0">
                  <td colspan="5" class="text-caption text-medium-emphasis">データなし</td>
                </tr>
              </tbody>
            </v-table>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- お知らせエリア -->
    <v-card elevation="1">
      <v-card-title class="text-h6">お知らせ</v-card-title>
      <v-card-text>
        <span class="text-caption text-medium-emphasis">お知らせはありません</span>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'

interface Competition {
  id: number
  name: string
  competition_type: string
}

interface RecentGame {
  id: number
  real_date: string
  home_team: string
  visitor_team: string
  home_score: number
  visitor_score: number
}

interface BattingTop {
  player_name: string
  batting_average: string
  hits: number
  hr: number
  rbi: number
}

interface PitchingTop {
  player_name: string
  era: string
  wins: number
  losses: number
  strikeouts: number
}

interface TeamSummary {
  team_name: string
  wins: number
  losses: number
  draws: number
  runs_scored: number
  runs_allowed: number
}

interface HomeSummary {
  season_progress: { completed: number; total: number }
  recent_games: RecentGame[]
  batting_top3: BattingTop[]
  pitching_top3: PitchingTop[]
  team_summary: TeamSummary | null
}

const selectedCompetitionId = ref<number | null>(null)
const competitions = ref<Competition[]>([])
const summary = ref<HomeSummary | null>(null)

const progressPercent = computed(() => {
  if (!summary.value) return 0
  const { completed, total } = summary.value.season_progress
  return total > 0 ? Math.round((completed / total) * 100) : 0
})

onMounted(() => {
  fetchCompetitions()
})

async function fetchCompetitions() {
  try {
    const response = await axios.get<Competition[]>('/competitions')
    competitions.value = response.data
    if (competitions.value.length > 0) {
      const lpena = competitions.value.find((c) => c.competition_type === 'league_pennant')
      selectedCompetitionId.value = lpena ? lpena.id : competitions.value[0].id
      fetchSummary()
    }
  } catch (error) {
    console.error('Error fetching competitions:', error)
  }
}

async function fetchSummary() {
  if (selectedCompetitionId.value === null) {
    summary.value = null
    return
  }
  try {
    const response = await axios.get<HomeSummary>('/home/summary', {
      params: { competition_id: selectedCompetitionId.value },
    })
    summary.value = response.data
  } catch (error) {
    console.error('Error fetching home summary:', error)
  }
}
</script>
