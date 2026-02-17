import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock axios before importing useAuth
vi.mock('axios', () => ({
  default: {
    post: vi.fn(),
    get: vi.fn(),
  },
}))

// Mock router before importing useAuth
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
  },
}))

import axios from 'axios'
import router from '@/router'
import { useAuth } from '../useAuth'

describe('useAuth', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('initial state has loading as false', () => {
    const { loading } = useAuth()
    expect(loading.value).toBe(false)
  })

  it('login sets user and isAuthenticated becomes true', async () => {
    const mockUser = { id: 1, name: 'testuser', role: 'director' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'ログインしました' },
    })

    const { login, isAuthenticated, user } = useAuth()
    const result = await login('testuser', 'password123')

    expect(axios.post).toHaveBeenCalledWith('auth/login', {
      name: 'testuser',
      password: 'password123',
    })
    expect(result.user).toEqual(mockUser)
    expect(user.value).toEqual(mockUser)
    expect(isAuthenticated.value).toBe(true)
  })

  it('logout clears user and isAuthenticated becomes false', async () => {
    // First login
    const mockUser = { id: 1, name: 'testuser', role: 'director' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'ログインしました' },
    })
    const { login, logout, isAuthenticated, user } = useAuth()
    await login('testuser', 'password123')
    expect(isAuthenticated.value).toBe(true)

    // Then logout
    vi.mocked(axios.post).mockResolvedValueOnce({ data: {} })
    await logout()

    expect(user.value).toBeNull()
    expect(isAuthenticated.value).toBe(false)
    expect(router.push).toHaveBeenCalledWith('/login')
  })

  it('currentUser is correctly set after login', async () => {
    const mockUser = { id: 42, name: 'commissioner_user', role: 'commissioner' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'OK' },
    })

    const { login, user } = useAuth()
    await login('commissioner_user', 'pass')

    expect(user.value).toEqual(mockUser)
    expect(user.value?.id).toBe(42)
    expect(user.value?.name).toBe('commissioner_user')
  })

  it('isCommissioner is true when role is commissioner', async () => {
    const mockUser = { id: 1, name: 'admin', role: 'commissioner' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'OK' },
    })

    const { login, isCommissioner } = useAuth()
    await login('admin', 'pass')

    expect(isCommissioner.value).toBe(true)
  })

  it('isCommissioner is false when role is not commissioner', async () => {
    const mockUser = { id: 2, name: 'normal', role: 'director' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'OK' },
    })

    const { login, isCommissioner } = useAuth()
    await login('normal', 'pass')

    expect(isCommissioner.value).toBe(false)
  })

  it('checkAuth sets user when authenticated', async () => {
    const mockUser = { id: 1, name: 'existing', role: 'director' }
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: { user: mockUser },
    })

    const { checkAuth, user } = useAuth()
    await checkAuth()

    expect(axios.get).toHaveBeenCalledWith('auth/current_user')
    expect(user.value).toEqual(mockUser)
  })

  it('checkAuth clears user when not authenticated', async () => {
    // First set a user
    const mockUser = { id: 1, name: 'temp', role: 'director' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'OK' },
    })
    const { login, checkAuth, user } = useAuth()
    await login('temp', 'pass')
    expect(user.value).not.toBeNull()

    // checkAuth fails → user cleared
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('Unauthorized'))
    await checkAuth()

    expect(user.value).toBeNull()
  })

  it('login throws error with server error message', async () => {
    vi.mocked(axios.post).mockRejectedValueOnce({
      response: { data: { error: 'ユーザー名またはパスワードが違います' } },
    })

    const { login } = useAuth()
    await expect(login('wrong', 'wrong')).rejects.toThrow('ユーザー名またはパスワードが違います')
  })

  it('login throws generic error when no server message', async () => {
    vi.mocked(axios.post).mockRejectedValueOnce({
      response: { data: {} },
    })

    const { login } = useAuth()
    await expect(login('wrong', 'wrong')).rejects.toThrow('ログインに失敗しました')
  })

  it('logout clears user even on error', async () => {
    // Login first
    const mockUser = { id: 1, name: 'user', role: 'director' }
    vi.mocked(axios.post).mockResolvedValueOnce({
      data: { user: mockUser, message: 'OK' },
    })
    const { login, logout, user } = useAuth()
    await login('user', 'pass')

    // Logout with error
    vi.mocked(axios.post).mockRejectedValueOnce(new Error('Network error'))
    await logout()

    expect(user.value).toBeNull()
  })

  it('loading is true during login and false after', async () => {
    let resolveLogin: (value: unknown) => void
    vi.mocked(axios.post).mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolveLogin = resolve
        }),
    )

    const { login, loading } = useAuth()
    expect(loading.value).toBe(false)

    const loginPromise = login('user', 'pass')
    expect(loading.value).toBe(true)

    resolveLogin!({ data: { user: { id: 1, name: 'user', role: 'director' }, message: 'OK' } })
    await loginPromise
    expect(loading.value).toBe(false)
  })
})
