<template>
  <v-alert
    v-if="message"
    type="info"
    color="state-info"
    variant="flat"
    density="compact"
    class="mb-3"
    data-testid="range-note"
  >
    <div class="d-flex flex-wrap align-center ga-2">
      <span>{{ message }}</span>
      <v-spacer />
      <v-btn
        v-if="to"
        size="small"
        variant="outlined"
        :style="{ borderColor: 'rgb(var(--v-theme-on-state-info))' }"
        :to="to"
        data-testid="range-note-link"
      >
        {{ t('gameDay.rangeNote.link') }}
      </v-btn>
    </div>
  </v-alert>
</template>

<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'
import { useI18n } from 'vue-i18n'

// 登録・昇降格・負傷・出場停止を操作できない日（今の範囲の外）に出す案内。過去分の修正はシーズン画面から行う。
// message が空なら何も出さない（操作できる日）
defineProps<{
  message: string
  to?: RouteLocationRaw
}>()

const { t } = useI18n()
</script>
