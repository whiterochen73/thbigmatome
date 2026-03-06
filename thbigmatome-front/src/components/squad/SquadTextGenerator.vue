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

      <!-- 読み込み済み: バリデーション警告 + 打順リスト -->
      <template v-else>
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
      </template>
    </v-card-text>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, toRef } from 'vue'
import axios from 'axios'
import { useSquadTextStore } from '@/stores/squadText'
import { useLineupTemplate } from '@/composables/useLineupTemplate'
import type { RosterPlayer } from '@/types/rosterPlayer'

const props = defineProps<{
  teamId: number
}>()

const store = useSquadTextStore()
const teamIdRef = toRef(props, 'teamId')
const { loadFromTemplate, loadFromPrevious } = useLineupTemplate(teamIdRef)

const showTemplateSelect = ref(false)
const selectedTemplateId = ref<number | null>(null)
const loadingTemplate = ref(false)
const loadingPrevious = ref(false)
const hasPrevious = ref(false)
const previousChecked = ref(false)

interface TemplateInfo {
  id: number
  dh_enabled: boolean
  opponent_pitcher_hand: 'left' | 'right'
}
const templates = ref<TemplateInfo[]>([])

// 1軍メンバーと離脱者 (SeasonPortalから渡す想定だが、ここで独自取得)
const firstSquadMembers = ref<RosterPlayer[]>([])
const absentPlayers = ref<RosterPlayer[]>([])

const hasValidationWarnings = computed(() => store.validationResults.some((r) => r.status !== 'ok'))

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

async function fetchRosterData() {
  try {
    const res = await axios.get<RosterPlayer[]>(`/teams/${props.teamId}/roster`)
    firstSquadMembers.value = res.data.filter((p) => p.squad === 'first' && !p.is_absent)
    absentPlayers.value = res.data.filter((p) => p.is_absent)
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

onMounted(async () => {
  await Promise.all([fetchRosterData(), fetchTemplates(), checkPreviousData()])
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
</style>
