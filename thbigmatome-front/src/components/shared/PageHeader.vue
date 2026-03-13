<template>
  <v-row class="mb-2">
    <v-col cols="12" class="d-flex align-center">
      <v-btn v-if="backTo" icon="mdi-arrow-left" variant="text" :to="backTo" class="mr-2" />
      <h1 class="text-h4">{{ title }}</h1>
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
