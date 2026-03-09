<template>
  <v-container style="max-width: 1080px">
    <v-progress-linear
      v-if="loading"
      indeterminate
      color="primary"
      class="mb-3"
    ></v-progress-linear>

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

    <!-- 戻るボタン -->
    <button class="detail-back-btn" @click="router.back()">← 一覧に戻る</button>

    <template v-if="player">
      <div class="detail-wrap">
        <!-- ヘッダー (藍色帯) -->
        <div class="detail-card-header">
          <div>
            <div class="detail-player-name">#{{ player.number }} {{ player.name }}</div>
            <div class="detail-player-sub" v-if="player.short_name">
              {{ player.short_name }}
            </div>
          </div>
          <div style="flex: 1"></div>
          <span class="header-badge">選手マスタ</span>
        </div>

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
          </div>

          <!-- 選手カード一覧セクション -->
          <div class="section-header-row mt-2">
            <span class="section-header-title">
              選手カード一覧（{{ player.player_cards?.length ?? 0 }}枚）
            </span>
          </div>

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
                  <td>{{ pc.handedness ?? '—' }}</td>
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
          <div v-else class="text-grey text-caption pa-2">選手カードなし</div>
        </div>
        <!-- /detail-body -->
      </div>
      <!-- /detail-wrap -->
    </template>

    <!-- 編集ダイアログ -->
    <PlayerDialog v-model="editDialog" :item="player" @save="onSave" />
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from '@/plugins/axios'
import PlayerDialog from '@/components/players/PlayerDialog.vue'
import type { PlayerDetail } from '@/types/playerDetail'

const route = useRoute()
const router = useRouter()
const player = ref<PlayerDetail | null>(null)
const loading = ref(false)
const errorMessage = ref('')
const editDialog = ref(false)

onMounted(() => {
  fetchPlayer()
})

async function fetchPlayer() {
  loading.value = true
  errorMessage.value = ''
  try {
    const id = route.params.id
    const response = await axios.get<PlayerDetail>(`/players/${id}`)
    player.value = response.data
  } catch {
    errorMessage.value = '選手情報の取得に失敗しました'
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
/* ── 戻るボタン ── */
.detail-back-btn {
  background: none;
  border: 1px solid #bbb;
  padding: 3px 10px;
  border-radius: 3px;
  cursor: pointer;
  font-size: 0.79em;
  margin-bottom: 8px;
  color: #555;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.detail-back-btn:hover {
  background: #e8e0d4;
  border-color: #999;
}

/* ── 詳細ラッパー ── */
.detail-wrap {
  background: white;
  border: 1px solid #ddd;
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
}

/* ── ヘッダー (藍色帯) ── */
.detail-card-header {
  background: var(--ai);
  color: white;
  padding: 7px 14px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.detail-player-name {
  font-size: 1.05em;
  font-weight: bold;
}

.detail-player-sub {
  font-size: 0.76em;
  opacity: 0.75;
  margin-top: 1px;
}

.header-badge {
  font-size: 0.72em;
  opacity: 0.6;
}

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
  color: #5a3e20;
  background: #ece4d8;
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
  color: #999;
  line-height: 1.2;
}

.info-val {
  font-size: 0.9em;
  font-weight: bold;
  color: #222;
}

/* ── カードテーブル ── */
.section-box {
  border: 1px solid #e0d8cc;
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
  color: #999;
  font-size: 0.8em;
  font-weight: normal;
  background: #ece4d8;
  border-bottom: 1px solid #d4c5a9;
  white-space: nowrap;
}

.card-table td {
  padding: 5px 8px;
  border-bottom: 1px solid #f4f0ea;
}

.card-table tr:last-child td {
  border-bottom: none;
}

.card-row {
  cursor: pointer;
}

.card-row:hover td {
  background: #faf5ec;
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
  background: rgba(219, 234, 254, 0.85);
  color: #1e40af;
  border: 1px solid #93c5fd;
}

.type-chip.batter {
  background: rgba(220, 252, 231, 0.85);
  color: #166534;
  border: 1px solid #6ee7b7;
}

/* ── 詳細リンク ── */
.detail-link {
  color: #5a3e20;
  font-size: 0.78em;
  text-decoration: none;
}

.detail-link:hover {
  text-decoration: underline;
}
</style>
