import { ref, computed } from 'vue'
import axios from 'axios'
import router from '@/router' // Vue Routerをインポート
import { useTeamSelectionStore } from '@/stores/teamSelection'

interface User {
  id: number
  name: string
  role: string
}

interface MyTeam {
  id: number
  name: string
  [key: string]: unknown
}

interface LoginResponse {
  user: User
  message: string
}

const user = ref<User | null>(null)
const loading = ref(false)

export function useAuth() {
  const isAuthenticated = computed(() => !!user.value)
  const isCommissioner = computed(() => user.value?.role === 'commissioner')

  const initializeUserState = async () => {
    const teamStore = useTeamSelectionStore()
    if (!teamStore.teamsLoaded) {
      try {
        const response = await axios.get<MyTeam[]>('/users/me/teams')
        teamStore.setMyTeams(response.data)
      } catch {
        teamStore.setMyTeams([])
      }
    }
    if (isCommissioner.value && !teamStore.allTeamsLoaded) {
      try {
        const response = await axios.get<MyTeam[]>('/teams')
        teamStore.setAllTeams(response.data)
      } catch {
        teamStore.setAllTeams([])
      }
    }
  }

  const login = async (name: string, password: string): Promise<LoginResponse> => {
    loading.value = true
    try {
      const response = await axios.post<LoginResponse>('auth/login', {
        name,
        password,
      })
      user.value = response.data.user
      await initializeUserState()
      return response.data
    } catch (error: unknown) {
      const axiosError = error as { response?: { data?: { error?: string } } }
      if (axiosError.response?.data?.error) {
        throw new Error(axiosError.response.data.error)
      }
      throw new Error('ログインに失敗しました')
    } finally {
      loading.value = false
    }
  }

  const logout = async (): Promise<void> => {
    loading.value = true
    try {
      await axios.post('auth/logout')
      user.value = null
      const teamStore = useTeamSelectionStore()
      teamStore.clearTeam()
      teamStore.resetTeams()
      router.push('/login')
    } catch (e) {
      console.error('ログアウト時にエラーが発生しました:', e)
      user.value = null
    } finally {
      loading.value = false
    }
  }

  const checkAuth = async (): Promise<void> => {
    try {
      const response = await axios.get<{ user: User }>('auth/current_user')
      user.value = response.data.user
      await initializeUserState()
    } catch {
      user.value = null
    }
  }

  return {
    user: computed(() => user.value),
    isAuthenticated,
    isCommissioner,
    loading: computed(() => loading.value),
    login,
    logout,
    checkAuth,
  }
}
