<template>
  <v-chip
    :color="resolvedColor"
    :size="size"
    :variant="absenceAppearance ? 'flat' : 'tonal'"
    :prepend-icon="absenceAppearance?.icon"
  >
    <slot>{{ label }}</slot>
  </v-chip>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { ABSENCE_APPEARANCE } from '@/components/gameDay/gameDayStatus'

const props = defineProps<{
  status: string
  label?: string
  size?: string
}>()

const statusColorMap: Record<string, string> = {
  active: 'success',
  inactive: 'default',
  commissioner: 'primary',
  hachinai: 'purple',
  warning: 'warning',
}

const absenceAppearance = computed(() => ABSENCE_APPEARANCE[props.status])
const resolvedColor = computed(
  () => absenceAppearance.value?.color ?? statusColorMap[props.status] ?? 'default',
)
</script>
