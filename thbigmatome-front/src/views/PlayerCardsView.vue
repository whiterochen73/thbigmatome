<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="d-flex align-center">
        <h1 class="text-h4">選手カード一覧</h1>
      </v-col>
    </v-row>

    <!-- フィルター -->
    <v-row>
      <v-col cols="12" sm="3">
        <v-select
          v-model="filterCardSetId"
          :items="cardSets"
          item-title="name"
          item-value="id"
          label="カードセット"
          density="compact"
          clearable
        ></v-select>
      </v-col>
      <v-col cols="12" sm="3" class="d-flex align-center">
        <v-btn-toggle v-model="filterCardType" density="compact" rounded="sm" color="primary">
          <v-btn value="">全種別</v-btn>
          <v-btn value="pitcher">投手</v-btn>
          <v-btn value="batter">野手</v-btn>
        </v-btn-toggle>
      </v-col>
      <v-col cols="12" sm="4">
        <v-text-field
          v-model="filterName"
          label="選手名"
          density="compact"
          clearable
          @keyup.enter="fetchPlayerCards"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2" class="d-flex align-center">
        <v-btn color="primary" @click="fetchPlayerCards" :loading="loading">検索</v-btn>
      </v-col>
    </v-row>

    <!-- テーブル -->
    <v-row>
      <v-col cols="12">
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

        <v-data-table
          :headers="headers"
          :items="playerCards"
          :loading="loading"
          class="elevation-1"
          density="compact"
          item-value="id"
          :items-per-page="perPage"
          @click:row="(_: Event, row: { item: PlayerCard }) => navigateToDetail(row.item.id)"
          style="cursor: pointer"
        >
          <template v-slot:[`item.image`]="{ item }">
            <v-img
              v-if="item.card_image_path"
              :src="`http://localhost:3000${item.card_image_path}`"
              width="36"
              height="50"
              cover
            ></v-img>
            <v-icon v-else>mdi-card-account-details</v-icon>
          </template>

          <template v-slot:[`item.card_type`]="{ item }">
            <v-chip :color="item.card_type === 'pitcher' ? 'blue' : 'green'" size="small" label>
              {{ item.card_type === 'pitcher' ? '投手' : '野手' }}
            </v-chip>
          </template>
        </v-data-table>

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
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'

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
  card_image_path: string | null
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

const totalPages = computed(() => Math.ceil(totalCount.value / perPage) || 1)

const headers = [
  { title: '', key: 'image', width: '60px', sortable: false },
  { title: '背番号', key: 'player_number', width: '80px' },
  { title: '選手名', key: 'player_name' },
  { title: 'カードセット', key: 'card_set_name' },
  { title: '種別', key: 'card_type', width: '100px' },
  { title: '走力', key: 'speed', width: '70px' },
]

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
