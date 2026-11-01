import type { RouteLocationRaw } from 'vue-router'

const LOGIN_PATH = '/login'

// redirect クエリの値を、サイト内の遷移先として安全な文字列に絞る。
// 外部 URL（https://…、//host、/\host）や /login 自身は '/' に落とす（オープンリダイレクト対策・ループ防止）
export function sanitizeRedirect(value: unknown): string {
  const raw = Array.isArray(value) ? value[0] : value
  if (typeof raw !== 'string' || raw === '') return '/'
  if (!raw.startsWith('/') || raw.startsWith('//') || raw.includes('\\')) return '/'
  // 制御文字（改行・タブなど）を含むものは、ブラウザが解釈を変えうるので受けない
  if (/[\u0000-\u001f\u007f]/.test(raw)) return '/'
  try {
    const base = 'http://redirect.invalid'
    const url = new URL(raw, base)
    if (url.origin !== base) return '/'
    if (url.pathname === LOGIN_PATH) return '/'
  } catch {
    return '/'
  }
  return raw
}

// ログイン画面への遷移先。元の画面（fullPath）を redirect に持たせる。ホームだけは持たせない
export function loginLocation(fullPath: string): RouteLocationRaw {
  const redirect = sanitizeRedirect(fullPath)
  if (redirect === '/') return { path: LOGIN_PATH }
  return { path: LOGIN_PATH, query: { redirect } }
}
