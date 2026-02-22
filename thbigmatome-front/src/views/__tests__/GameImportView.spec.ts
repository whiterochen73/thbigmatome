import { describe, it, expect, vi, beforeEach } from 'vitest'
import { ref } from 'vue'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import GameImportView from '../GameImportView.vue'

vi.mock('axios', () => {
  const mockAxios = {
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
  }
  return { default: mockAxios }
})

vi.mock('@/plugins/axios', () => ({ default: {} }))
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({ showSnackbar: vi.fn() }),
}))

const mockUser = ref<{ id: number; name: string; role: string } | null>({
  id: 1,
  name: 'テストユーザー',
  role: 'player',
})
const mockIsCommissioner = ref(false)
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    user: mockUser,
    isCommissioner: mockIsCommissioner,
  }),
}))

import axios from 'axios'
const mockedAxios = vi.mocked(axios)

const vuetify = createVuetify({ components, directives })

const mockCompetitions = [
  { id: 1, name: 'テストリーグ', year: 2024, competition_type: 'league_pennant', entry_count: 4 },
  { id: 2, name: 'テスト大会', year: 2024, competition_type: 'tournament', entry_count: 8 },
]

const mockTeams = [
  { id: 10, name: '自チーム', short_name: '自', user_id: 1, is_active: true },
  { id: 20, name: '相手チーム', short_name: '相手', user_id: 2, is_active: true },
]

describe('GameImportView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockUser.value = { id: 1, name: 'テストユーザー', role: 'player' }
    mockIsCommissioner.value = false
    mockedAxios.get = vi
      .fn()
      .mockResolvedValueOnce({ data: mockCompetitions })
      .mockResolvedValueOnce({ data: mockTeams })
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

  it('shows error message when master data fetch fails on mount', async () => {
    mockedAxios.get = vi.fn().mockRejectedValue(new Error('Network Error'))
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('データの取得に失敗しました')
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

  it('does not show mode toggle for non-commissioner users', async () => {
    mockIsCommissioner.value = false
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).not.toContain('コミッショナーモード')
  })

  it('shows mode toggle for commissioner users', async () => {
    mockIsCommissioner.value = true
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('コミッショナーモード')
    expect(wrapper.text()).toContain('プレイヤーモード')
  })

  it('fetches teams for league_pennant competition by default', async () => {
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(mockedAxios.get).toHaveBeenCalledWith('/competitions')
    expect(mockedAxios.get).toHaveBeenCalledWith('/competitions/1/teams')
    expect(wrapper.exists()).toBe(true)
  })

  it('shows my team error when user has no matching team', async () => {
    const teamsWithoutMyTeam = [
      { id: 20, name: '相手チーム', short_name: '相手', user_id: 2, is_active: true },
    ]
    mockedAxios.get = vi
      .fn()
      .mockResolvedValueOnce({ data: mockCompetitions })
      .mockResolvedValueOnce({ data: teamsWithoutMyTeam })
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('あなたのチームが見つかりません')
  })
})
