<template>
  <v-row class="mb-2">
    <v-col cols="12" class="d-flex align-center">
      <v-btn v-if="backTo" icon="mdi-arrow-left" variant="text" :to="backTo" class="mr-2" />
      <!-- 画面タイトルはヘッダーバー（AppBar）が出す。バーが題を出している間は本文で繰り返さない -->
      <h1 v-if="!shownInAppBar" class="page-title">{{ title }}</h1>
      <v-spacer />
      <slot name="actions" />
    </v-col>
  </v-row>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { RouteLocationRaw } from 'vue-router'
import { appBarShownTitle } from '@/composables/useAppBarTitle'

// 非推奨: 新しい画面は PageLayout を使い、タイトルはヘッダーバーへ（useAppBarTitle / route.meta.title）。
// まだ移していない画面のために残す。バーがタイトルを出している時は本文の h1 を省く
defineProps<{
  title: string
  backTo?: string | RouteLocationRaw
}>()

const shownInAppBar = computed(() => appBarShownTitle.value !== '')
</script>

<style scoped>
.page-title {
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
  color: rgb(var(--v-theme-link));
  border-left: 3px solid rgb(var(--v-theme-link));
  padding-left: 14px;
  margin-bottom: 0;
  line-height: 1.3;
}
</style>
