import { describe, expect, it, vi } from 'vitest'

vi.mock('@/plugins/axios', () => ({ default: {} }))
vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import router from '../index'

// Test Basis: thbig-dugout-ui-unification-design.md §1.2 #2・§4.1（AppBar は宣言の無い画面で route.meta.title を出す。全ルートに題が要る）
describe('route.meta.title', () => {
  const pages = router
    .getRoutes()
    .filter((r) => r.components && r.path !== '/login' && r.path !== '/' + ':pathMatch(.*)*')
    // 親のレイアウト（DefaultLayout）自体は画面ではない
    .filter((r) => r.path !== '/')

  it('画面になる全ルートに meta.title が付いている（バーに題が出る）', () => {
    const missing = pages.filter((r) => typeof r.meta.title !== 'string' || !r.meta.title)
    expect(missing.map((r) => r.path)).toEqual([])
    expect(pages.length).toBeGreaterThan(15)
  })

  it('名前を統一した画面（設定・シーズン・チーム一覧）の題', () => {
    const title = (path: string) => router.getRoutes().find((r) => r.path === path)?.meta.title
    expect(title('/settings')).toBe('設定')
    expect(title('/teams/:teamId/season')).toBe('シーズン')
    expect(title('/teams')).toBe('チーム一覧')
    expect(title('/players')).toBe('選手一覧')
    // チーム編成は、バーにチーム名が宣言されるまで（宣言できない時）の題
    expect(title('/teams/:teamId/members')).toBe('チーム編成')
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.2（ナビ名 = バータイトル = meta.title）。段 2 で画面の見出しとそろえた名前
  it('段 2 で名前をそろえた画面の題（カードセット・選手カード）', () => {
    const title = (path: string) => router.getRoutes().find((r) => r.path === path)?.meta.title
    expect(title('/commissioner/card_sets')).toBe('カードセット')
    expect(title('/player-cards')).toBe('選手カード')
    expect(title('/commissioner/dashboard')).toBe('ダッシュボード')
    expect(title('/managers')).toBe('監督一覧')
    expect(title('/commissioner/users')).toBe('ユーザー管理')
  })

  // Test Basis: Operator 決定 2026-11-01（cmd_1795）「パーサー経由の試合記録・試合詳細・成績集計・レビューは廃止」
  it('パーサー経由の画面（試合記録・試合詳細・オーダー確認・成績集計・パーサーレビュー・旧ホーム）の route は無い', () => {
    const paths = router.getRoutes().map((r) => r.path)
    for (const path of [
      '/home',
      '/games',
      '/games/:id',
      '/games/:id/lineup',
      '/stats',
      '/game-records',
      '/game-records/:id',
    ]) {
      expect(paths).not.toContain(path)
    }
  })

  // Test Basis: Operator 決定 2026-11-01（cmd_1795）旧ホーム（/home）を削除。今のホーム（/ の HomePortalView）は残す
  it('旧ホーム（/home）は画面に解決されず、ホーム（/）は残る', () => {
    expect(router.resolve('/home').matched.some((r) => r.path === '/home')).toBe(false)
    const home = router.getRoutes().find((r) => r.name === 'ホーム')
    expect(home?.meta.title).toBe('ホーム')
    expect(router.resolve('/').name).toBe('ホーム')
  })
})
