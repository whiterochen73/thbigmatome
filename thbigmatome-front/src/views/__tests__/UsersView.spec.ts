import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import UsersView from '../commissioner/UsersView.vue'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    defaults: {
      baseURL: '',
      withCredentials: false,
      headers: { common: {} },
    },
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))

vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

describe('UsersView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(UsersView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays user list header', async () => {
    const wrapper = mount(UsersView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('ユーザー管理')
  })

  it('fetches users on mount', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [{ id: 1, name: 'admin', display_name: '管理者', role: 'commissioner' }],
    })
    mount(UsersView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/users')
  })
})
