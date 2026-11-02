<template>
  <PageLayout>
    <template #actions>
      <v-btn color="action" variant="flat" prepend-icon="mdi-plus" @click="openDialog()">
        {{ t('teamList.addTeam') }}
      </v-btn>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      :error-message="t('teamList.fetchFailed')"
      :empty="teams.length === 0"
      empty-icon="mdi-account-group-outline"
      empty-message="チームが登録されていません"
      @retry="fetchTeams"
    >
      <template #empty-actions>
        <p class="text-caption on-surface-variant mb-0">
          「チーム追加」からチームを作成し、メンバーを登録してシーズンを開始できます
        </p>
      </template>
      <v-card>
        <v-data-table
          :headers="headers"
          :items="teams"
          class="ui-table"
          item-value="id"
          :no-data-text="t('teamList.noData')"
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
              {{ t('teamList.teamTypes.hachinai') }}
            </v-chip>
            <span v-else class="text-caption on-surface-variant">{{
              t('teamList.teamTypes.normal')
            }}</span>
          </template>

          <template #[`item.is_active`]="{ item }">
            <v-icon v-if="item.is_active"> mdi-check </v-icon>
          </template>

          <template #[`item.last_game_real_date`]="{ item }">
            {{ item.last_game_real_date ? formatDate(item.last_game_real_date) : '-' }}
          </template>

          <template #[`item.last_game_date`]="{ item }">
            {{ item.last_game_date ? formatDate(item.last_game_date) : '-' }}
          </template>

          <template #[`item.manager_name`]="{ item }">
            {{ item.director?.name || '-' }}
          </template>

          <template #[`item.actions`]="{ item }">
            <div class="row-actions">
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
                :label="t('settings.rowActions.edit', { name: item.name })"
                @click="openDialog(item)"
              />
              <RowIconButton
                icon="mdi-delete-outline"
                danger
                :label="t('settings.rowActions.delete', { name: item.name })"
                @click="deleteTeam(item.id)"
              />
            </div>
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>

    <TeamDialog v-model:isVisible="dialogVisible" :team="editingTeam" @save="fetchTeams" />

    <ConfirmDialog ref="confirmDialog" />
  </PageLayout>
</template>

<script lang="ts" setup>
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import { type Team } from '@/types/team'
import TeamDialog from '@/components/TeamDialog.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'

const { t } = useI18n()
const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()

// v-data-tableのヘッダー定義
const headers = computed(() => [
  { title: t('teamList.headers.id'), key: 'id', nowrap: true },
  { title: t('teamList.headers.name'), key: 'name' },
  { title: t('teamList.headers.shortName'), key: 'short_name', nowrap: true },
  { title: t('teamList.headers.teamType'), key: 'team_type', sortable: false, nowrap: true },
  { title: t('teamList.headers.managerName'), key: 'manager_name', sortable: false },
  { title: t('teamList.headers.isActive'), key: 'is_active', sortable: false, nowrap: true },
  { title: t('teamList.headers.lastGameRealDate'), key: 'last_game_real_date', nowrap: true },
  { title: t('teamList.headers.lastGameDate'), key: 'last_game_date', nowrap: true },
  { title: t('teamList.headers.actions'), key: 'actions', sortable: false, nowrap: true },
])

const teams = ref<Team[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
const { showSnackbar } = useSnackbar()
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)

// ダイアログ関連のstate
const dialogVisible = ref(false)
const editingTeam = ref<Team | null>(null) // 編集中のTeamデータ

/**
 * Team一覧を取得する
 */
const fetchTeams = async () => {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<Team[]>('/teams')
    teams.value = response.data
  } catch (error) {
    // 取得の失敗はページ内のアラート（AsyncState）で出す。スナックバーは保存・削除の成否だけ
    console.error('Error fetching teams:', error)
    fetchFailed.value = true
  } finally {
    loading.value = false
  }
}

/**
 * Teamを削除する
 * @param id 削除対象のTeam ID
 */
const deleteTeam = async (id: number) => {
  if (!confirmDialog.value) return
  const result = await confirmDialog.value.open(
    t('teamList.deleteConfirmTitle'),
    t('teamList.deleteConfirmMessage'),
    { destructive: true },
  )
  if (!result) {
    return
  }
  try {
    await axios.delete(`/teams/${id}`)
    showSnackbar(t('teamList.deleteSuccess'), 'success')
    fetchTeams() // 削除後、一覧を再取得
  } catch (error) {
    console.error('Error deleting team:', error)
    showSnackbar(t('teamList.deleteFailed'), 'error')
  }
}

/**
 * Team編集/作成ダイアログを開く
 * @param team 編集対象のTeamデータ (新規作成の場合はnull)
 */
const openDialog = (team: Team | null = null) => {
  editingTeam.value = team ? { ...team } : null // 参照渡しを防ぐためスプレッド構文でコピー
  dialogVisible.value = true
}

/**
 * チームメンバー編集画面へ遷移する
 * @param teamId チームID
 */
const navigateToMembers = (teamId: number) => {
  router.push(`/teams/${teamId}/members`)
}

/**
 * シーズンポータルへ遷移する
 * @param team チームデータ
 */
const navigateToSeason = (team: Team) => {
  teamSelectionStore.selectTeam(team.id, team.name)
  router.push(`/teams/${team.id}/season`)
}

/**
 * 日付文字列をYYYY/MM/DD形式でフォーマットする
 */
function formatDate(dateStr: string): string {
  if (!dateStr) return '-'
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}`
}

// コンポーネントがマウントされた時にTeam一覧を取得
onMounted(() => {
  fetchTeams()
})
</script>
