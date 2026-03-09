<template>
  <v-container style="max-width: 1080px">
    <!-- タイトル -->
    <div class="d-flex align-center mb-2">
      <h1 class="text-h5 font-weight-bold">選手カード一覧</h1>
    </div>

    <!-- フィルタバー -->
    <div class="list-filters">
      <span class="filter-label">カードセット:</span>
      <v-select
        v-model="filterCardSetId"
        :items="cardSets"
        item-title="name"
        item-value="id"
        density="compact"
        hide-details
        clearable
        variant="outlined"
        style="max-width: 170px; font-size: 0.82em"
      ></v-select>

      <span class="filter-label">種別:</span>
      <div class="type-btn-group">
        <button
          class="type-btn"
          :class="{ active: filterCardType === '' }"
          @click="filterCardType = ''"
        >
          全種
        </button>
        <button
          class="type-btn"
          :class="{ active: filterCardType === 'pitcher' }"
          @click="filterCardType = 'pitcher'"
        >
          投手
        </button>
        <button
          class="type-btn"
          :class="{ active: filterCardType === 'batter' }"
          @click="filterCardType = 'batter'"
        >
          野手
        </button>
      </div>

      <span class="filter-label">選手名:</span>
      <input
        class="search-input"
        v-model="filterName"
        placeholder="検索..."
        @keyup.enter="fetchPlayerCards"
      />

      <v-btn
        size="small"
        color="primary"
        @click="fetchPlayerCards"
        :loading="loading"
        class="search-btn"
        >検索</v-btn
      >

      <span class="result-count">{{ totalCount }}件</span>

      <div class="view-toggle-wrap">
        <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="sm" color="primary">
          <v-btn value="table" size="small" title="テーブル表示">
            <v-icon size="small">mdi-table</v-icon>
          </v-btn>
          <v-btn value="grid" size="small" title="グリッド表示">
            <v-icon size="small">mdi-view-grid</v-icon>
          </v-btn>
        </v-btn-toggle>
      </div>
    </div>

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
      <v-progress-linear
        v-if="loading"
        indeterminate
        color="primary"
        class="mb-2"
      ></v-progress-linear>
      <table class="player-list-table" v-else>
        <thead>
          <tr>
            <th style="width: 50px"></th>
            <th class="ctr" style="width: 70px">背番号</th>
            <th>選手名</th>
            <th class="ctr" style="width: 90px">種別</th>
            <th class="ctr" style="width: 80px">ポジション</th>
            <th class="ctr" style="width: 60px">走力</th>
            <th class="ctr" style="width: 80px">コスト</th>
            <th class="ctr" style="width: 110px">カードセット</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="card in playerCards"
            :key="card.id"
            class="table-row"
            @click="navigateToDetail(card.id)"
          >
            <td>
              <div class="thumb-box">No<br />IMG</div>
            </td>
            <td class="ctr" style="font-weight: bold">{{ card.player_number }}</td>
            <td style="font-weight: bold">{{ card.player_name }}</td>
            <td class="ctr">
              <span class="type-chip" :class="card.card_type">
                {{ card.card_type === 'pitcher' ? '投手' : '野手' }}
              </span>
            </td>
            <td class="ctr" style="font-size: 0.85em">{{ card.primary_position ?? '—' }}</td>
            <td class="ctr speed-val">{{ card.speed }}</td>
            <td class="ctr" style="font-size: 0.86em">{{ card.cost ?? '—' }}</td>
            <td class="ctr" style="font-size: 0.78em; color: #888">{{ card.card_set_name }}</td>
          </tr>
        </tbody>
      </table>
    </template>

    <!-- グリッド表示 -->
    <v-row v-else-if="viewMode === 'grid'">
      <v-col v-for="card in playerCards" :key="card.id" cols="12" sm="6" md="4" lg="3">
        <PlayerCardItem :card="card" @click="navigateToDetail(card.id)" />
      </v-col>
    </v-row>

    <!-- ページネーション -->
    <div class="d-flex align-center justify-end mt-2">
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
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import PlayerCardItem from '@/components/PlayerCardItem.vue'

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
}

const router = useRouter()
const playerCards = ref<PlayerCard[]>([])
const cardSets = ref<CardSet[]>([])
const loading = ref(false)
const errorMessage = ref('')
const totalCount = ref(0)
const currentPage = ref(1)
const perPage = 50

const filterCardSetId = ref<number | null>(null)
const filterCardType = ref('')
const filterName = ref('')
const viewMode = ref<'table' | 'grid'>('table')

const totalPages = computed(() => Math.ceil(totalCount.value / perPage) || 1)

onMounted(() => {
  fetchCardSets()
  fetchPlayerCards()
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
/* ── フィルタバー ── */
.list-filters {
  display: flex;
  gap: 8px;
  margin-bottom: 10px;
  flex-wrap: wrap;
  align-items: center;
  background: white;
  border: 1px solid #ddd;
  border-radius: 5px;
  padding: 8px 12px;
}

.filter-label {
  font-size: 0.79em;
  color: #666;
  white-space: nowrap;
}

.type-btn-group {
  display: flex;
  border: 1px solid #ccc;
  border-radius: 4px;
  overflow: hidden;
}

.type-btn {
  padding: 4px 12px;
  background: white;
  border: none;
  cursor: pointer;
  font-size: 0.82em;
  border-right: 1px solid #ccc;
}

.type-btn:last-child {
  border-right: none;
}

.type-btn.active {
  background: var(--ai);
  color: white;
}

.type-btn:hover:not(.active) {
  background: #f0eadd;
}

.search-input {
  padding: 4px 8px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 0.82em;
  min-width: 140px;
  outline: none;
}

.search-input:focus {
  border-color: var(--ai-light);
}

.search-btn {
  margin-left: 2px;
}

.result-count {
  font-size: 0.78em;
  color: #888;
  white-space: nowrap;
}

.view-toggle-wrap {
  margin-left: auto;
}

/* ── 一覧テーブル ── */
.player-list-table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.player-list-table thead th {
  background: var(--ai);
  color: white;
  padding: 7px 10px;
  font-size: 0.8em;
  text-align: left;
  font-weight: bold;
}

.player-list-table thead th.ctr {
  text-align: center;
}

.player-list-table tbody tr {
  border-bottom: 1px solid #eee;
  cursor: pointer;
  transition: background 0.1s;
}

.player-list-table tbody tr:hover {
  background: #f0eadd;
}

.player-list-table tbody td {
  padding: 5px 10px;
  font-size: 0.86em;
  vertical-align: middle;
}

.player-list-table tbody td.ctr {
  text-align: center;
}

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

.type-chip {
  padding: 2px 9px;
  border-radius: 10px;
  font-size: 0.75em;
  font-weight: bold;
  display: inline-block;
}

.type-chip.pitcher {
  background: #dbeafe;
  color: #1e40af;
  border: 1px solid #bfdbfe;
}

.type-chip.batter {
  background: #dcfce7;
  color: #166534;
  border: 1px solid #bbf7d0;
}

.speed-val {
  font-weight: bold;
  color: var(--ai);
}
</style>
