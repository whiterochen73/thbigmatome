<template>
  <PageLayout>
    <template #filters>
      <v-text-field
        v-model="filterName"
        label="選手名検索"
        prepend-inner-icon="mdi-magnify"
        density="compact"
        hide-details
        variant="outlined"
        clearable
        class="cards-filter cards-filter--search"
        data-testid="player-cards-search"
        @keyup.enter="fetchPlayerCards"
        @click:clear="fetchPlayerCards"
      />
      <v-select
        v-model="filterCardSetId"
        :items="cardSets"
        item-title="name"
        item-value="id"
        label="カードセット"
        density="compact"
        hide-details
        clearable
        variant="outlined"
        class="cards-filter cards-filter--set"
      />
      <v-btn-toggle
        v-model="filterCardType"
        mandatory
        density="compact"
        rounded="sm"
        variant="outlined"
        selected-class="bg-primary"
        :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
      >
        <v-btn value="" size="small">全種</v-btn>
        <v-btn value="pitcher" size="small">投手</v-btn>
        <v-btn value="batter" size="small">野手</v-btn>
      </v-btn-toggle>
      <span class="text-caption cards-count">{{ totalCount }}件</span>
      <v-btn-toggle
        v-model="viewMode"
        mandatory
        density="compact"
        rounded="sm"
        variant="outlined"
        selected-class="bg-primary"
        class="cards-view-mode"
        :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
      >
        <v-btn value="table" size="small" title="テーブル表示" aria-label="テーブル表示">
          <v-icon size="small">mdi-table</v-icon>
        </v-btn>
        <v-btn value="grid" size="small" title="グリッド表示" aria-label="グリッド表示">
          <v-icon size="small">mdi-view-grid</v-icon>
        </v-btn>
      </v-btn-toggle>
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="選手カードの取得に失敗しました"
      :empty="playerCards.length === 0"
      empty-icon="mdi-card-account-details-outline"
      empty-message="該当する選手カードがありません"
      @retry="fetchPlayerCards"
    >
      <!-- テーブル表示 -->
      <v-card v-if="viewMode === 'table'">
        <v-data-table
          :headers="headers"
          :items="playerCards"
          :server-items-length="totalCount"
          v-model:page="currentPage"
          :items-per-page="perPage"
          :items-per-page-options="[{ value: 50, title: '50' }]"
          class="ui-table"
          @update:page="fetchPlayerCards"
          density="compact"
          hover
          @click:row="(_: Event, { item }: { item: PlayerCard }) => navigateToDetail(item.id)"
        >
          <template v-slot:[`item.image_url`]="{ item }">
            <div class="thumb-box">
              <v-img v-if="item.image_url" :src="item.image_url" width="28" height="40" cover />
              <template v-else>No<br />IMG</template>
            </div>
          </template>
          <template v-slot:[`item.card_type`]="{ item }">
            <v-chip
              :color="item.card_type === 'pitcher' ? 'tag-pitcher' : 'tag-fielder'"
              size="x-small"
              variant="flat"
              :prepend-icon="item.card_type === 'pitcher' ? 'mdi-baseball' : 'mdi-baseball-bat'"
            >
              {{ item.card_type === 'pitcher' ? '投手' : '野手' }}
            </v-chip>
          </template>
        </v-data-table>
      </v-card>

      <!-- グリッド表示 -->
      <v-row v-else-if="viewMode === 'grid'">
        <v-col v-for="card in playerCards" :key="card.id" cols="12" sm="6" md="4" lg="3">
          <PlayerCardItem :card="card" @click="navigateToDetail(card.id)" />
        </v-col>
      </v-row>

      <!-- グリッドモード用ページネーション（テーブルはv-data-table内蔵を使用） -->
      <div v-if="viewMode === 'grid'" class="d-flex align-center justify-end mt-2">
        <span class="text-caption mr-3">全{{ totalCount }}件</span>
        <v-pagination
          v-model="currentPage"
          :length="totalPages"
          :total-visible="7"
          size="small"
          @update:model-value="fetchPlayerCards"
        ></v-pagination>
      </div>
    </AsyncState>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, onBeforeRouteLeave } from 'vue-router'
import axios from '@/plugins/axios'
import PlayerCardItem from '@/components/PlayerCardItem.vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import { usePlayerCardsSearchStore } from '@/stores/playerCardsSearch'

interface CardSet {
  id: number
  name: string
  year: number
}

interface PlayerCard {
  id: number
  card_set_id: number
  player_id: number
  card_type: 'pitcher' | 'batter'
  player_name: string
  player_number: string
  card_set_name: string
  speed: number
  steal_start: number
  steal_end: number
  injury_rate: number
  primary_position: string | null
  cost?: number | null
  image_url?: string | null
}

const headers = [
  { title: '', key: 'image_url', sortable: false, width: 50 },
  { title: '背番号', key: 'player_number', sortable: false, width: 70 },
  { title: '選手名', key: 'player_name', sortable: false },
  { title: '種別', key: 'card_type', sortable: false, width: 90 },
  { title: 'ポジション', key: 'primary_position', sortable: false, width: 90 },
  { title: '走力', key: 'speed', sortable: false, width: 60 },
  { title: 'コスト', key: 'cost', sortable: false, width: 80 },
  { title: 'カードセット', key: 'card_set_name', sortable: false, width: 110 },
]

const router = useRouter()
const store = usePlayerCardsSearchStore()
const playerCards = ref<PlayerCard[]>([])
const cardSets = ref<CardSet[]>([])
const loading = ref(true)
const fetchFailed = ref(false)
const totalCount = ref(0)
const perPage = 50

const filterCardSetId = ref<number | null>(store.filterCardSetId)
const filterCardType = ref(store.filterCardType)
const filterName = ref(store.filterName)
const currentPage = ref(store.currentPage)
const viewMode = ref<'table' | 'grid'>(store.viewMode)

const totalPages = computed(() => Math.ceil(totalCount.value / perPage) || 1)

onMounted(async () => {
  fetchCardSets()
  await fetchPlayerCards()
  window.scrollTo(0, store.scrollY)
})

onBeforeRouteLeave(() => {
  store.filterCardSetId = filterCardSetId.value
  store.filterCardType = filterCardType.value
  store.filterName = filterName.value
  store.currentPage = currentPage.value
  store.viewMode = viewMode.value
  store.setScrollY(window.scrollY)
})

watch([filterCardSetId, filterCardType], () => {
  currentPage.value = 1
  fetchPlayerCards()
})

async function fetchCardSets() {
  try {
    const response = await axios.get<CardSet[]>('/card_sets')
    cardSets.value = response.data
  } catch (error) {
    console.error('Error fetching card sets:', error)
  }
}

async function fetchPlayerCards() {
  loading.value = true
  fetchFailed.value = false
  try {
    const params: Record<string, string | number> = {
      page: currentPage.value,
      per_page: perPage,
    }
    if (filterCardSetId.value) params.card_set_id = filterCardSetId.value
    if (filterCardType.value) params.card_type = filterCardType.value
    if (filterName.value) params.name = filterName.value

    const response = await axios.get<{ player_cards: PlayerCard[]; meta: { total: number } }>(
      '/player_cards',
      { params },
    )
    playerCards.value = response.data.player_cards
    totalCount.value = response.data.meta.total
  } catch (error) {
    fetchFailed.value = true
    console.error('Error fetching player cards:', error)
  } finally {
    loading.value = false
  }
}

function navigateToDetail(id: number) {
  router.push({ name: 'PlayerCardDetail', params: { id } })
}
</script>

<style scoped>
.cards-filter--search {
  flex: 0 1 260px;
  min-width: 180px;
}
.cards-filter--set {
  flex: 0 1 220px;
  min-width: 160px;
}
.cards-view-mode {
  margin-inline-start: auto;
}

@media (max-width: 599.98px) {
  .cards-filter--search,
  .cards-filter--set {
    flex: 1 1 100%;
  }
}

.thumb-box {
  width: 28px;
  height: 40px;
  background: rgb(var(--v-theme-surface-variant));
  border-radius: 2px;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6em;
  color: rgb(var(--v-theme-on-surface-variant));
  text-align: center;
  line-height: 1.2;
}
</style>
