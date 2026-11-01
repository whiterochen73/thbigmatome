<template>
  <PageLayout>
    <AsyncState
      framed
      skeleton="article"
      :loading="loading"
      :error="fetchFailed"
      :error-message="errorMessage"
      :empty="!lineup"
      empty-icon="mdi-clipboard-list-outline"
      empty-message="オーダーが見つかりません"
      @retry="fetchLineup(route.params.id)"
    >
      <template v-if="lineup">
        <!-- スタメン（打順グリッド） -->
        <v-card>
          <v-card-title>スタメン</v-card-title>
          <v-card-text>
            <v-table density="compact">
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
                    <PlayerNameLink :player-id="entry.player_id" :player-name="entry.player_name" />
                    <v-chip
                      v-if="entry.is_dh_pitcher"
                      size="x-small"
                      color="tag-pitcher"
                      variant="flat"
                      class="ml-1"
                      >P/DH</v-chip
                    >
                  </td>
                  <td>{{ entry.position }}</td>
                </tr>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>

        <!-- ベンチ -->
        <v-card>
          <v-card-title>ベンチ</v-card-title>
          <v-card-text>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>選手名</th>
                  <th>守備位置</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in bench" :key="entry.id">
                  <td>
                    <PlayerNameLink :player-id="entry.player_id" :player-name="entry.player_name" />
                    <span v-if="entry.is_reliever" class="text-caption on-surface-variant"
                      >（中継）</span
                    >
                  </td>
                  <td>{{ entry.position }}</td>
                </tr>
                <tr v-if="bench.length === 0">
                  <td colspan="2" class="text-center on-surface-variant">なし</td>
                </tr>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>

        <!-- オフ（ベンチ外） -->
        <v-card>
          <v-card-title>オフ（ベンチ外）</v-card-title>
          <v-card-text>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>選手名</th>
                  <th>守備位置</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in off" :key="entry.id">
                  <td>
                    <PlayerNameLink :player-id="entry.player_id" :player-name="entry.player_name" />
                  </td>
                  <td>{{ entry.position }}</td>
                </tr>
                <tr v-if="off.length === 0">
                  <td colspan="2" class="text-center on-surface-variant">なし</td>
                </tr>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>

        <!-- 指定選手 -->
        <v-card>
          <v-card-title>指定選手</v-card-title>
          <v-card-text>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>選手名</th>
                  <th>守備位置</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in designated" :key="entry.id">
                  <td>
                    <PlayerNameLink :player-id="entry.player_id" :player-name="entry.player_name" />
                    <span class="text-caption on-surface-variant">（指定）</span>
                  </td>
                  <td>{{ entry.position }}</td>
                </tr>
                <tr v-if="designated.length === 0">
                  <td colspan="2" class="text-center on-surface-variant">なし</td>
                </tr>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>
      </template>
    </AsyncState>
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import { useAppBarTitle } from '@/composables/useAppBarTitle'
import PlayerNameLink from '@/components/shared/PlayerNameLink.vue'

interface LineupEntry {
  id: number
  player_card_id: number
  player_id: number
  player_name: string
  batting_order: number | null
  position: string
  role: 'starter' | 'bench' | 'off' | 'designated_player'
  is_dh_pitcher: boolean
  is_reliever: boolean
}

interface LineupData {
  lineup: LineupEntry[]
}

const route = useRoute()

const lineup = ref<LineupData | null>(null)
const loading = ref(true)
const fetchFailed = ref(false)
const errorMessage = 'オーダーデータの取得に失敗しました'

// ヘッダーバー: タイトル=オーダー確認、サブタイトル=試合 #ID、戻り先=試合詳細
useAppBarTitle(() => ({
  title: 'オーダー確認',
  subtitle: `試合 #${route.params.id}`,
  back: { to: { name: '試合詳細', params: { id: route.params.id } }, label: '試合詳細' },
}))

const starters = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.lineup
    .filter((e) => e.role === 'starter')
    .sort((a, b) => (a.batting_order ?? 0) - (b.batting_order ?? 0))
})

const bench = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.lineup.filter((e) => e.role === 'bench')
})

const off = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.lineup.filter((e) => e.role === 'off')
})

const designated = computed<LineupEntry[]>(() => {
  if (!lineup.value) return []
  return lineup.value.lineup.filter((e) => e.role === 'designated_player')
})

async function fetchLineup(id: string | string[]) {
  loading.value = true
  fetchFailed.value = false
  try {
    const response = await axios.get<LineupData>(`/games/${id}/lineup`)
    lineup.value = response.data
  } catch (error) {
    fetchFailed.value = true
    console.error('Error fetching lineup:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchLineup(route.params.id)
})
</script>
