<template>
  <v-chip :color="resolvedColor" :size="size" variant="tonal">
    <slot>{{ label }}</slot>
  </v-chip>
</template>

<script setup lang="ts">
import { computed } from 'vue'

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
  injury: 'error',
  suspension: 'warning',
  reconditioning: 'info',
  cooldown: 'info',
}

const resolvedColor = computed(() => statusColorMap[props.status] ?? 'default')
</script>
