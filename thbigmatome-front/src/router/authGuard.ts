// authGuard.ts
import { type RouteLocationNormalized } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

export async function authGuard(to: RouteLocationNormalized, from: RouteLocationNormalized) {
  const { isAuthenticated, checkAuth, isCommissioner } = useAuth()

  if (to.path === '/login') {
    if (isAuthenticated.value) {
      return '/'
    }
    return true
  }

  // /login からの遷移（ログイン直後）は必ずcheckAuthを呼ぶ。
  // 理由: login()でuser.valueをguard外でセットしても、Vue RouterのNavigationが
  // コミットしてDefaultLayout/NavigationDrawerがマウントされるタイミングまでに
  // Vueのリアクティビティ伝播が確実に完了しない場合がある。
  // F5リロード時と同じく「guard内でcheckAuth完了→navigation commit→コンポーネントmount」
  // の順序にすることで、NavigationDrawerマウント時に確実にisCommissioner=trueになる。
  if (!isAuthenticated.value || from.path === '/login') {
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
