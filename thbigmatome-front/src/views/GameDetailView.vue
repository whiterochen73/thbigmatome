<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="d-flex align-center">
        <v-btn variant="text" prepend-icon="mdi-arrow-left" @click="router.back()" class="mr-2">
          戻る
        </v-btn>
        <h1 class="text-h4">試合詳細</h1>
      </v-col>
    </v-row>

    <v-row v-if="errorMessage">
      <v-col cols="12">
        <v-alert type="error" variant="tonal">{{ errorMessage }}</v-alert>
      </v-col>
    </v-row>

    <template v-if="game">
      <!-- アクションボタン -->
      <v-row class="mb-2">
        <v-col cols="12" class="d-flex gap-2">
          <v-btn
            :to="{ name: 'GameLineup', params: { id: game.id } }"
            color="primary"
            variant="tonal"
          >
            オーダー確認
          </v-btn>
        </v-col>
      </v-row>

      <!-- 試合基本情報 -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>試合情報</v-card-title>
            <v-card-text>
              <v-row>
                <v-col cols="12" sm="6" md="3">
                  <div class="text-caption text-grey">日付</div>
                  <div>{{ game.real_date }}</div>
                </v-col>
                <v-col cols="12" sm="6" md="3">
                  <div class="text-caption text-grey">大会ID</div>
                  <div>{{ game.competition_id }}</div>
                </v-col>
                <v-col cols="12" sm="6" md="3">
                  <div class="text-caption text-grey">ホームチームID</div>
                  <div>{{ game.home_team_id }}</div>
                </v-col>
                <v-col cols="12" sm="6" md="3">
                  <div class="text-caption text-grey">ビジターチームID</div>
                  <div>{{ game.visitor_team_id }}</div>
                </v-col>
                <v-col cols="12" sm="6" md="3">
                  <div class="text-caption text-grey">ステータス</div>
                  <v-chip :color="game.status === 'confirmed' ? 'success' : 'warning'" size="small">
                    {{ game.status === 'confirmed' ? '確定' : '下書き' }}
                  </v-chip>
                </v-col>
                <v-col cols="12" sm="6" md="3">
                  <div class="text-caption text-grey">出典</div>
                  <div>{{ game.source }}</div>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- イニングスコアボード -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>スコアボード</v-card-title>
            <v-card-text>
              <v-table density="compact" class="elevation-1">
                <thead>
                  <tr>
                    <th>チーム</th>
                    <th v-for="inning in innings" :key="inning" class="text-center">
                      {{ inning }}
                    </th>
                    <th class="text-center font-weight-bold">計</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="font-weight-medium">ビジター ({{ game.visitor_team_id }})</td>
                    <td v-for="inning in innings" :key="inning" class="text-center">
                      {{ scoreBoard.visitor[inning] ?? 0 }}
                    </td>
                    <td class="text-center font-weight-bold">{{ visitorTotal }}</td>
                  </tr>
                  <tr>
                    <td class="font-weight-medium">ホーム ({{ game.home_team_id }})</td>
                    <td v-for="inning in innings" :key="inning" class="text-center">
                      {{ scoreBoard.home[inning] ?? 0 }}
                    </td>
                    <td class="text-center font-weight-bold">{{ homeTotal }}</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 打席一覧 -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>打席一覧</v-card-title>
            <v-card-text>
              <v-data-table
                :headers="atBatHeaders"
                :items="game.at_bats"
                density="compact"
                class="elevation-1"
              >
                <template v-slot:[`item.half`]="{ item }">
                  {{ item.half === 'top' ? '表' : '裏' }}
                </template>
                <template v-slot:[`item.rolls`]="{ item }">
                  {{ item.rolls.join(', ') }}
                </template>
                <template v-slot:[`item.scored`]="{ item }">
                  {{ item.scored ? '○' : '' }}
                </template>
              </v-data-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <v-row v-if="loading">
      <v-col cols="12" class="text-center">
        <v-progress-circular indeterminate color="primary" />
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'

interface AtBat {
  id: number
  game_id: number
  inning: number
  half: 'top' | 'bottom'
  seq: number
  batter_id: number
  pitcher_id: number
  result_code: string
  play_type: string
  rolls: number[]
  rbi: number
  runners: unknown[]
  runners_after: unknown[]
  outs_after: number
  scored: boolean
}

interface Game {
  id: number
  competition_id: number
  home_team_id: number
  visitor_team_id: number
  real_date: string
  status: 'draft' | 'confirmed'
  source: string
  at_bats: AtBat[]
}

const route = useRoute()
const router = useRouter()

const game = ref<Game | null>(null)
const loading = ref(false)
const errorMessage = ref('')

const atBatHeaders = [
  { title: '回', key: 'inning', width: '60px' },
  { title: '表裏', key: 'half', width: '70px' },
  { title: '順', key: 'seq', width: '60px' },
  { title: '打者ID', key: 'batter_id', width: '90px' },
  { title: '投手ID', key: 'pitcher_id', width: '90px' },
  { title: '結果コード', key: 'result_code', width: '110px' },
  { title: '打席種別', key: 'play_type', width: '110px' },
  { title: 'ダイス', key: 'rolls' },
  { title: 'RBI', key: 'rbi', width: '70px' },
  { title: '得点', key: 'scored', width: '70px' },
]

// イニング一覧（at_batsから動的に生成）
const innings = computed<number[]>(() => {
  if (!game.value) return []
  const set = new Set(game.value.at_bats.map((ab) => ab.inning))
  return Array.from(set).sort((a, b) => a - b)
})

// スコアボード: { visitor: { inning: rbi }, home: { inning: rbi } }
const scoreBoard = computed(() => {
  const visitor: Record<number, number> = {}
  const home: Record<number, number> = {}
  if (!game.value) return { visitor, home }

  for (const ab of game.value.at_bats) {
    if (ab.half === 'top') {
      // 表 = ビジター攻撃
      visitor[ab.inning] = (visitor[ab.inning] ?? 0) + ab.rbi
    } else {
      // 裏 = ホーム攻撃
      home[ab.inning] = (home[ab.inning] ?? 0) + ab.rbi
    }
  }
  return { visitor, home }
})

const visitorTotal = computed(() =>
  Object.values(scoreBoard.value.visitor).reduce((sum, v) => sum + v, 0),
)
const homeTotal = computed(() =>
  Object.values(scoreBoard.value.home).reduce((sum, v) => sum + v, 0),
)

async function fetchGame(id: string | string[]) {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await axios.get<Game>(`/games/${id}`)
    game.value = response.data
  } catch (error) {
    errorMessage.value = '試合データの取得に失敗しました'
    console.error('Error fetching game:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchGame(route.params.id)
})
</script>
