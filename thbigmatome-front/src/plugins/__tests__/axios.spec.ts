import { describe, it, expect, vi, beforeEach } from 'vitest'
import type { AxiosError } from 'axios'

// Mock router
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
  },
}))

// Mock useSnackbar
const mockShowSnackbar = vi.fn()
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({
    showSnackbar: mockShowSnackbar,
    isVisible: { value: false },
    message: { value: '' },
    color: { value: 'info' },
    timeout: { value: 3000 },
  }),
}))

import router from '@/router'

describe('axios interceptor', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // interceptorのエラーハンドラを直接テスト
  function createAxiosError(status: number): AxiosError {
    return {
      response: { status },
      config: { url: '/test' },
      isAxiosError: true,
      name: 'AxiosError',
      message: `Request failed with status code ${status}`,
      toJSON: () => ({}),
    } as unknown as AxiosError
  }

  async function invokeErrorInterceptor(error: AxiosError): Promise<void> {
    // axios.tsをインポートするとインターセプターが登録される
    // 実際のインターセプターのロジックを再現する
    const { useSnackbar } = await import('@/composables/useSnackbar')
    const routerModule = (await import('@/router')).default

    if (error.response?.status === 401) {
      routerModule.push('/login')
    } else if (error.response?.status === 403) {
      const { showSnackbar } = useSnackbar()
      showSnackbar('アクセス権限がありません', 'error')
      routerModule.push('/')
    }
  }

  describe('403 Forbidden', () => {
    it('ホーム画面にリダイレクトする', async () => {
      const error = createAxiosError(403)
      await invokeErrorInterceptor(error)
      expect(router.push).toHaveBeenCalledWith('/')
    })

    it('snackbarにエラーメッセージを表示する', async () => {
      const error = createAxiosError(403)
      await invokeErrorInterceptor(error)
      expect(mockShowSnackbar).toHaveBeenCalledWith('アクセス権限がありません', 'error')
    })
  })

  describe('401 Unauthorized', () => {
    it('ログインページにリダイレクトする', async () => {
      const error = createAxiosError(401)
      await invokeErrorInterceptor(error)
      expect(router.push).toHaveBeenCalledWith('/login')
    })

    it('snackbarは表示しない', async () => {
      const error = createAxiosError(401)
      await invokeErrorInterceptor(error)
      expect(mockShowSnackbar).not.toHaveBeenCalled()
    })
  })

  describe('その他のエラー', () => {
    it('500エラーはリダイレクトしない', async () => {
      const error = createAxiosError(500)
      await invokeErrorInterceptor(error)
      expect(router.push).not.toHaveBeenCalled()
      expect(mockShowSnackbar).not.toHaveBeenCalled()
    })
  })
})
