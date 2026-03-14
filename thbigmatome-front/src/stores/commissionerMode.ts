import { defineStore } from 'pinia'
import { ref } from 'vue'

const STORAGE_KEY = 'commissionerMode'

export const useCommissionerModeStore = defineStore('commissionerMode', () => {
  const stored = localStorage.getItem(STORAGE_KEY)
  const isCommissionerMode = ref<boolean>(stored === 'true')

  function toggle() {
    isCommissionerMode.value = !isCommissionerMode.value
    localStorage.setItem(STORAGE_KEY, String(isCommissionerMode.value))
  }

  function setMode(value: boolean) {
    isCommissionerMode.value = value
    localStorage.setItem(STORAGE_KEY, String(value))
  }

  return { isCommissionerMode, toggle, setMode }
})
