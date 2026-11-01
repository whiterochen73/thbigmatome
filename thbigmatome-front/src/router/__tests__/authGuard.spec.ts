import { describe, it, expect, vi, beforeEach } from 'vitest'
import type { RouteLocationNormalized } from 'vue-router'

const state = vi.hoisted(() => ({ authed: false, commissioner: false, checkAuth: vi.fn() }))

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    // ref のように .value を読むたびに最新の state を返す（computed だと最初の値で固まる）
    isAuthenticated: {
      get value() {
        return state.authed
      },
    },
    isCommissioner: {
      get value() {
        return state.commissioner
      },
    },
    checkAuth: state.checkAuth,
  }),
}))

import { authGuard } from '../authGuard'

const route = (
  path: string,
  meta: Record<string, unknown> = {},
  fullPath = path,
): RouteLocationNormalized => ({ path, fullPath, meta }) as unknown as RouteLocationNormalized

describe('authGuard', () => {
  beforeEach(() => {
    state.authed = false
    state.commissioner = false
    state.checkAuth.mockReset()
    state.checkAuth.mockResolvedValue(undefined)
  })

  it('未ログインで認証必須の画面を開くと、元の画面を redirect に持たせてログイン画面へ送る（リロード時の失効）', async () => {
    const result = await authGuard(
      route('/teams/1/season', { requiresAuth: true }, '/teams/1/season?tab=roster'),
      route('/'),
    )
    expect(state.checkAuth).toHaveBeenCalledTimes(1)
    expect(result).toEqual({ path: '/login', query: { redirect: '/teams/1/season?tab=roster' } })
  })

  it('ホームを開いた未ログインは redirect 無しでログイン画面へ', async () => {
    const result = await authGuard(route('/', { requiresAuth: true }), route('/'))
    expect(result).toEqual({ path: '/login' })
  })

  it('checkAuth で認証が通れば（失効していない）そのまま通す', async () => {
    state.checkAuth.mockImplementation(async () => {
      state.authed = true
    })
    expect(await authGuard(route('/teams', { requiresAuth: true }), route('/'))).toBe(true)
  })

  it('ログイン画面は未ログインなら通し、ログイン済みならホームへ戻す', async () => {
    expect(await authGuard(route('/login'), route('/'))).toBe(true)
    state.authed = true
    expect(await authGuard(route('/login'), route('/'))).toBe('/')
    expect(state.checkAuth).not.toHaveBeenCalled()
  })

  it('ログイン済みなら認証確認を呼ばず通す', async () => {
    state.authed = true
    expect(await authGuard(route('/teams', { requiresAuth: true }), route('/players'))).toBe(true)
    expect(state.checkAuth).not.toHaveBeenCalled()
  })

  it('ログイン画面からの遷移（ログイン直後）は認証確認を必ず呼ぶ', async () => {
    state.authed = true
    await authGuard(route('/teams', { requiresAuth: true }), route('/login'))
    expect(state.checkAuth).toHaveBeenCalledTimes(1)
  })

  it('コミッショナー専用の画面は、一般ユーザーならホームへ戻す（従来どおり）', async () => {
    state.authed = true
    const result = await authGuard(
      route('/managers', { requiresAuth: true, requiresCommissioner: true }),
      route('/teams'),
    )
    expect(result).toBe('/')
  })
})
