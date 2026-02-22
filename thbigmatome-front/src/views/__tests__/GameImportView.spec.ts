import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GameImportView from '../GameImportView.vue'

vi.mock('axios')
vi.mock('@/plugins/axios', () => ({ default: {} }))
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))

import axios from 'axios'
const mockedAxios = vi.mocked(axios)

const vuetify = createVuetify({ components, directives })

describe('GameImportView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockedAxios.get = vi.fn().mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays import form header', async () => {
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('IRCログ取り込み')
  })

  it('parse button triggers import_log API', async () => {
    mockedAxios.post = vi.fn().mockResolvedValue({
      data: {
        game: { id: 42, status: 'draft' },
        parsed_at_bats: { at_bats: [], innings: 9 },
        at_bat_count: 27,
      },
    })
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()

    const textarea = wrapper.find('textarea')
    await textarea.setValue('テストIRCログ')

    const btn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    expect(btn).toBeTruthy()
    await btn!.trigger('click')
    await flushPromises()

    expect(mockedAxios.post).toHaveBeenCalledWith(
      '/games/import_log',
      expect.objectContaining({ log: 'テストIRCログ' }),
    )
  })
})
