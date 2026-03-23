<template>
  <div>
    <div v-if="loading" class="d-flex justify-center pa-4">
      <v-progress-circular indeterminate color="primary" />
    </div>
    <div v-else-if="changes.length === 0" class="pa-4 text-medium-emphasis">
      {{ t('promotionHistory.noHistory') }}
    </div>
    <v-table v-else density="compact" class="history-table">
      <thead>
        <tr>
          <th class="text-left">{{ t('promotionHistory.headers.date') }}</th>
          <th class="text-left">{{ t('promotionHistory.headers.player') }}</th>
          <th class="text-left">{{ t('promotionHistory.headers.type') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(change, i) in sortedChanges" :key="`${change.player_id}-${change.date}-${i}`">
          <td class="text-caption">{{ change.date }}</td>
          <td>
            <PlayerNameLink :player-id="change.player_id" :player-name="change.player_name" />
          </td>
          <td>
            <v-chip
              size="x-small"
              :color="change.type === 'promote' ? 'primary' : 'blue-grey'"
              variant="tonal"
              :prepend-icon="change.type === 'promote' ? 'mdi-arrow-up' : 'mdi-arrow-down'"
            >
              {{
                change.type === 'promote'
                  ? t('promotionHistory.promote')
                  : t('promotionHistory.demote')
              }}
            </v-chip>
          </td>
        </tr>
      </tbody>
    </v-table>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import PlayerNameLink from '@/components/shared/PlayerNameLink.vue'

interface RosterChange {
  type: 'promote' | 'demote'
  player_id: number
  player_name: string
  number: string
  date: string
}

const props = defineProps<{
  teamId: number
  seasonId: number | null
}>()

const { t } = useI18n()
const loading = ref(false)
const changes = ref<RosterChange[]>([])

const sortedChanges = computed(() => {
  return [...changes.value].sort((a, b) => b.date.localeCompare(a.date))
})

const fetchHistory = async () => {
  if (!props.seasonId) return
  loading.value = true
  try {
    const response = await axios.get(`/teams/${props.teamId}/roster_changes`, {
      params: { season_id: props.seasonId },
    })
    changes.value = response.data.changes
  } catch (error) {
    console.error('Failed to fetch promotion history:', error)
  } finally {
    loading.value = false
  }
}

watch(() => props.seasonId, fetchHistory)
onMounted(fetchHistory)
</script>

<style scoped>
.history-table :deep(td),
.history-table :deep(th) {
  padding: 4px 8px !important;
}
</style>
