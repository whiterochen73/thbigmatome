<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="d-flex align-center">
        <h1 class="text-h4">試合記録</h1>
        <v-spacer></v-spacer>
        <v-btn color="primary" @click="navigateToImport">ログ取り込み</v-btn>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12" sm="4">
        <v-select
          v-model="filterCompetitionId"
          :items="competitions"
          item-title="name"
          item-value="id"
          label="大会"
          density="compact"
          clearable
        ></v-select>
      </v-col>
      <v-col cols="12" sm="3">
        <v-text-field
          v-model="filterFrom"
          label="開始日"
          type="date"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="3">
        <v-text-field
          v-model="filterTo"
          label="終了日"
          type="date"
          density="compact"
        ></v-text-field>
      </v-col>
      <v-col cols="12" sm="2" class="d-flex align-center">
        <v-btn color="primary" @click="fetchGames" :loading="loading">検索</v-btn>
      </v-col>
    </v-row>

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
          :items="games"
          :loading="loading"
          class="elevation-1"
          density="compact"
        >
          <template v-slot:[`item.status`]="{ item }">
            <v-chip
              :color="item.status === 'confirmed' ? 'green' : 'orange'"
              size="small"
            >
              {{ item.status }}
            </v-chip>
          </template>
          <template v-slot:[`item.actions`]="{ item }">
            <v-btn size="small" variant="text" @click="navigateToDetail(item.id)">詳細</v-btn>
          </template>
        </v-data-table>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

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
}

const games = ref<Game[]>([])
const competitions = ref<Competition[]>([])
const loading = ref(false)
const errorMessage = ref('')

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
  { title: '操作', key: 'actions', sortable: false, width: '100px' },
]

onMounted(() => {
  fetchGames()
  fetchCompetitions()
})

async function fetchGames() {
  loading.value = true
  errorMessage.value = ''
  try {
    const params: Record<string, string | number> = {}
    if (filterCompetitionId.value !== null) params.competition_id = filterCompetitionId.value
    if (filterFrom.value) params.from = filterFrom.value
    if (filterTo.value) params.to = filterTo.value
    const response = await axios.get<Game[]>('/games', { params })
    games.value = response.data
  } catch (error) {
    errorMessage.value = '試合の取得に失敗しました'
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
  console.log('navigate to detail:', id)
}

function navigateToImport() {
  console.log('navigate to import')
}
</script>
