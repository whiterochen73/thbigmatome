import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { AxiosError, type InternalAxiosRequestConfig } from 'axios'
import { createPinia, setActivePinia } from 'pinia'

// 本物の router（authGuard 込み）と本物の useAuth を使い、
// 「セッション切れの 401 でログイン画面に留まる」ことを結合で確かめる。
// 子画面は重いので差し替える（route の meta と guard だけが対象）
vi.mock('@/views/LoginForm.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/layouts/DefaultLayout.vue', () => ({ default: { template: '<router-view />' } }))
vi.mock('@/views/ManagerList.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/views/Players.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/views/CostAssignment.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/views/Settings.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/views/HomePortalView.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/views/TeamMembers.vue', () => ({ default: { template: '<div />' } }))

import axios from '@/plugins/axios'
import router from '@/router'
import { useAuth } from '@/composables/useAuth'
import { useTeamSelectionStore } from '@/stores/teamSelection'

type Reply = { status: number; data?: unknown }

// URL ごとの応答を差し込む。未登録の URL は 200 {}
let replies: Record<string, Reply>
const calls: string[] = []

const adapter = (config: InternalAxiosRequestConfig) => {
  const url = config.url ?? ''
  calls.push(url)
  const reply = replies[url] ?? { status: 200, data: {} }
  const response = {
    data: reply.data ?? {},
    status: reply.status,
    statusText: '',
    headers: {},
    config,
  }
  if (reply.status >= 400) {
    return Promise.reject(
      new AxiosError('failed', 'ERR_BAD_REQUEST', config, undefined, response as never),
    )
  }
  return Promise.resolve(response as never)
}

const commissioner = { id: 1, name: 'preview', role: 'commissioner' }

describe('セッション切れ（401）でログイン画面へ戻す', () => {
  beforeEach(async () => {
    setActivePinia(createPinia())
    calls.length = 0
    replies = {
      'auth/login': { status: 200, data: { user: commissioner, message: 'ok' } },
      'auth/current_user': { status: 200, data: { user: commissioner } },
      '/users/me/teams': { status: 200, data: [] },
      '/teams': { status: 200, data: [] },
    }
    axios.defaults.adapter = adapter as never
    vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    // ログイン済みの状態から始める
    await useAuth().login('preview', 'pw')
    await router.push('/teams')
    await router.isReady()
  })

  afterEach(async () => {
    replies['auth/current_user'] = { status: 401 }
    await router.push('/login').catch(() => {})
    vi.restoreAllMocks()
  })

  it('ログイン済みで /teams にいる前提が成立している', () => {
    expect(router.currentRoute.value.path).toBe('/teams')
    expect(useAuth().isAuthenticated.value).toBe(true)
  })

  it('API が 401 を返すと認証状態が消え、ログイン画面へ移り、元の画面を redirect に持つ', async () => {
    replies['/teams/1/members'] = { status: 401 }
    replies['auth/current_user'] = { status: 401 }

    await axios.get('/teams/1/members').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    expect(useAuth().isAuthenticated.value).toBe(false)
    expect(router.currentRoute.value.query.redirect).toBe('/teams')
  })

  it('401 で前のユーザーのチーム一覧も消える（次にログインする人へ残さない）', async () => {
    const store = useTeamSelectionStore()
    expect(store.teamsLoaded).toBe(true)
    replies['/a'] = { status: 401 }
    replies['auth/current_user'] = { status: 401 }

    await axios.get('/a').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    expect(store.teamsLoaded).toBe(false)
  })

  it('クエリ付きの画面も fullPath で redirect に残る', async () => {
    await router.push('/teams?tab=roster')
    replies['/teams/1/members'] = { status: 401 }
    replies['auth/current_user'] = { status: 401 }

    await axios.get('/teams/1/members').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    expect(router.currentRoute.value.query.redirect).toBe('/teams?tab=roster')
  })

  it('同時に複数の API が 401 になっても、ログイン画面への移動は 1 回', async () => {
    replies['/a'] = { status: 401 }
    replies['/b'] = { status: 401 }
    replies['/c'] = { status: 401 }
    replies['auth/current_user'] = { status: 401 }
    const push = vi.spyOn(router, 'push')

    await Promise.all(
      [axios.get('/a'), axios.get('/b'), axios.get('/c')].map((p) => p.catch(() => {})),
    )
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    expect(push).toHaveBeenCalledTimes(1)
    expect(router.currentRoute.value.query.redirect).toBe('/teams')
  })

  it('ログイン画面にいる時の 401 では移動しない', async () => {
    replies['auth/current_user'] = { status: 401 }
    replies['/a'] = { status: 401 }
    await axios.get('/a').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    const push = vi.spyOn(router, 'push')
    await axios.get('/a').catch(() => {})
    await new Promise((r) => setTimeout(r, 20))

    expect(push).not.toHaveBeenCalled()
    expect(router.currentRoute.value.path).toBe('/login')
    expect(router.currentRoute.value.query.redirect).toBe('/teams')
  })

  it('ログイン API 自体の 401（パスワード違い）では移動せず、認証状態も触らない', async () => {
    replies['auth/login'] = {
      status: 401,
      data: { error: 'ログインIDまたはパスワードが間違っています' },
    }
    const push = vi.spyOn(router, 'push')

    await expect(useAuth().login('preview', 'bad')).rejects.toThrow(
      'ログインIDまたはパスワードが間違っています',
    )
    await new Promise((r) => setTimeout(r, 20))

    expect(push).not.toHaveBeenCalled()
    expect(router.currentRoute.value.path).toBe('/teams')
    expect(useAuth().isAuthenticated.value).toBe(true)
  })

  it('認証確認（auth/current_user）の 401 では interceptor は移動しない', async () => {
    replies['auth/current_user'] = { status: 401 }
    const push = vi.spyOn(router, 'push')

    await useAuth().checkAuth()
    await new Promise((r) => setTimeout(r, 20))

    expect(push).not.toHaveBeenCalled()
  })

  it('401 の後に再ログインすると redirect の画面へ戻れる', async () => {
    replies['/a'] = { status: 401 }
    replies['auth/current_user'] = { status: 401 }
    await axios.get('/a').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    replies['auth/current_user'] = { status: 200, data: { user: commissioner } }
    await useAuth().login('preview', 'pw')
    const redirect = router.currentRoute.value.query.redirect
    await router.push(typeof redirect === 'string' ? redirect : '/')

    expect(router.currentRoute.value.path).toBe('/teams')
  })

  it('401 の後にもう一度 401 が来る（再ログイン後の失効）と、また 1 回だけ移動できる', async () => {
    replies['/a'] = { status: 401 }
    replies['auth/current_user'] = { status: 401 }
    await axios.get('/a').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))

    replies['auth/current_user'] = { status: 200, data: { user: commissioner } }
    await useAuth().login('preview', 'pw')
    await router.push('/players')
    replies['auth/current_user'] = { status: 401 }

    await axios.get('/a').catch(() => {})
    await vi.waitFor(() => expect(router.currentRoute.value.path).toBe('/login'))
    expect(router.currentRoute.value.query.redirect).toBe('/players')
  })
})
