import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useCommissionerModeStore } from '@/stores/commissionerMode'

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
  const allTeams = ref<MyTeam[]>([])
  const allTeamsLoaded = ref(false)

  const hasTeam = computed(() => myTeams.value.length > 0)

  const availableTeams = computed(() => {
    const cmStore = useCommissionerModeStore()
    return cmStore.isCommissionerMode ? allTeams.value : myTeams.value
  })

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

  function setAllTeams(teams: MyTeam[]) {
    allTeams.value = teams
    allTeamsLoaded.value = true
  }

  function resetTeams() {
    myTeams.value = []
    teamsLoaded.value = false
    allTeams.value = []
    allTeamsLoaded.value = false
  }

  return {
    selectedTeamId,
    selectedTeamName,
    myTeams,
    hasTeam,
    teamsLoaded,
    allTeams,
    allTeamsLoaded,
    availableTeams,
    selectTeam,
    clearTeam,
    setMyTeams,
    setAllTeams,
    resetTeams,
  }
})
