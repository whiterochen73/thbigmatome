<template>
  <PageLayout>
    <template #filters>
      <v-btn-toggle
        v-model="filterStatus"
        density="compact"
        rounded="sm"
        variant="outlined"
        selected-class="bg-primary"
        :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
      >
        <v-btn value="">全ステータス</v-btn>
        <v-btn value="draft">draft</v-btn>
        <v-btn value="confirmed">confirmed</v-btn>
      </v-btn-toggle>
      <v-chip
        color="state-neutral"
        variant="flat"
        prepend-icon="mdi-flask-outline"
        size="small"
        label
        class="record-beta"
        >β</v-chip
      >
    </template>

    <AsyncState
      framed
      :loading="loading"
      :error="fetchFailed"
      error-message="試合記録の取得に失敗しました"
      :empty="gameRecords.length === 0"
      empty-icon="mdi-clipboard-text-outline"
      empty-message="パーサー結果がありません"
      @retry="fetchGameRecords"
    >
      <v-card>
        <v-data-table
          :headers="headers"
          :items="filteredRecords"
          class="ui-table"
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
            <span v-else class="on-surface-variant">-</span>
          </template>

          <template v-slot:[`item.status`]="{ item }">
            <v-chip
              :color="item.status === 'confirmed' ? 'state-done' : 'state-todo'"
              size="small"
              label
              variant="flat"
              :prepend-icon="
                item.status === 'confirmed' ? 'mdi-check-circle' : 'mdi-circle-outline'
              "
            >
              {{ item.status === 'confirmed' ? '確定済み' : '未確定' }}
            </v-chip>
          </template>

          <template v-slot:[`item.action`]="{ item }">
            <v-btn
              size="x-small"
              variant="text"
              color="link"
              icon="mdi-arrow-right"
              :aria-label="`${formatDate(item.game_date)} vs ${item.opponent_team_name}の詳細を開く`"
              @click.stop="navigateToDetail(item.id)"
            />
          </template>
        </v-data-table>
      </v-card>
    </AsyncState>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'

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
const loading = ref(true)
const fetchFailed = ref(false)
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
  fetchFailed.value = false
  try {
    const response = await axios.get<{
      game_records: GameRecord[]
      pagination: Record<string, number>
    }>('/game_records')
    gameRecords.value = response.data.game_records
  } catch {
    fetchFailed.value = true
  } finally {
    loading.value = false
  }
}

function navigateToDetail(id: number) {
  router.push({ name: 'GameRecordDetail', params: { id } })
}
</script>
