<template>
  <v-card variant="outlined" class="pa-3 mb-3" data-testid="as-of-bar">
    <div class="d-flex flex-wrap align-center ga-3">
      <v-icon class="on-surface-variant">mdi-history</v-icon>
      <span class="text-subtitle-2">{{ t('asOfBar.title') }}</span>
      <v-text-field
        :model-value="date"
        type="date"
        density="compact"
        hide-details
        style="max-width: 190px"
        :label="t('asOfBar.date')"
        :min="min"
        :max="max"
        data-testid="as-of-date"
        @update:model-value="onDate"
      />
      <v-btn-toggle
        v-if="showPhase"
        :model-value="phase"
        mandatory
        density="compact"
        variant="outlined"
        selected-class="bg-primary"
        :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
        data-testid="as-of-phase"
        @update:model-value="(value: string) => emit('update:phase', value)"
      >
        <v-btn value="pre_game" data-testid="as-of-phase-pre">{{
          t('asOfBar.phaseLabel.pre_game')
        }}</v-btn>
        <v-btn value="post_game" data-testid="as-of-phase-post">{{
          t('asOfBar.phaseLabel.post_game')
        }}</v-btn>
      </v-btn-toggle>
      <v-btn
        v-if="currentDate && date !== currentDate"
        size="small"
        variant="outlined"
        :style="{ borderColor: 'rgb(var(--v-theme-border-strong))' }"
        data-testid="as-of-reset"
        @click="emit('update:date', currentDate)"
      >
        {{ t('asOfBar.backToCurrent') }}
      </v-btn>
    </div>
  </v-card>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'

// シーズン画面から過去分のロスター・離脱・チーム編成を直す時の、日付（と試合前／試合後）の選択。
// 読む GET と保存する POST は、この日付と区分を必ず同じ値で送る（呼び出し側の義務）。
const props = defineProps<{
  date: string
  phase?: string
  showPhase?: boolean
  min?: string
  max?: string
  // 現在日（既定の日付）。選んだ日付が現在日と違う時だけ「現在日に戻す」を出す
  currentDate?: string
}>()
const emit = defineEmits<{ 'update:date': [value: string]; 'update:phase': [value: string] }>()

const { t } = useI18n()

// 日付欄を空にした時や、範囲外の日付は取り込まない
const onDate = (value: string | null) => {
  if (!value) return
  if (props.min && value < props.min) return
  if (props.max && value > props.max) return
  emit('update:date', value)
}
</script>
