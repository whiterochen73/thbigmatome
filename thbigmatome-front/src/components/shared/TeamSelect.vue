<template>
  <v-select
    v-model="selectedTeam"
    :items="props.teams"
    :item-title="displayNameType"
    item-value="id"
  ></v-select>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Team } from '@/types/team'

const selectedTeam = defineModel()
const props = defineProps({
  teams: {
    type: Array as () => Team[],
    required: true,
  },
  displayNameType: {
    type: String,
    default: 'name',
  },
})

const displayNameType = computed(() => {
  return props.displayNameType === 'short_name' ? 'short_name' : 'name'
})
</script>
