// authGuard.ts
import { type RouteLocationNormalized } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

export async function authGuard(to: RouteLocationNormalized) {
  const { isAuthenticated, checkAuth, isCommissioner } = useAuth()

  if (to.path === '/login') {
    if (isAuthenticated.value) {
      return '/'
    }
    return true
  }

  // 認証済みの場合はキャッシュ済み状態を使い、不要なHTTPリクエストをスキップ
  // (タブ切替など同一ルート内ナビゲーションの警告を防ぐ)
  if (!isAuthenticated.value) {
    await checkAuth()
  }

  if (to.meta.requiresAuth && !isAuthenticated.value) {
    return '/login'
  }
  if (to.meta.requiresCommissioner && !isCommissioner.value) {
    return '/'
  }
  return true
}
