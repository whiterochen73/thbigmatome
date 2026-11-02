<template>
  <PageLayout>
    <template #actions>
      <v-btn color="action" variant="flat" prepend-icon="mdi-plus" @click="openDialog()">
        {{ t('managerList.addManager') }}
      </v-btn>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      :error-message="t('managerList.fetchFailed')"
      :empty="managers.length === 0"
      empty-icon="mdi-account-tie-outline"
      :empty-message="t('managerList.noData')"
      @retry="fetchManagers()"
    >
      <v-card>
        <!-- 総件数はサーバが持つ。v-data-table は items-length を読まず、取得済みの行数を総数とみなす -->
        <v-data-table-server
          :headers="headers"
          :items="managers"
          :loading="loading"
          :items-length="totalItems"
          :page="currentPage"
          :items-per-page="itemsPerPage"
          class="ui-table"
          item-value="id"
          show-expand
          :no-data-text="t('managerList.noData')"
          @update:options="onOptionsUpdate"
        >
          <!-- eslint-disable-next-line vue/valid-v-slot -->
          <template #item.team_count="{ item }">
            <span>{{ item.active_director_team_count ?? 0 }}/2</span>
            <v-chip
              v-if="(item.active_director_team_count ?? 0) >= 2"
              size="x-small"
              color="state-todo"
              variant="flat"
              class="ml-1"
            >
              {{ t('managerList.atCapacity') }}
            </v-chip>
          </template>

          <!-- eslint-disable-next-line vue/valid-v-slot -->
          <template #item.actions="{ item }">
            <div class="row-actions">
              <RowIconButton
                icon="mdi-pencil"
                :label="t('settings.rowActions.edit', { name: item.name })"
                @click="openDialog(item)"
              />
              <RowIconButton
                icon="mdi-delete-outline"
                danger
                :label="t('settings.rowActions.delete', { name: item.name })"
                @click="deleteManager(item.id)"
              />
            </div>
          </template>

          <template #expanded-row="{ columns, item }">
            <tr>
              <td :colspan="columns.length">
                <div class="pa-4 bg-surface-variant">
                  <div class="d-flex align-center mb-2">
                    <h4 class="text-subtitle-1">{{ t('managerList.expanded.title') }}</h4>
                    <v-spacer></v-spacer>
                    <v-btn
                      size="small"
                      color="link"
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
                            :color="team.is_active ? 'state-done' : 'state-neutral'"
                            size="small"
                            variant="flat"
                            class="mr-4"
                          >
                            {{
                              team.is_active
                                ? t('managerList.expanded.active')
                                : t('managerList.expanded.inactive')
                            }}
                          </v-chip>
                          <RowIconButton
                            icon="mdi-pencil"
                            :label="t('settings.rowActions.edit', { name: team.name })"
                            @click="openTeamDialog(team, item.id)"
                          />
                        </template>
                      </v-list-item>
                    </v-list>
                  </div>
                  <div v-else class="py-4 text-center on-surface-variant">
                    {{ t('managerList.expanded.noTeams') }}
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </v-data-table-server>
      </v-card>
    </AsyncState>

    <ManagerDialog
      v-model:isVisible="dialogVisible"
      :manager="editingManager"
      @save="handleManagerSaved"
    />

    <TeamDialog
      v-model:isVisible="teamDialogVisible"
      :team="editingTeam"
      :default-manager-id="defaultManagerIdForTeam ?? undefined"
      @save="fetchManagers"
    />

    <ConfirmDialog ref="confirmDialog" />
  </PageLayout>
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
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'

const { t } = useI18n()

const { showSnackbar } = useSnackbar()
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)
// v-data-table-serverのヘッダー定義
// サーバは id の降順でしか返さないので、列の並べ替えは出さない（手元の 1 ページ分だけが並ぶ偽の並べ替えになる）
const headers = computed(() => [
  { title: '', key: 'data-table-expand', sortable: false },
  { title: t('managerList.headers.id'), key: 'id', sortable: false },
  { title: t('managerList.headers.name'), key: 'name', sortable: false },
  { title: t('managerList.headers.shortName'), key: 'short_name', sortable: false },
  { title: t('managerList.headers.ircName'), key: 'irc_name', sortable: false },
  { title: t('managerList.headers.userId'), key: 'user_id', sortable: false },
  { title: t('managerList.headers.teamCount'), key: 'team_count', sortable: false },
  { title: t('managerList.headers.actions'), key: 'actions', sortable: false },
])

const managers = ref<Manager[]>([])
const loading = ref(true)
const fetchFailed = ref(false)

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
  fetchFailed.value = false
  try {
    const response = await axios.get<PaginatedResponse<Manager>>('/managers', {
      params: { page, per_page: perPage },
    })
    managers.value = response.data.data
    totalItems.value = response.data.meta.total_count
    currentPage.value = response.data.meta.current_page
    itemsPerPage.value = response.data.meta.per_page
  } catch (error) {
    // 取得の失敗はページ内のアラート（AsyncState）で出す。スナックバーは保存・削除の成否だけ
    console.error('Error fetching managers:', error)
    fetchFailed.value = true
  } finally {
    loading.value = false
  }
}

/**
 * v-data-tableのページネーションオプション変更時のハンドラー
 */
const onOptionsUpdate = (options: { page: number; itemsPerPage: number }) => {
  // 表は最初の取得が済んでから描かれ、その時の更新通知は取得済みの条件と同じなので取り直さない
  if (
    managers.value.length > 0 &&
    options.page === currentPage.value &&
    options.itemsPerPage === itemsPerPage.value
  ) {
    return
  }
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
    { destructive: true },
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

const handleManagerSaved = () => {
  currentPage.value = 1
  fetchManagers(1, itemsPerPage.value)
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
