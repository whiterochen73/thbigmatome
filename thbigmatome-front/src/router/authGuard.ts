// authGuard.ts
import { type RouteLocationNormalized } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

export async function authGuard(to: RouteLocationNormalized) {
  const { isAuthenticated, checkAuth, isCommissioner } = useAuth()

  // ログインページへの遷移中に checkAuth を呼ばないようにする
  // または、checkAuth の結果で適切に遷移を制御する
  if (to.path === '/login') {
    // ログインページへのアクセスの場合、checkAuthは行わない (無限ループ回避)
    // ただし、ログイン済みであればトップページへリダイレクト
    if (isAuthenticated.value) {
      return '/'
    } else {
      return // 未ログインであればそのままログインページへ
    }
  }

  // それ以外のページの場合のみ認証チェックを行う
  await checkAuth()

  if (to.meta.requiresAuth && !isAuthenticated.value) {
    // 認証が必要なページで未認証の場合、ログインページへリダイレクト
    return '/login'
  } else if (to.meta.requiresCommissioner && !isCommissioner.value) {
    // コミッショナー権限が必要なページでコミッショナーでない場合、トップページへリダイレクト
    return '/'
  }
}
