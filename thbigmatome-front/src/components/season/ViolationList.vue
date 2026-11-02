<template>
  <v-alert
    v-if="violations.length > 0"
    type="error"
    color="state-warn"
    variant="flat"
    density="compact"
    class="mb-3"
    data-testid="violation-list"
  >
    <div class="font-weight-bold mb-1">{{ t('violationList.title') }}</div>
    <ul class="ps-4">
      <li v-for="(v, i) in violations" :key="`${v.date}-${v.phase}-${v.kind}-${i}`">
        {{ t('violationList.line', { date: formatDate(v.date), phase: phaseLabel(v.phase) }) }}
        {{ v.message }}
      </li>
    </ul>
  </v-alert>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import type { RosterViolation } from '@/types/rosterViolation'

// 保存が後の日付の検査で止まった時、違反した日付（と試合前／試合後）と内容をそのまま出す。
defineProps<{ violations: RosterViolation[] }>()

const { t } = useI18n()

// "2026-05-10" → "5/10"
const formatDate = (value: string): string => {
  const [, month, day] = value.slice(0, 10).split('-')
  return `${Number(month)}/${Number(day)}`
}

const phaseLabel = (phase: string): string =>
  ['pre_game', 'in_game', 'post_game'].includes(phase) ? t(`asOfBar.phaseLabel.${phase}`) : phase
</script>
