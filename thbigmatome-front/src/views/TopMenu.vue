<template>
  <v-container>
    <v-row justify="center">
      <v-col cols="12" md="8">
        <v-card>
          <v-card-item>
            <v-card-title class="text-h5">{{ t('topMenu.welcome.title') }}</v-card-title>
            <v-card-subtitle>{{ t('topMenu.welcome.subtitle') }}</v-card-subtitle>
          </v-card-item>
          <v-card-text>
            <p>{{ t('topMenu.welcome.message') }}</p>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
    <v-row justify="center" class="mt-4">
      <v-col cols="12" md="8">
        <v-card>
          <v-card-item>
            <v-card-title>{{ t('topMenu.teamSelection.title') }}</v-card-title>
            <v-card-subtitle v-if="manager">{{
              t('topMenu.teamSelection.managerName', { name: manager.name })
            }}</v-card-subtitle>
          </v-card-item>
          <v-card-text>
            <v-switch
              v-if="isCommissioner"
              v-model="commissionerMode"
              :label="t('topMenu.commissionerMode.switchLabel')"
              color="primary"
              hide-details
              class="mb-4"
              density="compact"
            >
              <template #prepend>
                <v-icon icon="mdi-shield-crown"></v-icon>
              </template>
            </v-switch>
            <v-btn
              v-if="isCommissioner"
              color="primary"
              variant="elevated"
              class="mb-4"
              prepend-icon="mdi-shield-crown"
              @click="goToCommissionerLeagues"
            >
              {{ t('topMenu.commissionerMode.button') }}
            </v-btn>
            <div v-if="displayedTeams.length > 0">
              <div class="d-flex flex-wrap ga-2">
                <v-btn
                  v-for="team in displayedTeams"
                  :key="team.id"
                  :color="selectedTeam?.id === team.id ? 'primary' : undefined"
                  :variant="selectedTeam?.id === team.id ? 'flat' : 'outlined'"
                  @click="selectTeam(team)"
                >
                  {{ team.name }}
                </v-btn>
              </div>
            </div>
            <div v-else>
              <p>{{ t('topMenu.teamSelection.noTeams') }}</p>
              <v-btn color="primary" @click="addTeam" class="mt-4">{{
                t('topMenu.teamSelection.addTeam')
              }}</v-btn>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
    <TeamDialog
      v-model:isVisible="teamDialog"
      :team="null"
      :default-manager-id="manager?.id"
      @save="handleSave"
    />
    <SeasonInitializationDialog
      v-model:isVisible="seasonInitializationDialog"
      :schedules="schedules"
      :selected-team="selectedTeam"
      @save="handleSeasonSave"
    />
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuth } from '@/composables/useAuth'
import axios from 'axios'
import type { Manager } from '@/types/manager'
import type { Team } from '@/types/team'
import type { ScheduleList } from '@/types/scheduleList'
import TeamDialog from '@/components/TeamDialog.vue'
import SeasonInitializationDialog from '@/components/SeasonInitializationDialog.vue'
import { useRouter } from 'vue-router'

const { t } = useI18n()
const { user, isCommissioner } = useAuth()
const router = useRouter()

const managers = ref<Manager[]>([])
const teams = ref<Team[]>([])
const allTeams = ref<Team[]>([])
const selectedTeam = ref<Team | null>(null)
const manager = ref<Manager | null>(null)
const teamDialog = ref(false)
const seasonInitializationDialog = ref(false)
const schedules = ref<ScheduleList[]>([])
const commissionerMode = ref(localStorage.getItem('commissionerMode') === 'on')

const displayedTeams = computed(() => {
  return commissionerMode.value ? allTeams.value : teams.value
})

const selectTeam = (team: Team) => {
  selectedTeam.value = team
  localStorage.setItem('selectedTeamId', String(team.id))
  if (team.has_season) {
    router.push({ name: 'SeasonPortal', params: { teamId: team.id } })
  } else {
    seasonInitializationDialog.value = true
  }
}

const goToCommissionerLeagues = () => {
  router.push({ name: 'Leagues' })
}

const restoreSelectedTeam = () => {
  const savedId = localStorage.getItem('selectedTeamId')
  if (savedId) {
    const found = displayedTeams.value.find((t) => t.id === Number(savedId))
    if (found) {
      selectedTeam.value = found
      return
    }
  }
  if (displayedTeams.value.length > 0) {
    selectedTeam.value = displayedTeams.value[0]
  } else {
    selectedTeam.value = null
  }
}

watch(commissionerMode, async (newVal) => {
  localStorage.setItem('commissionerMode', newVal ? 'on' : 'off')
  if (newVal) {
    await fetchAllTeams()
  }
  restoreSelectedTeam()
})

const addTeam = () => {
  teamDialog.value = true
}

const fetchManagers = async () => {
  try {
    // NOTE: /managers はページネーション形式 { data: [...], meta: {...} } を返す
    // このロジックを変更する際はトップ画面のチーム選択表示に影響しないか確認すること
    const response = await axios.get('/managers', { params: { per_page: 100 } })
    managers.value = response.data.data
    if (user.value) {
      manager.value = managers.value.find((m) => m.user_id == user.value?.id) || null
      if (manager.value) {
        teams.value = manager.value.teams || []
      }
    }
  } catch (error) {
    console.error('Failed to fetch managers:', error)
  }
}

const fetchAllTeams = async () => {
  try {
    const response = await axios.get('/teams')
    allTeams.value = response.data
  } catch (error) {
    console.error('Failed to fetch all teams:', error)
  }
}

const fetchSchedules = async () => {
  try {
    const response = await axios.get('/schedules')
    schedules.value = response.data
  } catch (error) {
    console.error('Failed to fetch schedules:', error)
  }
}

const handleSave = () => {
  fetchManagers()
  teamDialog.value = false
}

const handleSeasonSave = () => {
  seasonInitializationDialog.value = false
  if (selectedTeam.value) {
    router.push({ name: 'SeasonPortal', params: { teamId: selectedTeam.value.id } })
  }
}

onMounted(async () => {
  await fetchManagers()
  fetchSchedules()
  if (commissionerMode.value && isCommissioner.value) {
    await fetchAllTeams()
  }
  restoreSelectedTeam()
})
</script>
