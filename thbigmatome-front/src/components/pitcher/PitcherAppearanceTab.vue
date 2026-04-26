<template>
  <div>
    <!-- 試合結果 -->
    <div class="d-flex align-center mb-3">
      <span class="text-caption text-grey mr-2">試合結果:</span>
      <v-chip :color="gameResultColor" size="small">{{ gameResultLabel }}</v-chip>
    </div>

    <template v-if="loadingPitchers">
      <v-progress-circular indeterminate color="primary" size="24" class="d-block mx-auto" />
    </template>

    <template v-else>
      <!-- 投手行リスト（コンパクトレイアウト） -->
      <div
        v-for="(row, idx) in pitcherRows"
        :key="idx"
        class="pitcher-row pa-2 mb-1 rounded"
        :class="[
          idx === 0 ? 'bg-blue-lighten-5' : 'bg-grey-lighten-4',
          dragSrcIdx === idx ? 'opacity-50' : '',
        ]"
        style="position: relative"
        :draggable="idx > 0"
        @dragstart="idx > 0 && onDragStart(idx, $event)"
        @dragover="onDragOver(idx, $event)"
        @drop="onDrop(idx, $event)"
        @dragend="onDragEnd"
      >
        <!-- 削除ボタン（右上固定） -->
        <v-btn
          v-if="idx > 0"
          icon
          size="x-small"
          variant="text"
          color="error"
          style="position: absolute; top: 4px; right: 4px; z-index: 1"
          @click="removeRow(idx)"
        >
          <v-icon>mdi-close</v-icon>
        </v-btn>

        <!-- メイン行 -->
        <v-row density="compact" align="center">
          <!-- 番手ラベル + ドラッグハンドル -->
          <v-col cols="auto" class="d-flex align-center" style="min-width: 80px">
            <v-icon
              v-if="idx > 0"
              size="small"
              color="grey-lighten-1"
              style="cursor: grab; margin-right: 2px; flex-shrink: 0"
            >
              mdi-drag-vertical
            </v-icon>
            <span
              v-else
              style="width: 20px; margin-right: 2px; display: inline-block; flex-shrink: 0"
            />
            <span
              class="text-caption font-weight-bold"
              :class="idx === 0 ? 'text-blue-darken-2' : 'text-medium-emphasis'"
              style="min-width: 42px; display: inline-block"
            >
              {{ idx === 0 ? '先発' : `${idx + 1}番手` }}
            </span>
          </v-col>

          <!-- 投手選択 -->
          <v-col cols="12" sm="4">
            <v-autocomplete
              v-model="row.pitcher_id"
              :items="pitcherItems"
              item-title="label"
              item-value="id"
              label="投手"
              variant="outlined"
              density="compact"
              hide-details
              :item-props="(item: PitcherItem) => ({ disabled: item.disabled })"
            >
              <template #item="{ props, item }">
                <v-list-item v-bind="props" :disabled="item.disabled">
                  <template #append>
                    <span class="ml-1 text-caption text-grey">{{ item.preGameInfo }}</span>
                  </template>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>

          <!-- 区分（1番手: 先発/オープナー, 2番手: リリーフ/第二先発, 3番手以降: リリーフ固定） -->
          <v-col cols="6" sm="2">
            <v-select
              v-if="idx === 0"
              v-model="row.role"
              :items="starterRoleOptions"
              item-title="label"
              item-value="value"
              label="区分"
              variant="outlined"
              density="compact"
              hide-details
            />
            <v-select
              v-else-if="idx === 1"
              :model-value="row.is_second_starter ? 'second_starter' : 'reliever'"
              @update:model-value="
                (v: string) => {
                  row.is_second_starter = v === 'second_starter'
                }
              "
              :items="secondPitcherRoleOptions"
              item-title="label"
              item-value="value"
              label="区分"
              variant="outlined"
              density="compact"
              hide-details
            />
            <v-text-field
              v-else
              model-value="リリーフ"
              label="区分"
              variant="outlined"
              density="compact"
              hide-details
              readonly
            />
          </v-col>

          <!-- 投球回（整数） -->
          <v-col cols="3" sm="1">
            <v-text-field
              v-model.number="row.innings_int"
              label="回"
              type="number"
              step="1"
              min="0"
              variant="outlined"
              density="compact"
              hide-details
            />
          </v-col>

          <!-- 端数セレクト -->
          <v-col cols="4" sm="1">
            <v-select
              v-model="row.innings_frac"
              :items="fracOptions"
              item-title="label"
              item-value="value"
              label="端数"
              variant="outlined"
              density="compact"
              hide-details
            />
          </v-col>

          <!-- 0アウト降板 -->
          <v-col cols="auto">
            <v-checkbox
              v-model="row.no_out_exit"
              label="0アウト降板"
              density="compact"
              hide-details
            />
          </v-col>

          <!-- 責任投手チップ（W/L/S/H/—） -->
          <v-col cols="12" sm="3">
            <div class="d-flex align-center gap-1 flex-wrap">
              <v-chip
                v-for="opt in getDecisionChipOptions(idx)"
                :key="String(opt.value)"
                :color="getChipColor(opt.value, row.decision)"
                :variant="row.decision === opt.value ? 'elevated' : 'outlined'"
                :disabled="opt.disabled"
                size="small"
                style="cursor: pointer"
                @click="!opt.disabled && toggleDecision(row, opt.value)"
              >
                {{ opt.label }}
              </v-chip>
            </div>
          </v-col>
        </v-row>

        <!-- サブ情報行 -->
        <v-row density="compact" align="center" class="mt-1">
          <!-- オープナー本人チェック（1番手のopener選択時のみ） -->
          <v-col v-if="idx === 0 && row.role === 'opener'" cols="auto">
            <v-checkbox
              v-model="row.is_opener"
              label="オープナー（リリーフルール適用）"
              density="compact"
              hide-details
            />
          </v-col>

          <!-- 試合前状態テキスト -->
          <v-col cols="auto">
            <span v-if="getPitcherPreGameInfo(row.pitcher_id)" class="text-caption text-grey">
              {{ getPitcherPreGameInfo(row.pitcher_id) }}
            </span>
          </v-col>

          <!-- 結果区分チップ -->
          <v-col cols="auto" class="ml-auto">
            <span class="text-caption text-medium-emphasis mr-1">結果区分:</span>
            <v-chip size="x-small" :color="resultCategoryColor(computeResultCategory(idx))">
              {{ resultCategoryLabel(computeResultCategory(idx)) }}
            </v-chip>
          </v-col>
        </v-row>
      </div>

      <!-- 投手追加ボタン -->
      <v-btn variant="outlined" size="small" prepend-icon="mdi-plus" class="mt-1" @click="addRow">
        投手を追加
      </v-btn>

      <!-- エラー/警告/成功 -->
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
          prepend-icon="mdi-content-save"
          @click="saveAll"
        >
          登板記録を保存
        </v-btn>
      </div>

      <!-- 投手状態一覧 -->
      <v-divider class="my-4" />
      <div class="d-flex align-center mb-2">
        <span class="text-subtitle-2 font-weight-bold">投手状態一覧（1軍）</span>
        <v-btn
          icon
          size="x-small"
          variant="text"
          class="ml-1"
          :loading="loadingFatigue"
          @click="fetchFatigueSummary"
        >
          <v-icon>mdi-refresh</v-icon>
        </v-btn>
      </div>
      <v-table density="compact" v-if="fatigueSummary.length > 0">
        <thead>
          <tr>
            <th>投手名</th>
            <th>区分</th>
            <th>中日数 / 累積IP</th>
            <th>負傷</th>
            <th>登板時ステータス</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in fatigueSummary" :key="row.player_id">
            <td>
              <PlayerNameLink
                :player-id="row.player_id"
                :player-name="row.player_name"
                card-type="pitcher"
              />
            </td>
            <td>{{ lastRoleLabel(row.last_role) }}</td>
            <td>{{ fatigueDetail(row) }}</td>
            <td>{{ row.is_injured ? '🏥' : '' }}</td>
            <td>
              <v-chip :color="projectedStatusColor(row.projected_status)" size="x-small">
                {{ projectedStatusLabel(row.projected_status) }}
              </v-chip>
            </td>
          </tr>
        </tbody>
      </v-table>
      <div v-else-if="!loadingFatigue" class="text-caption text-grey">データなし</div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import PlayerNameLink from '@/components/shared/PlayerNameLink.vue'
import type {
  PitcherAppearanceInput,
  PitcherAppearanceRecord,
  PitcherRole,
  PitcherDecision,
} from '@/types/pitcherAppearance'

const props = defineProps<{
  teamId: number
  gameDate: string
  gameResult: 'win' | 'lose' | 'draw' | 'no_game'
  scheduleId: number
  announcedStarterId?: number | null
  competitionId?: number | null
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
  innings_int: number | null
  innings_frac: '' | '0' | '1' | '2'
}

interface FatigueSummaryRow {
  player_id: number
  player_name: string
  last_role: string | null
  rest_days: number | null
  cumulative_innings: number | null
  last_result_category: string | null
  is_injured: boolean
  is_unavailable: boolean
  projected_status: string
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
const fatigueSummary = ref<FatigueSummaryRow[]>([])
const loadingFatigue = ref(false)
const dragSrcIdx = ref<number | null>(null)

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

const secondPitcherRoleOptions = [
  { label: 'リリーフ', value: 'reliever' },
  { label: '第二先発', value: 'second_starter' },
]

const fracOptions = [
  { label: '—', value: '' },
  { label: '0/3', value: '0' },
  { label: '1/3', value: '1' },
  { label: '2/3', value: '2' },
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
    appearance_order: 0,
    innings_int: null,
    innings_frac: '',
  }
}

function computeIPFromRow(row: PitcherRow): number | null {
  if (row.innings_int === null && row.innings_frac === '') return null
  const base = row.innings_int ?? 0
  if (row.innings_frac === '1') return base + 0.1
  if (row.innings_frac === '2') return base + 0.2
  return base
}

function addRow() {
  pitcherRows.value.push(createEmptyRow('reliever'))
}

function removeRow(idx: number) {
  pitcherRows.value.splice(idx, 1)
}

// ドラッグ&ドロップ（リリーフのみ、先発=idx0は固定）
function onDragStart(idx: number, event: DragEvent) {
  dragSrcIdx.value = idx
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
  }
}

function onDragOver(idx: number, event: DragEvent) {
  if (idx === 0) return // 先発行へのドロップ禁止
  event.preventDefault()
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move'
  }
}

function onDrop(targetIdx: number, event: DragEvent) {
  event.preventDefault()
  const srcIdx = dragSrcIdx.value
  if (srcIdx === null || srcIdx === targetIdx || targetIdx === 0) return
  const rows = pitcherRows.value
  const moved = rows.splice(srcIdx, 1)[0]
  rows.splice(targetIdx, 0, moved)
  dragSrcIdx.value = null
}

function onDragEnd() {
  dragSrcIdx.value = null
}

function getPitcherPreGameInfo(pitcherId: number | null): string {
  if (!pitcherId) return ''
  const state = preGameStates.value.find((s) => s.player_id === pitcherId)
  return buildPreGameInfo(state)
}

function computeResultCategory(idx: number): string | null {
  const row = pitcherRows.value[idx]
  if (props.gameResult === 'no_game') return 'no_game'
  if (row.role !== 'starter') return 'normal'
  const innings = computeIPFromRow(row) ?? 0
  const hasSuccessor = pitcherRows.value.length > 1
  const fatigueP = row.fatigue_p_used ?? 0
  if (innings > 0 && innings < 5 && hasSuccessor) return 'ko'
  if (props.gameResult === 'lose' && fatigueP > 0 && innings > fatigueP + 1) return 'long_loss'
  return 'normal'
}

function getDecisionChipOptions(idx: number) {
  const hasW = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'W')
  const hasL = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'L')
  const hasS = pitcherRows.value.some((r, i) => i !== idx && r.decision === 'S')
  const row = pitcherRows.value[idx]
  const isStarter = row.role === 'starter'
  const isLastPitcher = idx === pitcherRows.value.length - 1
  const result = props.gameResult
  return [
    { label: 'W', value: 'W' as PitcherDecision, disabled: result !== 'win' || hasW },
    { label: 'L', value: 'L' as PitcherDecision, disabled: result !== 'lose' || hasL },
    {
      label: 'S',
      value: 'S' as PitcherDecision,
      disabled: isStarter || hasS || result !== 'win' || !isLastPitcher,
    },
    { label: 'H', value: 'H' as PitcherDecision, disabled: isStarter || isLastPitcher },
    { label: '—', value: null as PitcherDecision, disabled: false },
  ]
}

function getChipColor(value: PitcherDecision, current: PitcherDecision): string {
  if (value !== current) return 'default'
  const map: Record<string, string> = { W: 'warning', L: 'primary', S: 'success', H: 'info' }
  return value ? (map[value] ?? 'default') : 'default'
}

function toggleDecision(row: PitcherRow, value: PitcherDecision) {
  row.decision = row.decision === value ? null : value
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

function lastRoleLabel(role: string | null): string {
  const map: Record<string, string> = {
    starter: '先発',
    reliever: 'リリーフ',
    opener: 'オープナー',
  }
  return role ? (map[role] ?? role) : '未登板'
}

function fatigueDetail(row: FatigueSummaryRow): string {
  if (row.is_injured) return '—'
  if (row.last_role === 'starter') return row.rest_days != null ? `中${row.rest_days}日` : '—'
  if (row.last_role === 'reliever' || row.last_role === 'opener')
    return row.cumulative_innings != null ? `累積${row.cumulative_innings}` : '—'
  return '—'
}

function projectedStatusLabel(status: string): string {
  if (status === 'full') return '✅ 全快'
  if (status === 'injury_check') return '⚠️ 負傷CK'
  if (status === 'unavailable') return '🚫 不可'
  if (status === 'injured') return '🏥 負傷中'
  if (status.startsWith('reduced_')) {
    const n = status.replace('reduced_', '')
    return n === '0' ? '⚡ P0' : `⚡ P-${n}`
  }
  return status
}

function projectedStatusColor(status: string): string {
  if (status === 'full') return 'success'
  if (status === 'injury_check') return 'warning'
  if (status === 'unavailable' || status === 'injured') return 'error'
  return 'info'
}

// ─────────────────────────────────────────
// Data fetching
// ─────────────────────────────────────────

async function fetchFatigueSummary() {
  if (!props.gameDate) return
  loadingFatigue.value = true
  try {
    const res = await axios.get(`/teams/${props.teamId}/pitcher_game_states/fatigue_summary`, {
      params: { date: props.gameDate },
    })
    fatigueSummary.value = res.data
  } catch {
    fatigueSummary.value = []
  } finally {
    loadingFatigue.value = false
  }
}

async function fetchPitchersAndStates() {
  loadingPitchers.value = true
  pitcherRows.value = [createEmptyRow('starter')]
  errors.value = []
  warnings.value = []
  savedMessage.value = ''

  try {
    const [playersRes, statesRes, savedRes, membershipsRes] = await Promise.allSettled([
      axios.get(`/teams/${selectedTeamId.value}/team_players`),
      axios.get(`/teams/${selectedTeamId.value}/pitcher_game_states`, {
        params: { date: props.gameDate },
      }),
      axios.get('/pitcher_appearances', {
        params: { team_id: selectedTeamId.value, schedule_date: props.gameDate },
      }),
      axios.get(`/teams/${selectedTeamId.value}/team_memberships`),
    ])

    // Pre-game states
    if (statesRes.status === 'fulfilled') {
      preGameStates.value = statesRes.value.data
    } else {
      preGameStates.value = []
    }

    // Build pitcher items
    if (playersRes.status === 'fulfilled') {
      pitcherItems.value = playersRes.value.data
        .filter(
          (p: { position: string; is_pitcher?: boolean }) =>
            p.position === 'pitcher' || p.is_pitcher === true,
        )
        .map((p: { id: number; name: string }) => {
          const state = preGameStates.value.find((s) => s.player_id === p.id)
          const isInjured = state?.is_injured ?? false
          const preGameInfo = buildPreGameInfo(state)
          return {
            id: p.id,
            label: p.name,
            disabled: isInjured,
            statusBadge: isInjured ? '🏥' : '🟢',
            preGameInfo,
          }
        })
    }

    // pitcherItems構築後に保存済み登板記録または予告先発をセット
    const savedAppearances =
      savedRes.status === 'fulfilled' ? (savedRes.value.data as PitcherAppearanceRecord[]) : []

    if (savedAppearances.length > 0) {
      // 保存済みデータを復元（投手順序を維持）
      pitcherRows.value = savedAppearances.map((app, idx) => {
        const ip = app.innings_pitched
        let innings_int: number | null = null
        let innings_frac: '' | '0' | '1' | '2' = ''
        if (ip !== null && ip !== undefined) {
          innings_int = Math.floor(ip)
          const fracDigit = Math.round((ip - innings_int) * 10)
          innings_frac = fracDigit === 1 ? '1' : fracDigit === 2 ? '2' : ''
        }
        return {
          pitcher_id: app.pitcher_id,
          role: (idx === 0 ? app.role : 'reliever') as PitcherRole,
          innings_pitched: ip ?? null,
          earned_runs: app.earned_runs ?? 0,
          fatigue_p_used: app.fatigue_p_used ?? 0,
          decision: (app.decision as PitcherDecision) ?? null,
          is_opener: app.is_opener ?? false,
          is_second_starter: false,
          no_out_exit: app.no_out_exit ?? false,
          consecutive_short_rest_count: app.consecutive_short_rest_count ?? 0,
          pre_injury_days_excluded: app.pre_injury_days_excluded ?? 0,
          appearance_order: idx,
          innings_int,
          innings_frac,
        }
      })
    } else if (props.announcedStarterId) {
      // 保存済みデータなし → 予告先発を1番手にセット
      // announcedStarterIdはteam_membership_idのため、team_membershipsからplayer_idに変換する
      const memberships =
        membershipsRes.status === 'fulfilled'
          ? (membershipsRes.value.data as { id: number; player_id: number }[])
          : []
      const membership = memberships.find((m) => m.id === props.announcedStarterId)
      if (membership) {
        pitcherRows.value[0].pitcher_id = membership.player_id
      }
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

  const appearances = pitcherRows.value
    .filter((row) => !!row.pitcher_id)
    .map((row, idx) => ({
      pitcher_id: row.pitcher_id,
      role: row.role,
      innings_pitched: computeIPFromRow(row),
      no_out_exit: row.no_out_exit,
      earned_runs: row.earned_runs,
      fatigue_p_used: row.fatigue_p_used,
      decision: row.decision,
      is_opener: row.is_opener,
      consecutive_short_rest_count: row.consecutive_short_rest_count,
      pre_injury_days_excluded: row.pre_injury_days_excluded,
      appearance_order: idx,
    }))

  const payload = {
    pitcher_appearances_bulk: {
      team_id: props.teamId,
      competition_id: props.competitionId,
      schedule_date: props.gameDate,
      game_result: props.gameResult,
      appearances,
    },
  }

  try {
    const res = await axios.post('/pitcher_appearances/bulk_save', payload)
    warnings.value = res.data.warnings ?? []
    savedMessage.value = '登板記録を保存しました'
    await fetchPitchersAndStates()
  } catch (err: unknown) {
    const axiosErr = err as { response?: { data?: { errors?: string[]; pitcher_id?: number } } }
    const data = axiosErr.response?.data
    const errMsgs = data?.errors ?? ['登録に失敗しました']
    if (data?.pitcher_id) {
      const pitcherName =
        pitcherItems.value.find((p) => p.id === data.pitcher_id)?.label ??
        `pitcher_id=${data.pitcher_id}`
      errors.value.push(`${pitcherName}: ${errMsgs.join(', ')}`)
    } else {
      errors.value.push(...errMsgs)
    }
  }

  saving.value = false
}

// ─────────────────────────────────────────
// Lifecycle
// ─────────────────────────────────────────

onMounted(() => {
  fetchPitchersAndStates()
  fetchFatigueSummary()
})
</script>

<style scoped>
.pitcher-row {
  border: 1px solid rgba(0, 0, 0, 0.12);
}
</style>
