<template>
  <v-autocomplete
    v-model="selectedValue"
    :search="search"
    :items="players"
    :label="label"
    item-title="name"
    item-value="id"
    :custom-filter="filter"
    :multiple="multiple"
    :chips="multiple"
    clearable
    density="compact"
  ></v-autocomplete>
</template>

<script setup lang="ts">
import { ref, watch, type PropType } from 'vue'
import type { Player } from '@/types/player'

const props = defineProps({
  modelValue: {
    type: [Number, Array] as PropType<number | number[] | null>,
    default: null,
  },
  players: {
    type: Array as () => Player[],
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
  multiple: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['update:modelValue'])

const search = ref('')

const selectedValue = ref(props.modelValue)

watch(
  () => props.modelValue,
  (newValue) => {
    selectedValue.value = newValue
  },
)

watch(
  () => selectedValue.value,
  (newValue) => {
    emit('update:modelValue', newValue)
  },
)

const filter = (_text: string, queryText: string, item: unknown) => {
  const queryTextLower = queryText.toLowerCase()

  const player = (item as { raw: Player }).raw

  const searchText = [player.number, player.name, player.short_name].join(' ').toLowerCase()

  return searchText.includes(queryTextLower)
}
</script>
