import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  query: {} as Record<string, unknown>,
  login: vi.fn(),
}))

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
  useRoute: () => ({ query: mocks.query }),
}))
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({ login: mocks.login, loading: { value: false } }),
}))

import LoginForm from '../LoginForm.vue'
import ja from '@/locales/ja.json'

let wrapper: VueWrapper | undefined

async function submitLogin() {
  const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })
  wrapper = mount(LoginForm, { global: { plugins: [i18n] } })
  await wrapper.find('#loginName').setValue('preview')
  await wrapper.find('#password').setValue('pw')
  await wrapper.find('form').trigger('submit')
  await flushPromises()
}

describe('LoginForm のログイン後の遷移先', () => {
  beforeEach(() => {
    mocks.push.mockReset()
    mocks.login.mockReset()
    mocks.login.mockResolvedValue({})
    mocks.query = {}
  })
  afterEach(() => wrapper?.unmount())

  it('redirect が無ければホームへ', async () => {
    await submitLogin()
    expect(mocks.push).toHaveBeenCalledWith('/')
  })

  it('セッション切れで離れた元の画面（redirect）へ戻る', async () => {
    mocks.query = { redirect: '/teams/1/season?tab=roster' }
    await submitLogin()
    expect(mocks.push).toHaveBeenCalledTimes(1)
    expect(mocks.push).toHaveBeenCalledWith('/teams/1/season?tab=roster')
  })

  it.each(['https://evil.example/', '//evil.example/', '/\\evil.example/'])(
    '外部 URL（%s）を redirect に入れられてもホームへ',
    async (evil) => {
      mocks.query = { redirect: evil }
      await submitLogin()
      expect(mocks.push).toHaveBeenCalledWith('/')
    },
  )

  it('ログインに失敗した時は移動せず、エラーを表示する', async () => {
    mocks.query = { redirect: '/teams' }
    mocks.login.mockRejectedValue(new Error('ログインIDまたはパスワードが間違っています'))
    await submitLogin()
    expect(mocks.push).not.toHaveBeenCalled()
    expect(wrapper?.find('.error-message').text()).toBe(
      'ログインIDまたはパスワードが間違っています',
    )
  })
})
