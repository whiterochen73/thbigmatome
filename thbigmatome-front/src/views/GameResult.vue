<template>
  <v-container>
    <v-toolbar color="primary" density="compact">
      <template #prepend>
        <span class="text-subtitle-1 font-weight-bold mx-3">{{ gameData.team_name }}</span>
        <v-divider vertical class="mx-2" />
        <span class="text-subtitle-2 mx-2">Game {{ gameData.game_number }}</span>
        <span class="text-subtitle-2 mx-2 text-medium-emphasis">{{ formattedGameDate }}</span>
      </template>
      <v-btn class="mx-1" variant="text" size="small" :to="seasonPortalRoute">
        {{ t('seasonPortal.title') }}
      </v-btn>
      <v-btn :to="scoreSheetRoute" color="info" variant="tonal" size="small" class="mr-2">
        スコアシート
      </v-btn>
      <template #append>
        <v-btn
          @click="saveGame"
          color="success"
          variant="flat"
          size="small"
          prepend-icon="mdi-content-save-outline"
          class="mr-2"
        >
          {{ t('gameResult.save') }}
        </v-btn>
      </template>
    </v-toolbar>

    <v-tabs v-model="activeTab" color="primary" density="compact" class="mt-2">
      <v-tab value="overview">試合概要</v-tab>
      <v-tab value="pitchers">登板記録</v-tab>
    </v-tabs>

    <v-window v-model="activeTab">
      <v-window-item value="overview">
        <v-card class="mt-2" variant="outlined">
          <v-card-title class="text-subtitle-1 py-2 px-4 bg-surface-variant">
            {{ t('gameResult.basicInfo') }}
          </v-card-title>
          <v-card-text class="pt-4">
            <v-row dense>
              <v-col cols="12" sm="6" md="4">
                <TeamMemberSelect
                  v-model="gameData.announced_starter_id"
                  :team-id="gameData.team_id"
                  v-if="gameData.team_id"
                  :label="t('gameResult.announcedStarter')"
                  :starter-eligible="true"
                  clearable
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <TeamSelect
                  v-model="gameData.opponent_team_id"
                  :teams="allTeams"
                  display-name-type="short_name"
                  :label="t('gameResult.opponentTeam')"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-select
                  v-model="gameData.home_away"
                  :items="homeAwayItems"
                  item-title="name"
                  item-value="value"
                  :label="t('gameResult.homeAway.title')"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-text-field v-model="gameData.stadium" :label="t('gameResult.stadium')" />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-select
                  v-model="gameData.designated_hitter_enabled"
                  :items="dhItems"
                  item-title="name"
                  item-value="value"
                  :label="t('gameResult.dhSystem.title')"
                />
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>

        <v-card class="mt-3" variant="outlined">
          <v-card-title class="text-subtitle-1 py-2 px-4 bg-surface-variant">
            {{ t('gameResult.gameInfo') }}
          </v-card-title>
          <v-card-text class="pt-4">
            <v-row dense>
              <v-col cols="6" sm="4" md="3">
                <v-text-field
                  v-model.number="gameData.score"
                  :label="t('gameResult.score')"
                  type="number"
                  min="0"
                  hide-details
                />
              </v-col>
              <v-col cols="6" sm="4" md="3">
                <v-text-field
                  v-model.number="gameData.opponent_score"
                  :label="t('gameResult.opponentScore')"
                  type="number"
                  min="0"
                  hide-details
                />
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-window-item>

      <v-window-item value="pitchers">
        <v-card class="mt-2">
          <v-card-text>
            <PitcherAppearanceTab
              v-if="gameData.team_id"
              :team-id="Number(teamId)"
              :game-date="gameData.game_date"
              :game-result="pitcherGameResult"
              :schedule-id="Number(scheduleId)"
              :announced-starter-id="gameData.announced_starter_id"
              :competition-id="gameData.competition_id ?? null"
            />
          </v-card-text>
        </v-card>
      </v-window-item>
    </v-window>

    <v-snackbar v-model="snackbar" :color="snackbarColor" :timeout="3000">
      {{ snackbarText }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { GameData } from '@/types/gameData'
import type { Team } from '@/types/team'
import TeamMemberSelect from '@/components/shared/TeamMemberSelect.vue'
import TeamSelect from '@/components/shared/TeamSelect.vue'
import PitcherAppearanceTab from '@/components/pitcher/PitcherAppearanceTab.vue'

const { t } = useI18n()
const route = useRoute()
const gameDate = ref(new Date())
const activeTab = ref((route.query.tab as string) || 'overview')

const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('success')

const teamId = route.params.teamId
const scheduleId = route.params.scheduleId

const defaultGameData: GameData = {
  team_id: 0,
  team_name: '',
  season_id: 0,
  game_date: '',
  game_number: 0,
  announced_starter_id: null,
  stadium: '',
  home_away: null,
  designated_hitter_enabled: null,
  opponent_team_id: null,
  opponent_team_name: '',
  score: null,
  opponent_score: null,
  starting_lineup: null,
}

const seasonPortalRoute = computed(() => ({
  name: 'SeasonPortal',
  params: { teamId: teamId },
}))

const scoreSheetRoute = computed(() => ({
  name: 'ScoreSheet',
  params: { teamId: teamId, scheduleId: scheduleId },
}))

const gameData = ref<GameData>(defaultGameData)
const allTeams = ref<Team[]>([])

const homeAwayItems = [
  { name: t('gameResult.homeAway.home'), value: 'home' },
  { name: t('gameResult.homeAway.away'), value: 'visitor' },
]

const dhItems = [
  { name: t('gameResult.dhSystem.enabled'), value: true },
  { name: t('gameResult.dhSystem.disabled'), value: false },
]

const pitcherGameResult = computed<'win' | 'lose' | 'draw'>(() => {
  const myScore = gameData.value.score
  const oppScore = gameData.value.opponent_score
  if (myScore === null || oppScore === null) return 'draw'
  if (myScore === oppScore) return 'draw'
  return myScore > oppScore ? 'win' : 'lose'
})

watch(
  () => gameData.value.opponent_team_id,
  (newOpponentId) => {
    if (newOpponentId) {
      const opponentTeam = allTeams.value.find((team) => team.id === newOpponentId)
      if (opponentTeam) {
        gameData.value.opponent_team_name = opponentTeam.short_name
      }
    } else {
      gameData.value.opponent_team_name = ''
    }
  },
)

const fetchSeason = async () => {
  try {
    const response = await axios.get(`/game/${scheduleId}`)
    gameData.value = response.data
    if (gameData.value) {
      gameDate.value = new Date(gameData.value.game_date)
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error)
  }
}

const fetchAllTeams = async () => {
  try {
    const response = await axios.get('/teams')
    allTeams.value = response.data
  } catch (error) {
    console.error('Failed to fetch teams:', error)
  }
}

const showSnackbar = (text: string, color: string = 'success') => {
  snackbarText.value = text
  snackbarColor.value = color
  snackbar.value = true
}

const saveGame = async () => {
  try {
    await axios.put(`/game/${scheduleId}`, gameData.value)
    showSnackbar(t('gameResult.saveSuccess'))
  } catch (error) {
    console.error('Failed to save game data:', error)
    showSnackbar(t('gameResult.saveFailed'), 'error')
  }
}

const formattedGameDate = computed(() => {
  const date = new Date(gameData.value.game_date)
  const month = date.getMonth() + 1
  const day = date.getDate()
  const weekday = date.toLocaleDateString('ja-JP', { weekday: 'short' })
  return t('gameResult.dateDisplay', { month, day, weekday })
})

onMounted(() => {
  fetchSeason()
  fetchAllTeams()
})
</script>
