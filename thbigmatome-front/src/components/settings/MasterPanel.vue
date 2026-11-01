<template>
  <section class="master-panel" data-testid="master-panel">
    <header class="master-panel__header">
      <!-- 開閉の操作はこの 1 つ。::after でヘッダー全体を押せる範囲にし、追加ボタンはその上に載せる（ボタンの入れ子を避ける） -->
      <button
        type="button"
        class="master-panel__toggle"
        :aria-expanded="open ? 'true' : 'false'"
        :aria-controls="bodyId"
        data-testid="master-panel-toggle"
        @click="open = !open"
      >
        <v-icon class="on-surface-variant" size="22" aria-hidden="true">{{ icon }}</v-icon>
        <h3 class="master-panel__title">{{ title }}</h3>
        <v-chip
          v-if="count !== undefined"
          color="state-neutral"
          variant="flat"
          size="small"
          data-testid="master-panel-count"
          >{{ t('settings.itemCount', { count }) }}</v-chip
        >
      </button>
      <div v-if="$slots.actions" class="master-panel__actions">
        <slot name="actions" />
      </div>
      <v-icon class="master-panel__chevron on-surface-variant" aria-hidden="true">{{
        open ? 'mdi-chevron-up' : 'mdi-chevron-down'
      }}</v-icon>
    </header>
    <div v-show="open" :id="bodyId" class="master-panel__body">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
import { ref, useId } from 'vue'
import { useI18n } from 'vue-i18n'

// 設定画面のマスタ 1 件分の枠。アイコン・名前・件数・追加（枠ボタン）・開閉をそろえる。
// 追加ボタンは actions スロットへ（MasterAddButton）。同格の追加が並ぶので塗らず、枠ボタンにする
const props = withDefaults(
  defineProps<{
    title: string
    icon?: string
    count?: number
    defaultOpen?: boolean
  }>(),
  { icon: 'mdi-tag-outline', count: undefined, defaultOpen: false },
)

const { t } = useI18n()
const open = ref(props.defaultOpen)
const bodyId = `master-panel-body-${useId()}`
</script>

<style scoped>
.master-panel {
  overflow: hidden;
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
}
.master-panel__header {
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 48px;
  padding-inline-end: 12px;
}
.master-panel__toggle {
  display: flex;
  flex: 1 1 auto;
  align-items: center;
  gap: 8px;
  min-width: 0;
  min-height: 48px;
  padding: 0 0 0 16px;
  border: 0;
  background: none;
  color: inherit;
  font: inherit;
  text-align: start;
  cursor: pointer;
}
.master-panel__toggle::after {
  content: '';
  position: absolute;
  inset: 0;
}
.master-panel__toggle:focus-visible {
  outline: 2px solid rgb(var(--v-theme-link));
  outline-offset: -2px;
}
.master-panel__title {
  margin: 0;
  overflow: hidden;
  font-family: inherit;
  font-size: 0.9375rem;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.master-panel__actions {
  position: relative;
  z-index: 1;
  display: flex;
  flex: none;
  align-items: center;
  gap: 8px;
}
.master-panel__chevron {
  flex: none;
  pointer-events: none;
}
.master-panel__body {
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.master-panel__body :deep(.v-table) {
  background: transparent;
}
.master-panel__body :deep(.v-data-table__th:not(:has(.v-data-table__td-sort-select))) {
  background: rgb(var(--v-theme-surface-variant)) !important;
  color: rgb(var(--v-theme-on-surface-variant)) !important;
  font-size: 0.75rem;
  font-weight: 700;
}
.master-panel__body :deep(.v-data-table__th .v-data-table-header__content),
.master-panel__body :deep(.v-data-table__th i) {
  color: inherit;
}
</style>
