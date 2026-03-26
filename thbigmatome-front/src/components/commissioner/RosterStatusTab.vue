<!-- eslint-disable vue/valid-v-slot -->
<template>
  <v-row>
    <v-col cols="12">
      <DataCard title="1軍登録状況">
        <div class="d-flex align-center mb-4">
          <v-btn
            color="primary"
            variant="outlined"
            prepend-icon="mdi-download"
            :href="allCsvUrl"
            :disabled="loading"
          >
            全チームCSV出力
          </v-btn>
        </div>

        <v-data-table
          v-model:expanded="expanded"
          :headers="summaryHeaders"
          :items="rosterStatus"
          :loading="loading"
          density="compact"
          item-value="team_id"
          expand-on-click
          no-data-text="データなし"
        >
          <template #[`item.team_name`]="{ item }">
            <span class="text-primary" style="cursor: pointer">{{ item.team_name }}</span>
          </template>
          <template #[`item.team_type`]="{ item }">
            <v-chip
              v-if="item.team_type === 'hachinai'"
              size="small"
              color="purple"
              variant="tonal"
            >
              ハチナイ
            </v-chip>
            <span v-else class="text-caption text-medium-emphasis">通常</span>
          </template>
          <template #[`item.first_cost`]="{ item }">
            <div class="d-flex align-center gap-2">
              <span>{{ item.first_cost }} / {{ item.first_cost_limit }}</span>
              <StatusChip
                v-if="item.first_cost > item.first_cost_limit"
                status="error"
                label="超過"
              />
            </div>
          </template>
          <template #[`item.outside_world_count`]="{ item }">
            <div class="d-flex align-center gap-2">
              <span>{{ item.outside_world_count }} / {{ item.outside_world_limit }}</span>
              <StatusChip
                v-if="item.outside_world_count > item.outside_world_limit"
                status="error"
                label="超過"
              />
            </div>
          </template>
          <template #[`item.status`]="{ item }">
            <StatusChip
              v-if="item.warnings && item.warnings.length > 0"
              status="warning"
              label="警告あり"
            />
            <StatusChip v-else status="success" label="OK" />
          </template>

          <template #expanded-row="{ item }">
            <tr>
              <td :colspan="summaryHeaders.length + 1" class="pa-0">
                <v-sheet class="pa-4 bg-grey-lighten-5">
                  <div class="d-flex align-center justify-space-between mb-2">
                    <span class="text-subtitle-2 font-weight-bold">
                      {{ item.team_name }} — 1軍選手一覧
                    </span>
                    <v-btn
                      size="small"
                      variant="outlined"
                      prepend-icon="mdi-download"
                      :href="teamCsvUrl(item.team_id)"
                    >
                      CSV出力
                    </v-btn>
                  </div>
                  <v-progress-circular
                    v-if="loadingTeams.has(item.team_id)"
                    indeterminate
                    size="24"
                    class="ma-2"
                  />
                  <v-data-table
                    v-else
                    :headers="detailHeaders"
                    :items="teamDetails.get(item.team_id) || []"
                    density="compact"
                    no-data-text="選手なし"
                    hide-default-footer
                    :items-per-page="-1"
                  >
                    <template #[`item.squad`]="{ item: player }">
                      <v-chip
                        :color="player.squad === 'first' ? 'blue' : 'grey'"
                        size="small"
                        variant="tonal"
                      >
                        {{ player.squad === 'first' ? '1軍' : '2軍' }}
                      </v-chip>
                    </template>
                    <template #[`item.is_outside_world`]="{ item: player }">
                      <v-icon v-if="player.is_outside_world" color="orange" size="small">
                        mdi-earth
                      </v-icon>
                    </template>
                    <template #[`item.absence`]="{ item: player }">
                      <StatusChip
                        v-if="player.is_absent && player.absence_info"
                        :status="player.absence_info.absence_type"
                        :label="absenceLabel(player.absence_info.absence_type)"
                      />
                      <span v-else class="text-caption text-medium-emphasis">—</span>
                    </template>
                    <template #[`item.cooldown_until`]="{ item: player }">
                      <span v-if="player.cooldown_until" class="text-caption">
                        {{ formatDate(player.cooldown_until) }}まで
                      </span>
                      <span v-else class="text-caption text-medium-emphasis">—</span>
                    </template>
                  </v-data-table>
                </v-sheet>
              </td>
            </tr>
          </template>
        </v-data-table>
      </DataCard>
    </v-col>
  </v-row>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import axios from 'axios'
import DataCard from '@/components/shared/DataCard.vue'
import StatusChip from '@/components/shared/StatusChip.vue'
import type { RosterPlayer } from '@/types/rosterPlayer'

interface RosterStatusRecord {
  team_id: number
  team_name: string
  team_type: string
  first_count: number
  second_count: number
  first_cost: number
  first_cost_limit: number
  outside_world_count: number
  outside_world_limit: number
  warnings: string[]
}

const rosterStatus = ref<RosterStatusRecord[]>([])
const loading = ref(false)
const expanded = ref<string[]>([])
const teamDetails = ref<Map<number, RosterPlayer[]>>(new Map())
const loadingTeams = ref<Set<number>>(new Set())

const summaryHeaders = [
  { title: 'チーム名', key: 'team_name' },
  { title: 'タイプ', key: 'team_type', sortable: false },
  { title: '1軍', key: 'first_count' },
  { title: '2軍', key: 'second_count' },
  { title: 'コスト / 上限', key: 'first_cost', sortable: false },
  { title: '外枠 / 上限', key: 'outside_world_count', sortable: false },
  { title: '状態', key: 'status', sortable: false },
]

const detailHeaders = [
  { title: '背番号', key: 'number' },
  { title: '選手名', key: 'player_name' },
  { title: '軍', key: 'squad', sortable: false },
  { title: '投打', key: 'handedness', sortable: false },
  { title: 'ポジション', key: 'position', sortable: false },
  { title: 'コスト', key: 'cost' },
  { title: '外枠', key: 'is_outside_world', sortable: false },
  { title: '離脱', key: 'absence', sortable: false },
  { title: 'CD終了日', key: 'cooldown_until', sortable: false },
]

const absenceLabels: Record<string, string> = {
  injury: '負傷',
  suspension: '出場停止',
  reconditioning: 'リコンディ',
}

const absenceLabel = (type: string) => absenceLabels[type] ?? type

const formatDate = (dateStr: string) =>
  new Date(dateStr).toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric' })

const baseURL = computed(() => axios.defaults.baseURL ?? '/api/v1')

const allCsvUrl = computed(() => `${baseURL.value}/commissioner/dashboard/roster_status.csv`)

const teamCsvUrl = (teamId: number) =>
  `${baseURL.value}/commissioner/dashboard/roster_status.csv?team_id=${teamId}`

const fetchRosterStatus = async () => {
  loading.value = true
  try {
    const response = await axios.get<RosterStatusRecord[]>('/commissioner/dashboard/roster_status')
    rosterStatus.value = response.data
  } catch (error) {
    console.error('Failed to fetch roster status:', error)
  } finally {
    loading.value = false
  }
}

const fetchTeamDetail = async (teamId: number) => {
  if (teamDetails.value.has(teamId) || loadingTeams.value.has(teamId)) return

  const newLoadingSet = new Set(loadingTeams.value)
  newLoadingSet.add(teamId)
  loadingTeams.value = newLoadingSet

  try {
    const response = await axios.get<RosterPlayer[]>(`/teams/${teamId}/roster`)
    const newMap = new Map(teamDetails.value)
    newMap.set(teamId, response.data)
    teamDetails.value = newMap
  } catch (error) {
    console.error(`Failed to fetch roster for team ${teamId}:`, error)
  } finally {
    const newSet = new Set(loadingTeams.value)
    newSet.delete(teamId)
    loadingTeams.value = newSet
  }
}

watch(expanded, (newExpanded, oldExpanded) => {
  const added = newExpanded.filter((id) => !oldExpanded.includes(id))
  added.forEach((teamId) => fetchTeamDetail(Number(teamId)))
})

onMounted(() => {
  fetchRosterStatus()
})
</script>
