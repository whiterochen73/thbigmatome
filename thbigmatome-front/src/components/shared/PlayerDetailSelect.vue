<template>
  <v-autocomplete
    v-model="selectedPlayers"
    :search="search"
    :items="players"
    :label="label"
    item-title="name"
    item-value="id"
    :custom-filter="filter"
    multiple
    chips
    clearable
    density="compact"
  ></v-autocomplete>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import type { PlayerDetail } from '@/types/playerDetail'

const props = defineProps({
  modelValue: {
    type: Array<number>,
    default: () => [],
  },
  players: {
    type: Array as () => PlayerDetail[],
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
})

const emit = defineEmits(['update:modelValue'])

const search = ref('')

const selectedPlayers = ref<number[]>(props.modelValue)

watch(
  () => props.modelValue,
  (newValue) => {
    selectedPlayers.value = newValue
  },
)

watch(
  () => selectedPlayers.value,
  (newValue) => {
    emit('update:modelValue', newValue)
  },
)

const filter = (_text: string, queryText: string, item: unknown) => {
  const queryTextLower = queryText.toLowerCase()

  const player = (item as { raw: PlayerDetail }).raw

  const searchText = [player.number, player.name, player.short_name].join(' ').toLowerCase()

  return searchText.includes(queryTextLower)
}
</script>
