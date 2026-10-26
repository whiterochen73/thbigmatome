<template>
  <div>
    <template v-if="loading">
      <div data-testid="loading-spinner" class="d-flex justify-center">
        <v-progress-circular indeterminate color="primary" size="24" />
      </div>
    </template>

    <template v-else-if="error">
      <v-alert type="error" density="compact">投手状態の取得に失敗しました</v-alert>
    </template>

    <template v-else>
      <!-- 先発投手 -->
      <div class="mb-4">
        <div class="d-flex align-center justify-space-between mb-1">
          <span class="text-subtitle-2 font-weight-bold">先発投手</span>
          <v-btn
            v-if="hasStarterCustomOrder"
            size="x-small"
            variant="outlined"
            @click="resetStarterOrder"
            >初期順にリセット</v-btn
          >
        </div>
        <v-table density="compact">
          <thead>
            <tr>
              <th style="width: 32px"></th>
              <th>選手名</th>
              <th class="text-center">中日数</th>
              <th class="text-center">累積</th>
              <th class="text-center">疲労P</th>
              <th class="text-center">先発なら</th>
              <th class="text-center">リリーフなら</th>
              <th
                class="text-center"
                data-testid="opener-column-header"
                :title="openerHeaderTitle(pitchers)"
              >
                オープナーなら
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(pitcher, idx) in orderedStarters"
              :key="pitcher.player_id"
              draggable="true"
              :class="{ 'drag-over': dragOverIndex === idx && dragSection === 'starters' }"
              style="cursor: grab"
              @dragstart="onDragStart(idx, 'starters')"
              @dragover.prevent="onDragOver(idx, 'starters')"
              @drop="onDrop(idx, 'starters')"
              @dragend="onDragEnd"
            >
              <td class="text-center text-grey" style="cursor: grab">☰</td>
              <td>
                <PlayerNameLink
                  :player-id="pitcher.player_id"
                  :player-name="pitcher.player_name"
                  card-type="pitcher"
                />
              </td>
              <td class="text-center">{{ pitcher.rest_days != null ? pitcher.rest_days : '-' }}</td>
              <td class="text-center text-grey">-</td>
              <td class="text-center">{{ starterFatiguePLabel(pitcher) }}</td>
              <td class="text-center">
                <PitcherRoleStateCell
                  :state="pitcher.as_starter"
                  :test-id="`as-starter-${pitcher.player_id}`"
                />
              </td>
              <td class="text-center">
                <PitcherRoleStateCell
                  :state="pitcher.as_reliever"
                  :test-id="`as-reliever-${pitcher.player_id}`"
                />
              </td>
              <td class="text-center">
                <PitcherRoleStateCell
                  :state="pitcher.as_opener"
                  :test-id="`as-opener-${pitcher.player_id}`"
                />
              </td>
            </tr>
            <tr v-if="orderedStarters.length === 0">
              <td colspan="8" class="text-center text-grey text-caption py-2">先発投手なし</td>
            </tr>
          </tbody>
        </v-table>
      </div>

      <!-- リリーフ投手 -->
      <div>
        <div class="d-flex align-center justify-space-between mb-1">
          <span class="text-subtitle-2 font-weight-bold">リリーフ投手</span>
          <v-btn
            v-if="hasRelieverCustomOrder"
            size="x-small"
            variant="outlined"
            @click="resetRelieverOrder"
            >初期順にリセット</v-btn
          >
        </div>
        <v-table density="compact">
          <thead>
            <tr>
              <th style="width: 32px"></th>
              <th>選手名</th>
              <th class="text-center">中日数</th>
              <th class="text-center">累積</th>
              <th class="text-center">疲労P</th>
              <th class="text-center">先発なら</th>
              <th class="text-center">リリーフなら</th>
              <th
                class="text-center"
                data-testid="opener-column-header"
                :title="openerHeaderTitle(pitchers)"
              >
                オープナーなら
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(pitcher, idx) in orderedRelievers"
              :key="pitcher.player_id"
              draggable="true"
              :class="{ 'drag-over': dragOverIndex === idx && dragSection === 'relievers' }"
              style="cursor: grab"
              @dragstart="onDragStart(idx, 'relievers')"
              @dragover.prevent="onDragOver(idx, 'relievers')"
              @drop="onDrop(idx, 'relievers')"
              @dragend="onDragEnd"
            >
              <td class="text-center text-grey" style="cursor: grab">☰</td>
              <td>
                <PlayerNameLink
                  :player-id="pitcher.player_id"
                  :player-name="pitcher.player_name"
                  card-type="pitcher"
                />
              </td>
              <td class="text-center">{{ pitcher.rest_days != null ? pitcher.rest_days : '-' }}</td>
              <td class="text-center">
                {{ pitcher.cumulative_innings != null ? pitcher.cumulative_innings : '-' }}
              </td>
              <td class="text-center text-grey">-</td>
              <td class="text-center">
                <PitcherRoleStateCell
                  :state="pitcher.as_starter"
                  :test-id="`as-starter-${pitcher.player_id}`"
                />
              </td>
              <td class="text-center">
                <PitcherRoleStateCell
                  :state="pitcher.as_reliever"
                  :test-id="`as-reliever-${pitcher.player_id}`"
                />
              </td>
              <td class="text-center">
                <PitcherRoleStateCell
                  :state="pitcher.as_opener"
                  :test-id="`as-opener-${pitcher.player_id}`"
                />
              </td>
            </tr>
            <tr v-if="orderedRelievers.length === 0">
              <td colspan="8" class="text-center text-grey text-caption py-2">リリーフ投手なし</td>
            </tr>
          </tbody>
        </v-table>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import axios from 'axios'
import PlayerNameLink from '@/components/shared/PlayerNameLink.vue'
import PitcherRoleStateCell from './PitcherRoleStateCell.vue'
import { openerHeaderTitle } from './pitcherRoleState'
import type {
  OpenerCapableSource,
  PitcherRoleOmittedReason,
  PitcherRoleState,
} from './pitcherRoleState'

interface PitcherStatus {
  player_id: number
  player_name: string
  last_role: string | null
  rest_days: number | null
  cumulative_innings: number | null
  is_injured: boolean
  is_unavailable: boolean
  // 前回と同じ役割で続ける場合の状態（旧来の値）。役割別の状態は as_starter / as_reliever
  projected_status: string
  // 投手ごとの「先発なら」「リリーフなら」「オープナーなら」。省略する投手は null（理由は *_omitted_reason）
  as_starter?: PitcherRoleState | null
  as_reliever?: PitcherRoleState | null
  // 「オープナー可」アビリティを持つ投手だけ値がある（持たない投手は null）
  as_opener?: PitcherRoleState | null
  as_starter_omitted_reason?: PitcherRoleOmittedReason
  as_reliever_omitted_reason?: PitcherRoleOmittedReason
  as_opener_omitted_reason?: PitcherRoleOmittedReason
  // as_opener の出し分けの根拠（fallback_all_relievers = データ未取込のためリリーフ可能な投手全員）
  opener_capable_source?: OpenerCapableSource
}

interface LocalStorageOrder {
  starters: number[]
  relievers: number[]
}

const props = defineProps<{
  teamId: number
  scheduleDate: string
  competitionId: number | null
}>()

const loading = ref(false)
const error = ref(false)
const pitchers = ref<PitcherStatus[]>([])

const dragStartIndex = ref<number | null>(null)
const dragSection = ref<'starters' | 'relievers' | null>(null)
const dragOverIndex = ref<number | null>(null)

const localStorageKey = computed(() => `pitcher_status_order_${props.teamId}`)

function loadOrder(): LocalStorageOrder | null {
  try {
    const raw = localStorage.getItem(localStorageKey.value)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

function saveOrder(starters: PitcherStatus[], relievers: PitcherStatus[]) {
  const order: LocalStorageOrder = {
    starters: starters.map((p) => p.player_id),
    relievers: relievers.map((p) => p.player_id),
  }
  localStorage.setItem(localStorageKey.value, JSON.stringify(order))
}

const defaultStarters = computed(() =>
  pitchers.value
    .filter((p) => p.last_role === 'starter')
    .sort((a, b) => (b.rest_days ?? -1) - (a.rest_days ?? -1)),
)

const defaultRelievers = computed(() => pitchers.value.filter((p) => p.last_role !== 'starter'))

const orderedStarters = ref<PitcherStatus[]>([])
const orderedRelievers = ref<PitcherStatus[]>([])

const hasStarterCustomOrder = computed(() => {
  const saved = loadOrder()
  return saved != null && saved.starters.length > 0
})

const hasRelieverCustomOrder = computed(() => {
  const saved = loadOrder()
  return saved != null && saved.relievers.length > 0
})

function applyOrder() {
  const saved = loadOrder()
  if (!saved) {
    orderedStarters.value = [...defaultStarters.value]
    orderedRelievers.value = [...defaultRelievers.value]
    return
  }

  const reorder = (list: PitcherStatus[], ids: number[]) => {
    const map = new Map(list.map((p) => [p.player_id, p]))
    const ordered = ids.flatMap((id) => (map.has(id) ? [map.get(id)!] : []))
    const remaining = list.filter((p) => !ids.includes(p.player_id))
    return [...ordered, ...remaining]
  }

  orderedStarters.value = reorder(defaultStarters.value, saved.starters)
  orderedRelievers.value = reorder(defaultRelievers.value, saved.relievers)
}

watch(
  () => pitchers.value,
  () => applyOrder(),
  { deep: true },
)

async function fetchPitcherStatuses() {
  loading.value = true
  error.value = false
  try {
    const params: Record<string, string> = {}
    if (props.scheduleDate) params.date = props.scheduleDate
    const response = await axios.get(`/teams/${props.teamId}/pitcher_game_states/fatigue_summary`, {
      params,
    })
    pitchers.value = response.data
  } catch {
    error.value = true
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchPitcherStatuses()
})

watch(
  () => [props.teamId, props.scheduleDate],
  () => fetchPitcherStatuses(),
)

function starterFatiguePLabel(pitcher: PitcherStatus): string {
  const s = pitcher.projected_status
  if (s.startsWith('reduced_')) {
    const n = s.replace('reduced_', '')
    return `-${n}P`
  }
  return '-'
}

// Drag & Drop
function onDragStart(idx: number, section: 'starters' | 'relievers') {
  dragStartIndex.value = idx
  dragSection.value = section
}

function onDragOver(idx: number, section: 'starters' | 'relievers') {
  if (dragSection.value !== section) return
  dragOverIndex.value = idx
}

function onDrop(idx: number, section: 'starters' | 'relievers') {
  if (dragSection.value !== section || dragStartIndex.value === null) return
  const from = dragStartIndex.value
  const to = idx
  if (from === to) return

  const list = section === 'starters' ? orderedStarters.value : orderedRelievers.value
  const item = list.splice(from, 1)[0]
  list.splice(to, 0, item)

  saveOrder(orderedStarters.value, orderedRelievers.value)
}

function onDragEnd() {
  dragStartIndex.value = null
  dragSection.value = null
  dragOverIndex.value = null
}

function resetStarterOrder() {
  const saved = loadOrder()
  if (!saved) return
  const newOrder: LocalStorageOrder = { starters: [], relievers: saved.relievers }
  if (newOrder.relievers.length === 0) {
    localStorage.removeItem(localStorageKey.value)
  } else {
    localStorage.setItem(localStorageKey.value, JSON.stringify(newOrder))
  }
  orderedStarters.value = [...defaultStarters.value]
}

function resetRelieverOrder() {
  const saved = loadOrder()
  if (!saved) return
  const newOrder: LocalStorageOrder = { starters: saved.starters, relievers: [] }
  if (newOrder.starters.length === 0) {
    localStorage.removeItem(localStorageKey.value)
  } else {
    localStorage.setItem(localStorageKey.value, JSON.stringify(newOrder))
  }
  orderedRelievers.value = [...defaultRelievers.value]
}
</script>

<style scoped>
.drag-over {
  background-color: rgba(var(--v-theme-primary), 0.1);
}
</style>
