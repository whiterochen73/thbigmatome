<template>
  <div class="filter-bar-wrap">
    <v-row class="mb-0" density="compact">
      <v-col v-if="$slots.search" cols="12" sm="4">
        <slot name="search" />
      </v-col>
      <v-col v-if="$slots.filters">
        <slot name="filters" />
      </v-col>
      <v-col v-if="$slots.toggles" class="d-flex justify-end">
        <slot name="toggles" />
      </v-col>
    </v-row>
  </div>
</template>

<style scoped>
/* 色と縁は Vuetify のテーマのトークンから取る（--bg-elevated などの独自変数に頼らない。dark でも面が追従する） */
.filter-bar-wrap {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  padding: 12px 16px;
  margin-bottom: 16px;
}
/* 入力欄のラベル。Vuetify 既定（medium-emphasis 0.6）は light で 3.57 まで落ちるので、on-surface-variant・不透明にする（ツールバーの欄と同じ） */
.filter-bar-wrap :deep(.v-field .v-label.v-field-label) {
  color: rgb(var(--v-theme-on-surface-variant));
  opacity: 1;
}
</style>
