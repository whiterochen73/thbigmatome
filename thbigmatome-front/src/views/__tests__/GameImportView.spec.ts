import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import GameImportView from '../GameImportView.vue'

vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
    isAxiosError: vi.fn().mockReturnValue(false),
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
vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    user: { id: 1, name: 'テストユーザー', role: 'player' },
    isCommissioner: false,
  }),
}))

import axios from 'axios'
const mockedAxios = vi.mocked(axios)

const vuetify = createVuetify({ components, directives })

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div/>' } },
      { path: '/game-records/:id', component: { template: '<div/>' } },
    ],
  })
}

const mockCompetitions = [
  { id: 1, name: 'テストリーグ', year: 2024, competition_type: 'league_pennant', entry_count: 4 },
  { id: 2, name: 'テスト大会', year: 2024, competition_type: 'tournament', entry_count: 8 },
]

const mockTeams = [
  { id: 10, name: '自チーム', short_name: '自', user_id: 1, is_active: true },
  { id: 20, name: '相手チーム', short_name: '相手', user_id: 2, is_active: true },
]

const mockParseResponse = {
  pregame_info: {
    venue: 'テスト球場',
    home_team: 'ホームチーム',
    visitor_team: 'ビジターチーム',
    home_starter: '先発A',
    visitor_starter: '先発B',
    rain_canceled: false,
    home_lineup: [],
    visitor_lineup: [],
    home_bench: [],
    visitor_bench: [],
    injury_check_result: null,
  },
  parsed_at_bats: { at_bats: [], innings: 9 },
  at_bat_count: 27,
}

describe('GameImportView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockedAxios.get = vi
      .fn()
      .mockResolvedValueOnce({ data: mockCompetitions })
      .mockResolvedValueOnce({ data: mockTeams })
  })

  it('mounts successfully', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays import form header', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('IRCログ取り込み')
  })

  it('Step 1 shows only log textarea and analyze button', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('Step 1')
    expect(wrapper.text()).toContain('ログ入力')
    const btn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    expect(btn).toBeTruthy()
  })

  it('shows error message when master data fetch fails on mount', async () => {
    mockedAxios.get = vi.fn().mockRejectedValue(new Error('Network Error'))
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(wrapper.text()).toContain('データの取得に失敗しました')
  })

  it('analyze button calls parse_log API', async () => {
    mockedAxios.post = vi.fn().mockResolvedValue({ data: mockParseResponse })
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()

    const textarea = wrapper.find('textarea')
    await textarea.setValue('テストIRCログ')

    const btn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    expect(btn).toBeTruthy()
    await btn!.trigger('click')
    await flushPromises()

    expect(mockedAxios.post).toHaveBeenCalledWith('/games/parse_log', { log: 'テストIRCログ' })
  })

  it('after analyze, advances to Step 2 with pregame info', async () => {
    mockedAxios.post = vi.fn().mockResolvedValue({ data: mockParseResponse })
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()

    const textarea = wrapper.find('textarea')
    await textarea.setValue('テストIRCログ')

    const btn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    await btn!.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('Step 2')
    expect(wrapper.text()).toContain('自動検出情報')
  })

  it('Step 2 import button calls import_log API', async () => {
    mockedAxios.post = vi
      .fn()
      .mockResolvedValueOnce({ data: mockParseResponse })
      .mockResolvedValueOnce({
        data: {
          game: { id: 42, status: 'draft' },
          at_bat_count: 27,
          imported_count: 0,
        },
      })
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()

    const textarea = wrapper.find('textarea')
    await textarea.setValue('テストIRCログ')

    const analyzeBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    await analyzeBtn!.trigger('click')
    await flushPromises()

    // Set required form values directly to enable the import button
    const vm = wrapper.vm as unknown as {
      formData: { competition_id: number; home_team_id: number; visitor_team_id: number }
    }
    vm.formData.competition_id = 1
    vm.formData.home_team_id = 10
    vm.formData.visitor_team_id = 20
    await wrapper.vm.$nextTick()

    // Step 2 import button
    const importBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('インポート'))
    expect(importBtn).toBeTruthy()
    await importBtn!.trigger('click')
    await flushPromises()

    expect(mockedAxios.post).toHaveBeenCalledWith(
      '/games/import_log',
      expect.objectContaining({ log: 'テストIRCログ' }),
    )
  })

  it('fetches competitions on mount', async () => {
    const router = createTestRouter()
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()
    expect(mockedAxios.get).toHaveBeenCalledWith('/competitions')
    expect(wrapper.exists()).toBe(true)
  })

  it('redirects to game-records when game_record_id is present', async () => {
    mockedAxios.post = vi
      .fn()
      .mockResolvedValueOnce({ data: mockParseResponse })
      .mockResolvedValueOnce({
        data: {
          game: { id: 42, status: 'imported' },
          at_bat_count: 27,
          imported_count: 27,
          game_record_id: 99,
        },
      })
    const router = createTestRouter()
    const pushSpy = vi.spyOn(router, 'push').mockResolvedValue(undefined)
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
    await flushPromises()

    const textarea = wrapper.find('textarea')
    await textarea.setValue('テストIRCログ')
    const analyzeBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    await analyzeBtn!.trigger('click')
    await flushPromises()

    const vm = wrapper.vm as unknown as {
      formData: { competition_id: number; home_team_id: number; visitor_team_id: number }
    }
    vm.formData.competition_id = 1
    vm.formData.home_team_id = 10
    vm.formData.visitor_team_id = 20
    await wrapper.vm.$nextTick()

    const importBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('インポート'))
    await importBtn!.trigger('click')
    await flushPromises()

    expect(pushSpy).toHaveBeenCalledWith('/game-records/99')
  })

  describe('Step 3: fallback (no game_record_id)', () => {
    const mockImportResponse = {
      game: { id: 42, status: 'draft' },
      at_bat_count: 3,
      imported_count: 3,
      // no game_record_id → goes to Step 3 fallback
    }

    async function mountToStep3() {
      mockedAxios.post = vi
        .fn()
        .mockResolvedValueOnce({ data: mockParseResponse })
        .mockResolvedValueOnce({ data: mockImportResponse })
      const router = createTestRouter()
      const wrapper = mount(GameImportView, { global: { plugins: [vuetify, router] } })
      await flushPromises()

      const textarea = wrapper.find('textarea')
      await textarea.setValue('テストIRCログ')
      const analyzeBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
      await analyzeBtn!.trigger('click')
      await flushPromises()

      const vm = wrapper.vm as unknown as {
        formData: { competition_id: number; home_team_id: number; visitor_team_id: number }
      }
      vm.formData.competition_id = 1
      vm.formData.home_team_id = 10
      vm.formData.visitor_team_id = 20
      await wrapper.vm.$nextTick()

      const importBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('インポート'))
      await importBtn!.trigger('click')
      await flushPromises()

      return wrapper
    }

    it('shows Step 3 fallback after import without game_record_id', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('Step 3')
      expect(wrapper.text()).toContain('インポート完了')
    })

    it('shows game id and at_bat_count in Step 3 fallback', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('試合ID: 42')
      expect(wrapper.text()).toContain('打席数: 3件')
    })

    it('shows reset button in Step 3 fallback', async () => {
      const wrapper = await mountToStep3()
      const resetBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('やり直し'))
      expect(resetBtn).toBeTruthy()
    })

    it('reset button returns to Step 1', async () => {
      const wrapper = await mountToStep3()
      const resetBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('やり直し'))
      await resetBtn!.trigger('click')
      await wrapper.vm.$nextTick()
      expect(wrapper.text()).toContain('Step 1')
      expect(wrapper.text()).toContain('ログ入力')
    })
  })
})
