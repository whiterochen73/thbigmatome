<template>
  <v-container>
    <PageHeader title="パーサー結果レビュー">
      <template #actions>
        <v-chip color="amber-darken-2" size="small" label>β</v-chip>
      </template>
    </PageHeader>

    <!-- フィルター -->
    <v-row class="mb-2">
      <v-col cols="12" sm="4">
        <v-btn-toggle v-model="filterStatus" density="compact" rounded="sm" color="primary">
          <v-btn value="">全ステータス</v-btn>
          <v-btn value="draft">draft</v-btn>
          <v-btn value="confirmed">confirmed</v-btn>
        </v-btn-toggle>
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
          :items="filteredRecords"
          :loading="loading"
          class="elevation-1"
          density="compact"
          item-value="id"
          :items-per-page="50"
          @click:row="(_: Event, row: { item: GameRecord }) => navigateToDetail(row.item.id)"
          style="cursor: pointer"
        >
          <template v-slot:[`item.game_date`]="{ item }">
            {{ formatDate(item.game_date) }}
          </template>

          <template v-slot:[`item.matchup`]="{ item }"> vs {{ item.opponent_team_name }} </template>

          <template v-slot:[`item.score`]="{ item }">
            <span v-if="item.score_home !== null && item.score_away !== null">
              {{ item.score_away }} - {{ item.score_home }}
            </span>
            <span v-else class="text-grey">-</span>
          </template>

          <template v-slot:[`item.status`]="{ item }">
            <v-chip
              :color="item.status === 'confirmed' ? 'success' : 'amber-darken-2'"
              size="small"
              label
            >
              {{ item.status === 'confirmed' ? '確定済み' : '未確定' }}
            </v-chip>
          </template>

          <template v-slot:[`item.action`]="{ item }">
            <v-btn
              size="x-small"
              variant="text"
              icon="mdi-arrow-right"
              @click.stop="navigateToDetail(item.id)"
            />
          </template>
        </v-data-table>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import PageHeader from '@/components/shared/PageHeader.vue'

interface GameRecord {
  id: number
  game_date: string
  team_id: number
  opponent_team_name: string
  score_home: number | null
  score_away: number | null
  status: 'draft' | 'confirmed'
  stadium: string | null
}

const router = useRouter()
const gameRecords = ref<GameRecord[]>([])
const loading = ref(false)
const errorMessage = ref('')
const filterStatus = ref('')

const filteredRecords = computed(() => {
  if (!filterStatus.value) return gameRecords.value
  return gameRecords.value.filter((r) => r.status === filterStatus.value)
})

const headers = [
  { title: '日付', key: 'game_date', width: '110px' },
  { title: '対戦カード', key: 'matchup', sortable: false },
  { title: 'スコア', key: 'score', sortable: false, width: '90px' },
  { title: '球場', key: 'stadium', width: '120px' },
  { title: 'ステータス', key: 'status', width: '110px' },
  { title: '', key: 'action', sortable: false, width: '50px' },
]

onMounted(() => {
  fetchGameRecords()
})

function formatDate(dateStr: string): string {
  if (!dateStr) return '-'
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}`
}

async function fetchGameRecords() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await axios.get<{
      game_records: GameRecord[]
      pagination: Record<string, number>
    }>('/game_records')
    gameRecords.value = response.data.game_records
  } catch {
    errorMessage.value = '試合記録の取得に失敗しました'
  } finally {
    loading.value = false
  }
}

function navigateToDetail(id: number) {
  router.push({ name: 'GameRecordDetail', params: { id } })
}
</script>
