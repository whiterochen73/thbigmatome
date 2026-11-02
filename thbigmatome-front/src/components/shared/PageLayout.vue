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
/* 操作が 3 つ以上の行は、スマホ（<600px）でアイコンを隠して操作メニュー（RowMenu）に替える */
@media (max-width: 599.98px) {
  .page-layout :deep(.row-actions--full) {
    display: none;
  }
}

/* スマホ（<600px）の縦積み行（class="ui-table ui-table--rows" ＋ mobile-breakpoint="sm"）。
   1 行 = 名前（太字）＋要点 2 つ＋操作。列の class（tableCell）で置き場所を決め、class の無い列は 600px 未満では出さない。
   lead … 左の番号・画像 / title … 名前 / sub1・sub2 … 要点 / note … 補足 1 行 / act … 操作（labeled は列の見出しを値の前に出す） */
/* 行を grid にすると、table のままでは匿名のセルに包まれて幅が中身なりに縮み、ホバーの塗りや下線が操作側まで届かない。縦積みの時だけ table を block にして行を幅いっぱいにする */
.page-layout :deep(.ui-table--rows table:has(tr.v-data-table__tr--mobile)),
.page-layout :deep(.ui-table--rows table:has(tr.v-data-table__tr--mobile) > tbody),
.page-layout :deep(.ui-table--rows table:has(tr.v-data-table__tr--mobile) > thead) {
  display: block;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile) {
  display: grid;
  grid-template-columns: auto auto minmax(0, 1fr) auto;
  grid-template-areas:
    'lead title title act'
    'lead sub1 sub2 act'
    'lead note note act';
  align-items: center;
  padding: 8px 12px;
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td) {
  display: none;
  min-width: 0;
  min-height: 0;
  padding: 0 4px;
  border: 0;
  background: transparent !important;
}
/* ホバーは行全体に 1 枚。Vuetify は行のホバーを td ごとの ::after で塗るので、grid の隙間・余白・操作側が塗れない。td の ::after を止め、tr の ::before を行いっぱいに重ねる。行の地（bg-state-done など）は残す */
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td::after) {
  content: none !important;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile) {
  position: relative;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile:hover::before) {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(var(--v-theme-on-surface), var(--v-hover-opacity));
  pointer-events: none;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell) {
  display: block;
}
.page-layout :deep(.ui-table--rows .ui-cell .v-data-table__td-title) {
  display: none;
}
.page-layout :deep(.ui-table--rows .ui-cell .v-data-table__td-value) {
  text-align: start;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--labeled) {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  column-gap: 4px;
}
.page-layout :deep(.ui-table--rows .ui-cell--labeled .v-data-table__td-title) {
  display: block;
  color: rgb(var(--v-theme-on-surface-variant));
  font-size: 0.75rem;
  font-weight: 400;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--lead) {
  grid-area: lead;
  box-sizing: border-box;
  width: 2.8em;
  min-width: 2.8em;
  color: rgb(var(--v-theme-on-surface-variant));
  font-variant-numeric: tabular-nums;
  text-align: end;
}
.page-layout :deep(.ui-table--rows .ui-cell--lead .v-data-table__td-value) {
  text-align: end;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--title) {
  grid-area: title;
  font-weight: 700;
  overflow-wrap: anywhere;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--sub1) {
  grid-area: sub1;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--sub2) {
  grid-area: sub2;
  font-size: 0.8125rem;
}
/* 長い説明（text-truncate）は、スマホの縦積み行の中だけ PC 用の最大幅の指定を外してセルの幅で省略する（PC の表は変えない） */
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile .ui-cell .text-truncate) {
  display: block;
  max-width: 100% !important;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--note) {
  grid-area: note;
  color: rgb(var(--v-theme-on-surface-variant));
  font-size: 0.8125rem;
}
/* note2 は note の右隣（同じ 3 行目）。note2 のある行だけ note を 1 列に縮める */
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--note2) {
  grid-row: 3;
  grid-column: 3;
  color: rgb(var(--v-theme-on-surface-variant));
  font-size: 0.8125rem;
}
.page-layout
  :deep(
    .ui-table--rows tbody > tr.v-data-table__tr--mobile:has(> td.ui-cell--note2) > td.ui-cell--note
  ) {
  grid-column: 2;
}
.page-layout :deep(.ui-table--rows tbody > tr.v-data-table__tr--mobile > td.ui-cell--act) {
  grid-area: act;
  padding-inline-start: 8px;
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
