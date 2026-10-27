<template>
  <span class="gd-state-chip" :class="`gd-state-chip--${state}`" :data-state="state">
    {{ t(STAGE_STATE_LABEL_KEY[state]) }}
  </span>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { STAGE_STATE_LABEL_KEY, type StageState } from './gameDayStatus'

defineProps<{ state: StageState }>()

const { t } = useI18n()
</script>

<!-- 配色は設計書 §5.4 の組み合わせ（本文用 AA 4.5 以上。色だけで伝えないため、チップには必ず文字を付ける） -->
<style>
.gd-state-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 12px;
  padding: 1px 10px;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 20px;
  white-space: nowrap;
  background: #eeece7;
  color: #4a4a4a;
}
.gd-state-chip--done {
  background: #ddefc9;
  color: #2f5a12;
}
.gd-state-chip--editing,
.gd-state-chip--todo {
  background: #fbebc2;
  color: #7a5200;
}
.gd-state-chip--warn {
  background: #f7d9dc;
  color: #8a1420;
}
.gd-state-chip--info {
  background: #d6e9f2;
  color: #12506b;
}
.v-theme--dark .gd-state-chip {
  background: #33335a;
  color: #b8b8d0;
}
.v-theme--dark .gd-state-chip--done {
  background: #2c4a1c;
  color: #bfe59a;
}
.v-theme--dark .gd-state-chip--editing,
.v-theme--dark .gd-state-chip--todo {
  background: #4d3a0c;
  color: #ffd777;
}
.v-theme--dark .gd-state-chip--warn {
  background: #5a1a22;
  color: #ffb3b8;
}
.v-theme--dark .gd-state-chip--info {
  background: #1f3f52;
  color: #a9dbf2;
}
</style>
