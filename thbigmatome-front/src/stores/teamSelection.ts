import { defineStore } from 'pinia'
import { ref } from 'vue'

const STORAGE_KEY = 'selectedTeam'

export const useTeamSelectionStore = defineStore('teamSelection', () => {
  const stored = localStorage.getItem(STORAGE_KEY)
  const initialData = stored ? JSON.parse(stored) : null

  const selectedTeamId = ref<number | null>(initialData?.teamId ?? null)
  const selectedTeamName = ref<string>(initialData?.teamName ?? '')

  function selectTeam(teamId: number, teamName: string) {
    selectedTeamId.value = teamId
    selectedTeamName.value = teamName
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ teamId, teamName }))
  }

  function clearTeam() {
    selectedTeamId.value = null
    selectedTeamName.value = ''
    localStorage.removeItem(STORAGE_KEY)
  }

  return { selectedTeamId, selectedTeamName, selectTeam, clearTeam }
})
