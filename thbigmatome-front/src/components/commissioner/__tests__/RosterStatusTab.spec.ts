import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import RosterStatusTab from '../RosterStatusTab.vue'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    defaults: {
      baseURL: 'http://localhost:3000/api/v1',
      withCredentials: false,
      headers: { common: {} },
    },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { asyncState: ja.asyncState } },
})

const mockRosterStatus = [
  {
    team_id: 1,
    team_name: '紅魔館',
    team_type: 'normal',
    first_count: 27,
    second_count: 8,
    first_cost: 178,
    first_cost_limit: 190,
    outside_world_count: 3,
    outside_world_limit: 4,
    warnings: [],
  },
  {
    team_id: 2,
    team_name: '白玉楼',
    team_type: 'hachinai',
    first_count: 25,
    second_count: 10,
    first_cost: 195,
    first_cost_limit: 190,
    outside_world_count: 5,
    outside_world_limit: 4,
    warnings: ['コスト超過', '外枠超過'],
  },
]

const mountComponent = () =>
  mount(RosterStatusTab, {
    global: {
      plugins: [i18n, vuetify],
    },
  })

describe('RosterStatusTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('マウント時にroster_status APIが呼ばれる', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    mountComponent()
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/commissioner/dashboard/roster_status')
  })

  it('全チームCSV出力ボタンが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    const wrapper = mountComponent()
    await flushPromises()
    const btn = wrapper.find('a[href*="roster_status.csv"]')
    expect(btn.exists()).toBe(true)
    expect(btn.attributes('href')).not.toContain('team_id')
  })

  it('全チームCSVのhrefにbaseURLが含まれる', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    const wrapper = mountComponent()
    await flushPromises()
    const btn = wrapper.find('a[href*="roster_status.csv"]')
    expect(btn.attributes('href')).toContain('http://localhost:3000/api/v1')
  })

  it('警告ありチームに警告チップが表示される', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: mockRosterStatus })
    const wrapper = mountComponent()
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain('警告あり')
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b5-8〜b5-13
  it('展開した一軍・二軍チップと外の世界の印を役割色で示す', async () => {
    vi.mocked(axios.get).mockImplementation((url: string) =>
      Promise.resolve({
        data: url.includes('/teams/')
          ? [
              { player_name: '投手A', squad: 'first', is_outside_world: true },
              { player_name: '野手B', squad: 'second', is_outside_world: false },
            ]
          : mockRosterStatus,
      }),
    )
    const wrapper = mountComponent()
    await flushPromises()
    wrapper.vm.expanded = [2]
    await flushPromises()
    const chips = wrapper.findAllComponents(components.VChip)
    const first = chips.filter((chip) => chip.text() === '1軍')
    const second = chips.filter((chip) => chip.text() === '2軍')
    expect(first).toHaveLength(1)
    expect(second).toHaveLength(1)
    expect(first[0]!.props('color')).toBe('zone-game')
    expect(first[0]!.props('prependIcon')).toBe('mdi-numeric-1-box-outline')
    expect(second[0]!.props('color')).toBe('state-neutral')
    expect(second[0]!.props('prependIcon')).toBe('mdi-numeric-2-box-outline')
    for (const chip of [...first, ...second]) expect(chip.props('variant')).toBe('flat')
    expect(wrapper.find('.on-state-info.mdi-earth').exists()).toBe(true)
  })

  it('APIエラー時にクラッシュしない', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('network error'))
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.exists()).toBe(true)
    // 失敗は空状態ではなくページ内のアラート＋再読み込みで出す
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
  })

  it('0 件なら空状態を出し、読み込み中は空状態を出さない', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({ data: [] })
    const wrapper = mountComponent()
    expect(wrapper.find('[data-testid="state-loading"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(false)
    await flushPromises()
    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(true)
  })
})
