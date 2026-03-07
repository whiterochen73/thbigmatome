<template>
  <v-card variant="outlined" class="mt-2">
    <v-card-title class="d-flex align-center pa-4"> スカッドテキスト生成 </v-card-title>

    <v-card-text>
      <!-- 開始方法選択 -->
      <template v-if="store.mode === null">
        <div class="d-flex flex-wrap ga-3 mb-4">
          <v-btn
            color="primary"
            variant="elevated"
            prepend-icon="mdi-format-list-numbered"
            @click="showTemplateSelect = true"
          >
            テンプレートから始める
          </v-btn>
          <v-btn
            color="secondary"
            variant="elevated"
            prepend-icon="mdi-history"
            :disabled="!hasPrevious"
            :loading="loadingPrevious"
            @click="startFromPrevious"
          >
            前回のオーダーから始める
          </v-btn>
        </div>

        <!-- 前回データなし通知 -->
        <v-alert
          v-if="previousChecked && !hasPrevious"
          type="info"
          variant="tonal"
          density="compact"
          class="mb-3"
        >
          前回のオーダーデータがありません。テンプレートから始めてください。
        </v-alert>

        <!-- テンプレート選択 -->
        <v-expand-transition>
          <div v-if="showTemplateSelect">
            <p class="text-body-2 mb-3">パターンを選択してください：</p>
            <div class="d-flex flex-wrap ga-2 mb-4">
              <v-btn
                v-for="tmpl in templates"
                :key="tmpl.id"
                :color="selectedTemplateId === tmpl.id ? 'primary' : 'default'"
                :variant="selectedTemplateId === tmpl.id ? 'elevated' : 'outlined'"
                size="small"
                :loading="loadingTemplate && selectedTemplateId === tmpl.id"
                @click="startFromTemplate(tmpl.id, tmpl.dh_enabled, tmpl.opponent_pitcher_hand)"
              >
                {{ patternLabel(tmpl.dh_enabled, tmpl.opponent_pitcher_hand) }}
              </v-btn>
            </div>
            <v-alert v-if="templates.length === 0" type="warning" variant="tonal" density="compact">
              テンプレートが登録されていません。オーダータブでテンプレートを作成してください。
            </v-alert>
          </div>
        </v-expand-transition>
      </template>

      <!-- 読み込み済み: 2カラムレイアウト -->
      <template v-else>
        <v-row>
          <!-- 左カラム: 打順・ベンチ振り分け -->
          <v-col cols="12" lg="6">
            <!-- バリデーション警告 -->
            <v-alert
              v-if="hasValidationWarnings"
              type="warning"
              variant="tonal"
              density="compact"
              class="mb-4"
              icon="mdi-alert"
            >
              使用できない選手が含まれています。確認して差し替えてください。
            </v-alert>

            <!-- 打順リスト -->
            <div class="lineup-table-wrapper mb-4">
              <table class="lineup-table">
                <thead>
                  <tr>
                    <th class="order-col">打順</th>
                    <th class="pos-col">ポジション</th>
                    <th class="player-col">選手</th>
                    <th class="status-col"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="entry in store.startingLineup"
                    :key="entry.battingOrder"
                    :class="{ 'row-warning': getValidationStatus(entry.battingOrder) !== 'ok' }"
                  >
                    <td class="order-col text-center font-weight-bold">{{ entry.battingOrder }}</td>
                    <td class="pos-col">{{ entry.position }}</td>
                    <td class="player-col">
                      <span>{{ entry.playerName || `#${entry.playerId}` }}</span>
                      <span v-if="entry.playerNumber" class="text-caption text-medium-emphasis ml-1"
                        >({{ entry.playerNumber }})</span
                      >
                    </td>
                    <td class="status-col">
                      <v-chip
                        v-if="getValidationStatus(entry.battingOrder) !== 'ok'"
                        size="x-small"
                        color="warning"
                        variant="tonal"
                      >
                        {{ getValidationReason(entry.battingOrder) }}
                      </v-chip>
                      <v-icon v-else size="small" color="success">mdi-check-circle</v-icon>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- ベンチ振り分け -->
            <div class="mb-4">
              <div class="text-subtitle-1 font-weight-medium mb-3">ベンチ振り分け</div>

              <!-- 野手 -->
              <div v-if="nonStarterHitters.length > 0" class="mb-4">
                <div class="text-subtitle-2 text-medium-emphasis mb-2">野手</div>
                <div
                  v-for="p in nonStarterHitters"
                  :key="p.player_id"
                  class="d-flex align-center ga-2 mb-2 flex-wrap"
                >
                  <span class="player-label text-body-2"> {{ p.number }} {{ p.player_name }} </span>
                  <v-btn-toggle
                    :model-value="getHitterCategory(p.player_id)"
                    density="compact"
                    color="primary"
                    variant="outlined"
                    @update:model-value="
                      (v: 'bench' | 'off' | null) => setHitterCategory(p.player_id, v)
                    "
                  >
                    <v-btn value="bench" size="small">ベンチ</v-btn>
                    <v-btn value="off" size="small">オフ</v-btn>
                  </v-btn-toggle>
                </div>
              </div>

              <!-- 投手 -->
              <div v-if="nonStarterPitchers.length > 0">
                <div class="text-subtitle-2 text-medium-emphasis mb-2">投手</div>
                <div
                  v-for="p in nonStarterPitchers"
                  :key="p.player_id"
                  class="d-flex align-center ga-2 mb-2 flex-wrap"
                >
                  <span class="player-label text-body-2"> {{ p.number }} {{ p.player_name }} </span>
                  <v-btn-toggle
                    :model-value="getPitcherCategory(p.player_id)"
                    density="compact"
                    color="primary"
                    variant="outlined"
                    @update:model-value="
                      (v: 'relief' | 'starter_bench' | 'off' | null) =>
                        setPitcherCategory(p.player_id, v)
                    "
                  >
                    <v-btn value="relief" size="small">中継ぎ</v-btn>
                    <v-btn value="starter_bench" size="small">先発ベンチ</v-btn>
                    <v-btn value="off" size="small">オフ</v-btn>
                  </v-btn-toggle>
                </div>
              </div>

              <div
                v-if="nonStarterHitters.length === 0 && nonStarterPitchers.length === 0"
                class="text-body-2 text-medium-emphasis"
              >
                スタメン以外の1軍メンバーがいません。
              </div>
            </div>

            <!-- リセットボタン -->
            <v-btn
              variant="text"
              color="error"
              size="small"
              prepend-icon="mdi-restart"
              @click="resetAndRestart"
            >
              最初からやり直す
            </v-btn>
          </v-col>

          <!-- 右カラム: プレビュー -->
          <v-col cols="12" lg="6">
            <div class="text-subtitle-2 font-weight-medium mb-2">プレビュー</div>
            <v-progress-circular
              v-if="generatorLoading"
              indeterminate
              color="primary"
              size="24"
              class="mb-2"
            />
            <pre v-else class="preview-text">{{ generatedText }}</pre>

            <div class="d-flex align-center ga-2 mt-3">
              <v-btn
                color="primary"
                variant="elevated"
                prepend-icon="mdi-content-copy"
                :loading="copying"
                :disabled="!generatedText"
                @click="copyAndSave"
              >
                コピー
              </v-btn>
              <span v-if="copySuccess" class="text-success text-caption"> コピーしました </span>
            </div>
          </v-col>
        </v-row>
      </template>
    </v-card-text>

    <!-- Snackbar: 保存エラー -->
    <v-snackbar v-model="saveError" color="error" timeout="4000">
      自動保存に失敗しました
    </v-snackbar>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, toRef, watch } from 'vue'
import axios from 'axios'
import { useSquadTextStore } from '@/stores/squadText'
import { useLineupTemplate } from '@/composables/useLineupTemplate'
import { useSquadTextGenerator } from '@/composables/useSquadTextGenerator'
import type { RosterPlayer } from '@/types/rosterPlayer'

const props = defineProps<{
  teamId: number
}>()

const store = useSquadTextStore()
const teamIdRef = toRef(props, 'teamId')
const { loadFromTemplate, loadFromPrevious } = useLineupTemplate(teamIdRef)

const {
  loading: generatorLoading,
  generatedText,
  init: initGenerator,
  saveAsGameLineup,
} = useSquadTextGenerator(teamIdRef)

const showTemplateSelect = ref(false)
const selectedTemplateId = ref<number | null>(null)
const loadingTemplate = ref(false)
const loadingPrevious = ref(false)
const hasPrevious = ref(false)
const previousChecked = ref(false)
const copying = ref(false)
const copySuccess = ref(false)
const saveError = ref(false)

interface TemplateInfo {
  id: number
  dh_enabled: boolean
  opponent_pitcher_hand: 'left' | 'right'
}
const templates = ref<TemplateInfo[]>([])

const firstSquadMembers = ref<RosterPlayer[]>([])
const absentPlayers = ref<RosterPlayer[]>([])

const hasValidationWarnings = computed(() => store.validationResults.some((r) => r.status !== 'ok'))

// スタメンID
const starterIds = computed(() => new Set(store.startingLineup.map((e) => e.playerId)))

// スタメン以外の野手
const nonStarterHitters = computed(() =>
  firstSquadMembers.value.filter((p) => !starterIds.value.has(p.player_id) && p.position !== 'P'),
)

// スタメン以外の投手
const nonStarterPitchers = computed(() =>
  firstSquadMembers.value.filter((p) => !starterIds.value.has(p.player_id) && p.position === 'P'),
)

function getValidationStatus(battingOrder: number) {
  return store.validationResults.find((r) => r.battingOrder === battingOrder)?.status ?? 'ok'
}

function getValidationReason(battingOrder: number) {
  return store.validationResults.find((r) => r.battingOrder === battingOrder)?.reason ?? ''
}

function patternLabel(dhEnabled: boolean, hand: 'left' | 'right') {
  const dh = dhEnabled ? 'DH有' : 'DH無'
  const h = hand === 'right' ? '対右' : '対左'
  return `${dh}・${h}`
}

// 野手カテゴリ取得
function getHitterCategory(playerId: number): 'bench' | 'off' | null {
  if (store.benchPlayers.includes(playerId)) return 'bench'
  if (store.offPlayers.includes(playerId)) return 'off'
  return null
}

// 野手カテゴリ設定
function setHitterCategory(playerId: number, category: 'bench' | 'off' | null) {
  store.benchPlayers = store.benchPlayers.filter((id) => id !== playerId)
  store.offPlayers = store.offPlayers.filter((id) => id !== playerId)
  if (category === 'bench') store.benchPlayers = [...store.benchPlayers, playerId]
  else if (category === 'off') store.offPlayers = [...store.offPlayers, playerId]
}

// 投手カテゴリ取得
function getPitcherCategory(playerId: number): 'relief' | 'starter_bench' | 'off' | null {
  if (store.reliefPitcherIds.includes(playerId)) return 'relief'
  if (store.starterBenchPitcherIds.includes(playerId)) return 'starter_bench'
  if (store.offPlayers.includes(playerId)) return 'off'
  return null
}

// 投手カテゴリ設定
function setPitcherCategory(playerId: number, category: 'relief' | 'starter_bench' | 'off' | null) {
  store.reliefPitcherIds = store.reliefPitcherIds.filter((id) => id !== playerId)
  store.starterBenchPitcherIds = store.starterBenchPitcherIds.filter((id) => id !== playerId)
  store.offPlayers = store.offPlayers.filter((id) => id !== playerId)
  if (category === 'relief') store.reliefPitcherIds = [...store.reliefPitcherIds, playerId]
  else if (category === 'starter_bench')
    store.starterBenchPitcherIds = [...store.starterBenchPitcherIds, playerId]
  else if (category === 'off') store.offPlayers = [...store.offPlayers, playerId]
}

async function copyAndSave() {
  const text = generatedText.value
  if (!text) return
  copying.value = true
  try {
    await navigator.clipboard.writeText(text)
    copySuccess.value = true
    setTimeout(() => {
      copySuccess.value = false
    }, 3000)
    try {
      await saveAsGameLineup()
    } catch {
      saveError.value = true
    }
  } finally {
    copying.value = false
  }
}

async function fetchRosterData() {
  try {
    const res = await axios.get<{ roster: RosterPlayer[] }>(`/teams/${props.teamId}/roster`)
    firstSquadMembers.value = (res.data.roster || []).filter(
      (p: RosterPlayer) => p.squad === 'first' && !p.is_absent,
    )
    absentPlayers.value = (res.data.roster || []).filter((p: RosterPlayer) => p.is_absent)
  } catch (e) {
    console.error('Failed to fetch roster:', e)
  }
}

async function fetchTemplates() {
  try {
    const res = await axios.get<TemplateInfo[]>(`/teams/${props.teamId}/lineup_templates`)
    templates.value = res.data
  } catch (e) {
    console.error('Failed to fetch templates:', e)
  }
}

async function checkPreviousData() {
  try {
    await axios.get(`/teams/${props.teamId}/game_lineup`)
    hasPrevious.value = true
  } catch {
    hasPrevious.value = false
  } finally {
    previousChecked.value = true
  }
}

async function startFromTemplate(templateId: number, dhEnabled: boolean, hand: 'left' | 'right') {
  selectedTemplateId.value = templateId
  loadingTemplate.value = true
  store.dhEnabled = dhEnabled
  store.opponentPitcherHand = hand
  try {
    await loadFromTemplate(templateId, firstSquadMembers.value, absentPlayers.value)
    showTemplateSelect.value = false
  } catch (e) {
    console.error('Failed to load template:', e)
  } finally {
    loadingTemplate.value = false
  }
}

async function startFromPrevious() {
  loadingPrevious.value = true
  try {
    const result = await loadFromPrevious(firstSquadMembers.value, absentPlayers.value)
    if (result === null) {
      hasPrevious.value = false
    }
  } catch (e) {
    console.error('Failed to load previous lineup:', e)
  } finally {
    loadingPrevious.value = false
  }
}

function resetAndRestart() {
  store.reset()
  showTemplateSelect.value = false
  selectedTemplateId.value = null
}

// modeが設定されたらgeneratorを初期化
watch(
  () => store.mode,
  (newMode) => {
    if (newMode !== null && firstSquadMembers.value.length > 0) {
      initGenerator(firstSquadMembers.value)
    }
  },
)

onMounted(async () => {
  await Promise.all([fetchRosterData(), fetchTemplates(), checkPreviousData()])
  // 既にmodeが設定されている場合（前回データ復元など）も初期化
  if (store.mode !== null) {
    await initGenerator(firstSquadMembers.value)
  }
})
</script>

<style scoped>
.lineup-table-wrapper {
  overflow-x: auto;
}

.lineup-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.lineup-table th,
.lineup-table td {
  padding: 6px 8px;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  vertical-align: middle;
}

.lineup-table th {
  font-size: 0.8rem;
  font-weight: 600;
  color: rgb(var(--v-theme-on-surface-variant));
  white-space: nowrap;
}

.order-col {
  width: 48px;
  text-align: center;
}

.pos-col {
  width: 80px;
}

.player-col {
  min-width: 160px;
}

.status-col {
  width: 100px;
}

.row-warning td {
  background-color: rgba(var(--v-theme-warning), 0.08);
}

.player-label {
  min-width: 120px;
  flex-shrink: 0;
}

.preview-text {
  font-family: 'Courier New', Courier, monospace;
  font-size: 0.8rem;
  white-space: pre-wrap;
  word-break: break-all;
  background-color: rgba(var(--v-theme-surface-variant), 0.4);
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 4px;
  padding: 12px;
  min-height: 200px;
  max-height: 480px;
  overflow-y: auto;
  line-height: 1.6;
}
</style>
