<!-- eslint-disable vue/valid-v-slot -->
<template>
  <v-tabs v-model="activeTab" color="primary" class="mb-4">
    <v-tab value="teams">全チーム管理</v-tab>
    <v-tab value="absences">離脱者一覧</v-tab>
    <v-tab value="costs">コスト状況</v-tab>
    <v-tab value="cooldowns">クールダウン</v-tab>
    <v-tab value="rosterStatus">1軍登録状況</v-tab>
  </v-tabs>

  <v-window v-model="activeTab">
    <!-- 全チーム管理タブ -->
    <v-window-item value="teams">
      <v-row>
        <v-col cols="12">
          <DataCard title="全チーム管理">
            <v-data-table
              :headers="teamHeaders"
              :items="teams"
              :loading="teamsLoading"
              density="compact"
              item-value="id"
              no-data-text="チームなし"
              :row-props="
                (row: { item: Team }) =>
                  row.item.is_active ? {} : { class: 'text-medium-emphasis' }
              "
            >
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
              <template #[`item.is_active`]="{ item }">
                <v-icon v-if="item.is_active">mdi-check</v-icon>
              </template>
              <template #[`item.manager_name`]="{ item }">
                {{ item.director?.name || '-' }}
              </template>
              <template #[`item.actions`]="{ item }">
                <v-tooltip text="シーズンポータル" location="top">
                  <template #activator="{ props }">
                    <v-icon
                      v-bind="props"
                      size="small"
                      class="mr-2"
                      @click="navigateToSeason(item)"
                    >
                      mdi-calendar-star
                    </v-icon>
                  </template>
                </v-tooltip>
                <v-tooltip text="メンバー編集" location="top">
                  <template #activator="{ props }">
                    <v-icon
                      v-bind="props"
                      size="small"
                      class="mr-2"
                      @click="navigateToMembers(item.id)"
                    >
                      mdi-account-group
                    </v-icon>
                  </template>
                </v-tooltip>
                <v-tooltip text="チーム編集" location="top">
                  <template #activator="{ props }">
                    <v-icon v-bind="props" size="small" class="mr-2" @click="openTeamDialog(item)">
                      mdi-pencil
                    </v-icon>
                  </template>
                </v-tooltip>
                <v-tooltip text="削除" location="top">
                  <template #activator="{ props }">
                    <v-icon v-bind="props" size="small" @click="deleteTeam(item.id)"
                      >mdi-delete</v-icon
                    >
                  </template>
                </v-tooltip>
              </template>
            </v-data-table>
          </DataCard>
        </v-col>
      </v-row>
    </v-window-item>

    <!-- 離脱者一覧タブ -->
    <v-window-item value="absences">
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
              :headers="absenceHeaders"
              :items="filteredAbsences"
              :loading="absencesLoading"
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
    </v-window-item>

    <!-- クールダウンタブ -->
    <v-window-item value="cooldowns">
      <v-row>
        <v-col cols="12">
          <DataCard title="クールダウン中選手">
            <FilterBar>
              <template #search>
                <v-text-field
                  v-model="cooldownSearchQuery"
                  label="選手名検索"
                  prepend-inner-icon="mdi-magnify"
                  variant="outlined"
                  density="compact"
                  clearable
                  hide-details
                />
              </template>
            </FilterBar>

            <v-data-table
              :headers="cooldownHeaders"
              :items="filteredCooldowns"
              :loading="cooldownsLoading"
              density="compact"
            >
              <template v-slot:item.demotion_date="{ item }">
                {{ formatDate(item.demotion_date) }}
              </template>
              <template v-slot:item.cooldown_until="{ item }">
                {{ formatDate(item.cooldown_until) }}
              </template>
              <template v-slot:item.remaining_days="{ item }">
                <v-chip
                  :color="item.remaining_days <= 2 ? 'green-darken-1' : undefined"
                  :variant="item.remaining_days <= 2 ? 'tonal' : 'text'"
                  size="small"
                >
                  {{ item.remaining_days }}日
                </v-chip>
              </template>
              <template v-slot:item.same_day_exempt="{ item }">
                <v-chip v-if="item.same_day_exempt" color="grey" variant="tonal" size="small">
                  同日免除
                </v-chip>
              </template>
            </v-data-table>
          </DataCard>
        </v-col>
      </v-row>
    </v-window-item>

    <!-- コスト使用状況タブ -->
    <v-window-item value="costs">
      <v-row>
        <v-col cols="12">
          <DataCard title="チーム別コスト使用状況">
            <v-data-table
              :headers="costHeaders"
              :items="costs"
              :loading="costsLoading"
              density="compact"
            >
              <template v-slot:item.team_type="{ item }">
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
              <template v-slot:item.total_cost="{ item }">
                <div class="d-flex align-center gap-2 flex-nowrap">
                  <span style="white-space: nowrap"
                    >{{ item.total_cost }} / {{ item.total_cost_limit }}</span
                  >
                  <v-progress-linear
                    :model-value="item.cost_usage_ratio * 100"
                    :color="getCostColor(item.cost_usage_ratio)"
                    height="8"
                    rounded
                    style="min-width: 80px; max-width: 120px"
                  />
                  <StatusChip v-if="item.cost_usage_ratio > 1.0" status="error" label="超過" />
                  <StatusChip
                    v-else-if="item.cost_usage_ratio > 0.9"
                    status="warning"
                    label="警告"
                  />
                </div>
              </template>
              <template v-slot:item.first_squad_cost="{ item }">
                <div class="d-flex align-center gap-2 flex-nowrap">
                  <span v-if="item.first_squad_cost_limit !== null" style="white-space: nowrap">
                    {{ item.first_squad_cost }} / {{ item.first_squad_cost_limit }}
                  </span>
                  <span v-else style="white-space: nowrap"> {{ item.first_squad_cost }} / — </span>
                  <v-progress-linear
                    v-if="item.first_squad_cost_limit"
                    :model-value="(item.first_squad_cost / item.first_squad_cost_limit) * 100"
                    :color="getCostColor(item.first_squad_cost / item.first_squad_cost_limit)"
                    height="8"
                    rounded
                    style="min-width: 80px; max-width: 120px"
                  />
                </div>
              </template>
            </v-data-table>
          </DataCard>
        </v-col>
      </v-row>
    </v-window-item>

    <!-- 1軍登録状況タブ -->
    <v-window-item value="rosterStatus">
      <RosterStatusTab />
    </v-window-item>
  </v-window>

  <TeamDialog v-model:isVisible="dialogVisible" :team="editingTeam" @save="fetchTeams" />
  <ConfirmDialog ref="confirmDialog" />
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import DataCard from '@/components/shared/DataCard.vue'
import FilterBar from '@/components/shared/FilterBar.vue'
import StatusChip from '@/components/shared/StatusChip.vue'
import TeamDialog from '@/components/TeamDialog.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import RosterStatusTab from '@/components/commissioner/RosterStatusTab.vue'
import { useSnackbar } from '@/composables/useSnackbar'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { type Team } from '@/types/team'

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

interface CostRecord {
  team_id: number
  team_name: string
  team_type: string
  total_cost: number
  total_cost_limit: number
  first_squad_cost: number
  first_squad_cost_limit: number | null
  first_squad_count: number
  exempt_count: number
  cost_usage_ratio: number
}

interface CooldownRecord {
  team_id: number
  team_name: string
  player_id: number
  player_name: string
  demotion_date: string
  cooldown_until: string
  remaining_days: number
  same_day_exempt: boolean
}

const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()
const { showSnackbar } = useSnackbar()

const activeTab = ref('teams')

// 全チーム管理
const teams = ref<Team[]>([])
const teamsLoading = ref(false)
const dialogVisible = ref(false)
const editingTeam = ref<Team | null>(null)
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)

const teamHeaders = [
  { title: 'ID', key: 'id' },
  { title: 'チーム名', key: 'name' },
  { title: '略称', key: 'short_name' },
  { title: '種別', key: 'team_type', sortable: false },
  { title: '監督', key: 'manager_name', sortable: false },
  { title: 'アクティブ', key: 'is_active', sortable: false },
  { title: '操作', key: 'actions', sortable: false },
]

// 離脱者
const absences = ref<AbsenceRecord[]>([])
const absencesLoading = ref(false)
const searchQuery = ref('')
const selectedAbsenceType = ref<string | null>(null)

// コスト
const costs = ref<CostRecord[]>([])
const costsLoading = ref(false)

// クールダウン
const cooldowns = ref<CooldownRecord[]>([])
const cooldownsLoading = ref(false)
const cooldownSearchQuery = ref('')

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

const absenceHeaders = [
  { title: 'チーム', key: 'team_name' },
  { title: '選手名', key: 'player_name' },
  { title: '離脱種別', key: 'absence_type' },
  { title: '理由', key: 'reason' },
  { title: '開始日', key: 'start_date' },
  { title: '復帰予定日', key: 'effective_end_date' },
  { title: '残り', key: 'remaining', sortable: false },
]

const costHeaders = [
  { title: 'チーム', key: 'team_name' },
  { title: '種別', key: 'team_type' },
  { title: '合計コスト / 上限', key: 'total_cost', sortable: false },
  { title: '1軍コスト / 上限', key: 'first_squad_cost', sortable: false },
  { title: '1軍人数', key: 'first_squad_count' },
  { title: 'コスト除外', key: 'exempt_count' },
]

const cooldownHeaders = [
  { title: 'チーム', key: 'team_name' },
  { title: '選手名', key: 'player_name' },
  { title: '降格日', key: 'demotion_date' },
  { title: 'CD終了日', key: 'cooldown_until' },
  { title: '残り日数', key: 'remaining_days' },
  { title: '同日免除', key: 'same_day_exempt', sortable: false },
]

const filteredAbsences = computed(() => {
  return absences.value.filter((a) => {
    if (selectedAbsenceType.value && a.absence_type !== selectedAbsenceType.value) return false
    if (searchQuery.value && !a.player_name.includes(searchQuery.value)) return false
    return true
  })
})

const filteredCooldowns = computed(() => {
  return cooldowns.value.filter((c) => {
    if (cooldownSearchQuery.value && !c.player_name.includes(cooldownSearchQuery.value))
      return false
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

const getCostColor = (ratio: number): string => {
  if (ratio > 1.0) return 'error'
  if (ratio > 0.9) return 'warning'
  return 'primary'
}

const fetchTeams = async () => {
  teamsLoading.value = true
  try {
    const response = await axios.get<Team[]>('/teams')
    teams.value = response.data
  } catch (error) {
    console.error('Failed to fetch teams:', error)
    showSnackbar('チーム一覧の取得に失敗しました', 'error')
  } finally {
    teamsLoading.value = false
  }
}

const navigateToSeason = (team: Team) => {
  teamSelectionStore.selectTeam(team.id, team.name)
  router.push(`/teams/${team.id}/season`)
}

const navigateToMembers = (teamId: number) => {
  router.push(`/teams/${teamId}/members`)
}

const openTeamDialog = (team: Team | null = null) => {
  editingTeam.value = team ? { ...team } : null
  dialogVisible.value = true
}

const deleteTeam = async (id: number) => {
  if (!confirmDialog.value) return
  const result = await confirmDialog.value.open('チーム削除', 'このチームを削除しますか？', {
    color: 'error',
  })
  if (!result) return
  try {
    await axios.delete(`/teams/${id}`)
    showSnackbar('チームを削除しました', 'success')
    fetchTeams()
  } catch (error) {
    console.error('Failed to delete team:', error)
    showSnackbar('チームの削除に失敗しました', 'error')
  }
}

const fetchAbsences = async () => {
  absencesLoading.value = true
  try {
    const response = await axios.get('/commissioner/dashboard/absences')
    absences.value = response.data
  } catch (error) {
    console.error('Failed to fetch absences:', error)
  } finally {
    absencesLoading.value = false
  }
}

const fetchCosts = async () => {
  costsLoading.value = true
  try {
    const response = await axios.get('/commissioner/dashboard/costs')
    costs.value = response.data
  } catch (error) {
    console.error('Failed to fetch costs:', error)
  } finally {
    costsLoading.value = false
  }
}

const fetchCooldowns = async () => {
  cooldownsLoading.value = true
  try {
    const response = await axios.get('/commissioner/dashboard/cooldowns')
    cooldowns.value = response.data
  } catch (error) {
    console.error('Failed to fetch cooldowns:', error)
  } finally {
    cooldownsLoading.value = false
  }
}

onMounted(() => {
  fetchTeams()
  fetchAbsences()
  fetchCosts()
  fetchCooldowns()
})
</script>
