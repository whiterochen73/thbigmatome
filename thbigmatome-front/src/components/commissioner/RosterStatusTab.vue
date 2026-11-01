<!-- eslint-disable vue/valid-v-slot -->
<template>
  <AsyncState
    framed
    :loading="loading"
    :error="failed"
    error-message="1軍登録状況の取得に失敗しました"
    :empty="records.length === 0"
    empty-icon="mdi-clipboard-list-outline"
    empty-message="1軍登録状況のデータがありません"
    @retry="emit('retry')"
  >
    <DataCard title="">
      <div class="d-flex align-center mb-4">
        <v-btn
          color="link"
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
        :items="records"
        class="ui-table"
        density="compact"
        item-value="team_id"
        expand-on-click
        no-data-text="データなし"
      >
        <template #[`item.team_name`]="{ item }">
          <span class="text-link" style="cursor: pointer">{{ item.team_name }}</span>
        </template>
        <template #[`item.team_type`]="{ item }">
          <v-chip
            v-if="item.team_type === 'hachinai'"
            size="small"
            color="state-info"
            variant="flat"
            prepend-icon="mdi-tag-outline"
          >
            ハチナイ
          </v-chip>
          <span v-else class="text-caption on-surface-variant">通常</span>
        </template>
        <template #[`item.first_cost`]="{ item }">
          <div class="d-flex align-center gap-2">
            <span>{{ item.first_cost }} / {{ item.first_cost_limit ?? '-' }}</span>
            <v-chip
              v-if="item.first_cost_limit !== null && item.first_cost > item.first_cost_limit"
              color="state-warn"
              variant="flat"
              size="small"
              prepend-icon="mdi-alert-circle"
            >
              超過
            </v-chip>
          </div>
        </template>
        <template #[`item.outside_world_count`]="{ item }">
          <div class="d-flex align-center gap-2">
            <span>{{ item.outside_world_count }} / {{ item.outside_world_limit }}</span>
            <v-chip
              v-if="item.outside_world_count > item.outside_world_limit"
              color="state-warn"
              variant="flat"
              size="small"
              prepend-icon="mdi-alert-circle"
            >
              超過
            </v-chip>
          </div>
        </template>
        <template #[`item.status`]="{ item }">
          <!-- 違反の無い行は何も出さない（「OK」を毎行出すと、違反の行が埋もれる） -->
          <v-chip
            v-if="item.warnings && item.warnings.length > 0"
            color="state-warn"
            variant="flat"
            size="small"
            prepend-icon="mdi-alert-circle"
          >
            警告あり
          </v-chip>
          <span v-else class="status-none text-caption on-surface-variant">—</span>
        </template>

        <template #expanded-row="{ item }">
          <tr>
            <td :colspan="summaryHeaders.length + 1" class="pa-0">
              <v-sheet class="pa-4 bg-surface-variant">
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
                <AsyncState
                  :loading="loadingTeams.has(item.team_id)"
                  :error="failedTeams.has(item.team_id)"
                  error-message="1軍選手一覧の取得に失敗しました"
                  :empty="!teamDetails.has(item.team_id)"
                  @retry="fetchTeamDetail(item.team_id)"
                >
                  <v-data-table
                    :headers="detailHeaders"
                    :items="teamDetails.get(item.team_id) || []"
                    density="compact"
                    no-data-text="選手なし"
                    hide-default-footer
                    :items-per-page="-1"
                  >
                    <template #[`item.squad`]="{ item: player }">
                      <v-chip
                        :color="player.squad === 'first' ? 'zone-game' : 'state-neutral'"
                        size="small"
                        variant="flat"
                        :prepend-icon="
                          player.squad === 'first'
                            ? 'mdi-numeric-1-box-outline'
                            : 'mdi-numeric-2-box-outline'
                        "
                      >
                        {{ player.squad === 'first' ? '1軍' : '2軍' }}
                      </v-chip>
                    </template>
                    <template #[`item.is_outside_world`]="{ item: player }">
                      <v-icon v-if="player.is_outside_world" class="on-state-info" size="small">
                        mdi-earth
                      </v-icon>
                    </template>
                    <template #[`item.absence`]="{ item: player }">
                      <StatusChip
                        v-if="player.is_absent && player.absence_info"
                        :status="player.absence_info.absence_type"
                        :label="absenceLabel(player.absence_info.absence_type)"
                      />
                      <span v-else class="text-caption on-surface-variant">—</span>
                    </template>
                    <template #[`item.cooldown_until`]="{ item: player }">
                      <span v-if="player.cooldown_until" class="text-caption">
                        {{ formatDate(player.cooldown_until) }}まで
                      </span>
                      <span v-else class="text-caption on-surface-variant">—</span>
                    </template>
                  </v-data-table>
                </AsyncState>
              </v-sheet>
            </td>
          </tr>
        </template>
      </v-data-table>
    </DataCard>
  </AsyncState>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import axios from 'axios'
import AsyncState from '@/components/shared/AsyncState.vue'
import DataCard from '@/components/shared/DataCard.vue'
import StatusChip from '@/components/shared/StatusChip.vue'
import type { RosterPlayer } from '@/types/rosterPlayer'
import type { RosterStatusRecord } from '@/types/commissionerDashboard'
import { useColumnMinWidth } from '@/composables/useColumnMinWidth'

// 1軍登録状況の取得は親（ダッシュボード）が持つ。概況の「要確認」と同じ API なので、2 度取らないよう共用する
defineProps<{
  records: RosterStatusRecord[]
  loading: boolean
  failed: boolean
}>()
const emit = defineEmits<{ retry: [] }>()

const expanded = ref<string[]>([])
const teamDetails = ref<Map<number, RosterPlayer[]>>(new Map())
const loadingTeams = ref<Set<number>>(new Set())
const failedTeams = ref<Set<number>>(new Set())

const minW = useColumnMinWidth()
const summaryHeaders = computed(() => [
  // 横に比べる数値の表なので縦積みにせず、スマホでは横スクロール。チームの列は左に固定する
  { title: 'チーム名', key: 'team_name', fixed: true, minWidth: minW(130) },
  { title: 'タイプ', key: 'team_type', sortable: false, minWidth: minW(90) },
  { title: '1軍', key: 'first_count', minWidth: minW(64) },
  { title: '2軍', key: 'second_count', minWidth: minW(64) },
  { title: 'コスト / 上限', key: 'first_cost', sortable: false, minWidth: minW(150) },
  { title: '外枠 / 上限', key: 'outside_world_count', sortable: false, minWidth: minW(130) },
  { title: '状態', key: 'status', sortable: false, minWidth: minW(100) },
])

const detailHeaders = computed(() => [
  { title: '背番号', key: 'number', minWidth: minW(72) },
  { title: '選手名', key: 'player_name', fixed: true, minWidth: minW(130) },
  { title: '軍', key: 'squad', sortable: false, minWidth: minW(80) },
  { title: '投打', key: 'handedness', sortable: false, minWidth: minW(72) },
  { title: 'ポジション', key: 'position', sortable: false, minWidth: minW(100) },
  { title: 'コスト', key: 'cost', minWidth: minW(72) },
  { title: '外枠', key: 'is_outside_world', sortable: false, minWidth: minW(64) },
  { title: '離脱', key: 'absence', sortable: false, minWidth: minW(100) },
  { title: 'CD終了日', key: 'cooldown_until', sortable: false, minWidth: minW(110) },
])

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

const fetchTeamDetail = async (teamId: number) => {
  if (teamDetails.value.has(teamId) || loadingTeams.value.has(teamId)) return

  const newLoadingSet = new Set(loadingTeams.value)
  newLoadingSet.add(teamId)
  loadingTeams.value = newLoadingSet
  const newFailedSet = new Set(failedTeams.value)
  newFailedSet.delete(teamId)
  failedTeams.value = newFailedSet

  try {
    // 応答は { roster: [...] }（cmd_1784 で配列から包みに変わった）。古い形（配列）も受ける
    const response = await axios.get<RosterPlayer[] | { roster: RosterPlayer[] }>(
      `/teams/${teamId}/roster`,
    )
    const players = Array.isArray(response.data) ? response.data : (response.data.roster ?? [])
    const newMap = new Map(teamDetails.value)
    newMap.set(teamId, players)
    teamDetails.value = newMap
  } catch (error) {
    console.error(`Failed to fetch roster for team ${teamId}:`, error)
    failedTeams.value = new Set(failedTeams.value).add(teamId)
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
</script>
