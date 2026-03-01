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
            @click="router.push({ name: 'GameRecordList' })"
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

      <!-- イニング別打席テーブル -->
      <div v-for="group in inningGroups" :key="group.key" class="mb-4">
        <div class="text-subtitle-2 font-weight-bold mb-1 ml-1">
          {{ group.label }}
        </div>
        <v-table density="compact" class="elevation-1">
          <thead>
            <tr>
              <th class="text-left" style="width: 40px">No</th>
              <th class="text-left" style="width: 100px">打者</th>
              <th class="text-left" style="width: 100px">投手</th>
              <th class="text-left" style="width: 80px">結果</th>
              <th class="text-left" style="width: 60px">得点</th>
              <th class="text-left" style="width: 90px">走者前</th>
              <th class="text-left" style="width: 90px">走者後</th>
              <th class="text-left" style="width: 80px">作戦</th>
              <th class="text-left" style="width: 120px">説明</th>
              <th style="width: 40px"></th>
            </tr>
          </thead>
          <tbody>
            <template v-for="ab in group.records" :key="ab.id">
              <tr
                :class="[
                  ab.is_modified ? 'bg-amber-lighten-5' : '',
                  ab.discrepancies?.length ? 'disc-row' : '',
                ]"
              >
                <td>{{ ab.ab_num }}</td>
                <td>{{ ab.batter_name }}</td>
                <td>{{ ab.pitcher_name }}</td>

                <!-- result_code インライン編集 -->
                <td>
                  <template v-if="editingId === ab.id && editingField === 'result_code'">
                    <v-text-field
                      v-model="editValue"
                      density="compact"
                      hide-details
                      variant="underlined"
                      style="min-width: 60px; max-width: 80px"
                      autofocus
                      @keyup.enter="saveEdit(ab)"
                      @keyup.escape="cancelEdit"
                      @blur="saveEdit(ab)"
                    />
                  </template>
                  <template v-else>
                    <v-chip
                      :color="resultColor(ab.result_code)"
                      size="x-small"
                      label
                      :class="gameRecord.status === 'draft' ? 'cursor-pointer' : ''"
                      @click="
                        gameRecord.status === 'draft' &&
                        startEdit(ab, 'result_code', ab.result_code)
                      "
                    >
                      {{ ab.result_code || '-' }}
                    </v-chip>
                  </template>
                </td>

                <!-- runs_scored インライン編集 -->
                <td>
                  <template v-if="editingId === ab.id && editingField === 'runs_scored'">
                    <v-text-field
                      v-model="editValue"
                      density="compact"
                      hide-details
                      variant="underlined"
                      type="number"
                      style="min-width: 50px; max-width: 60px"
                      autofocus
                      @keyup.enter="saveEdit(ab)"
                      @keyup.escape="cancelEdit"
                      @blur="saveEdit(ab)"
                    />
                  </template>
                  <template v-else>
                    <span
                      :class="
                        gameRecord.status === 'draft'
                          ? 'cursor-pointer text-decoration-underline-dotted'
                          : ''
                      "
                      @click="
                        gameRecord.status === 'draft' &&
                        startEdit(ab, 'runs_scored', String(ab.runs_scored ?? 0))
                      "
                    >
                      {{ ab.runs_scored ?? 0 }}
                    </span>
                  </template>
                </td>

                <!-- runners_before インライン編集 -->
                <td>
                  <template v-if="editingId === ab.id && editingField === 'runners_before'">
                    <v-text-field
                      v-model="editValue"
                      density="compact"
                      hide-details
                      variant="underlined"
                      style="min-width: 70px; max-width: 90px"
                      autofocus
                      @keyup.enter="saveEdit(ab)"
                      @keyup.escape="cancelEdit"
                      @blur="saveEdit(ab)"
                    />
                  </template>
                  <template v-else>
                    <span
                      class="text-caption text-mono"
                      :class="gameRecord.status === 'draft' ? 'cursor-pointer' : ''"
                      @click="
                        gameRecord.status === 'draft' &&
                        startEdit(ab, 'runners_before', ab.runners_before ?? '')
                      "
                    >
                      {{ ab.runners_before || '---' }}
                    </span>
                  </template>
                </td>

                <!-- runners_after インライン編集 -->
                <td>
                  <template v-if="editingId === ab.id && editingField === 'runners_after'">
                    <v-text-field
                      v-model="editValue"
                      density="compact"
                      hide-details
                      variant="underlined"
                      style="min-width: 70px; max-width: 90px"
                      autofocus
                      @keyup.enter="saveEdit(ab)"
                      @keyup.escape="cancelEdit"
                      @blur="saveEdit(ab)"
                    />
                  </template>
                  <template v-else>
                    <span
                      class="text-caption text-mono"
                      :class="gameRecord.status === 'draft' ? 'cursor-pointer' : ''"
                      @click="
                        gameRecord.status === 'draft' &&
                        startEdit(ab, 'runners_after', ab.runners_after ?? '')
                      "
                    >
                      {{ ab.runners_after || '---' }}
                    </span>
                  </template>
                </td>

                <td class="text-caption">{{ ab.strategy || '-' }}</td>

                <!-- play_description: ツールチップ -->
                <td>
                  <v-tooltip
                    v-if="ab.play_description"
                    :text="ab.play_description"
                    max-width="400"
                    location="top"
                  >
                    <template v-slot:activator="{ props: tooltipProps }">
                      <span
                        v-bind="tooltipProps"
                        class="text-caption text-truncate cursor-help"
                        style="max-width: 110px; display: inline-block"
                      >
                        {{ ab.play_description }}
                      </span>
                    </template>
                  </v-tooltip>
                  <span v-else class="text-caption text-grey">-</span>
                </td>

                <td>
                  <v-icon
                    v-if="ab.is_modified"
                    size="x-small"
                    color="amber-darken-3"
                    title="修正済み"
                  >
                    mdi-pencil-circle
                  </v-icon>
                  <v-icon
                    v-if="ab.discrepancies?.length"
                    size="x-small"
                    :color="discrepancyIconColor(ab.discrepancies[0].cause)"
                    title="差異あり"
                    class="ml-1"
                  >
                    mdi-alert-circle
                  </v-icon>
                </td>
              </tr>
              <!-- discrepancy バナー行 -->
              <tr v-if="ab.discrepancies?.length" class="disc-banner-row">
                <td colspan="10" class="pa-0">
                  <div class="disc-banner">
                    <span class="disc-banner-title"
                      >⚠️ discrepancy 検出 ({{ ab.discrepancies.length }}件)</span
                    >
                    <div
                      v-for="(d, di) in ab.discrepancies"
                      :key="di"
                      class="disc-item"
                      :class="`disc-cause--${d.cause}`"
                    >
                      <span class="disc-field">{{ d.field }}</span>
                      <span class="disc-sep">:</span>
                      <span class="disc-label">テキスト</span>
                      <span class="disc-val">{{ formatDiscValue(d.text_value) }}</span>
                      <span class="disc-sep">→ GSM</span>
                      <span class="disc-val">{{ formatDiscValue(d.gsm_value) }}</span>
                      <v-chip
                        size="x-small"
                        class="ml-2"
                        :color="discrepancyChipColor(d.cause)"
                        label
                        >{{ discrepancyCauseLabel(d.cause) }}</v-chip
                      >
                    </div>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </v-table>
      </div>

      <!-- 確定ボタン -->
      <v-row v-if="gameRecord.status === 'draft'" class="mt-2">
        <v-col cols="12" class="d-flex justify-end">
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
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import axios from '@/plugins/axios'

interface Discrepancy {
  field: string
  text_value: unknown
  gsm_value: unknown
  cause: 'parser_misread' | 'human_error' | 'gsm_limitation' | 'ambiguous' | 'unknown'
  resolution: 'gsm' | 'text' | 'manual' | null
  note?: string
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
  runners_before: string | null
  runners_after: string | null
  strategy: string | null
  play_description: string | null
  is_modified: boolean
  modified_fields: string[]
  discrepancies: Discrepancy[]
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
  records: AtBatRecord[]
}

const router = useRouter()
const route = useRoute()

const gameRecord = ref<GameRecord | null>(null)
const loading = ref(false)
const confirming = ref(false)
const errorMessage = ref('')
const snackbar = ref(false)
const snackbarMessage = ref('')
const snackbarColor = ref('success')

// インライン編集状態
const editingId = ref<number | null>(null)
const editingField = ref<string | null>(null)
const editValue = ref('')

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
    result.push({
      key,
      label: `${inning}回${half === 'top' ? '表' : '裏'}`,
      records,
    })
  })
  return result
})

function formatDate(dateStr: string): string {
  if (!dateStr) return '-'
  const d = new Date(dateStr)
  return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}`
}

function resultColor(code: string | null): string {
  if (!code) return 'grey'
  const c = code.toUpperCase()
  if (['K', 'K3'].includes(c)) return 'red-lighten-2'
  if (['BB', 'IBB'].includes(c)) return 'blue-lighten-2'
  if (['HR', '本塁打'].includes(c)) return 'purple-lighten-2'
  if (['H', '1B', '2B', '3B'].includes(c)) return 'green-lighten-2'
  return 'grey-lighten-1'
}

function discrepancyChipColor(cause: Discrepancy['cause']): string {
  const map: Record<string, string> = {
    parser_misread: 'yellow-darken-3',
    human_error: 'orange-darken-2',
    gsm_limitation: 'blue-darken-1',
    ambiguous: 'grey-darken-1',
    unknown: 'red-darken-1',
  }
  return map[cause] ?? 'grey'
}

function discrepancyIconColor(cause: Discrepancy['cause']): string {
  const map: Record<string, string> = {
    parser_misread: 'yellow-darken-3',
    human_error: 'orange-darken-2',
    gsm_limitation: 'blue-darken-1',
    ambiguous: 'grey-darken-1',
    unknown: 'red-darken-1',
  }
  return map[cause] ?? 'grey'
}

function discrepancyCauseLabel(cause: Discrepancy['cause']): string {
  const map: Record<string, string> = {
    parser_misread: 'パーサー誤読',
    human_error: 'ヒューマンエラー',
    gsm_limitation: 'GSM制限',
    ambiguous: '判定不能',
    unknown: '未分類',
  }
  return map[cause] ?? cause
}

function formatDiscValue(val: unknown): string {
  if (val === null || val === undefined) return '-'
  if (Array.isArray(val)) return val.length === 0 ? '[]' : `[${val.join(', ')}]`
  return String(val)
}

function startEdit(ab: AtBatRecord, field: string, value: string) {
  editingId.value = ab.id
  editingField.value = field
  editValue.value = value
}

function cancelEdit() {
  editingId.value = null
  editingField.value = null
  editValue.value = ''
}

async function saveEdit(ab: AtBatRecord) {
  if (editingId.value === null || editingField.value === null) return
  const field = editingField.value
  const rawValue = editValue.value

  // 値が変わっていない場合はスキップ
  const currentValue = String(ab[field as keyof AtBatRecord] ?? '')
  if (rawValue === currentValue) {
    cancelEdit()
    return
  }

  // 楽観的更新
  const prevValue = ab[field as keyof AtBatRecord]
  const patchBody: Record<string, string | number | null> = {}
  if (field === 'runs_scored') {
    const num = parseInt(rawValue, 10)
    ;(ab as Record<string, unknown>)[field] = isNaN(num) ? 0 : num
    patchBody[field] = isNaN(num) ? 0 : num
  } else {
    ;(ab as Record<string, unknown>)[field] = rawValue || null
    patchBody[field] = rawValue || null
  }

  cancelEdit()

  try {
    const response = await axios.patch<AtBatRecord>(`/at_bat_records/${ab.id}`, patchBody)
    // サーバーから返ったデータでis_modified等を更新
    const updated = response.data
    ab.is_modified = updated.is_modified
    ab.modified_fields = updated.modified_fields
    showSnackbar('保存しました', 'success')
  } catch {
    // ロールバック
    ;(ab as Record<string, unknown>)[field] = prevValue
    showSnackbar('保存に失敗しました', 'error')
  }
}

function showSnackbar(message: string, color: string) {
  snackbarMessage.value = message
  snackbarColor.value = color
  snackbar.value = true
}

async function confirmGameRecord() {
  if (!gameRecord.value) return
  confirming.value = true
  try {
    const response = await axios.post<GameRecord>(`/game_records/${gameRecord.value.id}/confirm`)
    gameRecord.value.status = response.data.status
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
.cursor-help {
  cursor: help;
}
.text-mono {
  font-family: monospace;
}
.text-decoration-underline-dotted {
  text-decoration: underline dotted;
}

/* discrepancy 行ハイライト */
.disc-row {
  border-left: 3px solid #b33333;
}

/* discrepancy バナー */
.disc-banner-row td {
  padding: 0 !important;
}
.disc-banner {
  background: #fff0f0;
  border-left: 3px solid #b33333;
  padding: 6px 12px;
  font-size: 0.8em;
}
.disc-banner-title {
  font-weight: bold;
  color: #b33333;
  display: block;
  margin-bottom: 4px;
}
.disc-item {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 2px 0;
  flex-wrap: wrap;
}
.disc-field {
  font-family: monospace;
  font-weight: bold;
  color: #444;
}
.disc-label {
  color: #888;
  font-size: 0.9em;
}
.disc-val {
  font-family: monospace;
  color: #333;
}
.disc-sep {
  color: #aaa;
}
</style>
