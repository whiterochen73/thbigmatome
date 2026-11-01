<template>
  <div class="d-flex flex-column align-center py-8 on-surface-variant empty-state">
    <v-icon size="40" class="mb-2" aria-hidden="true">{{ icon }}</v-icon>
    <span>{{ message }}</span>
    <div v-if="$slots.default" class="mt-3"><slot /></div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  icon: string
  message: string
}>()
</script>
