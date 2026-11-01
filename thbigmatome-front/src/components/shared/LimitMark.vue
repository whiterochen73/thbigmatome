<template>
  <v-icon
    v-if="state"
    :icon="LIMIT_APPEARANCE[state].icon"
    :color="LIMIT_APPEARANCE[state].color"
    :size="size"
    role="img"
    :aria-label="LIMIT_APPEARANCE[state].label"
    :data-state="state"
    data-testid="limit-mark"
  />
</template>

<script setup lang="ts">
import { LIMIT_APPEARANCE, type LimitState } from './rosterLimits'

withDefaults(defineProps<{ state: LimitState | null; size?: string | number }>(), {
  size: 18,
})
</script>
