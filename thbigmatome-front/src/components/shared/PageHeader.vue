<template>
  <v-row class="mb-2">
    <v-col cols="12" class="d-flex align-center">
      <v-btn v-if="backTo" icon="mdi-arrow-left" variant="text" :to="backTo" class="mr-2" />
      <h1 class="page-title">{{ title }}</h1>
      <v-spacer />
      <slot name="actions" />
    </v-col>
  </v-row>
</template>

<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'
defineProps<{
  title: string
  backTo?: string | RouteLocationRaw
}>()
</script>

<style scoped>
.page-title {
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
  color: var(--ai);
  border-left: 3px solid var(--shu);
  padding-left: 14px;
  margin-bottom: 0;
  line-height: 1.3;
}
</style>
