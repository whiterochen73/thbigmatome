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
.filter-bar-wrap {
  background: var(--bg-elevated);
  border: 1px solid var(--border-light);
  border-radius: 8px;
  padding: 12px 16px;
  box-shadow: var(--shadow-card);
  margin-bottom: 16px;
}
</style>
