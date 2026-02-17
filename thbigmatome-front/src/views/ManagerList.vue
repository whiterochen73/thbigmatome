<template>
  <v-container>
    <v-card>
      <v-card-title class="d-flex align-center">
        {{ t('managerList.title') }}
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="openDialog()" prepend-icon="mdi-plus">
          {{ t('managerList.addManager') }}
        </v-btn>
      </v-card-title>
      <v-card-text>
        <v-data-table
          :headers="headers"
          :items="managers"
          :loading="loading"
          :items-length="totalItems"
          :items-per-page="itemsPerPage"
          class="elevation-1"
          item-value="id"
          show-expand
          :no-data-text="t('managerList.noData')"
          @update:options="onOptionsUpdate"
        >
          <!-- eslint-disable-next-line vue/valid-v-slot -->
          <template #item.actions="{ item }">
            <v-icon size="small" class="mr-2" @click="openDialog(item)"> mdi-pencil </v-icon>
            <v-icon size="small" @click="deleteManager(item.id)"> mdi-delete </v-icon>
          </template>

          <template #expanded-row="{ columns, item }">
            <tr>
              <td :colspan="columns.length">
                <div class="pa-4 bg-grey-lighten-5">
                  <div class="d-flex align-center mb-2">
                    <h4 class="text-subtitle-1">{{ t('managerList.expanded.title') }}</h4>
                    <v-spacer></v-spacer>
                    <v-btn
                      size="small"
                      color="primary"
                      @click="openTeamDialog(null, item.id)"
                      prepend-icon="mdi-plus"
                    >
                      {{ t('managerList.expanded.addTeam') }}
                    </v-btn>
                  </div>

                  <div v-if="item.teams && item.teams.length > 0">
                    <v-list density="compact" lines="one">
                      <v-list-item v-for="team in item.teams" :key="team.id" :title="team.name">
                        <template #append>
                          <v-chip
                            :color="team.is_active ? 'success' : 'default'"
                            size="small"
                            variant="tonal"
                            class="mr-4"
                          >
                            {{
                              team.is_active
                                ? t('managerList.expanded.active')
                                : t('managerList.expanded.inactive')
                            }}
                          </v-chip>
                          <v-icon size="small" @click="openTeamDialog(team, item.id)"
                            >mdi-pencil</v-icon
                          >
                        </template>
                      </v-list-item>
                    </v-list>
                  </div>
                  <div v-else class="py-4 text-center text-grey">
                    {{ t('managerList.expanded.noTeams') }}
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <ManagerDialog
      v-model:isVisible="dialogVisible"
      :manager="editingManager"
      @save="fetchManagers"
    />

    <TeamDialog
      v-model:isVisible="teamDialogVisible"
      :team="editingTeam"
      :default-manager-id="defaultManagerIdForTeam ?? undefined"
      @save="fetchManagers"
    />

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script lang="ts" setup>
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import { type Manager } from '@/types/manager'
import { type Team } from '@/types/team'
import { type PaginatedResponse } from '@/types/pagination'
import ManagerDialog from '@/components/ManagerDialog.vue'
import TeamDialog from '@/components/TeamDialog.vue'

const { t } = useI18n()

const { showSnackbar } = useSnackbar()
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)
// v-data-tableのヘッダー定義
const headers = computed(() => [
  { title: '', key: 'data-table-expand' },
  { title: t('managerList.headers.id'), key: 'id' },
  { title: t('managerList.headers.name'), key: 'name' },
  { title: t('managerList.headers.shortName'), key: 'short_name' },
  { title: t('managerList.headers.ircName'), key: 'irc_name' },
  { title: t('managerList.headers.userId'), key: 'user_id' },
  { title: t('managerList.headers.actions'), key: 'actions', sortable: false },
])

const managers = ref<Manager[]>([])
const loading = ref(true)

// ページネーション関連のstate
const totalItems = ref(0)
const itemsPerPage = ref(25)
const currentPage = ref(1)

// 監督ダイアログ関連のstate
const dialogVisible = ref(false)
const editingManager = ref<Manager | null>(null) // 編集中のManagerデータ

// チームダイアログ関連のstate
const teamDialogVisible = ref(false)
const editingTeam = ref<Team | null>(null)
const defaultManagerIdForTeam = ref<number | null>(null)

/**
 * Manager一覧を取得する
 * @param page ページ番号（1始まり）
 * @param perPage 1ページあたりの件数
 */
const fetchManagers = async (
  page: number = currentPage.value,
  perPage: number = itemsPerPage.value,
) => {
  loading.value = true
  try {
    const response = await axios.get<PaginatedResponse<Manager>>('/managers', {
      params: { page, per_page: perPage },
    })
    managers.value = response.data.data
    totalItems.value = response.data.meta.total_count
    currentPage.value = response.data.meta.current_page
    itemsPerPage.value = response.data.meta.per_page
  } catch (error) {
    console.error('Error fetching managers:', error)
    showSnackbar(t('managerList.fetchFailed'), 'error')
  } finally {
    loading.value = false
  }
}

/**
 * v-data-tableのページネーションオプション変更時のハンドラー
 */
const onOptionsUpdate = (options: { page: number; itemsPerPage: number }) => {
  fetchManagers(options.page, options.itemsPerPage)
}

/**
 * Managerを削除する
 * @param id 削除対象のManager ID
 */
const deleteManager = async (id: number) => {
  if (!confirmDialog.value) return
  const result = await confirmDialog.value.open(
    t('managerList.deleteConfirmTitle'),
    t('managerList.deleteConfirmMessage'),
    { color: 'error' },
  )
  if (!result) {
    return
  }
  try {
    await axios.delete(`/managers/${id}`)
    showSnackbar(t('managerList.deleteSuccess'), 'success')
    fetchManagers() // 削除後、一覧を再取得
  } catch (error) {
    console.error('Error deleting manager:', error)
    showSnackbar(t('managerList.deleteFailed'), 'error')
  }
}

/**
 * Manager編集/作成ダイアログを開く
 * @param manager 編集対象のManagerデータ (新規作成の場合はnull)
 */
const openDialog = (manager: Manager | null = null) => {
  editingManager.value = manager ? { ...manager } : null // 参照渡しを防ぐためスプレッド構文でコピー
  dialogVisible.value = true
}

/**
 * チーム編集/作成ダイアログを開く
 * @param team 編集対象のTeamデータ (新規作成の場合はnull)
 * @param managerId 親となる監督のID
 */
const openTeamDialog = (team: Team | null, managerId: number) => {
  editingTeam.value = team ? { ...team } : null
  defaultManagerIdForTeam.value = managerId
  teamDialogVisible.value = true
}

// コンポーネントがマウントされた時にManager一覧を取得
onMounted(() => {
  fetchManagers()
})
</script>

<style scoped>
/* 必要に応じてスタイルを追加 */
</style>
