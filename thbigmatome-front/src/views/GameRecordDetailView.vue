<template>
  <v-container>
    <!-- エラー（常時表示） -->
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

    <!-- ローディング -->
    <v-row v-if="loading">
      <v-col class="text-center py-8">
        <v-progress-circular indeterminate color="primary" />
      </v-col>
    </v-row>

    <template v-else-if="gameRecord">
      <!-- ヘッダー: 試合サマリー -->
      <v-row>
        <v-col cols="12" class="d-flex align-center flex-wrap gap-2">
          <v-btn
            variant="text"
            icon="mdi-arrow-left"
            size="small"
            @click="router.push({ name: '試合記録' })"
          />
          <h1 class="text-h5">vs {{ gameRecord.opponent_team_name }}</h1>
          <v-chip
            :color="gameRecord.status === 'confirmed' ? 'success' : 'amber-darken-2'"
            size="small"
            label
            class="ml-1"
          >
            {{ gameRecord.status === 'confirmed' ? '確定済み' : '未確定' }}
          </v-chip>
        </v-col>
      </v-row>

      <v-row class="mb-2">
        <v-col cols="12">
          <v-card variant="outlined" density="compact">
            <v-card-text class="py-2">
              <v-row no-gutters>
                <v-col cols="auto" class="mr-4">
                  <span class="text-caption text-grey">日付</span><br />
                  <span>{{ formatDate(gameRecord.game_date) }}</span>
                </v-col>
                <v-col cols="auto" class="mr-4">
                  <span class="text-caption text-grey">スコア</span><br />
                  <span class="font-weight-bold">
                    {{ gameRecord.score_away ?? '?' }} - {{ gameRecord.score_home ?? '?' }}
                  </span>
                </v-col>
                <v-col cols="auto" class="mr-4" v-if="gameRecord.stadium">
                  <span class="text-caption text-grey">球場</span><br />
                  <span>{{ gameRecord.stadium }}</span>
                </v-col>
                <v-col cols="auto">
                  <span class="text-caption text-grey">打席数</span><br />
                  <span>{{ gameRecord.at_bat_records?.length ?? '-' }}</span>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 成功通知 -->
      <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="2000" location="top">
        {{ snackbarMessage }}
      </v-snackbar>

      <!-- レビュー進捗バー (draft時のみ) -->
      <div v-if="gameRecord.status === 'draft'" class="review-progress mb-3">
        <div class="d-flex align-center justify-space-between mb-1">
          <span class="text-caption text-grey">確認済み打席</span>
          <span class="text-caption font-weight-bold">{{ reviewedCount }} / {{ totalCount }}</span>
        </div>
        <v-progress-linear
          :model-value="reviewProgress"
          color="success"
          bg-color="grey-lighten-3"
          rounded
          height="8"
        />
      </div>

      <!-- フィルタバー -->
      <div class="filter-bar mb-3">
        <v-chip-group v-model="activeFilter" mandatory>
          <v-chip value="all" label variant="outlined" filter>全て</v-chip>
          <v-chip value="declaration" label variant="outlined" filter>📢 宣言のみ</v-chip>
          <v-chip value="dice" label variant="outlined" filter>🎲 ダイスのみ</v-chip>
          <v-chip value="discrepancy" label variant="outlined" filter color="error"
            >⚠️ 差異あり</v-chip
          >
        </v-chip-group>
      </div>

      <!-- イニング別タイムライン -->
      <div v-for="group in inningGroups" :key="group.key" class="inning-section mb-4">
        <!-- イニングサマリーバー -->
        <div
          class="inning-header d-flex align-center gap-3 px-3 py-2 cursor-pointer"
          :class="group.half === 'top' ? 'top-header' : 'bot-header'"
          @click="toggleInning(group.key)"
        >
          <span class="text-subtitle-2 font-weight-bold">{{ group.label }}</span>
          <span class="text-caption inning-meta">投手: {{ group.pitcher }}</span>
          <span class="text-caption inning-meta">打席数: {{ group.records.length }}</span>
          <span class="text-caption inning-meta">得点: {{ group.totalRuns }}</span>
          <v-chip v-if="group.discrepancyCount > 0" color="error" size="x-small" label class="ml-1">
            ⚠️ 差異 {{ group.discrepancyCount }}
          </v-chip>
          <v-spacer />
          <v-icon size="small">
            {{ collapsedInnings[group.key] ? 'mdi-chevron-right' : 'mdi-chevron-down' }}
          </v-icon>
        </div>

        <!-- 打席カード群 -->
        <div v-show="!collapsedInnings[group.key]" class="inning-body pa-3">
          <AtBatCard
            v-for="ab in filteredRecords(group.records)"
            :key="ab.id"
            :ab="ab"
            :game-status="gameRecord.status"
            :active-filter="activeFilter"
            class="mb-3"
            @updated="onAtBatUpdated"
          />
        </div>
      </div>

      <!-- アクションバー (draft時) -->
      <v-row v-if="gameRecord.status === 'draft'" class="mt-2">
        <v-col cols="12" class="d-flex justify-end gap-3">
          <v-btn
            color="amber-darken-2"
            variant="outlined"
            prepend-icon="mdi-check-all"
            @click="bulkConfirmDialog = true"
          >
            全打席確定
          </v-btn>
          <v-btn
            color="success"
            variant="elevated"
            :loading="confirming"
            prepend-icon="mdi-check-circle"
            @click="confirmGameRecord"
          >
            このゲームを確定
          </v-btn>
        </v-col>
      </v-row>
    </template>

    <!-- not found -->
    <v-row v-else-if="!loading">
      <v-col class="text-center py-8 text-grey"> 試合記録が見つかりません </v-col>
    </v-row>

    <!-- 全打席確定ダイアログ -->
    <v-dialog v-model="bulkConfirmDialog" max-width="400">
      <v-card>
        <v-card-title>全打席を確認済みにする</v-card-title>
        <v-card-text>
          全 {{ totalCount }} 打席を「確認済み」としてマークします。<br />
          この操作は取り消せません。続けますか？
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="bulkConfirmDialog = false">キャンセル</v-btn>
          <v-btn
            color="amber-darken-2"
            variant="elevated"
            :loading="bulkConfirming"
            @click="bulkMarkReviewed"
          >
            確定する
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, reactive } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import axios from '@/plugins/axios'
import AtBatCard from '@/components/AtBatCard.vue'

interface Discrepancy {
  field: string
  text_value: unknown
  gsm_value: unknown
  cause: 'parser_misread' | 'human_error' | 'gsm_limitation' | 'ambiguous' | 'unknown'
  resolution: 'gsm' | 'text' | 'manual' | null
  note?: string
}

interface SourceEvent {
  seq?: number
  type: 'declaration' | 'dice' | 'auto' | 'skip'
  [key: string]: unknown
}

interface AtBatRecord {
  id: number
  game_record_id: number
  inning: number
  half: 'top' | 'bottom'
  ab_num: number
  batter_name: string
  pitcher_name: string
  result_code: string | null
  runs_scored: number | null
  runners_before: unknown
  runners_after: unknown
  outs_before: number | null
  outs_after: number | null
  strategy: string | null
  play_description: string | null
  is_modified: boolean
  is_reviewed: boolean
  review_notes: string | null
  modified_fields: unknown
  discrepancies: Discrepancy[]
  source_events: SourceEvent[] | null
}

interface GameRecord {
  id: number
  game_date: string
  team_id: number
  opponent_team_name: string
  score_home: number | null
  score_away: number | null
  status: 'draft' | 'confirmed'
  stadium: string | null
  at_bat_records: AtBatRecord[]
}

interface InningGroup {
  key: string
  label: string
  half: 'top' | 'bottom'
  pitcher: string
  totalRuns: number
  discrepancyCount: number
  records: AtBatRecord[]
}

const router = useRouter()
const route = useRoute()

const gameRecord = ref<GameRecord | null>(null)
const loading = ref(false)
const confirming = ref(false)
const bulkConfirming = ref(false)
const bulkConfirmDialog = ref(false)
const errorMessage = ref('')
const snackbar = ref(false)
const snackbarMessage = ref('')
const snackbarColor = ref('success')

const activeFilter = ref('all')
const collapsedInnings = reactive<Record<string, boolean>>({})

const reviewedCount = computed(() => {
  return gameRecord.value?.at_bat_records?.filter((ab) => ab.is_reviewed).length ?? 0
})

const totalCount = computed(() => {
  return gameRecord.value?.at_bat_records?.length ?? 0
})

const reviewProgress = computed(() => {
  if (totalCount.value === 0) return 0
  return Math.round((reviewedCount.value / totalCount.value) * 100)
})

const inningGroups = computed<InningGroup[]>(() => {
  if (!gameRecord.value?.at_bat_records) return []
  const map = new Map<string, AtBatRecord[]>()
  for (const ab of gameRecord.value.at_bat_records) {
    const key = `${ab.inning}-${ab.half}`
    if (!map.has(key)) map.set(key, [])
    map.get(key)!.push(ab)
  }
  const result: InningGroup[] = []
  map.forEach((records, key) => {
    const [inning, half] = key.split('-')
    const totalRuns = records.reduce((sum, ab) => sum + (ab.runs_scored ?? 0), 0)
    const discrepancyCount = records.filter((ab) => ab.discrepancies?.length).length
    const pitcher = records[0]?.pitcher_name ?? '-'
    result.push({
      key,
      label: `${inning}回${half === 'top' ? '表' : '裏'}`,
      half: half as 'top' | 'bottom',
      pitcher,
      totalRuns,
      discrepancyCount,
      records,
    })
  })
  return result
})

function toggleInning(key: string) {
  collapsedInnings[key] = !collapsedInnings[key]
}

function filteredRecords(records: AtBatRecord[]): AtBatRecord[] {
  if (activeFilter.value === 'discrepancy') {
    return records.filter((ab) => ab.discrepancies?.length)
  }
  return records
}

function formatDate(dateStr: string): string {
  if (!dateStr) return '-'
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}`
}

function showSnackbar(message: string, color: string) {
  snackbarMessage.value = message
  snackbarColor.value = color
  snackbar.value = true
}

function onAtBatUpdated(updatedAb: AtBatRecord) {
  if (!gameRecord.value) return
  const idx = gameRecord.value.at_bat_records.findIndex((ab) => ab.id === updatedAb.id)
  if (idx !== -1) {
    gameRecord.value.at_bat_records[idx] = updatedAb
  }
  showSnackbar('保存しました', 'success')
}

async function bulkMarkReviewed() {
  if (!gameRecord.value) return
  bulkConfirming.value = true
  try {
    const unreviewed = gameRecord.value.at_bat_records.filter((ab) => !ab.is_reviewed)
    await Promise.all(
      unreviewed.map((ab) =>
        axios
          .patch<AtBatRecord>(`/at_bat_records/${ab.id}`, { is_reviewed: true })
          .then((r) => onAtBatUpdated(r.data)),
      ),
    )
    bulkConfirmDialog.value = false
    showSnackbar('全打席を確認済みにしました', 'success')
  } catch {
    showSnackbar('一括確定に失敗しました', 'error')
  } finally {
    bulkConfirming.value = false
  }
}

async function confirmGameRecord() {
  if (!gameRecord.value) return
  confirming.value = true
  try {
    const response = await axios.post<GameRecord>(`/game_records/${gameRecord.value.id}/confirm`)
    gameRecord.value.status = response.data.status
    // 全打席のis_reviewedをtrueに更新(BE側でも更新済み)
    if (gameRecord.value.at_bat_records) {
      gameRecord.value.at_bat_records.forEach((ab) => {
        ab.is_reviewed = true
      })
    }
    showSnackbar('確定しました', 'success')
  } catch {
    showSnackbar('確定に失敗しました', 'error')
  } finally {
    confirming.value = false
  }
}

onMounted(async () => {
  loading.value = true
  errorMessage.value = ''
  try {
    const id = route.params.id
    const response = await axios.get<GameRecord>(`/game_records/${id}`)
    gameRecord.value = response.data
  } catch {
    errorMessage.value = '試合記録の取得に失敗しました'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}

/* ── フィルタバー ── */
.filter-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

/* ── レビュー進捗バー ── */
.review-progress {
  background: #f8f8f6;
  border: 1px solid #e0e0e0;
  border-radius: 6px;
  padding: 10px 14px;
}

/* ── イニングセクション ── */
.inning-section {
  border: 1px solid #ccc;
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.07);
}

.inning-header {
  user-select: none;
}

.top-header {
  background: #1b3a6b;
  color: white;
}

.bot-header {
  background: #2c5f2e;
  color: white;
}

.inning-meta {
  opacity: 0.85;
}

.inning-body {
  background: #fafaf8;
}
</style>
