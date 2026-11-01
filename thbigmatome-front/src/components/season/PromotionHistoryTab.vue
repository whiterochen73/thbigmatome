<template>
  <div>
    <AsyncState
      :loading="loading"
      :error="fetchFailed"
      :error-message="t('promotionHistory.fetchFailed')"
      :empty="changes.length === 0"
      empty-icon="mdi-swap-vertical"
      :empty-message="t('promotionHistory.noHistory')"
      @retry="fetchHistory"
    >
      <v-table density="compact" class="history-table">
        <thead>
          <tr>
            <th class="text-left">{{ t('promotionHistory.headers.date') }}</th>
            <th class="text-left">{{ t('promotionHistory.headers.player') }}</th>
            <th class="text-left">{{ t('promotionHistory.headers.type') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(change, i) in sortedChanges" :key="`${change.player_id}-${change.date}-${i}`">
            <td class="text-caption">{{ formatDate(change.date) }}</td>
            <td>
              <PlayerNameLink :player-id="change.player_id" :player-name="change.player_name" />
            </td>
            <td>
              <v-chip
                size="x-small"
                :color="change.type === 'promote' ? 'zone-game' : 'state-neutral'"
                variant="flat"
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
    </AsyncState>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import AsyncState from '@/components/shared/AsyncState.vue'
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

const formatDate = (dateStr: string) => {
  const [, month, day] = dateStr.split('-')
  return `${parseInt(month)}月${parseInt(day)}日`
}
const loading = ref(Boolean(props.seasonId))
const fetchFailed = ref(false)
const changes = ref<RosterChange[]>([])

const sortedChanges = computed(() => {
  return [...changes.value].sort((a, b) => b.date.localeCompare(a.date))
})

const fetchHistory = async () => {
  if (!props.seasonId) return
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get(`/teams/${props.teamId}/roster_changes`, {
      params: { season_id: props.seasonId },
    })
    changes.value = response.data.changes
  } catch (error) {
    console.error('Failed to fetch promotion history:', error)
    fetchFailed.value = true
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
.history-table :deep(tbody tr:nth-child(even)) {
  background-color: rgba(0, 0, 0, 0.04);
}
</style>
