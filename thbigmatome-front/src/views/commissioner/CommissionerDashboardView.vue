<!-- eslint-disable vue/valid-v-slot -->
<template>
  <v-container>
    <PageHeader title="ダッシュボード" />

    <v-row>
      <v-col cols="12">
        <DataCard title="離脱者一覧">
          <FilterBar>
            <template #search>
              <v-text-field
                v-model="searchQuery"
                label="選手名検索"
                prepend-inner-icon="mdi-magnify"
                variant="outlined"
                density="compact"
                clearable
                hide-details
              />
            </template>
            <template #filters>
              <v-select
                v-model="selectedAbsenceType"
                :items="absenceTypeOptions"
                label="離脱種別"
                variant="outlined"
                density="compact"
                clearable
                hide-details
              />
            </template>
          </FilterBar>

          <v-data-table
            :headers="headers"
            :items="filteredAbsences"
            :loading="loading"
            density="compact"
            :row-props="getRowProps"
          >
            <template v-slot:item.absence_type="{ item }">
              <StatusChip
                :status="item.absence_type"
                :label="absenceTypeLabel(item.absence_type)"
              />
            </template>
            <template v-slot:item.start_date="{ item }">
              {{ formatDate(item.start_date) }}
            </template>
            <template v-slot:item.effective_end_date="{ item }">
              {{ item.effective_end_date ? formatDate(item.effective_end_date) : '不明' }}
            </template>
            <template v-slot:item.remaining="{ item }">
              <template v-if="getRemainingDisplay(item) !== null">
                <v-chip
                  :color="
                    getRemainingCount(item) !== null && getRemainingCount(item)! <= 2
                      ? 'green-darken-1'
                      : undefined
                  "
                  :variant="
                    getRemainingCount(item) !== null && getRemainingCount(item)! <= 2
                      ? 'tonal'
                      : 'text'
                  "
                  size="small"
                >
                  {{ getRemainingDisplay(item) }}
                </v-chip>
              </template>
              <span v-else class="text-caption text-medium-emphasis">不明</span>
            </template>
          </v-data-table>
        </DataCard>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import PageHeader from '@/components/shared/PageHeader.vue'
import DataCard from '@/components/shared/DataCard.vue'
import FilterBar from '@/components/shared/FilterBar.vue'
import StatusChip from '@/components/shared/StatusChip.vue'

interface AbsenceRecord {
  id: number
  team_name: string
  team_id: number
  player_name: string
  player_id: number
  absence_type: string
  reason: string | null
  start_date: string
  duration: number
  duration_unit: string
  effective_end_date: string | null
  remaining_days: number | null
  remaining_games: number | null
  season_current_date: string
}

const absences = ref<AbsenceRecord[]>([])
const loading = ref(false)
const searchQuery = ref('')
const selectedAbsenceType = ref<string | null>(null)

const absenceTypeOptions = [
  { title: '負傷', value: 'injury' },
  { title: '出場停止', value: 'suspension' },
  { title: 'リコンディショニング', value: 'reconditioning' },
]

const absenceTypeLabels: Record<string, string> = {
  injury: '負傷',
  suspension: '出場停止',
  reconditioning: 'リコンディショニング',
}

const headers = [
  { title: 'チーム', key: 'team_name' },
  { title: '選手名', key: 'player_name' },
  { title: '離脱種別', key: 'absence_type' },
  { title: '理由', key: 'reason' },
  { title: '開始日', key: 'start_date' },
  { title: '復帰予定日', key: 'effective_end_date' },
  { title: '残り', key: 'remaining', sortable: false },
]

const filteredAbsences = computed(() => {
  return absences.value.filter((a) => {
    if (selectedAbsenceType.value && a.absence_type !== selectedAbsenceType.value) return false
    if (searchQuery.value && !a.player_name.includes(searchQuery.value)) return false
    return true
  })
})

const absenceTypeLabel = (type: string) => absenceTypeLabels[type] ?? type

const formatDate = (dateStr: string) => {
  return new Date(dateStr).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric' })
}

const getRemainingCount = (absence: AbsenceRecord): number | null => {
  if (absence.duration_unit === 'days') return absence.remaining_days
  return absence.remaining_games
}

const getRemainingDisplay = (absence: AbsenceRecord): string | null => {
  const count = getRemainingCount(absence)
  if (count === null) return null
  const unit = absence.duration_unit === 'days' ? '日' : '試合'
  return `${count}${unit}`
}

const getRowProps = ({ item }: { item: AbsenceRecord }) => {
  const count = getRemainingCount(item)
  if (count !== null && count <= 2) {
    return { class: 'bg-green-lighten-4' }
  }
  return {}
}

const fetchAbsences = async () => {
  loading.value = true
  try {
    const response = await axios.get('/commissioner/dashboard/absences')
    absences.value = response.data
  } catch (error) {
    console.error('Failed to fetch absences:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchAbsences()
})
</script>
