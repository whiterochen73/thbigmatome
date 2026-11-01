// src/plugins/axios.ts
import axios, { AxiosError, type AxiosResponse } from 'axios'
import router from '@/router'
import { useSnackbar } from '@/composables/useSnackbar'
import { useAuth } from '@/composables/useAuth'
import { loginLocation } from '@/router/loginRedirect'

axios.defaults.baseURL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1'
axios.defaults.withCredentials = true

// ログイン・認証確認・ログアウト自体の 401 は「セッション切れ」ではない（パスワード違い・未ログイン）。
// ここで移動すると、ログイン失敗の表示や起動時の認証確認（authGuard）と喧嘩する
const AUTH_ENDPOINT = /(^|\/)auth\/(login|current_user|logout)(\?|$)/

// 同時に複数の API が 401 になっても、ログイン画面への移動は 1 回にする
let redirectingToLogin = false

async function handleSessionExpired(): Promise<void> {
  const current = router.currentRoute.value
  if (redirectingToLogin || current.path === '/login') return
  redirectingToLogin = true
  try {
    console.warn('Authentication error (401). Redirecting to login page.')
    useAuth().clearAuth()
    await router.push(loginLocation(current.fullPath))
  } finally {
    redirectingToLogin = false
  }
}

// レスポンスインターセプター
axios.interceptors.response.use(
  (response: AxiosResponse) => {
    // レスポンスヘッダーからCSRFトークンを確実に取得するロジック
    const csrfToken =
      response.headers['x-csrf-token'] ||
      response.headers['X-CSRF-Token'] ||
      response.headers['X-Csrf-Token']

    if (csrfToken) {
      axios.defaults.headers.common['X-CSRF-Token'] = csrfToken
    }
    return response
  },
  (error: AxiosError) => {
    console.error(
      'Axios plugin: Response interceptor error.',
      error.config?.url,
      error.response?.status,
    )
    if (error.response?.status === 401) {
      if (!AUTH_ENDPOINT.test(error.config?.url ?? '')) {
        handleSessionExpired().catch((e) => console.error('Failed to redirect to login page.', e))
      }
    } else if (error.response?.status === 403) {
      console.warn('Authorization error (403). Redirecting to home.')
      const { showSnackbar } = useSnackbar()
      showSnackbar('アクセス権限がありません', 'error')
      router.push('/')
    }
    return Promise.reject(error)
  },
)

export default axios
