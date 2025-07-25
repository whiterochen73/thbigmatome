import { ref, computed } from 'vue'
import axios from 'axios'
import router from '@/router' // Vue Routerをインポート

interface User {
  id: number
  name: string
}

interface LoginResponse {
  user: User
  message: string
}

interface ErrorResponse {
  error: string
}

const user = ref<User | null>(null)
const loading = ref(false)

export function useAuth() {
  const isAuthenticated = computed(() => !!user.value)

  const login = async (name: string, password: string): Promise<LoginResponse> => {
    loading.value = true
    try {
      const response = await axios.post<LoginResponse>('auth/login', {
        name,
        password
      })
      user.value = response.data.user
      return response.data
    } catch (error: any) {
      if (error.response?.data?.error) {
        throw new Error(error.response.data.error)
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
      user.value = null // 認証状態をクリア
      // ログアウト成功後、明示的にログインページへリダイレクト
      router.push('/login') // ★ここを追加★
    } catch (error) {
      console.error('ログアウト時にエラーが発生しました:', error)
      user.value = null // エラー時も一応認証状態をクリアしておく
    } finally {
      loading.value = false
    }
  }

  const checkAuth = async (): Promise<void> => {
    try {
      const response = await axios.get<{ user: User }>('auth/current_user')
      user.value = response.data.user
    } catch (error) {
      user.value = null
    }
  }

  return {
    user: computed(() => user.value),
    isAuthenticated,
    loading: computed(() => loading.value),
    login,
    logout,
    checkAuth
  }
}
