<template>
  <div class="d-flex flex-column align-center py-8 text-grey">
    <v-icon size="48" class="mb-2">{{ icon }}</v-icon>
    <span>{{ message }}</span>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  icon: string
  message: string
}>()
</script>
