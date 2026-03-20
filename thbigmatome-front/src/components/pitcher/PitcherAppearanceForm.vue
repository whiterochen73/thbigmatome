<template>
  <v-dialog
    :model-value="modelValue"
    max-width="700px"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card>
      <v-card-title class="d-flex align-center pt-3 pb-1">
        <v-icon start>mdi-baseball</v-icon>
        投手登板登録 — {{ scheduleDateLabel }}
        <v-spacer />
        <v-btn icon size="small" variant="text" @click="close">
          <v-icon>mdi-close</v-icon>
        </v-btn>
      </v-card-title>

      <v-card-text class="pt-2">
        <!-- 大会選択 -->
        <v-select
          v-model="selectedCompetitionId"
          :items="competitions"
          item-title="name"
          item-value="id"
          label="大会"
          variant="outlined"
          density="compact"
          :loading="loadingCompetitions"
          class="mb-3"
        />

        <!-- 試合結果 -->
        <v-select
          v-model="gameResult"
          :items="gameResultOptions"
          item-title="label"
          item-value="value"
          label="試合結果"
          variant="outlined"
          density="compact"
          class="mb-3"
        />

        <!-- 投手行リスト -->
        <div
          v-for="(row, idx) in pitcherRows"
          :key="idx"
          class="pitcher-row pa-3 mb-2 rounded"
          :class="{ 'bg-grey-lighten-4': idx % 2 === 0 }"
        >
          <div class="d-flex align-center justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis font-weight-bold">
              {{ idx === 0 ? '先発（1番手）' : `リリーフ（${idx + 1}番手）` }}
            </span>
            <v-btn
              v-if="idx > 0"
              icon
              size="x-small"
              variant="text"
              color="error"
              @click="removeRow(idx)"
            >
              <v-icon>mdi-close</v-icon>
            </v-btn>
          </div>

          <v-row dense>
            <!-- 投手選択 -->
            <v-col cols="12" sm="6">
              <v-autocomplete
                v-model="row.pitcher_id"
                :items="pitcherItems"
                item-title="label"
                item-value="id"
                label="投手"
                variant="outlined"
                density="compact"
                :item-props="(item: PitcherItem) => ({ disabled: item.injured })"
              >
                <template #item="{ props, item }">
                  <v-list-item v-bind="props" :disabled="item.raw.injured">
                    <template #append>
                      <span class="status-badge ml-2">{{ item.raw.statusBadge }}</span>
                    </template>
                  </v-list-item>
                </template>
                <template #prepend-inner>
                  <span v-if="row.pitcher_id" class="status-badge mr-1">
                    {{ getPitcherStatusBadge(row.pitcher_id) }}
                  </span>
                </template>
              </v-autocomplete>
            </v-col>

            <!-- ロール -->
            <v-col cols="12" sm="6">
              <v-select
                v-model="row.role"
                :items="idx === 0 ? starterRoleOptions : reliefRoleOptions"
                item-title="label"
                item-value="value"
                label="役割"
                variant="outlined"
                density="compact"
              />
            </v-col>

            <!-- オープナー / 第二先発チェックボックス -->
            <v-col
              cols="12"
              v-if="row.role === 'opener' || (idx === 1 && pitcherRows[0]?.role === 'opener')"
            >
              <div class="d-flex align-center gap-3">
                <v-checkbox
                  v-if="row.role === 'opener'"
                  v-model="row.is_opener"
                  label="オープナー本人（リリーフルール適用）"
                  density="compact"
                  hide-details
                />
                <v-checkbox
                  v-if="idx === 1 && pitcherRows[0]?.role === 'opener'"
                  v-model="row.is_second_starter"
                  label="第二先発"
                  density="compact"
                  hide-details
                />
              </div>
            </v-col>

            <!-- 投球回 -->
            <v-col cols="4">
              <v-text-field
                v-model.number="row.innings_pitched"
                label="投球回"
                type="number"
                step="0.1"
                min="0"
                variant="outlined"
                density="compact"
              />
            </v-col>

            <!-- 自責点 -->
            <v-col cols="4">
              <v-text-field
                v-model.number="row.earned_runs"
                label="自責点"
                type="number"
                min="0"
                variant="outlined"
                density="compact"
              />
            </v-col>

            <!-- 疲労P消費 -->
            <v-col cols="4">
              <v-text-field
                v-model.number="row.fatigue_p_used"
                label="疲労P消費"
                type="number"
                min="0"
                variant="outlined"
                density="compact"
              />
            </v-col>

            <!-- 勝敗投手 -->
            <v-col cols="6">
              <v-select
                v-model="row.decision"
                :items="getDecisionOptions(idx)"
                item-title="label"
                item-value="value"
                label="W/L/S/H"
                variant="outlined"
                density="compact"
                clearable
              />
            </v-col>

            <!-- result_category 自動計算表示 -->
            <v-col cols="6" class="d-flex align-center">
              <span class="text-caption text-medium-emphasis mr-1">結果区分:</span>
              <v-chip size="small" :color="resultCategoryColor(computeResultCategory(idx))">
                {{ resultCategoryLabel(computeResultCategory(idx)) }}
              </v-chip>
            </v-col>
          </v-row>
        </div>

        <!-- 投手追加ボタン -->
        <v-btn variant="outlined" size="small" prepend-icon="mdi-plus" class="mt-1" @click="addRow">
          投手を追加
        </v-btn>

        <!-- エラー/警告表示 -->
        <v-alert v-if="errors.length > 0" type="error" density="compact" class="mt-3">
          <div v-for="e in errors" :key="e">{{ e }}</div>
        </v-alert>
        <v-alert v-if="warnings.length > 0" type="warning" density="compact" class="mt-3">
          <div v-for="w in warnings" :key="w">{{ w }}</div>
        </v-alert>
      </v-card-text>

      <v-card-actions class="pb-3 px-4">
        <v-spacer />
        <v-btn variant="text" @click="close">キャンセル</v-btn>
        <v-btn
          color="primary"
          variant="elevated"
          :loading="saving"
          :disabled="!canSave"
          @click="saveAll"
        >
          保存
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import axios from 'axios'
import type { PitcherAppearanceInput, PitcherRole } from '@/types/pitcherAppearance'

const props = defineProps<{
  modelValue: boolean
  teamId: number
  scheduleDate: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  saved: []
}>()

// ─────────────────────────────────────────
// 型定義
// ─────────────────────────────────────────

interface Competition {
  id: number
  name: string
  year: number
}

interface PitcherItem {
  id: number
  label: string
  injured: boolean
  statusBadge: string
}

interface PitcherRow extends PitcherAppearanceInput {
  is_second_starter: boolean
}

// ─────────────────────────────────────────
// State
// ─────────────────────────────────────────

const competitions = ref<Competition[]>([])
const loadingCompetitions = ref(false)
const selectedCompetitionId = ref<number | null>(null)
const gameResult = ref<string>('win')
const pitcherItems = ref<PitcherItem[]>([])
const injuredPlayerIds = ref<Set<number>>(new Set())
const saving = ref(false)
const errors = ref<string[]>([])
const warnings = ref<string[]>([])

const pitcherRows = ref<PitcherRow[]>([createEmptyRow('starter')])

// ─────────────────────────────────────────
// Options
// ─────────────────────────────────────────

const gameResultOptions = [
  { label: '勝利 ○', value: 'win' },
  { label: '敗戦 ●', value: 'lose' },
  { label: '引き分け △', value: 'draw' },
  { label: 'ノーゲーム', value: 'no_game' },
]

const starterRoleOptions = [
  { label: '先発', value: 'starter' },
  { label: 'オープナー', value: 'opener' },
]

const reliefRoleOptions = [
  { label: 'リリーフ', value: 'reliever' },
  { label: 'オープナー', value: 'opener' },
]

// ─────────────────────────────────────────
// Computed
// ─────────────────────────────────────────

const scheduleDateLabel = computed(() => {
  if (!props.scheduleDate) return ''
  const [y, m, d] = props.scheduleDate.split('-')
  return `${y}年${parseInt(m)}月${parseInt(d)}日`
})

const canSave = computed(() => {
  return (
    selectedCompetitionId.value !== null &&
    pitcherRows.value.length > 0 &&
    pitcherRows.value.every((r) => r.pitcher_id !== null)
  )
})

// ─────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────

function createEmptyRow(role: PitcherRole): PitcherRow {
  return {
    pitcher_id: null,
    role,
    innings_pitched: null,
    earned_runs: 0,
    fatigue_p_used: 0,
    decision: null,
    is_opener: false,
    is_second_starter: false,
    consecutive_short_rest_count: 0,
    pre_injury_days_excluded: 0,
  }
}

function addRow() {
  pitcherRows.value.push(createEmptyRow('reliever'))
}

function removeRow(idx: number) {
  pitcherRows.value.splice(idx, 1)
}

function getPitcherStatusBadge(pitcherId: number | null): string {
  if (!pitcherId) return ''
  return injuredPlayerIds.value.has(pitcherId) ? '🏥' : '🟢'
}

function computeResultCategory(idx: number): string | null {
  const row = pitcherRows.value[idx]
  if (gameResult.value === 'no_game') return 'no_game'
  if (row.role !== 'starter') return 'normal'

  const innings = row.innings_pitched ?? 0
  const hasSuccessor = pitcherRows.value.length > 1
  const fatigueP = row.fatigue_p_used ?? 0
  if (innings > 0 && innings < 5 && hasSuccessor) return 'ko'
  if (gameResult.value === 'lose' && fatigueP > 0 && innings > fatigueP + 1) return 'long_loss'
  return 'normal'
}

function getDecisionOptions(idx: number) {
  const hasW = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'W')
  const hasL = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'L')
  const hasS = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'S')
  const row = pitcherRows.value[idx]
  const isStarter = row.role === 'starter'
  const isLastPitcher = idx === pitcherRows.value.length - 1
  const result = gameResult.value
  return [
    { label: '—', value: null },
    { label: 'W（勝利投手）', value: 'W', disabled: result !== 'win' || hasW },
    { label: 'L（敗戦投手）', value: 'L', disabled: result !== 'lose' || hasL },
    // S: 先発以外・勝ち試合のみ・試合に1人のみ・最後の投手のみ
    {
      label: 'S（セーブ）',
      value: 'S',
      disabled: isStarter || hasS || result !== 'win' || !isLastPitcher,
    },
    // H: 先発以外・最後の投手には付与不可（手渡した投手に付く）
    { label: 'H（ホールド）', value: 'H', disabled: isStarter || isLastPitcher },
  ]
}

function resultCategoryLabel(cat: string | null): string {
  const map: Record<string, string> = {
    normal: '通常',
    ko: 'KO',
    no_game: 'ノーゲーム',
    long_loss: '長イニング敗戦',
  }
  return cat ? (map[cat] ?? cat) : '—'
}

function resultCategoryColor(cat: string | null): string {
  const map: Record<string, string> = {
    ko: 'error',
    no_game: 'grey',
    long_loss: 'warning',
    normal: 'success',
  }
  return cat ? (map[cat] ?? 'default') : 'default'
}

function close() {
  emit('update:modelValue', false)
}

// ─────────────────────────────────────────
// Data fetching
// ─────────────────────────────────────────

async function fetchCompetitions() {
  loadingCompetitions.value = true
  try {
    const res = await axios.get('/competitions')
    competitions.value = res.data
  } catch (e) {
    console.error('Failed to fetch competitions', e)
  } finally {
    loadingCompetitions.value = false
  }
}

async function fetchPitchers() {
  try {
    const [playersRes, absencesRes] = await Promise.all([
      axios.get(`/teams/${props.teamId}/team_players`),
      axios.get(`/player_absences?team_id=${props.teamId}`),
    ])

    // 負傷中選手のID集合を構築
    const today = props.scheduleDate || new Date().toISOString().split('T')[0]
    const injured = new Set<number>()
    for (const absence of absencesRes.data) {
      const start = absence.start_date
      const end = absence.end_date
      if ((!start || start <= today) && (!end || end >= today)) {
        injured.add(absence.player_id)
      }
    }
    injuredPlayerIds.value = injured

    // 投手のみフィルタ
    pitcherItems.value = playersRes.data
      .filter((p: { position: string }) => p.position === 'pitcher')
      .map((p: { id: number; name: string }) => ({
        id: p.id,
        label: p.name,
        injured: injured.has(p.id),
        statusBadge: injured.has(p.id) ? '🏥' : '🟢',
      }))
  } catch (e) {
    console.error('Failed to fetch pitchers', e)
  }
}

// ─────────────────────────────────────────
// Save
// ─────────────────────────────────────────

async function saveAll() {
  if (!canSave.value || !selectedCompetitionId.value) return
  saving.value = true
  errors.value = []
  warnings.value = []

  const allWarnings: string[] = []

  for (const row of pitcherRows.value) {
    if (!row.pitcher_id) continue
    try {
      const payload = {
        pitcher_appearance: {
          pitcher_id: row.pitcher_id,
          team_id: props.teamId,
          competition_id: selectedCompetitionId.value,
          role: row.role,
          innings_pitched: row.innings_pitched,
          earned_runs: row.earned_runs,
          fatigue_p_used: row.fatigue_p_used,
          decision: row.decision,
          schedule_date: props.scheduleDate,
          is_opener: row.is_opener,
          consecutive_short_rest_count: row.consecutive_short_rest_count,
          pre_injury_days_excluded: row.pre_injury_days_excluded,
          game_result: gameResult.value,
        },
      }
      const res = await axios.post('/pitcher_appearances', payload)
      if (res.data.warnings?.length > 0) {
        allWarnings.push(...res.data.warnings)
      }
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { errors?: string[] } } }
      const errMsgs = axiosErr.response?.data?.errors ?? ['登録に失敗しました']
      errors.value.push(...errMsgs)
    }
  }

  saving.value = false

  if (errors.value.length === 0) {
    warnings.value = allWarnings
    if (allWarnings.length === 0) {
      emit('saved')
      close()
    }
  }
}

// ─────────────────────────────────────────
// Lifecycle
// ─────────────────────────────────────────

onMounted(async () => {
  await Promise.all([fetchCompetitions(), fetchPitchers()])
})

watch(
  () => props.modelValue,
  (val) => {
    if (val) {
      pitcherRows.value = [createEmptyRow('starter')]
      errors.value = []
      warnings.value = []
    }
  },
)
</script>

<style scoped>
.pitcher-row {
  border: 1px solid rgba(0, 0, 0, 0.12);
}
.status-badge {
  font-size: 1rem;
}
</style>
