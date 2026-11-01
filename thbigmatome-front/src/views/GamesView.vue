<template>
  <PageLayout>
    <template #filters>
      <v-select
        v-model="filterCompetitionId"
        :items="competitions"
        item-title="name"
        item-value="id"
        label="大会"
        density="compact"
        hide-details
        clearable
        class="games-filter games-filter--competition"
      ></v-select>
      <v-text-field
        v-model="filterFrom"
        label="開始日"
        type="date"
        density="compact"
        hide-details
        class="games-filter games-filter--date"
      ></v-text-field>
      <v-text-field
        v-model="filterTo"
        label="終了日"
        type="date"
        density="compact"
        hide-details
        class="games-filter games-filter--date"
      ></v-text-field>
    </template>
    <template #actions>
      <v-btn
        color="action"
        variant="flat"
        prepend-icon="mdi-magnify"
        :loading="loading"
        @click="fetchGames"
        >検索</v-btn
      >
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="試合の取得に失敗しました"
      :empty="games.length === 0"
      empty-icon="mdi-scoreboard-outline"
      empty-message="該当する試合がありません"
      @retry="fetchGames"
    >
      <v-card>
        <v-data-table :headers="headers" :items="games" class="ui-table" density="compact">
          <template v-slot:[`item.status`]="{ item }">
            <v-chip
              :color="item.status === 'confirmed' ? 'state-done' : 'state-todo'"
              size="small"
              variant="flat"
              :prepend-icon="
                item.status === 'confirmed' ? 'mdi-check-circle' : 'mdi-circle-outline'
              "
            >
              {{ item.status }}
            </v-chip>
          </template>
          <template v-slot:[`item.review`]="{ item }">
            <v-btn
              v-if="item.game_record_id"
              size="small"
              variant="text"
              color="link"
              @click="router.push(`/game-records/${item.game_record_id}`)"
              >レビュー</v-btn
            >
            <span v-else class="on-surface-variant">-</span>
          </template>
          <template v-slot:[`item.actions`]="{ item }">
            <v-btn size="small" variant="text" color="link" @click="navigateToDetail(item.id)"
              >詳細</v-btn
            >
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'

interface Competition {
  id: number
  name: string
}

interface Game {
  id: number
  competition_id: number
  home_team_id: number
  visitor_team_id: number
  real_date: string
  status: 'draft' | 'confirmed'
  source: string
  game_record_id?: number | null
}

const router = useRouter()
const games = ref<Game[]>([])
const competitions = ref<Competition[]>([])
const loading = ref(true)
const fetchFailed = ref(false)

const filterCompetitionId = ref<number | null>(null)
const filterFrom = ref('')
const filterTo = ref('')

const headers = [
  { title: 'ID', key: 'id', width: '80px' },
  { title: '日付', key: 'real_date' },
  { title: '大会', key: 'competition_id' },
  { title: 'ホームチームID', key: 'home_team_id' },
  { title: 'ビジターチームID', key: 'visitor_team_id' },
  { title: 'ステータス', key: 'status' },
  { title: 'レビュー', key: 'review', sortable: false, width: '90px' },
  { title: '操作', key: 'actions', sortable: false, width: '100px' },
]

onMounted(() => {
  fetchGames()
  fetchCompetitions()
})

async function fetchGames() {
  loading.value = true
  fetchFailed.value = false
  try {
    const params: Record<string, string | number> = {}
    if (filterCompetitionId.value !== null) params.competition_id = filterCompetitionId.value
    if (filterFrom.value) params.from = filterFrom.value
    if (filterTo.value) params.to = filterTo.value
    const response = await axios.get<Game[]>('/games', { params })
    games.value = response.data
  } catch (error) {
    fetchFailed.value = true
    console.error('Error fetching games:', error)
  } finally {
    loading.value = false
  }
}

async function fetchCompetitions() {
  try {
    const response = await axios.get<Competition[]>('/competitions')
    competitions.value = response.data
  } catch (error) {
    console.error('Error fetching competitions:', error)
  }
}

function navigateToDetail(id: number) {
  router.push({ name: '試合詳細', params: { id } })
}
</script>

<style scoped>
.games-filter--competition {
  flex: 0 1 220px;
  min-width: 160px;
}
.games-filter--date {
  flex: 0 1 160px;
  min-width: 140px;
}

@media (max-width: 599.98px) {
  .games-filter--competition,
  .games-filter--date {
    flex: 1 1 100%;
  }
}
</style>
