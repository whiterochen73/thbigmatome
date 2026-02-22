<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="d-flex align-center">
        <v-btn
          variant="text"
          prepend-icon="mdi-arrow-left"
          :to="{ name: '試合詳細', params: { id: route.params.id } }"
          class="mr-2"
        >
          試合詳細へ戻る
        </v-btn>
        <h1 class="text-h4">オーダー確認</h1>
      </v-col>
    </v-row>

    <v-row v-if="errorMessage">
      <v-col cols="12">
        <v-alert type="error" variant="tonal">{{ errorMessage }}</v-alert>
      </v-col>
    </v-row>

    <v-row v-if="loading">
      <v-col cols="12" class="text-center">
        <v-progress-circular indeterminate color="primary" />
      </v-col>
    </v-row>

    <template v-if="!loading && lineup">
      <!-- スタメン（打順グリッド） -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>スタメン</v-card-title>
            <v-card-text>
              <v-table density="compact" class="elevation-1">
                <thead>
                  <tr>
                    <th>打順</th>
                    <th>選手名</th>
                    <th>守備位置</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="entry in starters" :key="entry.id">
                    <td>{{ entry.batting_order }}</td>
                    <td>
                      {{ entry.player_name }}
                      <v-chip v-if="entry.is_dh_pitcher" size="x-small" color="purple" class="ml-1"
                        >P/DH</v-chip
                      >
                    </td>
                    <td>{{ entry.position }}</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- ベンチ -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>ベンチ</v-card-title>
            <v-card-text>
              <v-table density="compact" class="elevation-1">
                <thead>
                  <tr>
                    <th>選手名</th>
                    <th>守備位置</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="entry in bench" :key="entry.id">
                    <td>
                      {{ entry.player_name }}
                      <span v-if="entry.is_reliever" class="text-caption text-grey">（中継）</span>
                    </td>
                    <td>{{ entry.position }}</td>
                  </tr>
                  <tr v-if="bench.length === 0">
                    <td colspan="2" class="text-center text-grey">なし</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- オフ（ベンチ外） -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>オフ（ベンチ外）</v-card-title>
            <v-card-text>
              <v-table density="compact" class="elevation-1">
                <thead>
                  <tr>
                    <th>選手名</th>
                    <th>守備位置</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="entry in off" :key="entry.id">
                    <td>{{ entry.player_name }}</td>
                    <td>{{ entry.position }}</td>
                  </tr>
                  <tr v-if="off.length === 0">
                    <td colspan="2" class="text-center text-grey">なし</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <!-- 指定選手 -->
      <v-row>
        <v-col cols="12">
          <v-card>
            <v-card-title>指定選手</v-card-title>
            <v-card-text>
              <v-table density="compact" class="elevation-1">
                <thead>
                  <tr>
                    <th>選手名</th>
                    <th>守備位置</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="entry in designated" :key="entry.id">
                    <td>
                      {{ entry.player_name }}
                      <span class="text-caption text-grey">（指定）</span>
                    </td>
                    <td>{{ entry.position }}</td>
                  </tr>
                  <tr v-if="designated.length === 0">
                    <td colspan="2" class="text-center text-grey">なし</td>
                  </tr>
                </tbody>
              </v-table>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'

interface LineupEntry {
  id: number
  game_id: number
  player_id: number
  player_name: string
  batting_order: number | null
  position: string
  role: 'starter' | 'bench' | 'off' | 'designated_player'
  is_dh_pitcher: boolean
  is_reliever: boolean
}

interface LineupData {
  entries: LineupEntry[]
}

const route = useRoute()

const lineup = ref<LineupData | null>(null)
const loading = ref(false)
const errorMessage = ref('')

const starters = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.entries
    .filter((e) => e.role === 'starter')
    .sort((a, b) => (a.batting_order ?? 0) - (b.batting_order ?? 0))
})

const bench = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.entries.filter((e) => e.role === 'bench')
})

const off = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.entries.filter((e) => e.role === 'off')
})

const designated = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.entries.filter((e) => e.role === 'designated_player')
})

async function fetchLineup(id: string | string[]) {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await axios.get<LineupData>(`/games/${id}/lineup`)
    lineup.value = response.data
  } catch (error) {
    errorMessage.value = 'オーダーデータの取得に失敗しました'
    console.error('Error fetching lineup:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchLineup(route.params.id)
})
</script>
