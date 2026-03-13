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
                <v-btn color="accent" variant="flat" :loading="loading" @click="analyzeLog"
                  >解析する</v-btn
                >
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Step 2: メタデータ確認・補正 + DB紐付け -->
    <div v-if="currentStep === 2">
      <!-- 解析サマリー -->
      <v-row class="mb-2">
        <v-col cols="12">
          <v-card variant="outlined" class="parse-summary-card">
            <v-card-text class="d-flex align-center flex-wrap ga-3 py-3">
              <span class="text-body-1 font-weight-medium">
                {{ parsedAtBatCount }}打席 / {{ parsedInnings }}イニング検出
              </span>
              <v-chip v-if="pregameData.rain_canceled" color="warning" size="small" variant="flat">
                雨天中止
              </v-chip>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 試合設定 -->
      <v-row class="mb-2">
        <v-col cols="12">
          <v-card class="game-settings-card">
            <v-card-title class="text-subtitle-1 pb-1">試合設定</v-card-title>
            <v-card-text>
              <v-row dense>
                <v-col cols="12" sm="4">
                  <v-text-field
                    v-model="pregameForm.venue"
                    label="球場名"
                    density="compact"
                    variant="outlined"
                    :placeholder="pregameForm.venue ? '' : '未検出'"
                  ></v-text-field>
                </v-col>
                <v-col cols="6" sm="4">
                  <v-text-field
                    :model-value="pregameData.venue_code_1112 ?? '—'"
                    label="UP表1112"
                    density="compact"
                    variant="outlined"
                    readonly
                  ></v-text-field>
                </v-col>
                <v-col cols="6" sm="4">
                  <v-text-field
                    :model-value="pregameData.venue_code_1314 ?? '—'"
                    label="UP表1314"
                    density="compact"
                    variant="outlined"
                    readonly
                  ></v-text-field>
                </v-col>
                <v-col cols="12" sm="4">
                  <v-switch
                    v-model="pregameForm.dh_enabled"
                    label="DH制"
                    density="compact"
                    color="primary"
                    hide-details
                  ></v-switch>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- ホーム / ビジター 2カラム -->
      <v-row class="mb-2">
        <!-- ホーム -->
        <v-col cols="12" md="6">
          <v-card class="team-card team-card--home">
            <v-card-title class="team-card__header team-card__header--home text-subtitle-1">
              ホーム
            </v-card-title>
            <v-card-text>
              <v-text-field
                v-model="pregameForm.home_team"
                label="チーム名"
                density="compact"
                variant="outlined"
                :placeholder="pregameForm.home_team ? '' : '未検出'"
                class="mb-2"
              ></v-text-field>
              <v-text-field
                v-model="pregameForm.home_starter"
                label="先発投手"
                density="compact"
                variant="outlined"
                :placeholder="pregameForm.home_starter ? '' : '未検出'"
                class="mb-1"
              ></v-text-field>
              <!-- 先発投手詳細（読み取り専用） -->
              <div
                v-if="pregameData.home_starter_info"
                class="starter-info text-body-2 text-medium-emphasis mb-3"
              >
                <span v-if="pregameData.home_starter_info.jersey != null"
                  >#{{ pregameData.home_starter_info.jersey }}</span
                >
                <span v-if="pregameData.home_starter_info.rest_days != null">
                  中{{ pregameData.home_starter_info.rest_days }}日</span
                >
                <span v-if="pregameData.home_starter_info.fatigue != null">
                  疲労{{ pregameData.home_starter_info.fatigue }}</span
                >
                <br v-if="pregameData.home_starter_info.wins != null" />
                <span v-if="pregameData.home_starter_info.wins != null"
                  >{{ pregameData.home_starter_info.wins }}勝{{
                    pregameData.home_starter_info.losses
                  }}敗</span
                >
                <span v-if="pregameData.home_starter_info.era != null">
                  ERA{{ pregameData.home_starter_info.era }}</span
                >
                <span v-if="pregameData.home_starter_info.appearances != null">
                  登板{{ pregameData.home_starter_info.appearances }}</span
                >
              </div>

              <!-- スタメン -->
              <v-expansion-panels
                v-if="pregameData.home_lineup.length > 0"
                variant="accordion"
                class="mb-2"
              >
                <v-expansion-panel>
                  <v-expansion-panel-title class="text-body-2 py-2">
                    スタメン ({{ pregameData.home_lineup.length }}人)
                  </v-expansion-panel-title>
                  <v-expansion-panel-text>
                    <div
                      v-for="p in pregameData.home_lineup"
                      :key="'hl' + p.order"
                      class="lineup-row text-body-2"
                    >
                      <span class="lineup-order">{{ p.order }}</span>
                      <span class="lineup-pos">({{ p.position }})</span>
                      <span>{{ p.name }}</span>
                    </div>
                  </v-expansion-panel-text>
                </v-expansion-panel>
              </v-expansion-panels>

              <!-- ベンチ -->
              <v-expansion-panels v-if="pregameData.home_bench.length > 0" variant="accordion">
                <v-expansion-panel>
                  <v-expansion-panel-title class="text-body-2 py-2">
                    ベンチ (投手{{ homeBenchPitchers }}/野手{{ homeBenchFielders }})
                  </v-expansion-panel-title>
                  <v-expansion-panel-text>
                    <div
                      v-for="(b, i) in pregameData.home_bench"
                      :key="'hb' + i"
                      class="bench-row text-body-2"
                    >
                      <v-chip
                        :color="benchRoleColor(b.role)"
                        size="x-small"
                        variant="flat"
                        class="mr-1"
                        >{{ benchRoleLabel(b.role) }}</v-chip
                      >
                      <span>{{ b.name }}</span>
                    </div>
                  </v-expansion-panel-text>
                </v-expansion-panel>
              </v-expansion-panels>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- ビジター -->
        <v-col cols="12" md="6">
          <v-card class="team-card team-card--visitor">
            <v-card-title class="team-card__header team-card__header--visitor text-subtitle-1">
              ビジター
            </v-card-title>
            <v-card-text>
              <v-text-field
                v-model="pregameForm.visitor_team"
                label="チーム名"
                density="compact"
                variant="outlined"
                :placeholder="pregameForm.visitor_team ? '' : '未検出'"
                class="mb-2"
              ></v-text-field>
              <v-text-field
                v-model="pregameForm.visitor_starter"
                label="先発投手"
                density="compact"
                variant="outlined"
                :placeholder="pregameForm.visitor_starter ? '' : '未検出'"
                class="mb-1"
              ></v-text-field>
              <!-- 先発投手詳細（読み取り専用） -->
              <div
                v-if="pregameData.visitor_starter_info"
                class="starter-info text-body-2 text-medium-emphasis mb-3"
              >
                <span v-if="pregameData.visitor_starter_info.jersey != null"
                  >#{{ pregameData.visitor_starter_info.jersey }}</span
                >
                <span v-if="pregameData.visitor_starter_info.rest_days != null">
                  中{{ pregameData.visitor_starter_info.rest_days }}日</span
                >
                <span v-if="pregameData.visitor_starter_info.fatigue != null">
                  疲労{{ pregameData.visitor_starter_info.fatigue }}</span
                >
                <br v-if="pregameData.visitor_starter_info.wins != null" />
                <span v-if="pregameData.visitor_starter_info.wins != null"
                  >{{ pregameData.visitor_starter_info.wins }}勝{{
                    pregameData.visitor_starter_info.losses
                  }}敗</span
                >
                <span v-if="pregameData.visitor_starter_info.era != null">
                  ERA{{ pregameData.visitor_starter_info.era }}</span
                >
                <span v-if="pregameData.visitor_starter_info.appearances != null">
                  登板{{ pregameData.visitor_starter_info.appearances }}</span
                >
              </div>

              <!-- スタメン -->
              <v-expansion-panels
                v-if="pregameData.visitor_lineup.length > 0"
                variant="accordion"
                class="mb-2"
              >
                <v-expansion-panel>
                  <v-expansion-panel-title class="text-body-2 py-2">
                    スタメン ({{ pregameData.visitor_lineup.length }}人)
                  </v-expansion-panel-title>
                  <v-expansion-panel-text>
                    <div
                      v-for="p in pregameData.visitor_lineup"
                      :key="'vl' + p.order"
                      class="lineup-row text-body-2"
                    >
                      <span class="lineup-order">{{ p.order }}</span>
                      <span class="lineup-pos">({{ p.position }})</span>
                      <span>{{ p.name }}</span>
                    </div>
                  </v-expansion-panel-text>
                </v-expansion-panel>
              </v-expansion-panels>

              <!-- ベンチ -->
              <v-expansion-panels v-if="pregameData.visitor_bench.length > 0" variant="accordion">
                <v-expansion-panel>
                  <v-expansion-panel-title class="text-body-2 py-2">
                    ベンチ (投手{{ visitorBenchPitchers }}/野手{{ visitorBenchFielders }})
                  </v-expansion-panel-title>
                  <v-expansion-panel-text>
                    <div
                      v-for="(b, i) in pregameData.visitor_bench"
                      :key="'vb' + i"
                      class="bench-row text-body-2"
                    >
                      <v-chip
                        :color="benchRoleColor(b.role)"
                        size="x-small"
                        variant="flat"
                        class="mr-1"
                        >{{ benchRoleLabel(b.role) }}</v-chip
                      >
                      <span>{{ b.name }}</span>
                    </div>
                  </v-expansion-panel-text>
                </v-expansion-panel>
              </v-expansion-panels>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 怪我チェック（条件表示） -->
      <v-row v-if="pregameData.injury_check_result?.injured" class="mb-2">
        <v-col cols="12">
          <v-alert type="warning" variant="tonal" density="compact">
            <div class="text-body-2">
              ダイス: {{ pregameData.injury_check_result.roll }} → 負傷者:
              {{ pregameData.injury_check_result.player }}
            </div>
            <div class="text-body-2">
              怪我レベル{{ pregameData.injury_check_result.injury_level ?? '?' }} / 怪我{{
                pregameData.injury_check_result.injury_days ?? '?'
              }}日
              <span v-if="pregameData.injury_check_result.note">
                ({{ pregameData.injury_check_result.note }})</span
              >
            </div>
          </v-alert>
        </v-col>
      </v-row>

      <!-- DB紐付け（必須） -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title class="text-subtitle-1 pb-1">DB紐付け（必須）</v-card-title>
            <v-card-text>
              <v-row dense>
                <v-col cols="12" sm="6" md="3">
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
                <v-col cols="12" sm="6" md="3">
                  <v-text-field
                    v-model="formData.real_date"
                    label="試合日"
                    type="date"
                    density="compact"
                    variant="outlined"
                  ></v-text-field>
                </v-col>
                <v-col cols="12" sm="6" md="3">
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
                <v-col cols="12" sm="6" md="3">
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
              </v-row>
              <v-row class="mt-1">
                <v-col>
                  <v-btn variant="outlined" class="mr-2" @click="backToStep1">戻る</v-btn>
                  <v-btn
                    color="accent"
                    variant="flat"
                    :loading="loading"
                    :disabled="!canImport"
                    @click="importLog"
                  >
                    インポート
                  </v-btn>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </div>

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
import type { PregameInfo, BenchEntry } from '@/types/game-record'

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

interface ParseResponse {
  pregame_info: PregameInfo
  at_bat_count: number
  parsed_at_bats?: { innings?: number }
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
  dh_enabled: boolean
}>({
  venue: '',
  home_team: '',
  visitor_team: '',
  home_starter: '',
  visitor_starter: '',
  dh_enabled: false,
})

const defaultPregameData: PregameInfo = {
  venue: null,
  venue_code_1112: null,
  venue_code_1314: null,
  dh_enabled: null,
  home_team: null,
  visitor_team: null,
  rain_canceled: false,
  home_lineup: [],
  visitor_lineup: [],
  home_bench: [],
  visitor_bench: [],
  home_starter: null,
  visitor_starter: null,
  home_starter_info: null,
  visitor_starter_info: null,
  injury_check_result: null,
}

const pregameData = ref<PregameInfo>({ ...defaultPregameData })
const parsedAtBatCount = ref(0)
const parsedInnings = ref(0)

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

// Bench role helpers
function countBenchByRole(bench: BenchEntry[], role: string): number {
  return bench.filter((b) => b.role === role).length
}
const homeBenchPitchers = computed(() => countBenchByRole(pregameData.value.home_bench, 'pitcher'))
const homeBenchFielders = computed(() => countBenchByRole(pregameData.value.home_bench, 'fielder'))
const visitorBenchPitchers = computed(() =>
  countBenchByRole(pregameData.value.visitor_bench, 'pitcher'),
)
const visitorBenchFielders = computed(() =>
  countBenchByRole(pregameData.value.visitor_bench, 'fielder'),
)

function benchRoleColor(role: string): string {
  if (role === 'pitcher') return 'var(--color-visitor)'
  if (role === 'fielder') return '#2c5f2e'
  return 'grey'
}

function benchRoleLabel(role: string): string {
  if (role === 'pitcher') return '投手'
  if (role === 'fielder') return '野手'
  return '?'
}

// Normalize bench entries: API may return string[] (legacy) or BenchEntry[]
function normalizeBench(bench: unknown): BenchEntry[] {
  if (!Array.isArray(bench)) return []
  return bench.map((b) => {
    if (typeof b === 'string') return { name: b, role: 'unknown' as const }
    return { name: b.name ?? '', role: b.role ?? 'unknown' }
  })
}

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
    // Editable fields
    pregameForm.value = {
      venue: info.venue ?? '',
      home_team: info.home_team ?? '',
      visitor_team: info.visitor_team ?? '',
      home_starter: info.home_starter ?? '',
      visitor_starter: info.visitor_starter ?? '',
      dh_enabled: info.dh_enabled ?? false,
    }
    // Full pregame data (read-only display)
    pregameData.value = {
      ...defaultPregameData,
      ...info,
      home_lineup: Array.isArray(info.home_lineup) ? info.home_lineup : [],
      visitor_lineup: Array.isArray(info.visitor_lineup) ? info.visitor_lineup : [],
      home_bench: normalizeBench(info.home_bench),
      visitor_bench: normalizeBench(info.visitor_bench),
    }
    parsedAtBatCount.value = response.data.at_bat_count ?? 0
    parsedInnings.value = response.data.parsed_at_bats?.innings ?? 0
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
    dh_enabled: false,
  }
  pregameData.value = { ...defaultPregameData }
  parsedAtBatCount.value = 0
  parsedInnings.value = 0
  formData.value = {
    competition_id: null,
    home_team_id: null,
    visitor_team_id: null,
    real_date: '',
    stadium_id: null,
  }
}
</script>

<style scoped>
.parse-summary-card {
  border-left: 4px solid var(--color-visitor);
}

.game-settings-card {
  background: #f8f8f6;
}

.team-card__header {
  color: white;
  padding: 8px 16px;
}

.team-card__header--home {
  background: var(--color-home);
}

.team-card__header--visitor {
  background: var(--color-visitor);
}

.starter-info {
  padding-left: 4px;
  line-height: 1.6;
}

.lineup-row {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 2px 0;
}

.lineup-order {
  min-width: 18px;
  text-align: right;
  font-weight: 500;
}

.lineup-pos {
  min-width: 36px;
  color: rgba(0, 0, 0, 0.6);
}

.bench-row {
  display: flex;
  align-items: center;
  padding: 2px 0;
}
</style>
