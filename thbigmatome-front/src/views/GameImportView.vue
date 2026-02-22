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

    <!-- Step 1: 入力フォーム -->
    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title>Step 1: ログ入力・メタデータ設定</v-card-title>
          <v-card-text>
            <v-row>
              <v-col cols="12">
                <v-textarea
                  v-model="logText"
                  label="IRCログ"
                  placeholder="IRCログをここに貼り付け..."
                  :rows="15"
                  variant="outlined"
                ></v-textarea>
              </v-col>
              <v-col cols="12" md="3">
                <v-select
                  v-model="formData.competition_id"
                  :items="competitions"
                  :item-title="(item: Competition) => `${item.name} (${item.year}年)`"
                  item-value="id"
                  label="大会"
                  density="compact"
                  variant="outlined"
                ></v-select>
              </v-col>
              <v-col cols="12" md="3">
                <v-select
                  v-model="formData.home_team_id"
                  :items="teams"
                  item-title="name"
                  item-value="id"
                  label="ホームチーム"
                  density="compact"
                  variant="outlined"
                ></v-select>
              </v-col>
              <v-col cols="12" md="3">
                <v-select
                  v-model="formData.visitor_team_id"
                  :items="teams"
                  item-title="name"
                  item-value="id"
                  label="ビジターチーム"
                  density="compact"
                  variant="outlined"
                ></v-select>
              </v-col>
              <v-col cols="12" md="3">
                <v-text-field
                  v-model="formData.real_date"
                  label="試合日"
                  type="date"
                  density="compact"
                  variant="outlined"
                ></v-text-field>
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12">
                <v-btn color="primary" :loading="loading" @click="parseLog">解析する</v-btn>
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Step 2: プレビュー -->
    <v-expand-transition>
      <v-row v-if="parsedResult">
        <v-col cols="12">
          <v-card class="mt-4">
            <v-card-title>Step 2: 解析結果プレビュー</v-card-title>
            <v-card-text>
              <p class="mb-3">
                打席数: {{ parsedResult.at_bat_count }}件、イニング数:
                {{ parsedResult.parsed_at_bats.innings }}回
              </p>
              <v-data-table
                :headers="previewHeaders"
                :items="previewItems"
                density="compact"
                class="elevation-1 mb-4"
              ></v-data-table>
              <v-row>
                <v-col>
                  <v-btn color="success" :loading="loading" class="mr-2" @click="confirmGame">
                    確定してDB保存
                  </v-btn>
                  <v-btn variant="outlined" @click="resetPreview">やり直し</v-btn>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </v-expand-transition>
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
}

interface AtBat {
  inning: number
  top_bottom: string
  order: number
  batter: string
  pitcher: string
  result_code: string
}

interface ParsedAtBats {
  at_bats: AtBat[]
  innings: number
}

interface ParseResponse {
  game: { id: number; status: string }
  parsed_at_bats: ParsedAtBats
  at_bat_count: number
}

const { showSnackbar } = useSnackbar()

const competitions = ref<Competition[]>([])
const teams = ref<Team[]>([])

onMounted(async () => {
  try {
    const [compRes, teamRes] = await Promise.all([
      axios.get<Competition[]>('/competitions'),
      axios.get<Team[]>('/teams'),
    ])
    competitions.value = compRes.data
    teams.value = teamRes.data
  } catch (error) {
    errorMessage.value = 'データの取得に失敗しました'
    console.error('Failed to load master data:', error)
  }
})

const logText = ref('')
const formData = ref({
  competition_id: null as number | null,
  home_team_id: null as number | null,
  visitor_team_id: null as number | null,
  real_date: '',
  stadium_id: null as number | null,
})
const loading = ref(false)
const errorMessage = ref('')
const successMessage = ref('')
const parsedResult = ref<ParseResponse | null>(null)

const previewHeaders = [
  { title: '回', key: 'inning', width: '60px' },
  { title: '表裏', key: 'top_bottom', width: '80px' },
  { title: '順', key: 'order', width: '60px' },
  { title: '打者', key: 'batter' },
  { title: '投手', key: 'pitcher' },
  { title: '結果コード', key: 'result_code' },
]

const previewItems = computed(() => {
  if (!parsedResult.value) return []
  return parsedResult.value.parsed_at_bats.at_bats.slice(0, 10)
})

async function parseLog() {
  errorMessage.value = ''
  successMessage.value = ''
  loading.value = true
  try {
    const response = await axios.post<ParseResponse>('/games/import_log', {
      log: logText.value,
      ...formData.value,
    })
    parsedResult.value = response.data
  } catch (error) {
    errorMessage.value = 'ログの解析に失敗しました'
    showSnackbar('ログの解析に失敗しました', 'error')
    console.error('Error parsing log:', error)
  } finally {
    loading.value = false
  }
}

async function confirmGame() {
  if (!parsedResult.value) return
  errorMessage.value = ''
  loading.value = true
  try {
    await axios.post(`/games/${parsedResult.value.game.id}/confirm`)
    successMessage.value = `取り込み完了！試合ID: ${parsedResult.value.game.id}`
    showSnackbar(`取り込み完了！試合ID: ${parsedResult.value.game.id}`, 'success')
    parsedResult.value = null
    logText.value = ''
  } catch (error) {
    errorMessage.value = '確定処理に失敗しました'
    showSnackbar('確定処理に失敗しました', 'error')
    console.error('Error confirming game:', error)
  } finally {
    loading.value = false
  }
}

function resetPreview() {
  parsedResult.value = null
  errorMessage.value = ''
}
</script>
