<template>
  <div
    class="async-state"
    :class="{ 'async-state--framed': framed }"
    :aria-busy="loading ? 'true' : undefined"
  >
    <v-progress-linear
      v-if="loading && !empty"
      indeterminate
      height="2"
      color="link"
      data-testid="state-refreshing"
    />
    <v-alert
      v-if="error"
      type="error"
      color="state-warn"
      variant="flat"
      density="compact"
      class="mb-3"
      data-testid="state-error"
    >
      <div class="d-flex flex-wrap align-center ga-2">
        <span>{{ errorMessage ?? t('asyncState.error') }}</span>
        <v-spacer />
        <v-btn
          size="small"
          variant="outlined"
          class="async-state__retry"
          prepend-icon="mdi-refresh"
          data-testid="state-retry"
          @click="emit('retry')"
        >
          {{ t('asyncState.retry') }}
        </v-btn>
      </div>
    </v-alert>

    <v-skeleton-loader v-if="loading && empty" :type="skeleton" data-testid="state-loading" />
    <EmptyState
      v-else-if="empty && !error"
      :icon="emptyIcon"
      :message="emptyMessage"
      data-testid="state-empty"
    >
      <slot name="empty-actions" />
    </EmptyState>
    <slot v-else-if="!empty" />
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import EmptyState from '@/components/EmptyState.vue'

// 読み込み中・空・失敗の出し方を 1 か所に持つ。
//   loading … 取得中。内容がまだ無ければスケルトン、あれば細い進捗線だけ（前の内容は消さない）
//   empty   … 出す内容が無い。読み込み中・失敗の間は空状態を出さない
//   error   … 取得に失敗した。ページ内のアラート＋「再読み込み」（保存の成否はスナックバーのまま）
withDefaults(
  defineProps<{
    loading?: boolean
    empty?: boolean
    error?: boolean
    errorMessage?: string
    emptyIcon?: string
    emptyMessage?: string
    skeleton?: string
    /** スケルトンと空状態を縁つきの枠で包む（内容側がカードの時に、状態も同じ見た目にそろえる） */
    framed?: boolean
  }>(),
  {
    loading: false,
    empty: false,
    error: false,
    errorMessage: undefined,
    emptyIcon: 'mdi-database-off-outline',
    emptyMessage: '',
    skeleton: 'table',
    framed: false,
  },
)

const emit = defineEmits<{ retry: [] }>()
const { t } = useI18n()
</script>

<style scoped>
.async-state--framed > .v-skeleton-loader,
.async-state--framed > .empty-state {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  background: rgb(var(--v-theme-surface));
}
.async-state__retry {
  border-color: rgb(var(--v-theme-on-state-warn));
  color: rgb(var(--v-theme-on-state-warn));
}
</style>
