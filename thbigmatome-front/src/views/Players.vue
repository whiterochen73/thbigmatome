<!-- eslint-disable vue/multi-word-component-names, vue/valid-v-slot -->
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
        <!-- フィルターUI -->
        <v-row dense class="mb-4">
          <v-col cols="12" sm="6" md="4">
            <v-text-field
              v-model="searchText"
              :label="t('playerList.filters.searchPlaceholder')"
              prepend-inner-icon="mdi-magnify"
              clearable
              dense
              hide-details
            ></v-text-field>
          </v-col>
          <v-col cols="12" sm="6" md="3">
            <v-select
              v-model="selectedPosition"
              :items="positionFilterOptions"
              :label="t('playerList.filters.position')"
              clearable
              dense
              hide-details
            ></v-select>
          </v-col>
        </v-row>

        <v-data-table
          :headers="headers"
          :items="filteredPlayers"
          :loading="loading"
          :no-data-text="t('playerList.noData')"
          :class="displayClasses"
          item-value="id"
          class="elevation-1"
        >
          <template #item.position="{ item }">
            {{ t(`baseball.positions.${item.position}`) }}
          </template>
          <template #item.actions="{ item }">
            <v-icon size="small" class="me-2" @click="openDialog(item)" icon="mdi-pencil"></v-icon>
            <v-icon size="small" @click="deletePlayer(item.id!)" icon="mdi-delete"></v-icon>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <PlayerDialog v-model="dialog" :item="editedItem" @save="onSave" />

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
import type { PlayerDetail } from '@/types/playerDetail'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()
const { displayClasses } = useDisplay()

const players = ref<PlayerDetail[]>([])
const loading = ref(true)
const dialog = ref(false)
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)
const editedItem = ref<PlayerDetail | null>(null)

// フィルター用のstate
const searchText = ref('')
const selectedPosition = ref<string | null>(null)

const headers = computed(() => [
  { title: t('playerList.headers.number'), key: 'number', width: '15%' },
  { title: t('playerList.headers.name'), key: 'name', width: '30%' },
  { title: t('playerList.headers.short_name'), key: 'short_name', width: '20%' },
  { title: t('playerList.headers.position'), key: 'position', width: '15%' },
  { title: t('playerList.headers.actions'), key: 'actions', sortable: false, width: '10%' },
])

// ポジションフィルターのオプション
const positionFilterOptions = computed(() => [
  { value: 'pitcher', title: t('baseball.positions.pitcher') },
  { value: 'catcher', title: t('baseball.positions.catcher') },
  { value: 'infielder', title: t('baseball.positions.infielder') },
  { value: 'outfielder', title: t('baseball.positions.outfielder') },
])

// フィルター適用後の選手リスト
const filteredPlayers = computed(() => {
  let result = players.value

  // 名前検索フィルター（name または short_name に部分一致）
  if (searchText.value) {
    const search = searchText.value.toLowerCase()
    result = result.filter(
      (player) =>
        player.name.toLowerCase().includes(search) ||
        (player.short_name && player.short_name.toLowerCase().includes(search)),
    )
  }

  // ポジションフィルター
  if (selectedPosition.value) {
    result = result.filter((player) => player.position === selectedPosition.value)
  }

  return result
})

const fetchPlayers = async () => {
  loading.value = true
  try {
    const response = await axios.get<PlayerDetail[]>('/players')
    players.value = response.data
  } catch {
    showSnackbar(t('playerList.fetchFailed'), 'error')
  } finally {
    loading.value = false
  }
}

onMounted(fetchPlayers)

const openDialog = (player: PlayerDetail | null = null) => {
  editedItem.value = player ? { ...player } : null // 参照渡しを防ぐためスプレッド構文でコピー
  dialog.value = true
}

const deletePlayer = async (id: number) => {
  if (!confirmDialog.value) return
  const result = await confirmDialog.value.open(
    t('playerList.deleteConfirmTitle'),
    t('playerList.deleteConfirmMessage'),
    { color: 'error' },
  )
  if (!result) {
    return
  }
  try {
    await axios.delete(`/players/${id}`)
    showSnackbar(t('playerList.deleteSuccess'), 'success')
    fetchPlayers() // 削除後、一覧を再取得
  } catch (error) {
    console.error('Error deleting player:', error)
    showSnackbar(t('playerList.deleteFailed'), 'error')
  }
}

const onSave = () => {
  fetchPlayers()
}
</script>
