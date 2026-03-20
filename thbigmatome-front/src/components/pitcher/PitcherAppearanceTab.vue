<template>
  <div>
    <!-- 試合結果 -->
    <v-row class="mb-3">
      <v-col cols="12" sm="6" class="d-flex align-center">
        <span class="text-caption text-grey mr-2">試合結果:</span>
        <v-chip :color="gameResultColor" size="small">{{ gameResultLabel }}</v-chip>
      </v-col>
    </v-row>

    <template v-if="loadingPitchers">
      <v-progress-circular indeterminate color="primary" size="24" class="d-block mx-auto" />
    </template>

    <template v-else>
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
              :item-props="(item: PitcherItem) => ({ disabled: item.disabled })"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props" :disabled="item.raw.disabled">
                  <template #append>
                    <span class="ml-2 text-caption">{{ item.raw.statusBadge }}</span>
                    <span v-if="item.raw.preGameInfo" class="ml-1 text-caption text-grey">
                      {{ item.raw.preGameInfo }}
                    </span>
                  </template>
                </v-list-item>
              </template>
              <template #prepend-inner>
                <span v-if="row.pitcher_id" class="mr-1 text-caption">
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

          <!-- 登板開始後アウト無し降板 -->
          <v-col cols="4" class="d-flex align-center">
            <v-checkbox
              v-model="row.no_out_exit"
              label="登板後アウト無し降板"
              density="compact"
              hide-details
            />
          </v-col>

          <!-- 勝敗投手 -->
          <v-col cols="4">
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

          <!-- result_category 自動計算 -->
          <v-col cols="12" class="d-flex align-center">
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

      <!-- エラー/警告 -->
      <v-alert v-if="errors.length > 0" type="error" density="compact" class="mt-3">
        <div v-for="e in errors" :key="e">{{ e }}</div>
      </v-alert>
      <v-alert v-if="warnings.length > 0" type="warning" density="compact" class="mt-3">
        <div v-for="w in warnings" :key="w">{{ w }}</div>
      </v-alert>
      <v-alert v-if="savedMessage" type="success" density="compact" class="mt-3">
        {{ savedMessage }}
      </v-alert>

      <!-- 保存ボタン -->
      <div class="d-flex justify-end mt-4">
        <v-btn
          color="primary"
          variant="elevated"
          :loading="saving"
          :disabled="!canSave"
          @click="saveAll"
          prepend-icon="mdi-content-save"
        >
          登板記録を保存
        </v-btn>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import type { PitcherAppearanceInput, PitcherRole } from '@/types/pitcherAppearance'

const props = defineProps<{
  teamId: number
  gameDate: string
  gameResult: 'win' | 'lose' | 'draw'
  scheduleId: number
}>()

// ─────────────────────────────────────────
// 型定義
// ─────────────────────────────────────────

interface PreGameState {
  player_id: number
  rest_days: number | null
  cumulative_innings: number
  last_role: string | null
  is_injured: boolean
}

interface PitcherItem {
  id: number
  label: string
  disabled: boolean
  statusBadge: string
  preGameInfo: string
}

interface PitcherRow extends PitcherAppearanceInput {
  is_second_starter: boolean
  no_out_exit: boolean
}

// ─────────────────────────────────────────
// State
// ─────────────────────────────────────────

const pitcherItems = ref<PitcherItem[]>([])
const preGameStates = ref<PreGameState[]>([])
const loadingPitchers = ref(false)
const saving = ref(false)
const errors = ref<string[]>([])
const warnings = ref<string[]>([])
const savedMessage = ref('')
const pitcherRows = ref<PitcherRow[]>([createEmptyRow('starter')])

// ─────────────────────────────────────────
// Computed
// ─────────────────────────────────────────

const selectedTeamId = computed(() => props.teamId)

const gameResultLabel = computed(() => {
  const map: Record<string, string> = { win: '勝利 ○', lose: '敗戦 ●', draw: '引き分け △' }
  return map[props.gameResult] ?? props.gameResult
})

const gameResultColor = computed(() => {
  const map: Record<string, string> = { win: 'success', lose: 'error', draw: 'grey' }
  return map[props.gameResult] ?? 'default'
})

const canSave = computed(
  () => pitcherRows.value.length > 0 && pitcherRows.value.every((r) => r.pitcher_id !== null),
)

// ─────────────────────────────────────────
// Options
// ─────────────────────────────────────────

const starterRoleOptions = [
  { label: '先発', value: 'starter' },
  { label: 'オープナー', value: 'opener' },
]

const reliefRoleOptions = [
  { label: 'リリーフ', value: 'reliever' },
  { label: 'オープナー', value: 'opener' },
]

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
    no_out_exit: false,
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
  const state = preGameStates.value.find((s) => s.player_id === pitcherId)
  return state?.is_injured ? '🏥' : '🟢'
}

function computeResultCategory(idx: number): string | null {
  const row = pitcherRows.value[idx]
  if (props.gameResult === 'no_game') return 'no_game'
  if (row.role !== 'starter') return 'normal'
  const innings = row.innings_pitched ?? 0
  const hasSuccessor = pitcherRows.value.length > 1
  const fatigueP = row.fatigue_p_used ?? 0
  if (innings > 0 && innings < 5 && hasSuccessor) return 'ko'
  if (props.gameResult === 'lose' && fatigueP > 0 && innings > fatigueP + 1) return 'long_loss'
  return 'normal'
}

function getDecisionOptions(idx: number) {
  const hasW = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'W')
  const hasL = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'L')
  const hasS = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'S')
  const row = pitcherRows.value[idx]
  const isStarter = row.role === 'starter'
  const isLastPitcher = idx === pitcherRows.value.length - 1
  const result = props.gameResult
  return [
    { label: '—', value: null },
    { label: 'W（勝利投手）', value: 'W', disabled: result !== 'win' || hasW },
    { label: 'L（敗戦投手）', value: 'L', disabled: result !== 'lose' || hasL },
    {
      label: 'S（セーブ）',
      value: 'S',
      disabled: isStarter || hasS || result !== 'win' || !isLastPitcher,
    },
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

function buildPreGameInfo(state: PreGameState | undefined): string {
  if (!state) return ''
  if (state.is_injured) return '🏥 負傷中'
  if (state.last_role === 'starter' && state.rest_days != null) return `中${state.rest_days}日`
  if (
    (state.last_role === 'reliever' || state.last_role === 'opener') &&
    state.cumulative_innings > 0
  )
    return `累積${state.cumulative_innings}`
  return ''
}

// ─────────────────────────────────────────
// Data fetching
// ─────────────────────────────────────────

async function fetchPitchersAndStates() {
  loadingPitchers.value = true
  pitcherRows.value = [createEmptyRow('starter')]
  errors.value = []
  warnings.value = []
  savedMessage.value = ''

  try {
    const [playersRes, statesRes, absencesRes] = await Promise.allSettled([
      axios.get(`/teams/${selectedTeamId.value}/team_players`),
      axios.get(`/teams/${selectedTeamId.value}/pitcher_game_states`, {
        params: { date: props.gameDate },
      }),
      axios.get(`/player_absences?team_id=${selectedTeamId.value}`),
    ])

    // 負傷中選手ID
    const injuredIds = new Set<number>()
    if (absencesRes.status === 'fulfilled') {
      const today = props.gameDate
      for (const pa of absencesRes.value.data) {
        const start = pa.start_date
        const end = pa.end_date
        if ((!start || start <= today) && (!end || end >= today)) {
          injuredIds.add(pa.player_id)
        }
      }
    }

    // Pre-game states
    if (statesRes.status === 'fulfilled') {
      preGameStates.value = statesRes.value.data
    } else {
      preGameStates.value = []
    }

    // Build pitcher items
    if (playersRes.status === 'fulfilled') {
      pitcherItems.value = playersRes.value.data
        .filter((p: { position: string }) => p.position === 'pitcher')
        .map((p: { id: number; name: string }) => {
          const state = preGameStates.value.find((s) => s.player_id === p.id)
          const isInjured = injuredIds.has(p.id)
          const preGameInfo = buildPreGameInfo(
            state ? { ...state, is_injured: isInjured } : undefined,
          )
          return {
            id: p.id,
            label: p.name,
            disabled: isInjured,
            statusBadge: isInjured ? '🏥' : '🟢',
            preGameInfo,
          }
        })
    }
  } finally {
    loadingPitchers.value = false
  }
}

// ─────────────────────────────────────────
// Save
// ─────────────────────────────────────────

async function saveAll() {
  if (!canSave.value) return
  saving.value = true
  errors.value = []
  warnings.value = []
  savedMessage.value = ''

  const allWarnings: string[] = []

  for (const row of pitcherRows.value) {
    if (!row.pitcher_id) continue
    try {
      const payload = {
        pitcher_appearance: {
          pitcher_id: row.pitcher_id,
          team_id: props.teamId,
          game_id: props.scheduleId,
          role: row.role,
          innings_pitched: row.innings_pitched,
          earned_runs: row.earned_runs,
          fatigue_p_used: row.fatigue_p_used,
          decision: row.decision,
          schedule_date: props.gameDate,
          is_opener: row.is_opener,
          consecutive_short_rest_count: row.consecutive_short_rest_count,
          pre_injury_days_excluded: row.pre_injury_days_excluded,
          game_result: props.gameResult,
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
    savedMessage.value = '登板記録を保存しました'
    await fetchPitchersAndStates()
  }
}

// ─────────────────────────────────────────
// Lifecycle / Watchers
// ─────────────────────────────────────────

onMounted(() => {
  fetchPitchersAndStates()
})
</script>

<style scoped>
.pitcher-row {
  border: 1px solid rgba(0, 0, 0, 0.12);
}
</style>
