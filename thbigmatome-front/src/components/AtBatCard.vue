<template>
  <div
    class="ab-card"
    :class="{
      'ab-card--modified': ab.is_modified,
      'ab-card--reviewed': ab.is_reviewed,
      'ab-card--disc': ab.discrepancies?.length,
    }"
  >
    <!-- ヘッダー (常時表示) -->
    <div
      class="ab-card-header d-flex align-center gap-2 px-3 py-2 cursor-pointer"
      @click="collapsed = !collapsed"
    >
      <div class="ab-num-badge">{{ ab.ab_num }}</div>
      <span class="font-weight-bold text-body-2">{{ ab.batter_name }}</span>
      <span class="text-grey text-caption">vs</span>
      <span class="text-body-2">{{ ab.pitcher_name }}</span>
      <v-chip v-if="ab.discrepancies?.length" color="error" size="x-small" label
        >⚠️ 差異あり</v-chip
      >
      <v-chip v-if="ab.is_reviewed" color="success" size="x-small" label>✓ 確認済</v-chip>
      <v-spacer />
      <v-chip size="x-small" :color="resultColor(ab.result_code)" label>
        {{ ab.result_code || '-' }}
      </v-chip>
      <v-icon v-if="ab.is_modified" size="x-small" color="amber-darken-3" title="修正済み">
        mdi-pencil-circle
      </v-icon>
      <v-btn
        v-if="canEdit && !isEditing"
        size="x-small"
        variant="outlined"
        color="primary"
        class="ml-1"
        @click.stop="startEdit"
      >
        編集
      </v-btn>
      <v-icon size="small" class="text-grey">
        {{ collapsed ? 'mdi-chevron-right' : 'mdi-chevron-down' }}
      </v-icon>
    </div>

    <!-- ボディ -->
    <div v-show="!collapsed" class="ab-card-body">
      <!-- discrepancy バナー -->
      <div v-if="ab.discrepancies?.length" class="disc-banner mx-3 mt-2">
        <div class="disc-banner-title">⚠️ discrepancy 検出 ({{ ab.discrepancies.length }}件)</div>
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
          <v-chip v-if="d.resolution" size="x-small" color="blue-lighten-2" class="ml-1" label>
            {{ resolutionLabel(d.resolution) }}
          </v-chip>
          <v-chip v-else size="x-small" class="ml-2" :color="discrepancyChipColor(d.cause)" label>
            {{ discrepancyCauseLabel(d.cause) }}
          </v-chip>
        </div>
      </div>

      <!-- 編集フォーム -->
      <template v-if="isEditing">
        <div class="edit-form mx-3 my-2 pa-3">
          <v-row dense>
            <v-col cols="12" sm="4">
              <v-text-field
                v-model="editForm.result_code"
                label="結果コード"
                density="compact"
                variant="outlined"
                hide-details
              />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field
                v-model.number="editForm.runs_scored"
                label="得点"
                type="number"
                :min="0"
                density="compact"
                variant="outlined"
                hide-details
              />
            </v-col>
          </v-row>

          <div class="mt-2">
            <div class="text-caption text-grey mb-1">走者前 (チェック=塁に走者あり)</div>
            <div class="d-flex gap-2">
              <v-checkbox
                v-model="editForm.runners_before"
                :value="1"
                label="1塁"
                density="compact"
                hide-details
              />
              <v-checkbox
                v-model="editForm.runners_before"
                :value="2"
                label="2塁"
                density="compact"
                hide-details
              />
              <v-checkbox
                v-model="editForm.runners_before"
                :value="3"
                label="3塁"
                density="compact"
                hide-details
              />
            </div>
          </div>

          <div class="mt-2">
            <div class="text-caption text-grey mb-1">走者後 (チェック=塁に走者あり)</div>
            <div class="d-flex gap-2">
              <v-checkbox
                v-model="editForm.runners_after"
                :value="1"
                label="1塁"
                density="compact"
                hide-details
              />
              <v-checkbox
                v-model="editForm.runners_after"
                :value="2"
                label="2塁"
                density="compact"
                hide-details
              />
              <v-checkbox
                v-model="editForm.runners_after"
                :value="3"
                label="3塁"
                density="compact"
                hide-details
              />
            </div>
          </div>

          <div class="mt-2">
            <v-textarea
              v-model="editForm.review_notes"
              label="レビューメモ"
              density="compact"
              variant="outlined"
              rows="2"
              hide-details
            />
          </div>

          <div class="d-flex gap-2 mt-3">
            <v-btn
              color="primary"
              size="small"
              variant="elevated"
              :loading="saving"
              @click="saveEdit"
            >
              保存
            </v-btn>
            <v-btn size="small" variant="text" @click="cancelEdit">キャンセル</v-btn>
          </div>
        </div>
      </template>

      <!-- 表示モード -->
      <template v-else>
        <!-- source_events タイムライン表示 -->
        <template v-if="hasSourceEvents">
          <div v-if="showSection('declaration')" class="ev-section sec-decl mx-3 mt-2">
            <div class="ev-section-title">📢 宣言 (Declaration)</div>
            <div class="ev-body pa-2">
              <template v-if="declarations.length > 0">
                <v-chip
                  v-for="(ev, i) in declarations"
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

          <div
            v-if="showSection('dice') && diceEvents.length > 0"
            class="ev-section sec-dice mx-3 mt-2"
          >
            <div class="ev-section-title">🎲 ダイス (Dice)</div>
            <div class="ev-body pa-2">
              <div
                v-for="(ev, i) in diceEvents"
                :key="i"
                class="ev-row d-flex align-center gap-2 py-1"
              >
                <span>🎲</span>
                <span class="text-caption">{{ formatDiceEvent(ev) }}</span>
              </div>
            </div>
          </div>

          <div v-if="skipReason" class="skip-row mx-3 mt-2 d-flex align-center gap-2">
            <span>⏩</span>
            <span class="text-caption">{{ skipReason }}</span>
          </div>

          <div
            v-if="showSection('auto') && autoEvents.length > 0"
            class="ev-section sec-auto mx-3 mt-2"
          >
            <div class="ev-section-title">⚙️ 自動計算 / GSM演繹（読み取り専用）</div>
            <div class="ev-body pa-2">
              <div
                v-for="(ev, i) in autoEvents"
                :key="i"
                class="ev-row d-flex align-center gap-2 py-1"
              >
                <span>⚙️</span>
                <span class="text-caption">{{ formatAutoEvent(ev) }}</span>
              </div>
            </div>
          </div>

          <div v-if="ab.play_description" class="play-desc mx-3 mt-2 mb-2">
            <span class="text-caption text-grey mr-1">原文:</span>
            <span class="text-caption font-italic">「{{ ab.play_description }}」</span>
          </div>
        </template>

        <!-- レガシー表示 (source_eventsなし) -->
        <template v-else>
          <div class="legacy-fields pa-3">
            <v-row dense align="center">
              <v-col cols="auto" class="d-flex align-center gap-1">
                <span class="text-caption text-grey">結果:</span>
                <v-chip :color="resultColor(ab.result_code)" size="x-small" label>
                  {{ ab.result_code || '-' }}
                </v-chip>
              </v-col>
              <v-col cols="auto" class="d-flex align-center gap-1 ml-3">
                <span class="text-caption text-grey">得点:</span>
                <span>{{ ab.runs_scored ?? 0 }}</span>
              </v-col>
              <v-col cols="auto" class="d-flex align-center gap-1 ml-3">
                <span class="text-caption text-grey">走者前:</span>
                <span class="text-caption text-mono">{{ displayRunners(ab.runners_before) }}</span>
              </v-col>
              <v-col cols="auto" class="d-flex align-center gap-1 ml-3">
                <span class="text-caption text-grey">走者後:</span>
                <span class="text-caption text-mono">{{ displayRunners(ab.runners_after) }}</span>
              </v-col>
            </v-row>
            <div v-if="ab.review_notes" class="mt-1 text-caption text-grey">
              📝 {{ ab.review_notes }}
            </div>
          </div>
        </template>
      </template>

      <!-- 走者・アウト状態フッター -->
      <div class="ab-state px-3 py-2 d-flex gap-4 flex-wrap">
        <span>
          <span class="text-grey text-caption">走者</span>
          <span class="font-weight-bold text-caption ml-1">
            {{ displayRunners(ab.runners_before) }} → {{ displayRunners(ab.runners_after) }}
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
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import axios from '@/plugins/axios'
import type { SourceEvent, Discrepancy, AtBatRecord } from '@/types/game-record'

const props = defineProps<{
  ab: AtBatRecord
  gameStatus: 'draft' | 'confirmed'
  activeFilter?: string
}>()

const emit = defineEmits<{
  updated: [ab: AtBatRecord]
  error: [message: string]
}>()

const collapsed = ref(false)
const isEditing = ref(false)
const saving = ref(false)

const editForm = ref({
  result_code: '',
  runners_before: [] as number[],
  runners_after: [] as number[],
  runs_scored: 0,
  review_notes: '',
})

const canEdit = computed(() => props.gameStatus === 'draft')

const hasSourceEvents = computed(
  () => !!(props.ab.source_events && (props.ab.source_events as SourceEvent[]).length > 0),
)

const declarations = computed(() =>
  (props.ab.source_events ?? []).filter((e: SourceEvent) => e.type === 'declaration'),
)

const diceEvents = computed(() =>
  (props.ab.source_events ?? []).filter((e: SourceEvent) => e.type === 'dice'),
)

const autoEvents = computed(() =>
  (props.ab.source_events ?? []).filter((e: SourceEvent) => e.type === 'auto'),
)

const skipReason = computed(() => {
  const skip = (props.ab.source_events ?? []).find((e: SourceEvent) => e.type === 'skip')
  if (!skip) return null
  return skip.text ?? skip.reason ?? 'ダイス省略'
})

function showSection(sectionType: 'declaration' | 'dice' | 'auto'): boolean {
  const f = props.activeFilter ?? 'all'
  if (f === 'all' || f === 'discrepancy') return true
  if (f === 'declaration') return sectionType === 'declaration'
  if (f === 'dice') return sectionType === 'dice'
  return false
}

function parseRunners(val: unknown): number[] {
  if (!val) return []
  if (Array.isArray(val))
    return (val as unknown[]).filter((n) => [1, 2, 3].includes(Number(n))).map(Number)
  return []
}

function displayRunners(val: unknown): string {
  const bases = parseRunners(val)
  if (bases.length === 0) return '---'
  return bases.map((b) => `${b}塁`).join('・')
}

function startEdit() {
  editForm.value = {
    result_code: props.ab.result_code ?? '',
    runners_before: parseRunners(props.ab.runners_before),
    runners_after: parseRunners(props.ab.runners_after),
    runs_scored: props.ab.runs_scored ?? 0,
    review_notes: props.ab.review_notes ?? '',
  }
  isEditing.value = true
  collapsed.value = false
}

function cancelEdit() {
  isEditing.value = false
}

async function saveEdit() {
  saving.value = true
  try {
    const payload: Record<string, unknown> = {
      result_code: editForm.value.result_code || null,
      runners_before: editForm.value.runners_before,
      runners_after: editForm.value.runners_after,
      runs_scored: editForm.value.runs_scored,
      review_notes: editForm.value.review_notes || null,
      is_reviewed: true,
    }
    const response = await axios.patch<AtBatRecord>(`/at_bat_records/${props.ab.id}`, payload)
    emit('updated', response.data)
    isEditing.value = false
  } catch {
    emit('error', '保存に失敗しました')
  } finally {
    saving.value = false
  }
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

function resolutionLabel(resolution: string): string {
  const map: Record<string, string> = {
    gsm: 'GSM採用',
    text: 'テキスト採用',
    manual: '手動修正済',
  }
  return map[resolution] ?? resolution
}

function formatDiscValue(val: unknown): string {
  if (val === null || val === undefined) return '-'
  if (Array.isArray(val)) return val.length === 0 ? '[]' : `[${val.join(', ')}]`
  return String(val)
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
</script>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}
.text-mono {
  font-family: monospace;
}

.v-card,
.ab-card {
  --ai: #1b3a6b;
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

.ab-card {
  border: 1px solid #ddd;
  border-radius: 5px;
  overflow: hidden;
  background: white;
}

.ab-card--modified {
  background: #fffbf0;
}

.ab-card--reviewed {
  border-color: #4a9e4a;
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

.sec-decl .ev-section-title {
  background: #e0e0e4;
  color: #556;
  border-bottom: 1px solid #bbb;
}
.sec-decl .ev-body {
  background: var(--decl-bg);
}

.sec-dice .ev-section-title {
  background: #dce6ff;
  color: #3a6bd8;
  border-bottom: 1px solid #9ab;
}
.sec-dice .ev-body {
  background: var(--dice-bg);
  border-left: 3px solid var(--dice-border);
}

.sec-auto .ev-section-title {
  background: #d8f0d8;
  color: #5a8a00;
  border-bottom: 1px solid #9c9;
}
.sec-auto .ev-body {
  background: var(--auto-bg);
  border-left: 3px solid var(--auto-border);
}

.skip-row {
  background: var(--skip-bg);
  border-left: 3px solid var(--skip-border);
  border-radius: 2px;
  padding: 5px 10px;
  color: #8a5500;
}

.play-desc {
  background: #fafaf5;
  border: 1px solid #eee;
  border-radius: 3px;
  padding: 5px 10px;
  color: #666;
}

.ab-state {
  background: #f8f8f6;
  border-top: 1px solid #eee;
}

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

.edit-form {
  background: #f0f4ff;
  border: 1px solid #b0c0e8;
  border-radius: 4px;
}

.legacy-fields {
  background: white;
}
</style>
