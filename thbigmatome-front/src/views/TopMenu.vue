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
            <div v-if="teams.length > 0">
              <v-select
                v-model="selectedTeam"
                :items="teams"
                item-title="name"
                item-value="id"
                :label="t('topMenu.teamSelection.selectLabel')"
                return-object
              ></v-select>
              <div class="mt-4" v-if="selectedTeam">
                <v-btn color="primary" @click="goToTeamMembers" class="me-4">
                  {{ t('topMenu.teamSelection.registerMembers') }}
                </v-btn>
                <v-btn
                  color="primary"
                  @click="seasonInitializationDialog = true"
                  v-if="!selectedTeam.has_season"
                >
                  {{ t('topMenu.seasonInitialization.title') }}
                </v-btn>
                <v-btn color="secondary" @click="goToSeasonPortal" v-if="selectedTeam.has_season">
                  {{ t('topMenu.seasonPortal.title') }}
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
import { ref, onMounted } from 'vue'
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
const { user } = useAuth()
const router = useRouter()

const managers = ref<Manager[]>([])
const teams = ref<Team[]>([])
const selectedTeam = ref<Team | null>(null)
const manager = ref<Manager | null>(null)
const teamDialog = ref(false)
const seasonInitializationDialog = ref(false)
const schedules = ref<ScheduleList[]>([])

const addTeam = () => {
  teamDialog.value = true
}

const goToTeamMembers = () => {
  if (selectedTeam.value) {
    router.push({ name: 'TeamMembers', params: { teamId: selectedTeam.value.id } })
  }
}

const goToSeasonPortal = () => {
  if (selectedTeam.value) {
    router.push({ name: 'SeasonPortal', params: { teamId: selectedTeam.value.id } })
  }
}

const fetchManagers = async () => {
  try {
    const response = await axios.get('/managers')
    managers.value = response.data
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
  fetchManagers()
}

onMounted(() => {
  fetchManagers()
  fetchSchedules()
})
</script>
