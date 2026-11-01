<template>
  <div class="page-layout" :class="`page-layout--${width}`" data-testid="page-layout">
    <slot name="lead" />
    <div v-if="$slots.tabs" class="page-layout__tabs" data-testid="page-tabs">
      <slot name="tabs" />
    </div>
    <div
      v-if="$slots.filters || $slots.actions"
      class="page-layout__toolbar"
      data-testid="page-toolbar"
    >
      <div v-if="$slots.filters" class="page-layout__filters">
        <slot name="filters" />
      </div>
      <div v-if="$slots.actions" class="page-layout__actions">
        <slot name="actions" />
      </div>
    </div>
    <slot />
  </div>
</template>

<script setup lang="ts">
// ページの骨格。画面タイトルはヘッダーバー（AppBar）が持つので、ここには置かない。
//   lead     … 任意。タブより前に置く帯（例: シーズンの「いま」）
//   tabs     … 任意。アイコン＋文字のタブ
//   filters  … 任意。ツールバー行の左（検索・絞り込み）
//   actions  … 任意。ツールバー行の右（主ボタンは 1 つまで、副ボタンはその左）
//   既定      … カードを縦に積む
// 幅は narrow（720: 単一フォーム）/ default（1080）/ wide（レイアウトの外枠 1440 まで）
withDefaults(
  defineProps<{
    width?: 'narrow' | 'default' | 'wide'
  }>(),
  { width: 'default' },
)
</script>

<style scoped>
.page-layout {
  --page-gutter: 24px;
  --page-width: 1080px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  box-sizing: border-box;
  width: 100%;
  max-width: calc(var(--page-width) + 2 * var(--page-gutter));
  margin: 0 auto;
  padding: 20px var(--page-gutter) 24px;
}
.page-layout--narrow {
  --page-width: 720px;
}
.page-layout--wide {
  --page-width: 1440px;
}

/* カードは縁 1px・影なし・角 8px。VCard の既定（elevation 1）は全画面に及ぶので、移行が済むまでは骨格の中のカードにだけ当てる */
.page-layout :deep(.v-card.v-card--variant-elevated),
.page-layout :deep(.v-card.v-card--variant-outlined) {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  box-shadow: none;
}

/* 表の見出し行（class="ui-table" を付けた v-data-table）: surface-variant の地・12px・700。スマホの縦積み（並べ替えの select を持つ見出し）は除く */
.page-layout :deep(.ui-table .v-data-table__th:not(:has(.v-data-table__td-sort-select))) {
  background: rgb(var(--v-theme-surface-variant)) !important;
  color: rgb(var(--v-theme-on-surface-variant)) !important;
  font-size: 0.75rem;
  font-weight: 700;
}

/* スマホの縦積み表の「ソート方式」select。ラベルの既定（medium-emphasis）は light で 3.45 になるので、文字色を on-surface-variant・不透明にする */
.page-layout :deep(.v-data-table__td-sort-select .v-field-label),
.page-layout :deep(.v-data-table__td-sort-select .v-label) {
  color: rgb(var(--v-theme-on-surface-variant));
  opacity: 1;
}

/* ツールバーの入力欄のラベル。Vuetify 既定（medium-emphasis 0.6）は light で 4.08 になるので、文字色を on-surface-variant・不透明にする */
.page-layout__filters :deep(.v-field .v-label.v-field-label) {
  color: rgb(var(--v-theme-on-surface-variant));
  opacity: 1;
}

/* 表の「操作」列のアイコンボタン群。折り返さず横に並べる（class="row-actions" の wrapper を表のセルに置く） */
.page-layout :deep(.row-actions) {
  display: flex;
  flex-wrap: nowrap;
  white-space: nowrap;
}

/* 選択中の v-btn-toggle（selected-class="bg-primary"）。active のオーバーレイが白を重ねて地を明るくし、dark で白文字が 3.81 まで落ちる（実測）ので、オーバーレイを消して地の色をそのまま出す */
.page-layout :deep(.v-btn-toggle .v-btn--active > .v-btn__overlay) {
  opacity: 0;
}

.page-layout__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
}
.page-layout__filters {
  display: flex;
  flex: 1 1 auto;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  min-width: 0;
}
.page-layout__actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-inline-start: auto;
}

@media (max-width: 599.98px) {
  .page-layout {
    --page-gutter: 12px;
  }
  .page-layout__toolbar,
  .page-layout__filters {
    gap: 8px;
  }
  .page-layout__filters,
  .page-layout__actions {
    flex: 1 1 100%;
    margin-inline-start: 0;
  }
  .page-layout__actions > * {
    flex: 1 1 0;
  }
}
</style>
