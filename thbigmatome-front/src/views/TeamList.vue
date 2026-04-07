<template>
  <v-container>
    <PageHeader :title="t('teamList.title')">
      <template #actions>
        <v-btn color="accent" variant="flat" @click="openDialog()" prepend-icon="mdi-plus">
          {{ t('teamList.addTeam') }}
        </v-btn>
      </template>
    </PageHeader>
    <DataCard title="">
      <FilterBar />
      <v-data-table
        :headers="headers"
        :items="teams"
        :loading="loading"
        class="elevation-1"
        item-value="id"
        :no-data-text="t('teamList.noData')"
        :row-props="
          (row: { item: Team }) => (row.item.is_active ? {} : { class: 'text-medium-emphasis' })
        "
      >
        <template #[`item.team_type`]="{ item }">
          <v-chip v-if="item.team_type === 'hachinai'" size="small" color="purple" variant="tonal">
            {{ t('teamList.teamTypes.hachinai') }}
          </v-chip>
          <span v-else class="text-caption text-medium-emphasis">{{
            t('teamList.teamTypes.normal')
          }}</span>
        </template>

        <template #[`item.is_active`]="{ item }">
          <v-icon v-if="item.is_active"> mdi-check </v-icon>
        </template>

        <template #[`item.manager_name`]="{ item }">
          {{ item.director?.name || '-' }}
        </template>

        <template #[`item.actions`]="{ item }">
          <v-tooltip text="シーズンポータル">
            <template #activator="{ props }">
              <v-icon v-bind="props" size="small" class="mr-2" @click="navigateToSeason(item)">
                mdi-calendar-star
              </v-icon>
            </template>
          </v-tooltip>
          <v-tooltip text="メンバー編集">
            <template #activator="{ props }">
              <v-icon v-bind="props" size="small" class="mr-2" @click="navigateToMembers(item.id)">
                mdi-account-group
              </v-icon>
            </template>
          </v-tooltip>
          <v-tooltip text="チーム編集">
            <template #activator="{ props }">
              <v-icon v-bind="props" size="small" class="mr-2" @click="openDialog(item)">
                mdi-pencil
              </v-icon>
            </template>
          </v-tooltip>
          <v-tooltip text="削除">
            <template #activator="{ props }">
              <v-icon v-bind="props" size="small" @click="deleteTeam(item.id)"> mdi-delete </v-icon>
            </template>
          </v-tooltip>
        </template>

        <template #no-data>
          <div class="d-flex flex-column align-center py-8">
            <v-icon size="48" class="mb-2 text-medium-emphasis">mdi-account-group-outline</v-icon>
            <p class="text-medium-emphasis mb-1">チームが登録されていません</p>
            <p class="text-caption text-disabled mb-4">
              「チーム追加」からチームを作成し、メンバーを登録してシーズンを開始できます
            </p>
            <v-btn color="accent" variant="flat" prepend-icon="mdi-plus" @click="openDialog()">
              {{ t('teamList.addTeam') }}
            </v-btn>
          </div>
        </template>
      </v-data-table>
    </DataCard>

    <TeamDialog v-model="dialogVisible" :team="editingTeam" @save="fetchTeams" />

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script lang="ts" setup>
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import DataCard from '@/components/shared/DataCard.vue'
import FilterBar from '@/components/shared/FilterBar.vue'
import PageHeader from '@/components/shared/PageHeader.vue'
import { type Team } from '@/types/team'
import TeamDialog from '@/components/TeamDialog.vue'
import { useTeamSelectionStore } from '@/stores/teamSelection'

const { t } = useI18n()
const router = useRouter()
const teamSelectionStore = useTeamSelectionStore()

// v-data-tableのヘッダー定義
const headers = computed(() => [
  { title: t('teamList.headers.id'), key: 'id' },
  { title: t('teamList.headers.name'), key: 'name' },
  { title: t('teamList.headers.shortName'), key: 'short_name' },
  { title: t('teamList.headers.teamType'), key: 'team_type', sortable: false },
  { title: t('teamList.headers.managerName'), key: 'manager_name', sortable: false },
  { title: t('teamList.headers.isActive'), key: 'is_active', sortable: false },
  { title: t('teamList.headers.actions'), key: 'actions', sortable: false },
])

const teams = ref<Team[]>([])
const loading = ref(true)
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
  try {
    const response = await axios.get<Team[]>('/teams')
    teams.value = response.data
  } catch (error) {
    console.error('Error fetching teams:', error)
    showSnackbar(t('teamList.fetchFailed'), 'error')
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
    { color: 'error' },
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

// コンポーネントがマウントされた時にTeam一覧を取得
onMounted(() => {
  fetchTeams()
})
</script>

<style scoped>
/* 必要に応じてスタイルを追加 */
</style>
