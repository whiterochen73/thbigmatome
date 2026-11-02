<template>
  <PageLayout>
    <AsyncState
      framed
      skeleton="article"
      :loading="loading"
      :error="fetchFailed"
      :error-message="errorMessage"
      :empty="!player"
      empty-icon="mdi-account-off-outline"
      empty-message="選手が見つかりません"
      @retry="fetchPlayer"
    >
      <v-card v-if="player" class="detail-card">
        <div class="detail-body">
          <!-- 基本情報セクション -->
          <div class="section-header-row">
            <span class="section-header-title">基本情報</span>
            <v-btn
              size="x-small"
              variant="outlined"
              prepend-icon="mdi-pencil"
              @click="openEditDialog"
              >編集</v-btn
            >
          </div>

          <div class="basic-info-grid mb-4">
            <div class="info-item">
              <div class="info-label">背番号</div>
              <div class="info-val">{{ player.number ?? '—' }}</div>
            </div>
            <div class="info-item">
              <div class="info-label">選手名</div>
              <div class="info-val">{{ player.name }}</div>
            </div>
            <div class="info-item">
              <div class="info-label">略称</div>
              <div class="info-val">{{ player.short_name ?? '—' }}</div>
            </div>
            <div class="info-item">
              <div class="info-label">所属作品</div>
              <div class="info-val">{{ seriesLabel(player.series) }}</div>
            </div>
          </div>

          <!-- 選手カード一覧セクション -->
          <div class="section-header-row mt-2">
            <span class="section-header-title">
              選手カード一覧（{{ player.player_cards?.length ?? 0 }}枚）
            </span>
          </div>

          <!-- コストセクション -->
          <div class="section-header-row mt-2">
            <span class="section-header-title">コスト</span>
          </div>
          <div v-if="player.costs && player.costs.length > 0" class="section-box mb-4">
            <table class="card-table">
              <thead>
                <tr>
                  <th>カードセット</th>
                  <th>通常</th>
                  <th>投手専</th>
                  <th>野手専</th>
                  <th>リリーフ専</th>
                  <th>二刀流</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(c, idx) in player.costs" :key="idx">
                  <td>{{ c.cost_name }}</td>
                  <td>{{ c.normal_cost ?? '—' }}</td>
                  <td>{{ c.pitcher_only_cost ?? '—' }}</td>
                  <td>{{ c.fielder_only_cost ?? '—' }}</td>
                  <td>{{ c.relief_only_cost ?? '—' }}</td>
                  <td>{{ c.two_way_cost ?? '—' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="on-surface-variant text-caption pa-2 mb-4">コストなし</div>

          <div v-if="player.player_cards && player.player_cards.length > 0" class="section-box">
            <table class="card-table">
              <thead>
                <tr>
                  <th>カードセット</th>
                  <th>タイプ</th>
                  <th>投打</th>
                  <th>走力</th>
                  <th>バント</th>
                  <th>怪我</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="pc in player.player_cards"
                  :key="pc.id"
                  class="card-row"
                  @click="router.push(`/player-cards/${pc.id}`)"
                >
                  <td>{{ pc.card_set?.name ?? '—' }}</td>
                  <td>
                    <span class="type-chip" :class="pc.card_type">
                      {{ pc.card_type === 'pitcher' ? '投手' : '野手' }}
                    </span>
                  </td>
                  <td>{{ handednessToJa(pc.handedness) }}</td>
                  <td>{{ pc.speed ?? '—' }}</td>
                  <td>{{ pc.bunt ?? '—' }}</td>
                  <td>{{ pc.injury_rate ?? '—' }}</td>
                  <td>
                    <router-link :to="`/player-cards/${pc.id}`" class="detail-link"
                      >詳細</router-link
                    >
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="on-surface-variant text-caption pa-2">選手カードなし</div>
        </div>
        <!-- /detail-body -->
      </v-card>
    </AsyncState>

    <!-- 編集ダイアログ -->
    <PlayerDialog v-model="editDialog" :item="player" @save="onSave" />
  </PageLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import PlayerDialog from '@/components/players/PlayerDialog.vue'
import AsyncState from '@/components/shared/AsyncState.vue'
import PageLayout from '@/components/shared/PageLayout.vue'
import { useAppBarTitle } from '@/composables/useAppBarTitle'
import type { PlayerDetail } from '@/types/playerDetail'

const SERIES_LABEL_MAP: Record<string, string> = {
  touhou: '東方Project',
  hachinai: 'ハチナイ',
  tamayomi: '球詠',
  original: 'オリジナル',
}

function seriesLabel(series: string | null | undefined): string {
  if (!series) return '—'
  return SERIES_LABEL_MAP[series] ?? series
}

const HANDEDNESS_MAP: Record<string, string> = {
  right_throw: '右投',
  left_throw: '左投',
  right_bat: '右打',
  left_bat: '左打',
  switch_bat: '両打',
}

function handednessToJa(val: string | null | undefined): string {
  if (!val) return '—'
  return val
    .split('/')
    .map((part) => HANDEDNESS_MAP[part] ?? part)
    .join('/')
}

const route = useRoute()
const router = useRouter()
const player = ref<PlayerDetail | null>(null)
const loading = ref(true)
const fetchFailed = ref(false)
const errorMessage = '選手情報の取得に失敗しました'
const editDialog = ref(false)

// ヘッダーバー: タイトル=選手名、サブタイトル=背番号、戻り先=選手一覧（取得前・失敗時も戻れるよう常に宣言する）
useAppBarTitle(() => ({
  title: player.value?.name ?? '選手詳細',
  subtitle: player.value?.number ? `#${player.value.number}` : null,
  back: { to: '/players', label: '選手一覧' },
}))

onMounted(() => {
  fetchPlayer()
})

async function fetchPlayer() {
  loading.value = true
  fetchFailed.value = false
  try {
    const id = route.params.id
    const response = await axios.get<PlayerDetail>(`/players/${id}`)
    player.value = response.data
  } catch {
    fetchFailed.value = true
  } finally {
    loading.value = false
  }
}

function openEditDialog() {
  editDialog.value = true
}

function onSave() {
  fetchPlayer()
}
</script>

<style scoped>
/* ── デタイルボディ ── */
.detail-body {
  padding: 10px 14px;
}

/* ── セクションヘッダー行 ── */
.section-header-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.section-header-title {
  font-size: 0.85em;
  font-weight: bold;
  color: rgb(var(--v-theme-on-surface-variant));
  background: rgb(var(--v-theme-surface-variant));
  padding: 3px 10px;
  border-radius: 3px;
}

/* ── 基本情報グリッド ── */
.basic-info-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 4px 10px;
}

.info-item {
}

.info-label {
  font-size: 0.68em;
  color: rgb(var(--v-theme-on-surface-variant));
  line-height: 1.2;
}

.info-val {
  font-size: 0.9em;
  font-weight: bold;
  color: rgb(var(--v-theme-on-surface));
}

/* ── カードテーブル ── */
.section-box {
  border: 1px solid rgb(var(--v-theme-border-strong));
  border-radius: 4px;
  overflow: hidden;
}

.card-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.82em;
}

.card-table th {
  padding: 4px 8px;
  text-align: left;
  color: rgb(var(--v-theme-on-surface-variant));
  font-size: 0.8em;
  font-weight: normal;
  background: rgb(var(--v-theme-surface-variant));
  border-bottom: 1px solid rgb(var(--v-theme-border-strong));
  white-space: nowrap;
}

.card-table td {
  padding: 5px 8px;
  border-bottom: 1px solid rgb(var(--v-theme-border-strong));
}

.card-table tr:last-child td {
  border-bottom: none;
}

.card-row {
  cursor: pointer;
}

.card-row:hover td {
  background: rgb(var(--v-theme-surface-variant));
}

/* ── タイプチップ ── */
.type-chip {
  padding: 1px 7px;
  border-radius: 8px;
  font-size: 0.75em;
  font-weight: bold;
  display: inline-block;
}

.type-chip.pitcher {
  background: rgb(var(--v-theme-tag-pitcher));
  color: rgb(var(--v-theme-on-tag-pitcher));
  border: 1px solid rgb(var(--v-theme-border-strong));
}

.type-chip.batter {
  background: rgb(var(--v-theme-tag-fielder));
  color: rgb(var(--v-theme-on-tag-fielder));
  border: 1px solid rgb(var(--v-theme-border-strong));
}

/* ── 詳細リンク ── */
.detail-link {
  color: rgb(var(--v-theme-link));
  font-size: 0.78em;
  text-decoration: none;
}

.detail-link:hover {
  text-decoration: underline;
}
</style>
