import { defineStore } from 'pinia'
import { ref } from 'vue'

export const usePlayersSearchStore = defineStore('playersSearch', () => {
  const searchText = ref('')
  const scrollY = ref(0)

  function setSearchText(val: string) {
    searchText.value = val
  }

  function setScrollY(val: number) {
    scrollY.value = val
  }

  return { searchText, scrollY, setSearchText, setScrollY }
})
