<!-- eslint-disable vue/valid-v-slot -->
<template>
  <v-tabs v-model="activeTab" color="link" class="mb-4">
    <v-tab value="overview" prepend-icon="mdi-view-dashboard-outline">概況</v-tab>
    <v-tab value="absences" prepend-icon="mdi-account-off-outline">
      離脱者
      <v-chip
        v-if="absencesReady"
        class="tab-count"
        color="state-neutral"
        variant="flat"
        size="small"
        >{{ absences.data.length }}</v-chip
      >
    </v-tab>
    <v-tab value="cooldowns" prepend-icon="mdi-timer-sand">
      クールダウン
      <v-chip
        v-if="cooldownsReady"
        class="tab-count"
        color="state-neutral"
        variant="flat"
        size="small"
        >{{ cooldowns.data.length }}</v-chip
      >
    </v-tab>
    <v-tab value="costs" prepend-icon="mdi-currency-jpy">
      コスト
      <v-chip
        v-if="costsReady"
        class="tab-count"
        :color="summary.costOverTeams > 0 ? 'state-warn' : 'state-neutral'"
        variant="flat"
        size="small"
        >{{ summary.costWatchTeams }}</v-chip
      >
    </v-tab>
    <v-tab value="rosterStatus" prepend-icon="mdi-clipboard-list-outline">
      1軍登録
      <v-chip
        v-if="rosterReady"
        class="tab-count"
        :color="CHECK_COLOR[checkState(summary.checkTeams, rosterReady, costsReady)]"
        variant="flat"
        size="small"
        >{{ summary.checkTeams }}</v-chip
      >
    </v-tab>
    <v-tab value="teams" prepend-icon="mdi-account-group-outline">
      チーム管理
      <v-chip
        v-if="teamsReady"
        class="tab-count"
        color="state-neutral"
        variant="flat"
        size="small"
        >{{ teams.data.length }}</v-chip
      >
    </v-tab>
  </v-tabs>

  <v-window v-model="activeTab">
    <!-- 概況タブ（先頭） -->
    <v-window-item value="overview">
      <DashboardOverview
        :teams="teams"
        :absences="absences"
        :cooldowns="cooldowns"
        :costs="costs"
        :roster-status="rosterStatus"
        @navigate="activeTab = $event"
        @retry="retryResource"
        @open-season="navigateToSeason"
      />
    </v-window-item>

    <!-- 全チーム管理タブ -->
    <v-window-item value="teams">
      <AsyncState
        framed
        :loading="teams.loading"
        :error="teams.failed"
        error-message="チーム一覧の取得に失敗しました"
        :empty="teams.data.length === 0"
        empty-icon="mdi-account-group-outline"
        empty-message="チームが登録されていません"
        @retry="fetchTeams"
      >
        <DataCard title="">
          <v-data-table
            class="ui-table ui-table--rows"
            mobile-breakpoint="sm"
            :headers="teamHeaders"
            :items="teams.data"
            density="compact"
            item-value="id"
            no-data-text="チームなし"
            :row-props="
              (row: { item: Team }) => (row.item.is_active ? {} : { class: 'on-surface-variant' })
            "
          >
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
            <template #[`item.is_active`]="{ item }">
              <v-icon v-if="item.is_active">mdi-check</v-icon>
            </template>
            <template #[`item.manager_name`]="{ item }">
              {{ item.director?.name || '-' }}
            </template>
            <template #[`item.last_game_real_date`]="{ item }">
              <span v-if="item.last_game_real_date" class="text-caption">
                {{ formatDate(item.last_game_real_date) }}
              </span>
              <span v-else class="text-caption on-surface-variant">-</span>
            </template>
            <template #[`item.season_current_date`]="{ item }">
              <span v-if="item.season_current_date" class="text-caption">
                {{ formatDate(item.season_current_date) }}
              </span>
              <span v-else class="text-caption on-surface-variant">-</span>
            </template>
            <template #[`item.actions`]="{ item }">
              <!-- 操作が 4 つあるので、スマホ（<600px）では操作メニューにまとめる -->
              <div class="row-actions row-actions--full">
                <RowIconButton
                  icon="mdi-calendar-star"
                  :label="`${item.name}のシーズンポータル`"
                  @click="navigateToSeason(item)"
                />
                <RowIconButton
                  icon="mdi-account-group"
                  :label="`${item.name}のメンバー編集`"
                  @click="navigateToMembers(item.id)"
                />
                <RowIconButton
                  icon="mdi-pencil"
                  :label="`${item.name}のチーム編集`"
                  @click="openTeamDialog(item)"
                />
                <RowIconButton
                  icon="mdi-delete-outline"
                  danger
                  :label="`${item.name}を削除`"
                  @click="deleteTeam(item.id)"
                />
              </div>
              <RowMenu
                :label="`${item.name}の操作`"
                :items="[
                  {
                    icon: 'mdi-calendar-star',
                    label: 'シーズンポータル',
                    onClick: () => navigateToSeason(item),
                  },
                  {
                    icon: 'mdi-account-group',
                    label: 'メンバー編集',
                    onClick: () => navigateToMembers(item.id),
                  },
                  { icon: 'mdi-pencil', label: 'チーム編集', onClick: () => openTeamDialog(item) },
                  {
                    icon: 'mdi-delete-outline',
                    label: '削除',
                    danger: true,
                    onClick: () => deleteTeam(item.id),
                  },
                ]"
              />
            </template>
          </v-data-table>
        </DataCard>
      </AsyncState>
    </v-window-item>

    <!-- 離脱者一覧タブ -->
    <v-window-item value="absences">
      <AsyncState
        framed
        :loading="absences.loading"
        :error="absences.failed"
        error-message="離脱者の取得に失敗しました"
        :empty="absences.data.length === 0"
        empty-icon="mdi-account-off-outline"
        empty-message="離脱者はいません"
        @retry="fetchAbsences"
      >
        <DataCard title="">
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
            class="ui-table ui-table--rows"
            mobile-breakpoint="sm"
            :headers="absenceHeaders"
            :items="filteredAbsences"
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
                      ? 'state-done'
                      : undefined
                  "
                  :variant="
                    getRemainingCount(item) !== null && getRemainingCount(item)! <= 2
                      ? 'flat'
                      : 'text'
                  "
                  :prepend-icon="
                    getRemainingCount(item) !== null && getRemainingCount(item)! <= 2
                      ? 'mdi-clock-check-outline'
                      : undefined
                  "
                  size="small"
                >
                  {{ getRemainingDisplay(item) }}
                </v-chip>
              </template>
              <span v-else class="text-caption on-surface-variant">不明</span>
            </template>
          </v-data-table>
        </DataCard>
      </AsyncState>
    </v-window-item>

    <!-- クールダウンタブ -->
    <v-window-item value="cooldowns">
      <AsyncState
        framed
        :loading="cooldowns.loading"
        :error="cooldowns.failed"
        error-message="クールダウン中の選手の取得に失敗しました"
        :empty="cooldowns.data.length === 0"
        empty-icon="mdi-timer-sand-empty"
        empty-message="クールダウン中の選手はいません"
        @retry="fetchCooldowns"
      >
        <DataCard title="">
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
            class="ui-table ui-table--rows"
            mobile-breakpoint="sm"
            :headers="cooldownHeaders"
            :items="filteredCooldowns"
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
                :prepend-icon="item.remaining_days <= 2 ? 'mdi-clock-check-outline' : undefined"
                :color="item.remaining_days <= 2 ? 'state-done' : undefined"
                :variant="item.remaining_days <= 2 ? 'flat' : 'text'"
                size="small"
              >
                {{ item.remaining_days }}日
              </v-chip>
            </template>
            <template v-slot:item.same_day_exempt="{ item }">
              <v-chip v-if="item.same_day_exempt" color="state-neutral" variant="flat" size="small">
                同日免除
              </v-chip>
            </template>
          </v-data-table>
        </DataCard>
      </AsyncState>
    </v-window-item>

    <!-- コスト使用状況タブ -->
    <v-window-item value="costs">
      <AsyncState
        framed
        :loading="costs.loading"
        :error="costs.failed"
        error-message="コスト使用状況の取得に失敗しました"
        :empty="costs.data.length === 0"
        empty-icon="mdi-currency-jpy"
        empty-message="コスト使用状況がありません"
        @retry="fetchCosts"
      >
        <DataCard title="">
          <v-data-table
            class="ui-table"
            :headers="costHeaders"
            :items="costs.data"
            density="compact"
          >
            <template v-slot:item.team_type="{ item }">
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
            <template v-slot:item.total_cost="{ item }">
              <!-- 合計コストは上限の 95% 以上で黄、超過で赤 -->
              <div class="d-flex align-center gap-2 flex-nowrap">
                <span style="white-space: nowrap"
                  >{{ item.total_cost }} / {{ item.total_cost_limit }}</span
                >
                <v-progress-linear
                  data-testid="total-cost-bar"
                  :model-value="(item.total_cost / item.total_cost_limit) * 100"
                  :color="costBarColor(costLevel(item.total_cost, item.total_cost_limit))"
                  bg-color="surface-variant"
                  bg-opacity="1"
                  height="8"
                  rounded
                  style="min-width: 80px; max-width: 120px"
                />
                <v-chip
                  v-if="costLevel(item.total_cost, item.total_cost_limit) === 'over'"
                  color="state-warn"
                  variant="flat"
                  size="small"
                  prepend-icon="mdi-alert-circle"
                >
                  超過
                </v-chip>
                <v-chip
                  v-else-if="costLevel(item.total_cost, item.total_cost_limit) === 'near'"
                  color="state-todo"
                  variant="flat"
                  size="small"
                  prepend-icon="mdi-alert"
                >
                  上限に近い
                </v-chip>
              </div>
            </template>
            <template v-slot:item.first_squad_cost="{ item }">
              <!-- 1軍コストは上限ぴったりが通常なので、棒に注意の色を付けない -->
              <div class="d-flex align-center gap-2 flex-nowrap">
                <span class="d-inline-flex align-center ga-1" style="white-space: nowrap">
                  <LimitMark
                    :state="costLimitState(item.first_squad_cost, item.first_squad_cost_limit)"
                    :size="16"
                  />
                  {{ item.first_squad_cost }} / {{ item.first_squad_cost_limit ?? '—' }}
                </span>
                <v-progress-linear
                  v-if="item.first_squad_cost_limit"
                  data-testid="first-cost-bar"
                  :model-value="(item.first_squad_cost / item.first_squad_cost_limit) * 100"
                  color="link"
                  bg-color="surface-variant"
                  bg-opacity="1"
                  height="8"
                  rounded
                  style="min-width: 80px; max-width: 120px"
                />
              </div>
            </template>
          </v-data-table>
        </DataCard>
      </AsyncState>
    </v-window-item>

    <!-- 1軍登録状況タブ -->
    <v-window-item value="rosterStatus">
      <RosterStatusTab
        :records="rosterStatus.data"
        :loading="rosterStatus.loading"
        :failed="rosterStatus.failed"
        @retry="fetchRosterStatus"
      />
    </v-window-item>
  </v-window>

  <TeamDialog v-model:isVisible="dialogVisible" :team="editingTeam" @save="fetchTeams" />
  <ConfirmDialog ref="confirmDialog" />
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import LimitMark from '@/components/shared/LimitMark.vue'
import { costLimitState } from '@/components/shared/rosterLimits'
import AsyncState from '@/components/shared/AsyncState.vue'
import DataCard from '@/components/shared/DataCard.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import RowMenu from '@/components/shared/RowMenu.vue'
import { tableCell } from '@/components/shared/tableCells'
import FilterBar from '@/components/shared/FilterBar.vue'
import StatusChip from '@/components/shared/StatusChip.vue'
import DashboardOverview from '@/components/commissioner/DashboardOverview.vue'
import {
  type DashboardResourceKey,
  type DashboardTab,
  costBarColor,
  costLevel,
  summarize,
  checkState,
  CHECK_COLOR,
} from '@/components/commissioner/dashboardLogic'
import { useDashboardResource } from '@/composables/useDashboardResource'
import type {
  AbsenceRecord,
  CooldownRecord,
  CostRecord,
  RosterStatusRecord,
} from '@/types/commissionerDashboard'
import TeamDialog from '@/components/TeamDialog.vue'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import RosterStatusTab from '@/components/commissioner/RosterStatusTab.vue'
import { useSnackbar } from '@/composables/useSnackbar'
import { useTeamSelectionStore } from '@/stores/teamSelection'
import { type Team } from '@/types/team'
import { useColumnMinWidth } from '@/composables/useColumnMinWidth'

const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()
const { showSnackbar } = useSnackbar()

// 先頭のタブは概況。API は 5 本とも最初に取り、API ごとに別々の読み込み中・失敗を持つ（概況と各タブで共用）
const activeTab = ref<DashboardTab>('overview')

const { state: teams, fetch: fetchTeams } = useDashboardResource<Team>('/teams', 'teams')
const { state: absences, fetch: fetchAbsences } = useDashboardResource<AbsenceRecord>(
  '/commissioner/dashboard/absences',
  'absences',
)
const { state: costs, fetch: fetchCosts } = useDashboardResource<CostRecord>(
  '/commissioner/dashboard/costs',
  'costs',
)
const { state: cooldowns, fetch: fetchCooldowns } = useDashboardResource<CooldownRecord>(
  '/commissioner/dashboard/cooldowns',
  'cooldowns',
)
const { state: rosterStatus, fetch: fetchRosterStatus } = useDashboardResource<RosterStatusRecord>(
  '/commissioner/dashboard/roster_status',
  'roster status',
)

const fetchers: Record<DashboardResourceKey, () => Promise<void>> = {
  teams: fetchTeams,
  absences: fetchAbsences,
  cooldowns: fetchCooldowns,
  costs: fetchCosts,
  rosterStatus: fetchRosterStatus,
}
const retryResource = (key: DashboardResourceKey) => fetchers[key]()

// タブの件数。読み込み中・失敗の間は出さない（0 件と見分ける）
const summary = computed(() =>
  summarize({
    teams: teams.data,
    absences: absences.data,
    cooldowns: cooldowns.data,
    costs: costs.data,
    rosterStatus: rosterStatus.data,
  }),
)
const teamsReady = computed(() => !teams.loading && !teams.failed)
const absencesReady = computed(() => !absences.loading && !absences.failed)
const cooldownsReady = computed(() => !cooldowns.loading && !cooldowns.failed)
const costsReady = computed(() => !costs.loading && !costs.failed)
const rosterReady = computed(() => !rosterStatus.loading && !rosterStatus.failed)

const dialogVisible = ref(false)
const editingTeam = ref<Team | null>(null)
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)

const teamHeaders = [
  { title: 'ID', key: 'id', nowrap: true, cellProps: tableCell.lead },
  { title: 'チーム名', key: 'name', cellProps: tableCell.title },
  { title: '略称', key: 'short_name', nowrap: true },
  { title: '種別', key: 'team_type', sortable: false, nowrap: true, cellProps: tableCell.sub2 },
  { title: '監督', key: 'manager_name', sortable: false, cellProps: tableCell.sub1 },
  { title: 'アクティブ', key: 'is_active', sortable: false, nowrap: true },
  { title: '最終試合日', key: 'last_game_real_date', nowrap: true },
  {
    title: 'ゲーム内日付',
    key: 'season_current_date',
    nowrap: true,
    cellProps: tableCell.noteLabeled,
  },
  { title: '操作', key: 'actions', sortable: false, nowrap: true, cellProps: tableCell.act },
]

// 離脱者
const searchQuery = ref('')
const selectedAbsenceType = ref<string | null>(null)

// クールダウン
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
  { title: 'チーム', key: 'team_name', cellProps: tableCell.sub1 },
  { title: '選手名', key: 'player_name', cellProps: tableCell.title },
  { title: '離脱種別', key: 'absence_type', cellProps: tableCell.sub2 },
  { title: '理由', key: 'reason' },
  { title: '開始日', key: 'start_date' },
  { title: '復帰予定日', key: 'effective_end_date' },
  { title: '残り', key: 'remaining', sortable: false, cellProps: tableCell.noteLabeled },
]

const minW = useColumnMinWidth()
const costHeaders = computed(() => [
  // 横に比べる数値の表なので縦積みにせず、スマホでは横スクロール。チームの列は左に固定する
  { title: 'チーム', key: 'team_name', fixed: true, minWidth: minW(130) },
  { title: '種別', key: 'team_type', minWidth: minW(80) },
  { title: '合計コスト / 上限', key: 'total_cost', sortable: false, minWidth: minW(260) },
  { title: '1軍コスト / 上限', key: 'first_squad_cost', sortable: false, minWidth: minW(260) },
  { title: '1軍人数', key: 'first_squad_count', minWidth: minW(90) },
  { title: 'コスト除外', key: 'exempt_count', minWidth: minW(100) },
])

const cooldownHeaders = [
  { title: 'チーム', key: 'team_name', cellProps: tableCell.sub1 },
  { title: '選手名', key: 'player_name', cellProps: tableCell.title },
  { title: '降格日', key: 'demotion_date' },
  { title: 'CD終了日', key: 'cooldown_until', cellProps: tableCell.noteLabeled },
  { title: '残り日数', key: 'remaining_days', cellProps: tableCell.sub2 },
  { title: '同日免除', key: 'same_day_exempt', sortable: false },
]

const filteredAbsences = computed(() => {
  return absences.data.filter((a) => {
    if (selectedAbsenceType.value && a.absence_type !== selectedAbsenceType.value) return false
    if (searchQuery.value && !a.player_name.includes(searchQuery.value)) return false
    return true
  })
})

const filteredCooldowns = computed(() => {
  return cooldowns.data.filter((c) => {
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
    return { class: 'bg-state-done' }
  }
  return {}
}

const navigateToSeason = (team: { id: number; name: string }) => {
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
    destructive: true,
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

onMounted(() => {
  fetchTeams()
  fetchAbsences()
  fetchCosts()
  fetchCooldowns()
  fetchRosterStatus()
})
</script>

<style scoped>
/* タブの件数。タブの文字（14px）の隣に小さく置く */
.tab-count.v-chip {
  height: 20px;
  min-width: 20px;
  margin-inline-start: 8px;
  padding: 0 6px;
  justify-content: center;
  font-weight: 700;
}
</style>
