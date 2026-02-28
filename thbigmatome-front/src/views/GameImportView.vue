<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <h1 class="text-h4">IRCログ取り込み</h1>
      </v-col>
    </v-row>

    <v-progress-linear
      v-if="loading"
      indeterminate
      color="primary"
      class="mb-3"
    ></v-progress-linear>

    <v-row>
      <v-col cols="12">
        <v-alert
          v-if="successMessage"
          type="success"
          variant="tonal"
          class="mb-3"
          closable
          @click:close="successMessage = ''"
        >
          {{ successMessage }}
        </v-alert>
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
      </v-col>
    </v-row>

    <!-- ステップ表示 -->
    <v-row class="mb-2">
      <v-col cols="12">
        <div class="d-flex align-center ga-2 text-body-2 text-medium-emphasis">
          <v-chip :color="currentStep === 1 ? 'primary' : 'default'" size="small">Step 1</v-chip>
          <span>ログ入力</span>
          <v-icon size="small">mdi-chevron-right</v-icon>
          <v-chip :color="currentStep === 2 ? 'primary' : 'default'" size="small">Step 2</v-chip>
          <span>メタデータ確認</span>
          <v-icon size="small">mdi-chevron-right</v-icon>
          <v-chip :color="currentStep === 3 ? 'primary' : 'default'" size="small">Step 3</v-chip>
          <span>プレビュー・確定</span>
        </div>
      </v-col>
    </v-row>

    <!-- Step 1: ログ貼り付けのみ -->
    <v-row v-if="currentStep === 1">
      <v-col cols="12">
        <v-card>
          <v-card-title>Step 1: ログ入力</v-card-title>
          <v-card-text>
            <v-textarea
              v-model="logText"
              label="IRCログ"
              placeholder="IRCログをここに貼り付け..."
              :rows="15"
              variant="outlined"
            ></v-textarea>
            <v-row class="mt-2">
              <v-col>
                <v-btn color="primary" :loading="loading" @click="analyzeLog">解析する</v-btn>
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Step 2: 自動検出情報の確認・補正 + DB紐付け -->
    <v-row v-if="currentStep === 2">
      <v-col cols="12">
        <v-card>
          <v-card-title>Step 2: 自動検出情報の確認・補正</v-card-title>
          <v-card-text>
            <p class="text-body-2 text-medium-emphasis mb-4">
              IRCログから自動検出された情報です。誤検出や検出漏れは手動で修正してください。
            </p>

            <v-row>
              <v-col cols="12">
                <div class="text-subtitle-2 mb-2">■ 自動検出情報（編集可能）</div>
              </v-col>

              <v-col cols="12" md="4">
                <v-text-field
                  v-model="pregameForm.venue"
                  label="球場名"
                  density="compact"
                  variant="outlined"
                  :placeholder="pregameForm.venue ? '' : '未検出'"
                ></v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model="pregameForm.home_team"
                  label="ホームチーム名（検出）"
                  density="compact"
                  variant="outlined"
                  :placeholder="pregameForm.home_team ? '' : '未検出'"
                ></v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model="pregameForm.visitor_team"
                  label="ビジターチーム名（検出）"
                  density="compact"
                  variant="outlined"
                  :placeholder="pregameForm.visitor_team ? '' : '未検出'"
                ></v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model="pregameForm.home_starter"
                  label="ホーム先発投手（検出）"
                  density="compact"
                  variant="outlined"
                  :placeholder="pregameForm.home_starter ? '' : '未検出'"
                ></v-text-field>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model="pregameForm.visitor_starter"
                  label="ビジター先発投手（検出）"
                  density="compact"
                  variant="outlined"
                  :placeholder="pregameForm.visitor_starter ? '' : '未検出'"
                ></v-text-field>
              </v-col>
            </v-row>

            <v-divider class="my-4"></v-divider>

            <v-row>
              <v-col cols="12">
                <div class="text-subtitle-2 mb-2">■ DB紐付け（必須）</div>
              </v-col>

              <v-col cols="12" md="4">
                <v-select
                  v-model="formData.competition_id"
                  :items="competitions"
                  :item-title="(item: Competition) => `${item.name} (${item.year}年)`"
                  item-value="id"
                  label="大会"
                  density="compact"
                  variant="outlined"
                  @update:model-value="onCompetitionChange"
                ></v-select>
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  v-model="formData.home_team_id"
                  :items="allTeams"
                  item-title="name"
                  item-value="id"
                  label="ホームチーム（DB）"
                  density="compact"
                  variant="outlined"
                ></v-select>
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  v-model="formData.visitor_team_id"
                  :items="allTeams"
                  item-title="name"
                  item-value="id"
                  label="ビジターチーム（DB）"
                  density="compact"
                  variant="outlined"
                ></v-select>
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model="formData.real_date"
                  label="試合日"
                  type="date"
                  density="compact"
                  variant="outlined"
                ></v-text-field>
              </v-col>
            </v-row>

            <v-row class="mt-2">
              <v-col>
                <v-btn variant="outlined" class="mr-2" @click="backToStep1">戻る</v-btn>
                <v-btn color="primary" :loading="loading" :disabled="!canImport" @click="importLog">
                  インポート
                </v-btn>
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Step 3: プレビュー・確定 -->
    <v-row v-if="currentStep === 3">
      <v-col cols="12">
        <v-card>
          <v-card-title>Step 3: 解析結果プレビュー</v-card-title>
          <v-card-text>
            <p class="mb-3">
              打席数: {{ importResult?.at_bat_count }}件、イニング数:
              {{ importResult?.parsed_at_bats.innings }}回
            </p>
            <v-data-table
              :headers="previewHeaders"
              :items="previewItems"
              :items-per-page="-1"
              density="compact"
              class="elevation-1 mb-4"
            ></v-data-table>
            <v-row>
              <v-col>
                <v-btn color="success" :loading="loading" class="mr-2" @click="confirmGame">
                  確定してDB保存
                </v-btn>
                <v-btn variant="outlined" @click="resetAll">やり直し</v-btn>
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import { useSnackbar } from '@/composables/useSnackbar'

interface Competition {
  id: number
  name: string
  year: number
  competition_type: string
  entry_count: number
}

interface Team {
  id: number
  name: string
  short_name: string
  user_id: number | null
  is_active: boolean
}

interface AtBatEvent {
  type: string
  speaker: string
  text: string
}

interface AtBat {
  inning: number
  top_bottom: string
  order: number
  batter: string
  pitcher: string
  result_code: string
  runners_before: number[]
  outs_after: number | null
  runners_after: number[]
  score: number | null
  events: AtBatEvent[]
}

interface ParsedAtBats {
  at_bats: AtBat[]
  innings: number
}

interface PregameInfo {
  venue: string | null
  home_team: string | null
  visitor_team: string | null
  home_starter: string | null
  visitor_starter: string | null
  rain_canceled: boolean
  home_lineup: unknown[]
  visitor_lineup: unknown[]
  home_bench: string[]
  visitor_bench: string[]
  injury_check_result: unknown | null
}

interface ParseResponse {
  pregame_info: PregameInfo
  parsed_at_bats: ParsedAtBats
  at_bat_count: number
}

interface ImportResponse {
  game: { id: number; status: string }
  parsed_at_bats: ParsedAtBats
  at_bat_count: number
  imported_count: number
}

const { showSnackbar } = useSnackbar()

const currentStep = ref<1 | 2 | 3>(1)
const logText = ref('')
const loading = ref(false)
const errorMessage = ref('')
const successMessage = ref('')

const competitions = ref<Competition[]>([])
const allTeams = ref<Team[]>([])

const pregameForm = ref<{
  venue: string
  home_team: string
  visitor_team: string
  home_starter: string
  visitor_starter: string
}>({
  venue: '',
  home_team: '',
  visitor_team: '',
  home_starter: '',
  visitor_starter: '',
})

const formData = ref({
  competition_id: null as number | null,
  home_team_id: null as number | null,
  visitor_team_id: null as number | null,
  real_date: '',
  stadium_id: null as number | null,
})

const importResult = ref<ImportResponse | null>(null)

const canImport = computed(
  () =>
    formData.value.competition_id !== null &&
    formData.value.home_team_id !== null &&
    formData.value.visitor_team_id !== null,
)

onMounted(async () => {
  try {
    const compRes = await axios.get<Competition[]>('/competitions')
    competitions.value = compRes.data
    const pennant = competitions.value.find((c) => c.competition_type === 'league_pennant')
    if (pennant) {
      formData.value.competition_id = pennant.id
      await fetchTeams(pennant.id)
    } else if (competitions.value.length > 0) {
      formData.value.competition_id = competitions.value[0].id
      await fetchTeams(competitions.value[0].id)
    }
  } catch {
    errorMessage.value = 'データの取得に失敗しました'
  }
})

async function fetchTeams(competitionId: number) {
  try {
    const res = await axios.get<Team[]>(`/competitions/${competitionId}/teams`)
    allTeams.value = res.data
  } catch {
    errorMessage.value = 'チームの取得に失敗しました'
  }
}

async function onCompetitionChange(newId: number | null) {
  if (newId) await fetchTeams(newId)
}

async function analyzeLog() {
  errorMessage.value = ''
  if (!logText.value.trim()) {
    errorMessage.value = 'IRCログを入力してください'
    return
  }
  loading.value = true
  try {
    const response = await axios.post<ParseResponse>('/games/parse_log', { log: logText.value })
    const info = response.data.pregame_info
    pregameForm.value = {
      venue: info.venue ?? '',
      home_team: info.home_team ?? '',
      visitor_team: info.visitor_team ?? '',
      home_starter: info.home_starter ?? '',
      visitor_starter: info.visitor_starter ?? '',
    }
    currentStep.value = 2
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      const data = error.response.data
      errorMessage.value = `解析に失敗しました: ${data.error || 'Unknown error'}`
    } else {
      errorMessage.value = '解析に失敗しました'
    }
    showSnackbar(errorMessage.value, 'error')
  } finally {
    loading.value = false
  }
}

async function importLog() {
  errorMessage.value = ''
  loading.value = true
  try {
    const response = await axios.post<ImportResponse>('/games/import_log', {
      log: logText.value,
      ...formData.value,
    })
    importResult.value = response.data
    currentStep.value = 3
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      const data = error.response.data
      const detail = data.error || (data.errors && data.errors.join(', ')) || 'Unknown error'
      errorMessage.value = `インポートに失敗しました: ${detail}`
    } else {
      errorMessage.value = 'インポートに失敗しました'
    }
    showSnackbar(errorMessage.value, 'error')
  } finally {
    loading.value = false
  }
}

function backToStep1() {
  currentStep.value = 1
  errorMessage.value = ''
}

const BASE_SYMBOLS = ['', '①', '②', '③']

function formatRunners(bases: number[]): string {
  if (bases.length === 0) return '---'
  return bases.map((b) => BASE_SYMBOLS[b] ?? `${b}`).join('')
}

function formatOuts(outs: number | null): string {
  if (outs === null || outs === undefined) return '-'
  return `${outs}`
}

function formatEvents(events: AtBatEvent[]): string {
  if (events.length === 0) return ''
  return events
    .map((e) => {
      if (e.type === 'pinch_hit') return '代打'
      if (e.type === 'pinch_run') return '代走'
      if (e.type === 'pitcher_change') return 'P交代'
      return e.type
    })
    .join(' ')
}

const previewHeaders = [
  { title: '回', key: 'inning', width: '50px' },
  { title: '表裏', key: 'top_bottom', width: '60px' },
  { title: '順', key: 'order', width: '50px' },
  { title: '打者', key: 'batter' },
  { title: '投手', key: 'pitcher' },
  { title: '結果', key: 'result_code', width: '80px' },
  { title: '走者(前→後)', key: 'runners', width: '110px' },
  { title: 'Out', key: 'outs_after', width: '50px' },
  { title: 'イベント', key: 'events_str', width: '80px' },
]

const previewItems = computed(() => {
  if (!importResult.value) return []
  return importResult.value.parsed_at_bats.at_bats.map((ab) => ({
    ...ab,
    runners: `${formatRunners(ab.runners_before)}→${formatRunners(ab.runners_after)}`,
    outs_after: formatOuts(ab.outs_after),
    events_str: formatEvents(ab.events),
  }))
})

async function confirmGame() {
  if (!importResult.value) return
  errorMessage.value = ''
  loading.value = true
  try {
    await axios.post(`/games/${importResult.value.game.id}/confirm`)
    successMessage.value = `取り込み完了！試合ID: ${importResult.value.game.id}`
    showSnackbar(`取り込み完了！試合ID: ${importResult.value.game.id}`, 'success')
    resetAll()
  } catch {
    errorMessage.value = '確定処理に失敗しました'
    showSnackbar('確定処理に失敗しました', 'error')
  } finally {
    loading.value = false
  }
}

function resetAll() {
  currentStep.value = 1
  logText.value = ''
  importResult.value = null
  errorMessage.value = ''
  pregameForm.value = {
    venue: '',
    home_team: '',
    visitor_team: '',
    home_starter: '',
    visitor_starter: '',
  }
  formData.value = {
    competition_id: null,
    home_team_id: null,
    visitor_team_id: null,
    real_date: '',
    stadium_id: null,
  }
}
</script>
