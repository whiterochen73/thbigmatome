<template>
  <v-row class="mb-2" dense>
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
</template>
