import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { useSquadTextStore } from '@/stores/squadText'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

vi.mock('@/composables/useLineupTemplate', () => ({
  useLineupTemplate: () => ({
    templates: { value: [] },
    loadFromTemplate: vi.fn().mockResolvedValue(undefined),
    loadFromPrevious: vi.fn().mockResolvedValue(null),
  }),
}))

vi.mock('@/composables/useSquadTextGenerator', () => ({
  useSquadTextGenerator: () => ({
    loading: { value: false },
    generatedText: { value: '' },
    init: vi.fn().mockResolvedValue(undefined),
    saveAsGameLineup: vi.fn().mockResolvedValue(undefined),
    fetchRosterChanges: vi.fn().mockResolvedValue(undefined),
  }),
}))

import axios from 'axios'
import SquadTextGenerator from '../SquadTextGenerator.vue'

const vuetify = createVuetify({ components, directives })

const globalConfig = {
  plugins: [vuetify],
}

function makeRosterResponse(previousGameDate: string | null) {
  return {
    data: {
      season_id: 1,
      current_date: '2026-05-20',
      previous_game_date: previousGameDate,
      roster: [],
    },
  }
}

describe('SquadTextGenerator — sinceDate の自動設定', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    // lineup_templates と game_lineup もデフォルトmock
    vi.mocked(axios.get).mockResolvedValue({ data: [] })
  })

  it('previous_game_date がある場合、sinceDate が自動設定される', async () => {
    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (String(url).includes('/roster')) {
        return Promise.resolve(makeRosterResponse('2026-05-12'))
      }
      if (String(url).includes('/game_lineup')) {
        return Promise.resolve({ data: {} })
      }
      return Promise.resolve({ data: [] })
    })

    const store = useSquadTextStore()
    store.mode = 'template'

    const wrapper = mount(SquadTextGenerator, {
      props: { teamId: 1 },
      global: globalConfig,
    })

    await flushPromises()

    // date input フィールドの値を確認
    const dateInput = wrapper.find('input[type="date"]')
    expect(dateInput.exists()).toBe(true)
    expect((dateInput.element as HTMLInputElement).value).toBe('2026-05-12')
  })

  it('previous_game_date が null の場合、sinceDate は空文字のまま', async () => {
    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (String(url).includes('/roster')) {
        return Promise.resolve(makeRosterResponse(null))
      }
      if (String(url).includes('/game_lineup')) {
        return Promise.resolve({ data: {} })
      }
      return Promise.resolve({ data: [] })
    })

    const store = useSquadTextStore()
    store.mode = 'template'

    const wrapper = mount(SquadTextGenerator, {
      props: { teamId: 1 },
      global: globalConfig,
    })

    await flushPromises()

    const dateInput = wrapper.find('input[type="date"]')
    expect(dateInput.exists()).toBe(true)
    expect((dateInput.element as HTMLInputElement).value).toBe('')
  })
})
