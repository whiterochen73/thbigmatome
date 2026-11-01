<!-- eslint-disable vue/multi-word-component-names, vue/valid-v-slot -->
<template>
  <PageLayout>
    <template #filters>
      <v-text-field
        v-model="searchText"
        :label="t('playerList.filters.searchPlaceholder')"
        prepend-inner-icon="mdi-magnify"
        clearable
        hide-details
        class="players-filter players-filter--search"
        data-testid="players-search"
      ></v-text-field>
      <v-select
        v-model="seriesFilter"
        :items="seriesOptions"
        :label="t('playerList.filters.series')"
        hide-details
        class="players-filter players-filter--series"
        data-testid="players-series-filter"
      ></v-select>
    </template>
    <template #actions>
      <v-btn color="action" variant="flat" prepend-icon="mdi-plus" @click="openDialog()">
        {{ t('playerList.addPlayer') }}
      </v-btn>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      :error-message="t('playerList.fetchFailed')"
      :empty="players.length === 0"
      empty-icon="mdi-account-off-outline"
      :empty-message="t('playerList.noData')"
      @retry="fetchPlayers"
    >
      <v-card>
        <v-data-table
          :headers="headers"
          :items="filteredPlayers"
          :no-data-text="t('playerList.noData')"
          :class="[displayClasses, 'ui-table', 'ui-table--rows']"
          item-value="id"
          mobile-breakpoint="sm"
        >
          <template #item.series="{ item }">
            <StatusChip
              v-if="item.series"
              :status="item.series"
              :label="seriesLabelMap[item.series] ?? item.series"
              size="small"
            />
            <span v-else class="on-surface-variant">—</span>
          </template>
          <template #item.card_count="{ item }">
            <a href="#" class="card-count-link" @click.prevent="router.push(`/players/${item.id}`)">
              {{ item.player_cards?.length ?? 0 }}枚
            </a>
          </template>
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
                @click="deletePlayer(item.id!)"
              />
            </div>
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>

    <PlayerDialog v-model="dialog" :item="editedItem" @save="onSave" />

    <ConfirmDialog ref="confirmDialog" />
  </PageLayout>
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
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import RowIconButton from '@/components/shared/RowIconButton.vue'
import StatusChip from '@/components/shared/StatusChip.vue'
import { tableCell } from '@/components/shared/tableCells'
import type { PlayerDetail } from '@/types/playerDetail'
import { usePlayersSearchStore } from '@/stores/playersSearch'

const { t } = useI18n()
const { showSnackbar } = useSnackbar()
const { displayClasses } = useDisplay()
const router = useRouter()
const playersSearchStore = usePlayersSearchStore()

const players = ref<PlayerDetail[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
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

// 所属作品の絞り込み。'' は絞り込まない（すべて）
const seriesFilter = ref('')
const seriesOptions = computed(() => [
  { title: t('playerList.filters.seriesAll'), value: '' },
  ...Object.entries(seriesLabelMap).map(([value, title]) => ({ title, value })),
])

const headers = computed(() => [
  { title: t('playerList.headers.number'), key: 'number', width: '10%', cellProps: tableCell.lead },
  { title: t('playerList.headers.name'), key: 'name', width: '40%', cellProps: tableCell.title },
  { title: '所属作品', key: 'series', sortable: false, width: '20%', cellProps: tableCell.sub1 },
  {
    title: 'カード数',
    key: 'card_count',
    sortable: false,
    width: '15%',
    cellProps: tableCell.sub2,
  },
  {
    title: t('playerList.headers.actions'),
    key: 'actions',
    sortable: false,
    width: '15%',
    cellProps: tableCell.act,
  },
])

const filteredPlayers = computed(() => {
  let result = players.value

  if (seriesFilter.value) {
    result = result.filter((player) => player.series === seriesFilter.value)
  }

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
  fetchFailed.value = false
  try {
    const response = await axios.get<PlayerDetail[]>('/players')
    players.value = response.data
  } catch {
    // 取得の失敗はページ内のアラート（AsyncState）で出す。スナックバーは保存・削除の成否だけ
    fetchFailed.value = true
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
    { destructive: true },
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
.players-filter--search {
  flex: 0 1 260px;
  min-width: 180px;
}
.players-filter--series {
  flex: 0 1 190px;
  min-width: 150px;
}

@media (max-width: 599.98px) {
  .players-filter--search,
  .players-filter--series {
    flex: 1 1 100%;
  }
}

.card-count-link {
  color: rgb(var(--v-theme-link));
  text-decoration: underline;
  text-underline-offset: 2px;
  font-size: 0.88em;
}
</style>
