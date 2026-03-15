import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const STORAGE_KEY = 'selectedTeam'

interface MyTeam {
  id: number
  name: string
  [key: string]: unknown
}

export const useTeamSelectionStore = defineStore('teamSelection', () => {
  const stored = localStorage.getItem(STORAGE_KEY)
  const initialData = stored ? JSON.parse(stored) : null

  const selectedTeamId = ref<number | null>(initialData?.teamId ?? null)
  const selectedTeamName = ref<string>(initialData?.teamName ?? '')
  const myTeams = ref<MyTeam[]>([])
  const teamsLoaded = ref(false)

  const hasTeam = computed(() => myTeams.value.length > 0)

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

  function setMyTeams(teams: MyTeam[]) {
    myTeams.value = teams
    teamsLoaded.value = true
  }

  return {
    selectedTeamId,
    selectedTeamName,
    myTeams,
    hasTeam,
    teamsLoaded,
    selectTeam,
    clearTeam,
    setMyTeams,
  }
})
