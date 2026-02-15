<!-- eslint-disable vue/valid-v-slot -->
<template>
  <v-container>
    <v-toolbar color="orange-lighten-3">
      <template #prepend>
        <h1 class="text-h4">{{ t('activeRoster.title') }}</h1>
      </template>
      <v-btn class="mx-2" color="light" variant="flat" :to="seasonPortalRoute">
        {{ t('seasonPortal.title') }}
      </v-btn>
      <v-btn class="mx-2" color="red-darken-4" variant="flat" :to="playerAbsenceRoute">
        {{ t('playerAbsenceHistory.title') }}
      </v-btn>
      <template #append>
        <p class="text-h5">{{ t('seasonPortal.currentDate') }}: {{ currentDateStr }}</p>
      </template>
    </v-toolbar>
    <v-row class="mt-2">
      <v-col cols="12">
        <v-card>
          <v-card-title class="d-flex">
            {{ t('activeRoster.keyPlayerSelection') }}
            <v-spacer></v-spacer>
            <v-btn color="primary" @click="saveKeyPlayer" :disabled="!isSeasonStartDate">
              {{ t('activeRoster.saveKeyPlayer') }}
            </v-btn>
          </v-card-title>
          <v-card-text>
            <v-select
              v-model="selectedKeyPlayerId"
              :items="availableKeyPlayers"
              item-title="player_name"
              item-value="team_membership_id"
              :label="t('activeRoster.selectKeyPlayer')"
              :hint="t('activeRoster.selectKeyPlayerHint')"
              :disabled="!isSeasonStartDate"
              clearable
            ></v-select>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <AbsenceInfo
      :season-id="seasonId"
      :current-date="currentDateFormatted"
      ref="absenceInfo"
      class="mt-2"
    />

    <PromotionCooldownInfo
      :cooldown-players="cooldownPlayers"
      :current-date="currentDateFormatted"
      class="mt-2"
    />

    <v-row class="mt-4">
      <v-col cols="6">
        <v-card>
          <v-card-title>
            <div class="d-flex justify-space-between align-center">
              <h2 class="text-h5">{{ t('activeRoster.firstSquad') }}</h2>
              <div class="text-right">
                <div>
                  <span class="text-h6 mx-4"
                    >{{ t('activeRoster.firstSquadCount') }}: {{ firstSquadPlayers.length }} /
                    29</span
                  >
                  <span class="text-h6"
                    >{{ t('activeRoster.firstSquadCost') }}: {{ firstSquadTotalCost }} / 120</span
                  >
                </div>
                <div>
                  <span
                    v-for="(count, type) in firstSquadPlayerTypeCounts"
                    :key="type"
                    class="text-body-2 mx-2"
                  >
                    {{ type }}: {{ count }}
                  </span>
                </div>
              </div>
            </div>
          </v-card-title>
          <v-card-text>
            <v-data-table
              density="compact"
              :headers="firstHeaders"
              :items="firstSquadPlayers"
              hide-default-footer
              items-per-page="-1"
            >
              <template #item.actions="{ item }">
                <v-btn
                  icon
                  size="small"
                  @click="movePlayer(item, 'second')"
                  :disabled="isPlayerOnCooldown(item)"
                >
                  <v-icon>mdi-arrow-right</v-icon>
                </v-btn>
              </template>
              <template #item.player_types="{ item }">
                <v-chip
                  v-for="player_type in item.player_types"
                  :key="player_type"
                  density="compact"
                  size="small"
                >
                  {{ player_type }}
                </v-chip>
              </template>
              <template #item.position="{ item }">
                {{ t(`baseball.shortPositions.${item.position}`) }}
              </template>
              <template #item.throwing_hand="{ item }">
                {{ t(`baseball.throwingHands.${item.throwing_hand}`) }}
              </template>
              <template #item.batting_hand="{ item }">
                {{ t(`baseball.battingHands.${item.batting_hand}`) }}
              </template>
              <template #item.selected_cost_type="{ item }">
                {{ t(`baseball.construction.${item.selected_cost_type}`) }}
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="6">
        <v-card>
          <v-card-title>
            <h2 class="text-h5">{{ t('activeRoster.secondSquad') }}</h2>
          </v-card-title>
          <v-card-text>
            <v-data-table
              density="compact"
              :headers="secondHeaders"
              :items="secondSquadPlayers"
              hide-default-footer
              items-per-page="-1"
            >
              <template #item.actions="{ item }">
                <v-btn
                  icon
                  size="small"
                  @click="movePlayer(item, 'first')"
                  :disabled="isPlayerOnCooldown(item)"
                >
                  <v-icon>mdi-arrow-left</v-icon>
                </v-btn>
              </template>
              <template #item.player_types="{ item }">
                <v-chip
                  v-for="player_type in item.player_types"
                  :key="player_type"
                  density="compact"
                  size="small"
                >
                  {{ player_type }}
                </v-chip>
              </template>
              <template #item.position="{ item }">
                {{ t(`baseball.shortPositions.${item.position}`) }}
              </template>
              <template #item.throwing_hand="{ item }">
                {{ t(`baseball.throwingHands.${item.throwing_hand}`) }}
              </template>
              <template #item.batting_hand="{ item }">
                {{ t(`baseball.battingHands.${item.batting_hand}`) }}
              </template>
              <template #item.selected_cost_type="{ item }">
                {{ t(`baseball.construction.${item.selected_cost_type}`) }}
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-4">
      <v-col>
        <v-btn color="primary" @click="saveRoster">{{ t('activeRoster.saveRoster') }}</v-btn>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import AbsenceInfo from '@/components/AbsenceInfo.vue'
import PromotionCooldownInfo from '@/components/PromotionCooldownInfo.vue'
import type { RosterPlayer } from '@/types/rosterPlayer'

const { t } = useI18n()
const route = useRoute()
const teamId = route.params.teamId
const seasonId = ref<number | null>(null)
const rosterPlayers = ref<RosterPlayer[]>([])
const currentDate = ref(new Date())
const currentDateStr = computed(() => {
  return currentDate.value.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
})

const currentDateFormatted = computed(() => currentDate.value.toISOString().split('T')[0])

const seasonPortalRoute = computed(() => {
  return {
    name: 'SeasonPortal',
    params: {
      teamId: teamId,
    },
  }
})

const playerAbsenceRoute = computed(() => {
  return {
    name: 'PlayerAbsenceHistory',
    params: {
      teamId: teamId,
    },
  }
})

const seasonStartDate = ref<Date | null>(null)
const selectedKeyPlayerId = ref<number | null>(null)

const headers = [
  { title: t('activeRoster.headers.number'), key: 'number' },
  { title: t('activeRoster.headers.name'), key: 'player_name' },
  { title: t('activeRoster.headers.player_types'), key: 'player_types' },
  { title: t('activeRoster.headers.position'), key: 'position' },
  { title: t('activeRoster.headers.throws'), key: 'throwing_hand' },
  { title: t('activeRoster.headers.bats'), key: 'batting_hand' },
  { title: t('activeRoster.headers.cost_type'), value: 'selected_cost_type' },
  { title: t('activeRoster.headers.cost'), key: 'cost' },
]
const firstHeaders = [
  ...headers,
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
]

const secondHeaders = [
  { title: t('activeRoster.headers.actions'), sortable: false, key: 'actions' },
  ...headers,
]

const fetchRoster = async () => {
  try {
    const response = await axios.get(`/teams/${teamId}/roster`)
    rosterPlayers.value = response.data.roster
    console.log('Fetched roster:', rosterPlayers.value)
    seasonId.value = response.data.season_id
    if (response.data.current_date) {
      currentDate.value = new Date(response.data.current_date)
    }
    if (response.data.season_start_date) {
      seasonStartDate.value = new Date(response.data.season_start_date)
    }
    if (response.data.key_player_id) {
      selectedKeyPlayerId.value = response.data.key_player_id
    }
  } catch (error) {
    console.error('Failed to fetch roster:', error)
  }
}

const firstSquadPlayers = computed(() => {
  return rosterPlayers.value.filter((p) => p.squad === 'first')
})

const secondSquadPlayers = computed(() => {
  return rosterPlayers.value.filter((p) => p.squad === 'second')
})

const cooldownPlayers = computed(() => {
  const now = currentDate.value
  return rosterPlayers.value.filter((p) => {
    if (p.cooldown_until) {
      const cooldownDate = new Date(p.cooldown_until)
      return now < cooldownDate
    }
    return false
  })
})

const firstSquadTotalCost = computed(() => {
  return firstSquadPlayers.value.reduce((sum, player) => sum + player.cost, 0)
})

const firstSquadPlayerTypeCounts = computed(() => {
  const counts: { [key: string]: number } = {}
  firstSquadPlayers.value.forEach((player) => {
    player.player_types.forEach((type) => {
      counts[type] = (counts[type] || 0) + 1
    })
  })
  return counts
})

const isSeasonStartDate = computed(() => {
  if (!seasonStartDate.value) return false
  return currentDate.value.toDateString() === seasonStartDate.value.toDateString()
})

const availableKeyPlayers = computed(() => {
  return firstSquadPlayers.value // All first squad players are potential key players
})

const movePlayer = (player: RosterPlayer, targetSquad: 'first' | 'second') => {
  const index = rosterPlayers.value.findIndex(
    (p) => p.team_membership_id === player.team_membership_id,
  )
  if (index !== -1) {
    rosterPlayers.value[index].squad = targetSquad
  }
}

const isPlayerOnCooldown = (player: RosterPlayer) => {
  if (player.cooldown_until) {
    if (player.same_day_exempt) return false // Same-day promotion+demotion: no cooldown enforcement
    const cooldownDate = new Date(player.cooldown_until)
    return currentDate.value < cooldownDate
  }
  return false
}

const saveRoster = async () => {
  try {
    const updates = rosterPlayers.value.map((player) => ({
      team_membership_id: player.team_membership_id,
      squad: player.squad,
    }))
    await axios.post(`/teams/${teamId}/roster`, {
      roster_updates: updates,
      target_date: currentDate.value.toISOString().split('T')[0],
    })
    alert(t('activeRoster.saveSuccess'))
    fetchRoster() // Re-fetch to update cooldowns and status
  } catch (error: unknown) {
    console.error('Failed to save roster:', error)
    const axiosError = error as { response?: { data?: { error?: string } }; message?: string }
    alert(
      `${t('activeRoster.saveFailed')}: ${axiosError.response?.data?.error || axiosError.message}`,
    )
  }
}

const saveKeyPlayer = async () => {
  try {
    await axios.post(`/teams/${teamId}/key_player`, {
      key_player_id: selectedKeyPlayerId.value,
    })
    alert(t('activeRoster.keyPlayerSaveSuccess'))
  } catch (error: unknown) {
    console.error('Failed to save key player:', error)
    const axiosError = error as { response?: { data?: { error?: string } }; message?: string }
    alert(
      `${t('activeRoster.keyPlayerSaveFailed')}: ${axiosError.response?.data?.error || axiosError.message}`,
    )
  }
}

onMounted(fetchRoster)
</script>
