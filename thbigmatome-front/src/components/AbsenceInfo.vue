<template>
  <v-row>
    <v-col>
      <v-alert
        variant="tonal"
        :color="filteredAbsences.length === 0 ? 'primary' : 'error'"
        border-color="error"
        density="compact"
        elevation="2"
      >
        <template #prepend>
          <v-icon>mdi-cancel</v-icon>
        </template>
        <template #title>
          <div class="d-flex justify-space-between align-center">
            <span>{{ t('seasonPortal.absenceInfo') }} ({{ currentDateStr }})</span>
          </div>
        </template>
        <div v-if="filteredAbsences.length > 0">
          <p v-for="absence in filteredAbsences" :key="absence.id" class="mb-0">
            {{ getAbsenceDisplayText(absence) }}
          </p>
        </div>
        <div v-else>
          {{ t('seasonPortal.noAbsenceInfo') }}
        </div>
      </v-alert>
    </v-col>
  </v-row>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, defineProps, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { PlayerAbsence } from '@/types/playerAbsence'
import axios from 'axios'

const playerAbsences = ref<PlayerAbsence[]>([])

const { t } = useI18n()

const props = defineProps<{
  seasonId: number | null
  currentDate: string
}>()

const currentDateStr = computed(() => {
  return new Date(props.currentDate).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
})

const fetchPlayerAbsences = async () => {
  if (!props.seasonId) return
  try {
    const response = await axios.get(`/player_absences`, {
      params: { season_id: props.seasonId },
    })
    playerAbsences.value = response.data
  } catch (error) {
    console.error('Failed to fetch player absences:', error)
  }
}

const filteredAbsences = computed(() => {
  const selected = new Date(props.currentDate)
  selected.setHours(0, 0, 0, 0)

  return playerAbsences.value.filter((absence) => {
    const startDate = new Date(absence.start_date)
    startDate.setHours(0, 0, 0, 0)

    if (absence.duration_unit === 'days') {
      const endDate = new Date(startDate)
      endDate.setDate(startDate.getDate() + absence.duration)
      return selected >= startDate && selected < endDate
    }

    // duration_unit === 'games': バックエンドが算出した effective_end_date を使用
    if (absence.effective_end_date) {
      const endDate = new Date(absence.effective_end_date)
      endDate.setHours(0, 0, 0, 0)
      return selected >= startDate && selected < endDate
    }
    // effective_end_date が null = スケジュール未設定で終了日不明 → 離脱継続中とみなす
    return selected >= startDate
  })
})

const getAbsenceDisplayText = (absence: PlayerAbsence) => {
  const absenceType = t(`enums.player_absence.absence_type.${absence.absence_type}`)
  const durationUnit = t(`enums.player_absence.duration_unit.${absence.duration_unit}`)
  return `【${absenceType}】${absence.player_name}: ${absence.reason} (${new Date(absence.start_date).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })}から${absence.duration}${durationUnit})`
}

watch(
  () => props.seasonId,
  () => {
    fetchPlayerAbsences()
  },
)

onMounted(() => {
  fetchPlayerAbsences()
})

defineExpose({
  fetchPlayerAbsences,
})
</script>
