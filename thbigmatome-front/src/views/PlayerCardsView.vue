<template>
  <v-container style="max-width: 1080px">
    <PageHeader title="選手カード一覧" />

    <FilterBar>
      <template #search>
        <v-text-field
          v-model="filterName"
          label="選手名検索"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          hide-details
          variant="outlined"
          clearable
          @keyup.enter="fetchPlayerCards"
          @click:clear="fetchPlayerCards"
        />
      </template>
      <template #filters>
        <div class="d-flex align-center flex-wrap gap-3">
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
            style="min-width: 160px; max-width: 220px"
          />
          <v-btn-toggle
            v-model="filterCardType"
            mandatory
            density="compact"
            rounded="sm"
            color="primary"
          >
            <v-btn value="" size="small">全種</v-btn>
            <v-btn value="pitcher" size="small">投手</v-btn>
            <v-btn value="batter" size="small">野手</v-btn>
          </v-btn-toggle>
          <span class="text-caption">{{ totalCount }}件</span>
        </div>
      </template>
      <template #toggles>
        <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="sm" color="primary">
          <v-btn value="table" size="small" title="テーブル表示">
            <v-icon size="small">mdi-table</v-icon>
          </v-btn>
          <v-btn value="grid" size="small" title="グリッド表示">
            <v-icon size="small">mdi-view-grid</v-icon>
          </v-btn>
        </v-btn-toggle>
      </template>
    </FilterBar>

    <!-- エラーメッセージ -->
    <v-alert
      v-if="errorMessage"
      type="error"
      variant="tonal"
      class="mb-3"
      closable
      @click:close="errorMessage = ''"
    >
      {{ errorMessage }}
    </v-alert>

    <!-- テーブル表示 -->
    <template v-if="viewMode === 'table'">
      <DataCard title="">
        <v-data-table
          :headers="headers"
          :items="playerCards"
          :loading="loading"
          :server-items-length="totalCount"
          v-model:page="currentPage"
          :items-per-page="perPage"
          :items-per-page-options="[{ value: 50, title: '50' }]"
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
              :color="item.card_type === 'pitcher' ? 'blue' : 'green'"
              size="x-small"
              variant="tonal"
            >
              {{ item.card_type === 'pitcher' ? '投手' : '野手' }}
            </v-chip>
          </template>
        </v-data-table>
      </DataCard>
    </template>

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
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, onBeforeRouteLeave } from 'vue-router'
import axios from '@/plugins/axios'
import PlayerCardItem from '@/components/PlayerCardItem.vue'
import PageHeader from '@/components/shared/PageHeader.vue'
import FilterBar from '@/components/shared/FilterBar.vue'
import DataCard from '@/components/shared/DataCard.vue'
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
const loading = ref(false)
const errorMessage = ref('')
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
  errorMessage.value = ''
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
    errorMessage.value = '選手カードの取得に失敗しました'
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
.thumb-box {
  width: 28px;
  height: 40px;
  background: #e8e0d4;
  border-radius: 2px;
  border: 1px solid var(--usuiro);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.6em;
  color: #aaa;
  text-align: center;
  line-height: 1.2;
}
</style>
