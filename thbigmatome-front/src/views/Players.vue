<template>
  <v-container fluid>
    <v-card>
      <v-card-title>
        {{ t('playerList.title') }}
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="openDialog">
          {{ t('playerList.addPlayer') }}
        </v-btn>
      </v-card-title>
      <v-card-text>
        <v-data-table
          :headers="headers"
          :items="players"
          :loading="loading"
          :no-data-text="t('playerList.noData')"
          :class="displayClasses"
          item-value="id"
          class="elevation-1"
        >
          <template v-slot:item.position="{ item }">
            {{ t('position.' + item.position) }}
          </template>
          <template v-slot:item.actions="{ item }">
            <v-icon size="small" class="me-2" @click="openDialog(item)" icon="mdi-pencil"></v-icon>
            <v-icon size="small" @click="deletePlayer(item.id)" icon="mdi-delete"></v-icon>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <PlayerDialog
      v-model="dialog"
      :item="editedItem"
      @save="onSave"
    />

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import PlayerDialog from '@/components/players/PlayerDialog.vue'
import { useDisplay } from 'vuetify'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import type { Player } from '@/types/player'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()
const { displayClasses } = useDisplay()

const players = ref<Player[]>([])
const loading = ref(true)
const dialog = ref(false)
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const editedItem = ref<Player | null>(null)

const headers = computed(() => [
  { title: t('playerList.headers.number'), key: 'number', width: '15%' },
  { title: t('playerList.headers.name'), key: 'name', width: '30%' },
  { title: t('playerList.headers.short_name'), key: 'short_name', width: '20%' },
  { title: t('playerList.headers.position'), key: 'position', width: '15%' },
  { title: t('playerList.headers.actions'), key: 'actions', sortable: false, width: '10%' },
])

const fetchPlayers = async () => {
  loading.value = true
  try {
    const response = await axios.get<Player[]>('/players')
    players.value = response.data
  } catch (error) {
    showSnackbar(t('playerList.fetchFailed'), 'error')
  } finally {
    loading.value = false
  }
}

onMounted(fetchPlayers)

const openDialog = (player: Player | null = null) => {
  editedItem.value = player ? { ...player } : null; // 参照渡しを防ぐためスプレッド構文でコピー
  dialog.value = true;
};

const deletePlayer = async (id: number) => {
  if (!confirmDialog.value) return;
  const result = await confirmDialog.value.open(
    t('playerList.deleteConfirmTitle'),
    t('playerList.deleteConfirmMessage'),
    { color: 'error' }
  );
  if (!result) {
    return;
  }
  try {
    await axios.delete(`/managers/${id}`);
    showSnackbar(t('playerList.deleteSuccess'), 'success');
    fetchPlayers(); // 削除後、一覧を再取得
  } catch (error) {
    console.error('Error deleting manager:', error);
    showSnackbar(t('playerList.deleteFailed'), 'error');
  }
};

const onSave = () => {
  fetchPlayers()
}
</script>