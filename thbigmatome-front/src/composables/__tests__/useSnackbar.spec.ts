import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { useSnackbar } from '../useSnackbar'

describe('useSnackbar', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('initial state is not visible', () => {
    const { isVisible } = useSnackbar()
    expect(isVisible.value).toBe(false)
  })

  it('showSnackbar sets isVisible to true', () => {
    const { showSnackbar, isVisible } = useSnackbar()
    showSnackbar('テストメッセージ')
    expect(isVisible.value).toBe(true)
  })

  it('showSnackbar sets the message', () => {
    const { showSnackbar, message } = useSnackbar()
    showSnackbar('保存しました')
    expect(message.value).toBe('保存しました')
  })

  it('showSnackbar sets type to success', () => {
    const { showSnackbar, color } = useSnackbar()
    showSnackbar('成功', 'success')
    expect(color.value).toBe('success')
  })

  it('showSnackbar sets type to error', () => {
    const { showSnackbar, color } = useSnackbar()
    showSnackbar('エラー発生', 'error')
    expect(color.value).toBe('error')
  })

  it('showSnackbar sets type to warning', () => {
    const { showSnackbar, color } = useSnackbar()
    showSnackbar('注意', 'warning')
    expect(color.value).toBe('warning')
  })

  it('showSnackbar defaults to info type', () => {
    const { showSnackbar, color } = useSnackbar()
    showSnackbar('情報')
    expect(color.value).toBe('info')
  })

  it('auto-hides after timeout (3000ms)', () => {
    const { showSnackbar, isVisible } = useSnackbar()
    showSnackbar('一時的なメッセージ')
    expect(isVisible.value).toBe(true)

    vi.advanceTimersByTime(2999)
    expect(isVisible.value).toBe(true)

    vi.advanceTimersByTime(1)
    expect(isVisible.value).toBe(false)
  })

  it('resets timer when showSnackbar called again', () => {
    const { showSnackbar, isVisible, message } = useSnackbar()
    showSnackbar('最初のメッセージ')

    // Advance 2 seconds
    vi.advanceTimersByTime(2000)
    expect(isVisible.value).toBe(true)

    // Show new message (should reset timer)
    showSnackbar('新しいメッセージ')
    expect(message.value).toBe('新しいメッセージ')

    // Advance 2 seconds (total 4s from first, 2s from second)
    vi.advanceTimersByTime(2000)
    expect(isVisible.value).toBe(true) // Still visible because timer was reset

    // Advance remaining 1 second to complete second timer
    vi.advanceTimersByTime(1000)
    expect(isVisible.value).toBe(false)
  })
})
