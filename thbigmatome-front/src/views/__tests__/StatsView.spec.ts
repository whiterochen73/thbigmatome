import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import StatsView from '../StatsView.vue'

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

// AsyncState（読み込み・空・失敗の出し方）が文言を引く
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

describe('StatsView', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: [] })
  })

  it('renders successfully', async () => {
    const wrapper = mount(StatsView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
  })

  it('大会を選ぶまでは表を出さず、選ぶように促す（空状態）', async () => {
    const wrapper = mount(StatsView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    expect(wrapper.find('[data-testid="state-empty"]').text()).toContain('大会を選んでください')
    expect(wrapper.text()).not.toContain('打撃成績')
  })

  it('大会を選ぶと打撃・投手・チームのタブを出す', async () => {
    const wrapper = mount(StatsView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    ;(wrapper.vm as unknown as { selectedCompetitionId: number }).selectedCompetitionId = 1
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain('打撃成績')
    expect(text).toContain('投手成績')
    expect(text).toContain('チーム成績')
  })

  it('fetches stats when competition is selected', async () => {
    ;(axios.get as ReturnType<typeof vi.fn>).mockImplementation((url: string) => {
      if (url === '/competitions') return Promise.resolve({ data: [{ id: 1, name: '大会A' }] })
      if (url === '/stats/batting') return Promise.resolve({ data: { batting_stats: [] } })
      if (url === '/stats/pitching') return Promise.resolve({ data: { pitching_stats: [] } })
      if (url === '/stats/team') return Promise.resolve({ data: { team_stats: [] } })
      return Promise.resolve({ data: [] })
    })

    const wrapper = mount(StatsView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()

    // Simulate competition selection by directly calling fetchStats via exposed API
    const vm = wrapper.vm as unknown as {
      selectedCompetitionId: number
      fetchStats: () => Promise<void>
    }
    vm.selectedCompetitionId = 1
    await vm.fetchStats()
    await flushPromises()

    expect(axios.get).toHaveBeenCalledWith(
      '/stats/batting',
      expect.objectContaining({ params: { competition_id: 1 } }),
    )
    expect(axios.get).toHaveBeenCalledWith(
      '/stats/pitching',
      expect.objectContaining({ params: { competition_id: 1 } }),
    )
    expect(axios.get).toHaveBeenCalledWith(
      '/stats/team',
      expect.objectContaining({ params: { competition_id: 1 } }),
    )
  })

  it('集計画面は、アプリがダークでも明るい淡色背景に固定する（light テーマ提供の内側に置く）', async () => {
    const dark = createVuetify({
      components,
      directives,
      theme: { defaultTheme: 'dark', themes: { light: { dark: false }, dark: { dark: true } } },
    })
    const wrapper = mount(StatsView, { global: { plugins: [dark, i18n] } })
    await flushPromises()
    const surface = wrapper.find('[data-testid="stats-light-surface"]')
    expect(surface.classes()).toContain('v-card')
    expect(surface.classes()).toContain('v-theme--light')
    expect(surface.classes()).not.toContain('v-theme--dark')
    expect(wrapper.find('h1').exists()).toBe(false)
  })

  it('成績の取得に失敗した時はページ内のアラートを出し、再読み込みで取り直す', async () => {
    const wrapper = mount(StatsView, { global: { plugins: [vuetify, i18n] } })
    await flushPromises()
    ;(axios.get as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error('boom'))
    const vm = wrapper.vm as unknown as {
      selectedCompetitionId: number
      fetchStats: () => Promise<void>
    }
    vm.selectedCompetitionId = 1
    await vm.fetchStats()
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').text()).toContain('成績の取得に失敗しました')
    ;(axios.get as ReturnType<typeof vi.fn>).mockResolvedValue({ data: { batting_stats: [] } })
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
  })
})
