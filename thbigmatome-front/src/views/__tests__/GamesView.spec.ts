import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GamesView from '../GamesView.vue'

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

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

describe('GamesView', () => {
  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b3-13
  it('全ての確定・下書きチップに状態色と flat とアイコンを付ける', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [
        { id: 1, real_date: '2026-01-01', status: 'confirmed' },
        { id: 2, real_date: '2026-01-02', status: 'draft' },
      ],
    })
    const wrapper = mount(GamesView, { global: { plugins: [vuetify] } })
    await flushPromises()
    for (const [status, color, icon] of [
      ['confirmed', 'state-done', 'mdi-check-circle'],
      ['draft', 'state-todo', 'mdi-circle-outline'],
    ]) {
      const matching = wrapper
        .findAllComponents(components.VChip)
        .filter((chip) => chip.text() === status)
      expect(matching.length, status).toBeGreaterThan(0)
      for (const chip of matching) {
        expect(chip.props('color')).toBe(color)
        expect(chip.props('variant')).toBe('flat')
        expect(chip.props('prependIcon')).toBe(icon)
      }
    }
  })
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('mounts successfully', async () => {
    const wrapper = mount(GamesView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays games list header', async () => {
    const wrapper = mount(GamesView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('試合記録')
  })

  it('fetches games on mount', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: [
        {
          id: 1,
          competition_id: 1,
          home_team_id: 2,
          visitor_team_id: 3,
          real_date: '2026-01-01',
          status: 'confirmed',
          source: 'manual',
        },
      ],
    })
    mount(GamesView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/games', expect.objectContaining({ params: {} }))
  })
})
