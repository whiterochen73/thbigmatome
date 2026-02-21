import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import CompetitionsView from '../commissioner/CompetitionsView.vue'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
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

describe('CompetitionsView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(CompetitionsView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays competition list header', async () => {
    const wrapper = mount(CompetitionsView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('大会管理')
  })

  it('fetches competitions on mount', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [
        { id: 1, name: '春季大会', year: 2026, competition_type: 'tournament', entry_count: 8 },
      ],
    })
    mount(CompetitionsView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/competitions')
  })
})
