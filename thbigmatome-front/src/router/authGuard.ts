// authGuard.ts
import { type NavigationGuardNext, type RouteLocationNormalized } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

export async function authGuard(
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  next: NavigationGuardNext
) {
  const { isAuthenticated, checkAuth, isCommissioner } = useAuth()

  // ログインページへの遷移中に checkAuth を呼ばないようにする
  // または、checkAuth の結果で適切に遷移を制御する
  if (to.path === '/login') {
    // ログインページへのアクセスの場合、checkAuthは行わない (無限ループ回避)
    // ただし、ログイン済みであればメニュー画面へリダイレクト
    if (isAuthenticated.value) {
      next('/menu')
    } else {
      next() // 未ログインであればそのままログインページへ
    }
    return; // ここでガードの処理を終了
  }

  // それ以外のページの場合のみ認証チェックを行う
  await checkAuth()

  if (to.meta.requiresAuth && !isAuthenticated.value) {
    // 認証が必要なページで未認証の場合、ログインページへリダイレクト
    next('/login')
  } else if (to.meta.requiresCommissioner && !isCommissioner.value) {
    // コミッショナー権限が必要なページでコミッショナーでない場合、メニュー画面へリダイレクト
    next('/menu')
  } else if (to.path === '/menu' && !to.meta.requiresAuth && isAuthenticated.value) {
    // この条件は通常発生しないが、念のため
    // 例外的なケースでログイン済みで/menuにいるがrequiresAuthがfalseの場合など
    next()
  } else {
    next()
  }
}