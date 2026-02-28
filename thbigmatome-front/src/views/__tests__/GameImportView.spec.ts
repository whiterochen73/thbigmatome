import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
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
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('displays import form header', async () => {
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('IRCログ取り込み')
  })

  it('Step 1 shows only log textarea and analyze button', async () => {
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('Step 1')
    expect(wrapper.text()).toContain('ログ入力')
    const btn = wrapper.findAll('.v-btn').find((b) => b.text().includes('解析する'))
    expect(btn).toBeTruthy()
  })

  it('shows error message when master data fetch fails on mount', async () => {
    mockedAxios.get = vi.fn().mockRejectedValue(new Error('Network Error'))
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(wrapper.text()).toContain('データの取得に失敗しました')
  })

  it('analyze button calls parse_log API', async () => {
    mockedAxios.post = vi.fn().mockResolvedValue({ data: mockParseResponse })
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
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
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
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
          parsed_at_bats: { at_bats: [], innings: 9 },
          at_bat_count: 27,
          imported_count: 0,
        },
      })
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
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
    const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
    await flushPromises()
    expect(mockedAxios.get).toHaveBeenCalledWith('/competitions')
    expect(wrapper.exists()).toBe(true)
  })

  describe('Step 3: preview features', () => {
    const mockAtBats = [
      {
        inning: 1,
        top_bottom: 'top',
        order: 1,
        batter: '打者A',
        pitcher: '投手X',
        result_code: 'H7',
        runners_before: [],
        outs_after: 0,
        runners_after: [1],
        score: null,
        runs_scored: 1,
        wild_pitch: false,
        wild_pitch_type: null,
        events: [],
      },
      {
        inning: 1,
        top_bottom: 'bottom',
        order: 1,
        batter: '打者B',
        pitcher: '投手Y',
        result_code: 'K',
        runners_before: [],
        outs_after: 1,
        runners_after: [],
        score: null,
        runs_scored: 0,
        wild_pitch: false,
        wild_pitch_type: null,
        events: [{ type: 'pitcher_change', speaker: 'GM', text: '投手交代' }],
      },
      {
        inning: 2,
        top_bottom: 'bottom',
        order: 1,
        batter: '打者C',
        pitcher: '投手Z',
        result_code: 'BB',
        runners_before: [],
        outs_after: 0,
        runners_after: [1],
        score: null,
        runs_scored: 2,
        wild_pitch: true,
        wild_pitch_type: '3-19',
        events: [],
      },
    ]

    const mockImportResponse = {
      game: { id: 42, status: 'draft' },
      parsed_at_bats: { at_bats: mockAtBats, innings: 4 },
      at_bat_count: 3,
      imported_count: 3,
    }

    async function mountToStep3() {
      mockedAxios.post = vi
        .fn()
        .mockResolvedValueOnce({ data: mockParseResponse })
        .mockResolvedValueOnce({ data: mockImportResponse })
      const wrapper = mount(GameImportView, { global: { plugins: [vuetify] } })
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

    it('shows Step 3 preview after import', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('Step 3')
      expect(wrapper.text()).toContain('解析結果プレビュー')
    })

    it('shows line score section', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('ラインスコア')
      expect(wrapper.text()).toContain('ビジター')
      expect(wrapper.text()).toContain('ホーム')
    })

    it('shows pitcher summary section', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('投手サマリー')
      expect(wrapper.text()).toContain('投手X')
      expect(wrapper.text()).toContain('投手Y')
      expect(wrapper.text()).toContain('投手Z')
    })

    it('shows at-bat list', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('打席一覧')
      expect(wrapper.text()).toContain('打者A')
      expect(wrapper.text()).toContain('打者B')
    })

    it('pitcher summary shows starter chip for first pitcher', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('先発')
    })

    it('shows confirm and reset buttons in Step 3', async () => {
      const wrapper = await mountToStep3()
      expect(wrapper.text()).toContain('確定してDB保存')
      expect(wrapper.text()).toContain('やり直し')
    })

    it('wild_pitch event is shown in editable events', async () => {
      const wrapper = await mountToStep3()
      // 暴投がある at-bat (index 2) の editableEvents に wild_pitch が含まれること
      const vm = wrapper.vm as unknown as {
        editableEvents: Map<number, Array<{ type: string; text: string }>>
      }
      const evs2 = vm.editableEvents.get(2) ?? []
      expect(evs2.some((e) => e.type === 'wild_pitch')).toBe(true)
    })
  })
})
