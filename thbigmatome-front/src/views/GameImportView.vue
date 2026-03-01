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

    <!-- Step 3: フォールバック（game_record_id なし時のみ表示） -->
    <v-row v-if="currentStep === 3">
      <v-col cols="12">
        <v-card>
          <v-card-title>Step 3: インポート完了</v-card-title>
          <v-card-text>
            <p class="mb-2">インポートが完了しました。</p>
            <p class="mb-3 text-body-2">
              試合ID: {{ importResult?.game.id }}、打席数: {{ importResult?.at_bat_count }}件
            </p>
            <v-row class="mt-2">
              <v-col>
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
import { useRouter } from 'vue-router'
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
  at_bat_count: number
  raw_at_bats: object
}

interface ImportResponse {
  game: { id: number; status: string }
  at_bat_count: number
  imported_count: number
  game_record_id?: number
}

const router = useRouter()
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
const rawAtBats = ref<object | null>(null)

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
    rawAtBats.value = response.data.raw_at_bats ?? null
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
      ...(rawAtBats.value ? { raw_at_bats: JSON.stringify(rawAtBats.value) } : {}),
    })
    importResult.value = response.data
    if (response.data.game_record_id) {
      router.push(`/game-records/${response.data.game_record_id}`)
    } else {
      currentStep.value = 3
    }
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

function resetAll() {
  currentStep.value = 1
  logText.value = ''
  importResult.value = null
  rawAtBats.value = null
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
