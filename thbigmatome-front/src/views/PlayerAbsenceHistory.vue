<template>
  <v-container>

    <v-toolbar
      color="orange-lighten-3"
    >
      <template #prepend>
        <h1 class="text-h4">{{ t('playerAbsenceHistory.title') }}</h1>
      </template>
      <v-btn
        class="mx-2"
        color="light"
        variant="flat"
        :to="seasonPortalRoute"
      >
        {{ t('seasonPortal.title') }}
      </v-btn>
      <v-btn
        color="orange-darken-3"
        variant="flat"
        @click="editAbsence(null)"
      >
        {{ t('playerAbsenceHistory.addAbsence') }}
      </v-btn>
      <template #append>
      </template>
    </v-toolbar>

    <v-card>
      <v-card-text>
        <v-data-table
          :headers="headers"
          :items="playerAbsences"
          item-key="id"
          class="elevation-1"
        >
          <template v-slot:item.start_date="{ item }">
            {{ new Date(item.start_date).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' }) }}
          </template>
          <template v-slot:item.absence_type="{ item }">
            {{ t(`enums.player_absence.absence_type.${item.absence_type}`) }}
          </template>
          <template v-slot:item.duration_unit="{ item }">
            {{ t(`enums.player_absence.duration_unit.${item.duration_unit}`) }}
          </template>
          <template v-slot:item.actions="{ item }">
            <v-icon
              small
              class="mr-2"
              @click="editAbsence(item)"
            >
              mdi-pencil
            </v-icon>
            <v-icon
              small
              @click="deleteAbsence(item)"
            >
              mdi-delete
            </v-icon>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <PlayerAbsenceFormDialog
      v-model="isDialogOpen"
      :team-id="teamId"
      :season-id="season?.id || 0"
      :initial-absence="selectedAbsence"
      :initial-start-date="initialStartDateForDialog"
      @saved="handleAbsenceSaved"
    />
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { SeasonDetail } from '@/types/seasonDetail'
import type { PlayerAbsence } from '@/types/playerAbsence'
import PlayerAbsenceFormDialog from '@/components/PlayerAbsenceFormDialog.vue'

const { t } = useI18n()
const route = useRoute()

const teamId = parseInt(<string>route.params.teamId, 10)
const season = ref<SeasonDetail | null>(null)
const playerAbsences = ref<PlayerAbsence[]>([])
const isDialogOpen = ref(false)
const selectedAbsence = ref<PlayerAbsence | null>(null)

const seasonPortalRoute = computed(() => {
  return {
    name: 'SeasonPortal',
    params: {
      teamId: teamId
    }
  };
});

const headers = computed(() => [
  { title: t('playerAbsenceHistory.tableHeaders.startDate'), key: 'start_date' },
  { title: t('playerAbsenceHistory.tableHeaders.playerName'), key: 'player_name' },
  { title: t('playerAbsenceHistory.tableHeaders.absenceType'), key: 'absence_type' },
  { title: t('playerAbsenceHistory.tableHeaders.reason'), key: 'reason' },
  { title: t('playerAbsenceHistory.tableHeaders.duration'), key: 'duration' },
  { title: t('playerAbsenceHistory.tableHeaders.durationUnit'), key: 'duration_unit' },
  { title: t('playerAbsenceHistory.tableHeaders.actions'), key: 'actions', sortable: false },
])

const initialStartDateForDialog = computed(() => {
  if (!season.value) return new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
  return new Date(season.value?.current_date).toISOString().split('T')[0]; // YYYY-MM-DD format
});

const fetchSeason = async () => {
  try {
    const response = await axios.get(`/teams/${teamId}/season`)
    season.value = response.data
    if (season.value) {
      await fetchPlayerAbsences()
    }
  } catch (error) {
    console.error('Failed to fetch season data:', error)
  }
}

const fetchPlayerAbsences = async () => {
  if (!season.value) return
  try {
    const response = await axios.get(`/player_absences`, {
      params: { season_id: season.value.id }
    })
    playerAbsences.value = response.data
  } catch (error) {
    console.error('Failed to fetch player absences:', error)
  }
}

const handleAbsenceSaved = () => {
  isDialogOpen.value = false
  selectedAbsence.value = null
  fetchPlayerAbsences()
}

const editAbsence = (absence: PlayerAbsence | null) => {
  selectedAbsence.value = absence
  isDialogOpen.value = true
}

const deleteAbsence = async (absence: PlayerAbsence) => {
  if (confirm(t('playerAbsenceHistory.confirmDelete', { playerName: absence.player_name }))) {
    try {
      await axios.delete(`/player_absences/${absence.id}`)
      fetchPlayerAbsences()
    } catch (error) {
      console.error('Failed to delete player absence:', error)
    }
  }
}

onMounted(() => {
  fetchSeason()
})
</script>

<style scoped>
/* Add any specific styles for this component here */
</style>