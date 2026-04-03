import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import PasswordChangeForm from '../PasswordChangeForm.vue'

vi.mock('@/plugins/axios', () => {
  return {
    default: {
      get: vi.fn(),
      post: vi.fn(),
      defaults: {
        baseURL: '',
        withCredentials: false,
        headers: { common: {} },
      },
      interceptors: {
        request: { use: vi.fn() },
        response: { use: vi.fn() },
      },
    },
  }
})

const mockShowSnackbar = vi.fn()
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: mockShowSnackbar }),
}))

import axios from '@/plugins/axios'

const vuetify = createVuetify({ components, directives })

type FormVm = {
  currentPassword: string
  newPassword: string
  confirmPassword: string
  serverError: string
  callChangePassword: () => Promise<void>
}

describe('PasswordChangeForm', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('マウントに成功する', async () => {
    const wrapper = mount(PasswordChangeForm, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('"パスワード変更"タイトルが表示される', async () => {
    const wrapper = mount(PasswordChangeForm, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('パスワード変更')
  })

  it('3つのパスワードフィールドが表示される', async () => {
    const wrapper = mount(PasswordChangeForm, { global: { plugins: [vuetify] } })
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain('現在のパスワード')
    expect(text).toContain('新しいパスワード')
    expect(text).toContain('確認用パスワード')
  })

  it('送信成功時にsnackbarが表示される', async () => {
    ;(axios.post as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: { message: 'パスワードを変更しました' },
    })

    const wrapper = mount(PasswordChangeForm, { global: { plugins: [vuetify] } })
    await flushPromises()

    const vm = wrapper.vm as unknown as FormVm
    vm.currentPassword = 'currentpass'
    vm.newPassword = 'newpass789'
    vm.confirmPassword = 'newpass789'
    await vm.callChangePassword()
    await flushPromises()

    expect(axios.post).toHaveBeenCalledWith('/users/change_password', {
      current_password: 'currentpass',
      password: 'newpass789',
      password_confirmation: 'newpass789',
    })
    expect(mockShowSnackbar).toHaveBeenCalledWith('パスワードを変更しました', 'success')
  })

  it('current_password誤り時にserverErrorがセットされる', async () => {
    ;(axios.post as ReturnType<typeof vi.fn>).mockRejectedValue({
      response: { data: { error: '現在のパスワードが正しくありません' } },
    })

    const wrapper = mount(PasswordChangeForm, { global: { plugins: [vuetify] } })
    await flushPromises()

    const vm = wrapper.vm as unknown as FormVm
    vm.currentPassword = 'wrongpass'
    vm.newPassword = 'newpass789'
    vm.confirmPassword = 'newpass789'
    await vm.callChangePassword()
    await flushPromises()

    expect(vm.serverError).toBe('現在のパスワードが正しくありません')
  })
})
