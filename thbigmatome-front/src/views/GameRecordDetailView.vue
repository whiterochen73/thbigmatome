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
          <div
            v-for="ab in filteredRecords(group.records)"
            :key="ab.id"
            class="ab-card mb-3"
            :class="{
              'ab-card--modified': ab.is_modified,
              'ab-card--disc': ab.discrepancies?.length,
            }"
          >
            <!-- 打席カードヘッダー (常時表示) -->
            <div
              class="ab-card-header d-flex align-center gap-2 px-3 py-2 cursor-pointer"
              @click="toggleAtbat(ab.id)"
            >
              <div class="ab-num-badge">{{ ab.ab_num }}</div>
              <span class="font-weight-bold text-body-2">{{ ab.batter_name }}</span>
              <span class="text-grey text-caption">vs</span>
              <span class="text-body-2">{{ ab.pitcher_name }}</span>
              <v-chip v-if="ab.discrepancies?.length" color="error" size="x-small" label
                >⚠️ 差異あり</v-chip
              >
              <v-spacer />
              <v-chip size="x-small" :color="resultColor(ab.result_code)" label>
                {{ ab.result_code || '-' }}
              </v-chip>
              <v-icon v-if="ab.is_modified" size="x-small" color="amber-darken-3" title="修正済み">
                mdi-pencil-circle
              </v-icon>
              <v-icon size="small" class="text-grey">
                {{ collapsedAtbats[ab.id] ? 'mdi-chevron-right' : 'mdi-chevron-down' }}
              </v-icon>
            </div>

            <!-- 打席ボディ -->
            <div v-show="!collapsedAtbats[ab.id]" class="ab-card-body">
              <!-- discrepancy バナー -->
              <div v-if="ab.discrepancies?.length" class="disc-banner mx-3 mt-2">
                <div class="disc-banner-title">
                  ⚠️ discrepancy 検出 ({{ ab.discrepancies.length }}件)
                </div>
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
                  <v-chip size="x-small" class="ml-2" :color="discrepancyChipColor(d.cause)" label>
                    {{ discrepancyCauseLabel(d.cause) }}
                  </v-chip>
                </div>
              </div>

              <!-- source_eventsがある場合: タイムライン表示 -->
              <template v-if="hasSourceEvents(ab)">
                <!-- 宣言セクション (灰色背景・📢) -->
                <div v-if="showSection('declaration')" class="ev-section sec-decl mx-3 mt-2">
                  <div class="ev-section-title">📢 宣言 (Declaration)</div>
                  <div class="ev-body pa-2">
                    <template v-if="getDeclarations(ab).length > 0">
                      <v-chip
                        v-for="(ev, i) in getDeclarations(ab)"
                        :key="i"
                        size="small"
                        label
                        class="mr-1 mb-1"
                      >
                        {{ ev.text || ev.action }}
                      </v-chip>
                    </template>
                    <span v-else class="text-caption text-grey">（宣言なし）</span>
                  </div>
                </div>

                <!-- ダイスセクション (青色左ボーダー・🎲) -->
                <div
                  v-if="showSection('dice') && getDiceEvents(ab).length > 0"
                  class="ev-section sec-dice mx-3 mt-2"
                >
                  <div class="ev-section-title">🎲 ダイス (Dice)</div>
                  <div class="ev-body pa-2">
                    <div
                      v-for="(ev, i) in getDiceEvents(ab)"
                      :key="i"
                      class="ev-row d-flex align-center gap-2 py-1"
                    >
                      <span>🎲</span>
                      <span class="text-caption">{{ formatDiceEvent(ev) }}</span>
                    </div>
                  </div>
                </div>

                <!-- ダイス省略（スキップ）行 (橙色・⏩) -->
                <div v-if="getSkipReason(ab)" class="skip-row mx-3 mt-2 d-flex align-center gap-2">
                  <span>⏩</span>
                  <span class="text-caption">{{ getSkipReason(ab) }}</span>
                </div>

                <!-- 自動計算セクション (緑色左ボーダー・⚙️・読み取り専用) -->
                <div
                  v-if="showSection('auto') && getAutoEvents(ab).length > 0"
                  class="ev-section sec-auto mx-3 mt-2"
                >
                  <div class="ev-section-title">⚙️ 自動計算 / GSM演繹（読み取り専用）</div>
                  <div class="ev-body pa-2">
                    <div
                      v-for="(ev, i) in getAutoEvents(ab)"
                      :key="i"
                      class="ev-row d-flex align-center gap-2 py-1"
                    >
                      <span>⚙️</span>
                      <span class="text-caption">{{ formatAutoEvent(ev) }}</span>
                    </div>
                  </div>
                </div>

                <!-- プレイ説明（原文） -->
                <div v-if="ab.play_description" class="play-desc mx-3 mt-2 mb-2">
                  <span class="text-caption text-grey mr-1">原文:</span>
                  <span class="text-caption font-italic">「{{ ab.play_description }}」</span>
                </div>
              </template>

              <!-- source_eventsがない場合: 既存のインライン編集表示（フォールバック） -->
              <template v-else>
                <div class="legacy-fields pa-3">
                  <v-row dense align="center">
                    <!-- result_code インライン編集 -->
                    <v-col cols="auto" class="d-flex align-center gap-1">
                      <span class="text-caption text-grey">結果:</span>
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
                            startEdit(ab, 'result_code', ab.result_code ?? '')
                          "
                        >
                          {{ ab.result_code || '-' }}
                        </v-chip>
                      </template>
                    </v-col>

                    <!-- runs_scored インライン編集 -->
                    <v-col cols="auto" class="d-flex align-center gap-1 ml-3">
                      <span class="text-caption text-grey">得点:</span>
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
                    </v-col>

                    <!-- runners_before インライン編集 -->
                    <v-col cols="auto" class="d-flex align-center gap-1 ml-3">
                      <span class="text-caption text-grey">走者前:</span>
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
                    </v-col>

                    <!-- runners_after インライン編集 -->
                    <v-col cols="auto" class="d-flex align-center gap-1 ml-3">
                      <span class="text-caption text-grey">走者後:</span>
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
                    </v-col>
                  </v-row>

                  <!-- 作戦・プレイ説明 -->
                  <div
                    v-if="ab.strategy || ab.play_description"
                    class="mt-1 d-flex gap-3 flex-wrap"
                  >
                    <span v-if="ab.strategy" class="text-caption text-grey"
                      >作戦: {{ ab.strategy }}</span
                    >
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
                          style="max-width: 200px; display: inline-block"
                        >
                          {{ ab.play_description }}
                        </span>
                      </template>
                    </v-tooltip>
                  </div>
                </div>
              </template>

              <!-- 走者・アウト状態フッター -->
              <div class="ab-state px-3 py-2 d-flex gap-4 flex-wrap">
                <span>
                  <span class="text-grey text-caption">走者</span>
                  <span class="font-weight-bold text-caption ml-1">
                    {{ ab.runners_before || '---' }} → {{ ab.runners_after || '---' }}
                  </span>
                </span>
                <span>
                  <span class="text-grey text-caption">OUT</span>
                  <span class="font-weight-bold text-caption ml-1">
                    {{ ab.outs_before ?? '?' }} → {{ ab.outs_after ?? '?' }}
                  </span>
                </span>
                <span>
                  <span class="text-grey text-caption">得点</span>
                  <span class="font-weight-bold text-caption ml-1">{{ ab.runs_scored ?? 0 }}</span>
                </span>
              </div>
            </div>
          </div>
        </div>
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
import { ref, computed, onMounted, reactive } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import axios from '@/plugins/axios'

interface SourceEvent {
  seq?: number
  type: 'declaration' | 'dice' | 'auto' | 'skip'
  dice_type?: string
  action?: string
  text?: string
  roll?: number | number[]
  result?: string
  reason?: string
  from?: string
  to?: string
  [key: string]: unknown
}

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
  outs_before: number | null
  outs_after: number | null
  strategy: string | null
  play_description: string | null
  is_modified: boolean
  modified_fields: string[]
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
const errorMessage = ref('')
const snackbar = ref(false)
const snackbarMessage = ref('')
const snackbarColor = ref('success')

// インライン編集状態
const editingId = ref<number | null>(null)
const editingField = ref<string | null>(null)
const editValue = ref('')

// フィルタ・展開/折畳状態
const activeFilter = ref('all')
const collapsedInnings = reactive<Record<string, boolean>>({})
const collapsedAtbats = reactive<Record<number, boolean>>({})

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

function toggleAtbat(id: number) {
  collapsedAtbats[id] = !collapsedAtbats[id]
}

function hasSourceEvents(ab: AtBatRecord): boolean {
  return !!(ab.source_events && ab.source_events.length > 0)
}

function filteredRecords(records: AtBatRecord[]): AtBatRecord[] {
  if (activeFilter.value === 'discrepancy') {
    return records.filter((ab) => ab.discrepancies?.length)
  }
  return records
}

function showSection(sectionType: 'declaration' | 'dice' | 'auto'): boolean {
  const f = activeFilter.value
  if (f === 'all' || f === 'discrepancy') return true
  if (f === 'declaration') return sectionType === 'declaration'
  if (f === 'dice') return sectionType === 'dice'
  return false
}

function getDeclarations(ab: AtBatRecord): SourceEvent[] {
  return (ab.source_events ?? []).filter((e) => e.type === 'declaration')
}

function getDiceEvents(ab: AtBatRecord): SourceEvent[] {
  return (ab.source_events ?? []).filter((e) => e.type === 'dice')
}

function getAutoEvents(ab: AtBatRecord): SourceEvent[] {
  return (ab.source_events ?? []).filter((e) => e.type === 'auto')
}

function getSkipReason(ab: AtBatRecord): string | null {
  const skip = (ab.source_events ?? []).find((e) => e.type === 'skip')
  if (!skip) return null
  return skip.text ?? skip.reason ?? 'ダイス省略'
}

function formatDiceEvent(ev: SourceEvent): string {
  const parts: string[] = []
  if (ev.dice_type) parts.push(ev.dice_type)
  if (ev.roll !== undefined) {
    const rollStr = Array.isArray(ev.roll)
      ? `[${(ev.roll as number[]).join(', ')}]`
      : `[${ev.roll}]`
    parts.push(`出目: ${rollStr}`)
  }
  if (ev.result) parts.push(`→ ${ev.result}`)
  return parts.join('  ') || ev.text || JSON.stringify(ev)
}

function formatAutoEvent(ev: SourceEvent): string {
  if (ev.text) return ev.text
  if (ev.action && ev.from && ev.to) return `${ev.action}: ${ev.from} → ${ev.to}`
  if (ev.action) return ev.action
  return JSON.stringify(ev)
}

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

/* ── 和色パレット ── */
/* NOTE: :rootをコンポーネントルート要素に変更（scoped内で:rootは[data-v-xxxx]付与でマッチしないため） */
.v-container {
  --ai: #1b3a6b;
  --ai-light: #2a5298;
  --moegi: #5a8a00;
  --kohaku: #c87a10;
  --decl-bg: #eeeef0;
  --decl-border: #888899;
  --dice-bg: #eef2ff;
  --dice-border: #3a6bd8;
  --auto-bg: #efffee;
  --auto-border: #4a9e4a;
  --skip-bg: #fff8e6;
  --skip-border: #c87a10;
  --disc-bg: #fff0f0;
  --disc-border: #b33333;
}

/* ── フィルタバー ── */
.filter-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
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

/* ── 打席カード ── */
.ab-card {
  border: 1px solid #ddd;
  border-radius: 5px;
  overflow: hidden;
  background: white;
}

.ab-card--modified {
  background: #fffbf0;
}

.ab-card--disc {
  border-color: #b33333;
}

.ab-card-header {
  background: #f8f8f8;
  border-bottom: 1px solid #eee;
  user-select: none;
}

.ab-card--modified .ab-card-header {
  background: #fff5e0;
}

.ab-card--disc .ab-card-header {
  background: #fff5f5;
}

.ab-num-badge {
  background: #1b3a6b;
  color: white;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.77em;
  font-weight: bold;
  flex-shrink: 0;
}

/* ── イベントセクション（宣言/ダイス/自動） ── */
.ev-section {
  border-radius: 4px;
  overflow: hidden;
}

.ev-section-title {
  padding: 3px 10px;
  font-size: 0.73em;
  font-weight: bold;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.ev-body {
  font-size: 0.86em;
}

/* 宣言セクション (灰色) */
.sec-decl .ev-section-title {
  background: #e0e0e4;
  color: #556;
  border-bottom: 1px solid #bbb;
}
.sec-decl .ev-body {
  background: var(--decl-bg);
}

/* ダイスセクション (青) */
.sec-dice .ev-section-title {
  background: #dce6ff;
  color: #3a6bd8;
  border-bottom: 1px solid #9ab;
}
.sec-dice .ev-body {
  background: var(--dice-bg);
  border-left: 3px solid var(--dice-border);
}

/* 自動計算セクション (緑) */
.sec-auto .ev-section-title {
  background: #d8f0d8;
  color: #5a8a00;
  border-bottom: 1px solid #9c9;
}
.sec-auto .ev-body {
  background: var(--auto-bg);
  border-left: 3px solid var(--auto-border);
}

/* ダイス省略行（橙色） */
.skip-row {
  background: var(--skip-bg);
  border-left: 3px solid var(--skip-border);
  border-radius: 2px;
  padding: 5px 10px;
  color: #8a5500;
}

/* プレイ説明 */
.play-desc {
  background: #fafaf5;
  border: 1px solid #eee;
  border-radius: 3px;
  padding: 5px 10px;
  color: #666;
}

/* 走者・アウト状態フッター */
.ab-state {
  background: #f8f8f6;
  border-top: 1px solid #eee;
}

/* discrepancy バナー */
.disc-banner {
  background: var(--disc-bg);
  border: 1px solid var(--disc-border);
  border-radius: 4px;
  padding: 8px 12px;
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

/* レガシー表示 */
.legacy-fields {
  background: white;
}
</style>
