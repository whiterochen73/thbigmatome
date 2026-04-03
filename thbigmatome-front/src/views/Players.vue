<!-- eslint-disable vue/multi-word-component-names, vue/valid-v-slot -->
<template>
  <v-container fluid>
    <PageHeader :title="t('playerList.title')">
      <template #actions>
        <v-btn color="accent" variant="flat" @click="openDialog">
          {{ t('playerList.addPlayer') }}
        </v-btn>
      </template>
    </PageHeader>
    <DataCard title="">
      <!-- フィルターUI -->
      <FilterBar>
        <template #search>
          <v-text-field
            v-model="searchText"
            :label="t('playerList.filters.searchPlaceholder')"
            prepend-inner-icon="mdi-magnify"
            clearable
            hide-details
          ></v-text-field>
        </template>
      </FilterBar>

      <v-data-table
        :headers="headers"
        :items="filteredPlayers"
        :loading="loading"
        :no-data-text="t('playerList.noData')"
        :class="displayClasses"
        item-value="id"
        class="elevation-1"
      >
        <template #item.series="{ item }">
          <StatusChip
            v-if="item.series"
            :status="item.series"
            :label="seriesLabelMap[item.series] ?? item.series"
            size="small"
          />
          <span v-else class="text-grey">—</span>
        </template>
        <template #item.card_count="{ item }">
          <a href="#" class="card-count-link" @click.prevent="router.push(`/players/${item.id}`)">
            {{ item.player_cards?.length ?? 0 }}枚
          </a>
        </template>
        <template #item.actions="{ item }">
          <v-icon size="small" class="me-2" @click="openDialog(item)" icon="mdi-pencil"></v-icon>
          <v-icon size="small" @click="deletePlayer(item.id!)" icon="mdi-delete"></v-icon>
        </template>
      </v-data-table>
    </DataCard>

    <PlayerDialog v-model="dialog" :item="editedItem" @save="onSave" />

    <ConfirmDialog ref="confirmDialog" />
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter, onBeforeRouteLeave } from 'vue-router'
import axios from '@/plugins/axios'
import { useSnackbar } from '@/composables/useSnackbar'
import PlayerDialog from '@/components/players/PlayerDialog.vue'
import { useDisplay } from 'vuetify'
import ConfirmDialog from '@/components/ConfirmDialog.vue'
import DataCard from '@/components/shared/DataCard.vue'
import FilterBar from '@/components/shared/FilterBar.vue'
import PageHeader from '@/components/shared/PageHeader.vue'
import StatusChip from '@/components/shared/StatusChip.vue'
import type { PlayerDetail } from '@/types/playerDetail'
import { usePlayersSearchStore } from '@/stores/playersSearch'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()
const { displayClasses } = useDisplay()
const router = useRouter()
const playersSearchStore = usePlayersSearchStore()

const players = ref<PlayerDetail[]>([])
const loading = ref(true)
const dialog = ref(false)
const confirmDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null)
const editedItem = ref<PlayerDetail | null>(null)

const searchText = computed({
  get: () => playersSearchStore.searchText,
  set: (val: string) => playersSearchStore.setSearchText(val),
})

const seriesLabelMap: Record<string, string> = {
  touhou: '東方Project',
  hachinai: 'ハチナイ',
  tamayomi: '球詠',
  original: 'オリジナル',
}

const headers = computed(() => [
  { title: t('playerList.headers.number'), key: 'number', width: '10%' },
  { title: t('playerList.headers.name'), key: 'name', width: '40%' },
  { title: '所属作品', key: 'series', sortable: false, width: '20%' },
  { title: 'カード数', key: 'card_count', sortable: false, width: '15%' },
  { title: t('playerList.headers.actions'), key: 'actions', sortable: false, width: '15%' },
])

const filteredPlayers = computed(() => {
  let result = players.value

  if (searchText.value) {
    const search = searchText.value.toLowerCase()
    result = result.filter(
      (player) =>
        player.name.toLowerCase().includes(search) ||
        (player.short_name && player.short_name.toLowerCase().includes(search)),
    )
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

onMounted(async () => {
  await fetchPlayers()
  window.scrollTo(0, playersSearchStore.scrollY)
})

onBeforeRouteLeave(() => {
  playersSearchStore.setScrollY(window.scrollY)
})

const openDialog = (player: PlayerDetail | null = null) => {
  editedItem.value = player ? { ...player } : null
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
    fetchPlayers()
  } catch (error) {
    console.error('Error deleting player:', error)
    showSnackbar(t('playerList.deleteFailed'), 'error')
  }
}

const onSave = () => {
  fetchPlayers()
}
</script>

<style scoped>
.card-count-link {
  color: #5a3e20;
  text-decoration: none;
  font-size: 0.88em;
}

.card-count-link:hover {
  text-decoration: underline;
}
</style>
