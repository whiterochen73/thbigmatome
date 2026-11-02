<template>
  <span
    class="gd-state-chip"
    :class="`gd-state-chip--${state}`"
    :data-state="state"
    :style="{
      backgroundColor: `rgb(var(--v-theme-${appearance.color}))`,
      color: `rgb(var(--v-theme-on-${appearance.color}))`,
    }"
  >
    <v-icon size="x-small" aria-hidden="true">{{ appearance.icon }}</v-icon>
    {{ t(appearance.labelKey) }}
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { STAGE_STATE_APPEARANCE, type StageState } from './gameDayStatus'

const props = defineProps<{ state: StageState }>()
const appearance = computed(() => STAGE_STATE_APPEARANCE[props.state])

const { t } = useI18n()
</script>

<!-- 配色は設計書 §6.1・§6.5。色だけで伝えず、アイコンと文字を併用する。 -->
<style>
.gd-state-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border-radius: 12px;
  padding: 1px 10px;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 20px;
  white-space: nowrap;
}
.gd-state-chip--editing {
  border: 1px dashed currentColor;
}
.gd-state-chip--none,
.gd-state-chip--upcoming {
  border: 1px dotted currentColor;
}
</style>
