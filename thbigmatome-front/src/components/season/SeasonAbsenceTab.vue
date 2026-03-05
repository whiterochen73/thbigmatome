<!-- eslint-disable vue/valid-v-slot -->
<template>
  <div>
    <div class="d-flex justify-end mb-2">
      <v-btn variant="outlined" @click="editAbsence(null)">
        {{ t('playerAbsenceHistory.addAbsence') }}
      </v-btn>
    </div>

    <!-- 現在の離脱者 -->
    <v-card variant="outlined" class="mb-4">
      <v-card-title class="text-subtitle-1">
        <v-icon class="mr-2" size="small">mdi-account-off</v-icon>
        {{ t('seasonAbsenceTab.currentAbsences') }}
      </v-card-title>
      <v-card-text class="pa-0">
        <v-data-table
          :headers="activeHeaders"
          :items="activeAbsences"
          item-key="id"
          density="compact"
          hide-default-footer
          items-per-page="-1"
          :row-props="getRowProps"
        >
          <template v-slot:item.start_date="{ item }">
            {{ formatDate(item.start_date) }}
          </template>
          <template v-slot:item.absence_type="{ item }">
            <v-chip
              :color="getAbsenceColor(item.absence_type)"
              size="small"
              variant="tonal"
              :prepend-icon="getAbsenceIcon(item.absence_type)"
            >
              {{ t(`enums.player_absence.absence_type.${item.absence_type}`) }}
            </v-chip>
          </template>
          <template v-slot:item.remaining="{ item }">
            <template v-if="getRemainingCount(item) !== null">
              <v-chip
                :color="getRemainingCount(item)! <= 2 ? 'green-darken-1' : undefined"
                :variant="getRemainingCount(item)! <= 2 ? 'tonal' : 'text'"
                size="small"
              >
                {{ getRemainingCount(item)
                }}{{ t(`enums.player_absence.duration_unit.${item.duration_unit}`) }}
              </v-chip>
            </template>
            <span v-else class="text-caption text-medium-emphasis">{{
              t('seasonAbsenceTab.unknownRemaining')
            }}</span>
          </template>
          <template v-slot:item.actions="{ item }">
            <v-btn icon size="small" variant="text" @click="editAbsence(item)">
              <v-icon size="small">mdi-pencil</v-icon>
            </v-btn>
            <v-btn icon size="small" variant="text" color="error" @click="deleteAbsence(item)">
              <v-icon size="small">mdi-delete</v-icon>
            </v-btn>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <!-- 過去の離脱履歴（折りたたみ） -->
    <v-expansion-panels variant="accordion">
      <v-expansion-panel>
        <v-expansion-panel-title>
          <v-icon class="mr-2" size="small">mdi-history</v-icon>
          {{ t('seasonAbsenceTab.pastAbsences', { count: pastAbsences.length }) }}
        </v-expansion-panel-title>
        <v-expansion-panel-text class="pa-0">
          <v-data-table
            :headers="pastHeaders"
            :items="pastAbsences"
            density="compact"
            hide-default-footer
            items-per-page="-1"
          >
            <template v-slot:item.start_date="{ item }">
              {{ formatDate(item.start_date) }}
            </template>
            <template v-slot:item.absence_type="{ item }">
              <v-chip :color="getAbsenceColor(item.absence_type)" size="small" variant="tonal">
                {{ t(`enums.player_absence.absence_type.${item.absence_type}`) }}
              </v-chip>
            </template>
            <template v-slot:item.effective_end_date="{ item }">
              {{
                item.effective_end_date
                  ? formatDate(item.effective_end_date)
                  : t('seasonAbsenceTab.unknownEndDate')
              }}
            </template>
            <template v-slot:item.duration="{ item }">
              {{ item.duration }}{{ t(`enums.player_absence.duration_unit.${item.duration_unit}`) }}
            </template>
          </v-data-table>
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>

    <PlayerAbsenceFormDialog
      v-model="isDialogOpen"
      :team-id="teamId"
      :season-id="season?.id || 0"
      :initial-absence="selectedAbsence"
      :initial-start-date="initialStartDateForDialog"
      @saved="handleAbsenceSaved"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { SeasonDetail } from '@/types/seasonDetail'
import type { PlayerAbsence } from '@/types/playerAbsence'
import PlayerAbsenceFormDialog from '@/components/PlayerAbsenceFormDialog.vue'

const props = defineProps<{
  teamId: number
}>()

const { t } = useI18n()

const season = ref<SeasonDetail | null>(null)
const playerAbsences = ref<PlayerAbsence[]>([])
const isDialogOpen = ref(false)
const selectedAbsence = ref<PlayerAbsence | null>(null)

const activeHeaders = computed(() => [
  { title: t('playerAbsenceHistory.tableHeaders.playerName'), key: 'player_name' },
  { title: t('playerAbsenceHistory.tableHeaders.absenceType'), key: 'absence_type' },
  { title: t('playerAbsenceHistory.tableHeaders.reason'), key: 'reason' },
  { title: t('playerAbsenceHistory.tableHeaders.startDate'), key: 'start_date' },
  { title: t('seasonAbsenceTab.headers.remaining'), key: 'remaining', sortable: false },
  { title: t('playerAbsenceHistory.tableHeaders.actions'), key: 'actions', sortable: false },
])

const pastHeaders = computed(() => [
  { title: t('playerAbsenceHistory.tableHeaders.playerName'), key: 'player_name' },
  { title: t('playerAbsenceHistory.tableHeaders.absenceType'), key: 'absence_type' },
  { title: t('playerAbsenceHistory.tableHeaders.reason'), key: 'reason' },
  { title: t('playerAbsenceHistory.tableHeaders.startDate'), key: 'start_date' },
  { title: t('seasonAbsenceTab.headers.returnDate'), key: 'effective_end_date' },
  { title: t('seasonAbsenceTab.headers.duration'), key: 'duration' },
])

const initialStartDateForDialog = computed(() => {
  if (!season.value) return new Date().toISOString().split('T')[0]
  return new Date(season.value?.current_date).toISOString().split('T')[0]
})

const currentSeasonDate = computed(() => {
  return season.value?.current_date ? new Date(season.value.current_date) : new Date()
})

const activeAbsences = computed(() => {
  const now = currentSeasonDate.value
  return playerAbsences.value.filter((a) => {
    if (!a.effective_end_date) return true
    return new Date(a.effective_end_date) >= now
  })
})

const pastAbsences = computed(() => {
  const now = currentSeasonDate.value
  return playerAbsences.value.filter((a) => {
    if (!a.effective_end_date) return false
    return new Date(a.effective_end_date) < now
  })
})

const getRemainingCount = (absence: PlayerAbsence): number | null => {
  if (!absence.effective_end_date) return null
  const endDate = new Date(absence.effective_end_date)
  const diffMs = endDate.getTime() - currentSeasonDate.value.getTime()
  return Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)))
}

const getRowProps = ({ item }: { item: PlayerAbsence }) => {
  const remaining = getRemainingCount(item)
  if (remaining !== null && remaining <= 2) {
    return { class: 'bg-green-lighten-4' }
  }
  return {}
}

const getAbsenceColor = (type: string) => {
  switch (type) {
    case 'injury':
      return 'red'
    case 'suspension':
      return 'orange'
    case 'reconditioning':
      return 'blue-grey'
    default:
      return 'grey'
  }
}

const getAbsenceIcon = (type: string) => {
  switch (type) {
    case 'injury':
      return 'mdi-hospital-box'
    case 'suspension':
      return 'mdi-gavel'
    case 'reconditioning':
      return 'mdi-wrench'
    default:
      return 'mdi-alert'
  }
}

const formatDate = (dateStr: string) => {
  return new Date(dateStr).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
}

const fetchSeason = async () => {
  try {
    const response = await axios.get(`/teams/${props.teamId}/season`)
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
      params: { season_id: season.value.id },
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
