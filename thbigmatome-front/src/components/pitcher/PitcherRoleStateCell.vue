<template>
  <div :data-testid="testId">
    <template v-if="state">
      <v-chip :color="roleStatusColor(state.status)" size="x-small">
        {{ roleStatusLabel(state.status) }}
      </v-chip>
      <div
        v-for="note in state.notes"
        :key="note"
        class="text-caption text-medium-emphasis role-state-note"
      >
        {{ roleNoteLabel(note) }}
      </div>
    </template>
    <!-- 省略（リリーフ専門の「先発なら」、リリーフ向けの疲労Pを持たない先発の「リリーフなら」、オープナー可でない投手の「オープナーなら」） -->
    <span v-else class="text-grey">—</span>
  </div>
</template>

<script setup lang="ts">
import { roleNoteLabel, roleStatusColor, roleStatusLabel } from './pitcherRoleState'
import type { PitcherRoleState } from './pitcherRoleState'

defineProps<{
  state?: PitcherRoleState | null
  testId: string
}>()
</script>

<style scoped>
.role-state-note {
  max-width: 16em;
  line-height: 1.3;
}
</style>
