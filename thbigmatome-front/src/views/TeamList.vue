<template>
  <v-container>
    <v-card>
      <v-card-title class="d-flex align-center">
        {{ t('teamList.title') }}
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="openDialog()" prepend-icon="mdi-plus">
          {{ t('teamList.addTeam') }}
        </v-btn>
      </v-card-title>
      <v-card-text>
        <v-data-table
          :headers="headers"
          :items="teams"
          :loading="loading"
          class="elevation-1"
          item-value="id"
          :no-data-text="t('teamList.noData')"
        >
          <template v-slot:item.is_active="{ item }">
            <v-icon v-if="item.is_active">
              mdi-check
            </v-icon>
          </template>

          <template v-slot:item.manager_name="{ item }">
            {{ item.manager?.name || '-' }}
          </template>

          <template v-slot:item.actions="{ item }">
            <v-icon
              size="small"
              class="mr-2"
              @click="openDialog(item)"
            >
              mdi-pencil
            </v-icon>
            <v-icon
              size="small"
              @click="deleteTeam(item.id)"
            >
              mdi-delete
            </v-icon>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <TeamDialog
      v-model:isVisible="dialogVisible"
      :team="editingTeam"
      @save="fetchTeams"
    />

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script lang="ts" setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from '@/plugins/axios';
import { useSnackbar } from '@/composables/useSnackbar';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import { type Team } from '@/types/team';
import TeamDialog from '@/components/TeamDialog.vue';

const { t } = useI18n();

// v-data-tableのヘッダー定義
const headers = computed(() => [
  { title: t('teamList.headers.id'), key: 'id' },
  { title: t('teamList.headers.name'), key: 'name' },
  { title: t('teamList.headers.shortName'), key: 'short_name' },
  { title: t('teamList.headers.managerName'), key: 'manager_name', sortable: false },
  { title: t('teamList.headers.isActive'), key: 'is_active', sortable: false },
  { title: t('teamList.headers.actions'), key: 'actions', sortable: false },
]);

const teams = ref<Team[]>([]);
const loading = ref(true);
const { showSnackbar } = useSnackbar();
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);

// ダイアログ関連のstate
const dialogVisible = ref(false);
const editingTeam = ref<Team | null>(null); // 編集中のTeamデータ

/**
 * Team一覧を取得する
 */
const fetchTeams = async () => {
  loading.value = true;
  try {
    const response = await axios.get<Team[]>('/teams');
    teams.value = response.data;
  } catch (error) {
    console.error('Error fetching teams:', error);
    showSnackbar(t('teamList.fetchFailed'), 'error');
  } finally {
    loading.value = false;
  }
};

/**
 * Teamを削除する
 * @param id 削除対象のTeam ID
 */
const deleteTeam = async (id: number) => {
  if (!confirmDialog.value) return;
  const result = await confirmDialog.value.open(
    t('teamList.deleteConfirmTitle'),
    t('teamList.deleteConfirmMessage'),
    { color: 'error' }
  );
  if (!result) {
    return;
  }
  try {
    await axios.delete(`/teams/${id}`);
    showSnackbar(t('teamList.deleteSuccess'), 'success');
    fetchTeams(); // 削除後、一覧を再取得
  } catch (error) {
    console.error('Error deleting team:', error);
    showSnackbar(t('teamList.deleteFailed'), 'error');
  }
};

/**
 * Team編集/作成ダイアログを開く
 * @param team 編集対象のTeamデータ (新規作成の場合はnull)
 */
const openDialog = (team: Team | null = null) => {
  editingTeam.value = team ? { ...team } : null; // 参照渡しを防ぐためスプレッド構文でコピー
  dialogVisible.value = true;
};

// コンポーネントがマウントされた時にTeam一覧を取得
onMounted(() => {
  fetchTeams();
});
</script>

<style scoped>
/* 必要に応じてスタイルを追加 */
</style>