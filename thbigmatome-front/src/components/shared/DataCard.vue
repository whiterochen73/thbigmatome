<template>
  <v-card>
    <v-card-title v-if="title || $slots['title-actions']" class="d-flex align-center">
      <span>{{ title }}</span>
      <v-spacer />
      <slot name="title-actions" />
    </v-card-title>
    <v-card-text>
      <slot />
    </v-card-text>
    <slot name="footer" />
  </v-card>
</template>

<script setup lang="ts">
defineProps<{
  title: string
}>()
</script>
