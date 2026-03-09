<template>
  <div class="card-item-wrapper">
    <v-card class="player-card" @click="emit('click')" :ripple="true" variant="outlined">
      <!-- カード画像 -->
      <div class="card-image-container">
        <div class="no-image">
          <v-icon size="large">mdi-card-account-details</v-icon>
        </div>
      </div>

      <!-- カード情報セクション -->
      <v-card-text class="card-content pa-2">
        <!-- 選手名 -->
        <div class="player-name text-subtitle-2 font-weight-bold mb-1 text-truncate">
          {{ card.player_name }}
        </div>

        <!-- 背番号 & 種別 -->
        <div class="d-flex align-center justify-between mb-1">
          <span class="text-caption">
            <span class="text-grey">#</span>{{ card.player_number }}
          </span>
          <v-chip
            :color="card.card_type === 'pitcher' ? 'blue' : 'green'"
            size="x-small"
            label
            variant="tonal"
          >
            {{ card.card_type === 'pitcher' ? '投手' : '野手' }}
          </v-chip>
        </div>

        <!-- ポジション（野手の場合） -->
        <div v-if="card.defenses && card.defenses.length > 0" class="mb-1">
          <div class="text-caption text-grey">ポジション</div>
          <div class="d-flex flex-wrap gap-1">
            <v-chip
              v-for="(def, idx) in card.defenses"
              :key="idx"
              size="x-small"
              variant="tonal"
              color="primary"
            >
              {{ def.position }}
            </v-chip>
          </div>
        </div>

        <!-- コスト（あればの情報） -->
        <div v-if="card.cost" class="mb-1">
          <div class="text-caption text-grey">コスト</div>
          <div class="text-caption font-weight-bold">{{ card.cost }}</div>
        </div>

        <!-- 走力 -->
        <div class="mb-1">
          <div class="text-caption text-grey">走力</div>
          <div class="text-caption font-weight-bold">{{ card.speed }}</div>
        </div>

        <!-- スタイル/スキル（テキスト省略） -->
        <div v-if="card.unique_traits" class="text-caption text-grey-darken-1 mb-1">
          <span class="text-truncate">{{ card.unique_traits }}</span>
        </div>
      </v-card-text>
    </v-card>
  </div>
</template>

<script setup lang="ts">
import type { PlayerCard } from '@/types/game-record'

interface Props {
  card: PlayerCard
}

defineProps<Props>()
const emit = defineEmits<{
  click: []
}>()
</script>

<style scoped>
.card-item-wrapper {
  cursor: pointer;
  height: 100%;
}

.player-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  transition: all 0.2s ease;
}

.player-card:hover {
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.15);
  transform: translateY(-2px);
}

.card-image-container {
  width: 100%;
  aspect-ratio: 3 / 4;
  overflow: hidden;
  background: #f5f5f5;
  display: flex;
  align-items: center;
  justify-content: center;
}

.card-image {
  width: 100%;
  height: 100%;
}

.no-image {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #ccc;
}

.card-content {
  flex: 1;
  overflow: auto;
}

.player-name {
  color: #1a1a1a;
}

.text-grey {
  color: #777777;
}

.text-grey-darken-1 {
  color: #555555;
}
</style>
