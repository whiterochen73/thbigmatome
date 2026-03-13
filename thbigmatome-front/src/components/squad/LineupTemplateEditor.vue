<template>
  <v-card variant="outlined" class="mt-2">
    <v-card-title class="d-flex align-center pa-4">
      {{ t('lineupTemplate.title') }}
    </v-card-title>

    <v-card-text>
      <!-- パターン切替タブ -->
      <v-tabs v-model="activePattern" color="primary" density="compact" class="mb-4">
        <v-tab v-for="p in patterns" :key="p.key" :value="p.key">{{ p.label }}</v-tab>
      </v-tabs>

      <!-- 打順リスト -->
      <div class="lineup-table-wrapper">
        <table class="lineup-table">
          <thead>
            <tr>
              <th class="order-col">{{ t('lineupTemplate.battingOrder') }}</th>
              <th class="pos-col">{{ t('lineupTemplate.position') }}</th>
              <th class="player-col">{{ t('lineupTemplate.player') }}</th>
              <th class="action-col"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(entry, idx) in currentEntries" :key="idx">
              <td class="order-col text-center font-weight-bold">{{ idx + 1 }}</td>
              <td class="pos-col">
                <v-select
                  v-model="entry.position"
                  :items="positions"
                  density="compact"
                  variant="outlined"
                  hide-details
                  class="pos-select"
                />
              </td>
              <td class="player-col">
                <v-autocomplete
                  v-model="entry.player_id"
                  :items="firstSquadItems"
                  item-title="label"
                  item-value="player_id"
                  density="compact"
                  variant="outlined"
                  hide-details
                  clearable
                  :no-data-text="t('lineupTemplate.noFirstSquad')"
                  class="player-autocomplete"
                />
              </td>
              <td class="action-col">
                <div class="d-flex flex-column" style="gap: 2px">
                  <v-btn
                    icon
                    size="x-small"
                    variant="text"
                    :disabled="idx === 0"
                    @click="moveUp(idx)"
                  >
                    <v-icon size="16">mdi-arrow-up</v-icon>
                  </v-btn>
                  <v-btn
                    icon
                    size="x-small"
                    variant="text"
                    :disabled="idx === currentEntries.length - 1"
                    @click="moveDown(idx)"
                  >
                    <v-icon size="16">mdi-arrow-down</v-icon>
                  </v-btn>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 保存・削除ボタン -->
      <div class="d-flex align-center mt-4" style="gap: 8px">
        <v-btn color="accent" variant="flat" :loading="saving" @click="saveTemplate">
          {{ t('lineupTemplate.save') }}
        </v-btn>
        <v-btn
          v-if="currentTemplateId !== null"
          color="error"
          variant="outlined"
          :loading="deleting"
          @click="confirmDelete"
        >
          {{ t('lineupTemplate.delete') }}
        </v-btn>
        <v-snackbar v-model="snackbar.show" :color="snackbar.color" :timeout="2500" location="top">
          {{ snackbar.message }}
        </v-snackbar>
      </div>
    </v-card-text>

    <!-- 削除確認ダイアログ -->
    <v-dialog v-model="deleteDialog" max-width="360">
      <v-card>
        <v-card-title>{{ t('lineupTemplate.confirmDelete') }}</v-card-title>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">キャンセル</v-btn>
          <v-btn color="error" variant="elevated" :loading="deleting" @click="deleteTemplate">
            {{ t('lineupTemplate.delete') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import type { RosterPlayer } from '@/types/rosterPlayer'

const props = defineProps<{
  teamId: number
}>()

const { t } = useI18n()

interface LineupEntry {
  id?: number
  batting_order: number
  player_id: number | null
  position: string
  player_name?: string
  player_number?: string
}

interface LineupTemplateData {
  id: number
  dh_enabled: boolean
  opponent_pitcher_hand: 'left' | 'right'
  entries: LineupEntry[]
}

type PatternKey = 'dh_right' | 'dh_left' | 'nodh_right' | 'nodh_left'

interface Pattern {
  key: PatternKey
  label: string
  dh_enabled: boolean
  opponent_pitcher_hand: 'left' | 'right'
}

const patterns: Pattern[] = [
  {
    key: 'dh_right',
    label: computed(() => t('lineupTemplate.patterns.dhRight')).value,
    dh_enabled: true,
    opponent_pitcher_hand: 'right',
  },
  {
    key: 'dh_left',
    label: computed(() => t('lineupTemplate.patterns.dhLeft')).value,
    dh_enabled: true,
    opponent_pitcher_hand: 'left',
  },
  {
    key: 'nodh_right',
    label: computed(() => t('lineupTemplate.patterns.noDhRight')).value,
    dh_enabled: false,
    opponent_pitcher_hand: 'right',
  },
  {
    key: 'nodh_left',
    label: computed(() => t('lineupTemplate.patterns.noDhLeft')).value,
    dh_enabled: false,
    opponent_pitcher_hand: 'left',
  },
]

const positions = ['C', '1B', '2B', '3B', 'SS', 'LF', 'CF', 'RF', 'P', 'DH']

const activePattern = ref<PatternKey>('dh_right')
const templates = ref<LineupTemplateData[]>([])
const firstSquad = ref<RosterPlayer[]>([])
const saving = ref(false)
const deleting = ref(false)
const deleteDialog = ref(false)
const snackbar = ref({ show: false, message: '', color: 'success' })

// 1軍メンバーのオートコンプリート用アイテム
const firstSquadItems = computed(() =>
  firstSquad.value.map((p) => ({
    player_id: p.player_id,
    label: `${p.number} ${p.player_name}`,
  })),
)

// 現在のパターンのテンプレート
const currentPattern = computed(() => patterns.find((p) => p.key === activePattern.value)!)

const currentTemplate = computed(() =>
  templates.value.find(
    (t) =>
      t.dh_enabled === currentPattern.value.dh_enabled &&
      t.opponent_pitcher_hand === currentPattern.value.opponent_pitcher_hand,
  ),
)

const currentTemplateId = computed(() => currentTemplate.value?.id ?? null)

// 編集中エントリ（パターンごとにローカル管理）
const localEntries = ref<Record<PatternKey, LineupEntry[]>>({
  dh_right: makeEmptyEntries(),
  dh_left: makeEmptyEntries(),
  nodh_right: makeEmptyEntries(),
  nodh_left: makeEmptyEntries(),
})

const currentEntries = computed(() => localEntries.value[activePattern.value])

function makeEmptyEntries(): LineupEntry[] {
  return Array.from({ length: 9 }, (_, i) => ({
    batting_order: i + 1,
    player_id: null,
    position: '',
  }))
}

function loadPatternEntries(key: PatternKey, template: LineupTemplateData | undefined) {
  if (!template) {
    localEntries.value[key] = makeEmptyEntries()
    return
  }
  const entries = [...template.entries].sort((a, b) => a.batting_order - b.batting_order)
  const result: LineupEntry[] = Array.from({ length: 9 }, (_, i) => {
    const existing = entries[i]
    return existing
      ? {
          id: existing.id,
          batting_order: i + 1,
          player_id: existing.player_id,
          position: existing.position,
        }
      : { batting_order: i + 1, player_id: null, position: '' }
  })
  localEntries.value[key] = result
}

function syncLocalFromTemplates() {
  for (const p of patterns) {
    const tmpl = templates.value.find(
      (t) => t.dh_enabled === p.dh_enabled && t.opponent_pitcher_hand === p.opponent_pitcher_hand,
    )
    loadPatternEntries(p.key, tmpl)
  }
}

watch(
  currentTemplate,
  (tmpl) => {
    loadPatternEntries(activePattern.value, tmpl)
  },
  { immediate: false },
)

async function fetchTemplates() {
  try {
    const res = await axios.get<LineupTemplateData[]>(`/teams/${props.teamId}/lineup_templates`)
    templates.value = res.data
    syncLocalFromTemplates()
  } catch (e) {
    console.error('Failed to fetch lineup templates:', e)
  }
}

async function fetchFirstSquad() {
  try {
    const res = await axios.get<{ roster: RosterPlayer[] }>(`/teams/${props.teamId}/roster`)
    firstSquad.value = (res.data.roster || []).filter((p: RosterPlayer) => p.squad === 'first')
  } catch (e) {
    console.error('Failed to fetch roster:', e)
  }
}

function moveUp(idx: number) {
  if (idx === 0) return
  const entries = localEntries.value[activePattern.value]
  const tmp = entries[idx]
  entries[idx] = entries[idx - 1]
  entries[idx - 1] = tmp
  entries.forEach((e, i) => (e.batting_order = i + 1))
}

function moveDown(idx: number) {
  const entries = localEntries.value[activePattern.value]
  if (idx === entries.length - 1) return
  const tmp = entries[idx]
  entries[idx] = entries[idx + 1]
  entries[idx + 1] = tmp
  entries.forEach((e, i) => (e.batting_order = i + 1))
}

async function saveTemplate() {
  saving.value = true
  try {
    const entries_attributes = currentEntries.value
      .filter((e) => e.player_id !== null || e.position !== '')
      .map((e) => ({
        batting_order: e.batting_order,
        player_id: e.player_id,
        position: e.position,
      }))

    const payload = {
      lineup_template: {
        dh_enabled: currentPattern.value.dh_enabled,
        opponent_pitcher_hand: currentPattern.value.opponent_pitcher_hand,
        entries_attributes,
      },
    }

    if (currentTemplateId.value !== null) {
      await axios.put(`/teams/${props.teamId}/lineup_templates/${currentTemplateId.value}`, payload)
    } else {
      await axios.post(`/teams/${props.teamId}/lineup_templates`, payload)
    }

    await fetchTemplates()
    showSnackbar(t('lineupTemplate.saved'), 'success')
  } catch (e) {
    console.error('Failed to save lineup template:', e)
    showSnackbar(t('lineupTemplate.saveError'), 'error')
  } finally {
    saving.value = false
  }
}

function confirmDelete() {
  deleteDialog.value = true
}

async function deleteTemplate() {
  if (currentTemplateId.value === null) return
  deleting.value = true
  try {
    await axios.delete(`/teams/${props.teamId}/lineup_templates/${currentTemplateId.value}`)
    await fetchTemplates()
    deleteDialog.value = false
    showSnackbar(t('lineupTemplate.deleted'), 'success')
  } catch (e) {
    console.error('Failed to delete lineup template:', e)
    showSnackbar(t('lineupTemplate.deleteError'), 'error')
  } finally {
    deleting.value = false
  }
}

function showSnackbar(message: string, color: string) {
  snackbar.value = { show: true, message, color }
}

onMounted(async () => {
  await Promise.all([fetchTemplates(), fetchFirstSquad()])
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
  padding: 4px 6px;
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
  width: 110px;
}

.player-col {
  min-width: 200px;
}

.action-col {
  width: 36px;
}

.pos-select,
.player-autocomplete {
  font-size: 0.875rem;
}
</style>
