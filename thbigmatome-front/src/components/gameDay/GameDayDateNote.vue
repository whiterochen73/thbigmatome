<template>
  <v-alert
    v-if="note"
    type="info"
    variant="tonal"
    density="compact"
    class="mb-3"
    data-testid="date-note"
  >
    {{ t('gameDay.dateNote', note) }}
  </v-alert>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { dateKey } from './gameDayStatus'

// 埋め込んだ画面（チーム編成・ロスター・離脱者）は、試合日ではなくシーズンの現在日で記録する。
// 二つの日付が違う時だけ、その旨を出す（同じ日・どちらかが分からない時は出さない）
const props = defineProps<{
  gameDate: string | null | undefined
  currentDate: string | null | undefined
}>()

const { t } = useI18n()

// "2026-05-07" → "5/7"
const monthDay = (key: string): string => {
  const [, month, day] = key.split('-')
  return `${Number(month)}/${Number(day)}`
}

const note = computed(() => {
  const game = dateKey(props.gameDate)
  const current = dateKey(props.currentDate)
  if (!game || !current || game === current) return null
  return { current: monthDay(current), game: monthDay(game) }
})
</script>
