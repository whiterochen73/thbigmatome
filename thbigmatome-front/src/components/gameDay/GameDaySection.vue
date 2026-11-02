<template>
  <v-card
    class="game-day-section"
    :class="{ 'game-day-section--open': collapsible && open }"
    variant="outlined"
    :data-testid="testId"
    :data-state="state"
  >
    <div class="game-day-section__head">
      <component
        :is="collapsible ? 'button' : 'div'"
        class="game-day-section__title"
        :type="collapsible ? 'button' : undefined"
        :aria-expanded="collapsible ? open : undefined"
        @click="collapsible && emit('update:open', !open)"
      >
        <span class="game-day-section__no">{{ no }}</span>
        <span class="game-day-section__name">{{ title }}</span>
        <span v-if="summary" class="game-day-section__summary">{{ summary }}</span>
      </component>
      <div class="game-day-section__right">
        <slot name="actions" />
        <!-- 別画面へ送るだけの段（info）は、状態を持たないのでチップを出さない -->
        <GameDayStateChip v-if="state !== 'info'" :state="state" />
        <v-icon v-if="collapsible" size="small" aria-hidden="true">
          {{ open ? 'mdi-chevron-up' : 'mdi-chevron-down' }}
        </v-icon>
      </div>
    </div>
    <!-- v-show: 閉じても中身を残す（入力中の値・テストの data-testid を失わない） -->
    <div
      v-if="$slots.default && (!lazy || everOpened)"
      v-show="!collapsible || open"
      class="game-day-section__body"
    >
      <slot />
    </div>
  </v-card>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import GameDayStateChip from './GameDayStateChip.vue'
import type { StageState } from './gameDayStatus'

const props = withDefaults(
  defineProps<{
    no: string | number
    title: string
    state: StageState
    summary?: string
    open?: boolean
    // false: 開閉しない 1 行の段（別画面への入口だけ置く段）
    collapsible?: boolean
    // true: 初めて開かれるまで中身を描画しない（重い部品を遅延させる）
    lazy?: boolean
    testId?: string
  }>(),
  { open: false, collapsible: true, lazy: false, summary: undefined, testId: undefined },
)

const emit = defineEmits<{ 'update:open': [value: boolean] }>()

const everOpened = ref(props.open)
watch(
  () => props.open,
  (value) => {
    if (value) everOpened.value = true
  },
)
</script>

<style scoped>
.game-day-section {
  overflow: hidden;
}
.game-day-section--open {
  border-color: rgb(var(--v-theme-primary));
}
.game-day-section__head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 14px;
  min-height: 52px;
}
.game-day-section__title {
  display: flex;
  flex: 1;
  align-items: center;
  gap: 10px;
  min-width: 0;
  min-height: 44px;
  text-align: left;
  background: transparent;
  border: 0;
  color: inherit;
  font: inherit;
}
button.game-day-section__title {
  cursor: pointer;
}
.game-day-section__no {
  display: inline-grid;
  place-items: center;
  flex: none;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgb(var(--v-theme-primary));
  color: rgb(var(--v-theme-on-primary));
  font-size: 0.8rem;
  font-weight: 700;
}
.game-day-section__name {
  flex: none;
  font-size: 0.95rem;
  font-weight: 700;
  white-space: nowrap;
}
.game-day-section__summary {
  min-width: 0;
  font-size: 0.8125rem;
  color: rgba(var(--v-theme-on-surface), var(--v-medium-emphasis-opacity));
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.game-day-section__right {
  display: flex;
  flex: none;
  align-items: center;
  gap: 8px;
}
.game-day-section__body {
  padding: 8px 14px 14px;
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
</style>
