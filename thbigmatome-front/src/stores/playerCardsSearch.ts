import { defineStore } from 'pinia'
import { ref } from 'vue'

export const usePlayerCardsSearchStore = defineStore('playerCardsSearch', () => {
  const filterCardSetId = ref<number | null>(null)
  const filterCardType = ref('')
  const filterName = ref('')
  const currentPage = ref(1)
  const viewMode = ref<'table' | 'grid'>('table')
  const scrollY = ref(0)

  function setScrollY(val: number) {
    scrollY.value = val
  }

  return {
    filterCardSetId,
    filterCardType,
    filterName,
    currentPage,
    viewMode,
    scrollY,
    setScrollY,
  }
})
