import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import CompetitionRosterView from '../CompetitionRosterView.vue'

// Mock axios
vi.mock('axios', () => {
  const mockAxios = {
    get: vi.fn(),
    post: vi.fn(),
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

vi.mock('@/plugins/axios', () => {
  return { default: {} }
})

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/competitions/:id/roster/:teamId',
        name: 'CompetitionRoster',
        component: { template: '<div />' },
      },
    ],
  })
}

const mockRosterPlayers = [
  {
    player_card_id: 1,
    player_name: '博麗霊夢',
    squad: 'first_squad',
    is_reliever: false,
    cost: 8,
  },
  {
    player_card_id: 2,
    player_name: '霧雨魔理沙',
    squad: 'second_squad',
    is_reliever: true,
    cost: 6,
  },
]

const mockCostCheckOk = {
  valid: true,
  errors: [],
  current_total_cost: 14,
  total_limit: 200,
  first_squad_cost: 8,
  first_squad_limit: 100,
  first_squad_count: 1,
}

const mockCostCheckError = {
  valid: false,
  errors: ['1軍コストが上限を超えています', '全体コストが上限200を超えています'],
  current_total_cost: 210,
  total_limit: 200,
  first_squad_cost: 150,
  first_squad_limit: 100,
  first_squad_count: 5,
}

function setupDefaultMocks(costCheck = mockCostCheckOk) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url.includes('/roster/cost_check')) {
      return Promise.resolve({ data: costCheck })
    }
    if (url.includes('/roster')) {
      return Promise.resolve({
        data: {
          first_squad: [mockRosterPlayers[0]],
          second_squad: [mockRosterPlayers[1]],
        },
      })
    }
    if (url.includes('/competitions/')) {
      return Promise.resolve({ data: { id: 1, name: 'テスト大会' } })
    }
    return Promise.resolve({ data: [] })
  })
}

async function mountView(costCheck = mockCostCheckOk) {
  setupDefaultMocks(costCheck)
  const router = createTestRouter()
  router.push('/competitions/1/roster/10')
  await router.isReady()
  const wrapper = mount(CompetitionRosterView, {
    global: {
      plugins: [vuetify, router],
    },
  })
  await flushPromises()
  return wrapper
}

describe('CompetitionRosterView.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b6-2〜b6-3, b6-7〜b6-15
  it('両軍タブと追加・除外ボタンの役割色を props で示す', async () => {
    const wrapper = await mountView()
    const tabs = wrapper.findAllComponents(components.VTabs)
    expect(tabs).toHaveLength(2)
    tabs.forEach((tab) => expect(tab.props('color')).toBe('link'))
    for (const squad of ['first_squad', 'second_squad']) {
      wrapper.vm.activeTab = squad
      await flushPromises()
      const buttons = wrapper.findAllComponents(components.VBtn)
      const add = buttons.filter((button) => button.text().includes('選手追加'))
      expect(add.length, squad).toBeGreaterThan(0)
      add.forEach((button) => expect(button.props('color')).toBe('link'))
      const remove = buttons.filter((button) => button.attributes('data-testid') === 'remove-btn')
      expect(remove.length, squad).toBeGreaterThan(0)
      remove.forEach((button) => {
        expect(button.props('color')).toBe('danger-ink')
        expect(button.props('variant')).toBe('outlined')
        expect(button.props('prependIcon')).toBe('mdi-delete-outline')
      })
    }
  })

  it('コンポーネントがマウントできる', async () => {
    const wrapper = await mountView()
    expect(wrapper.exists()).toBe(true)
  })

  it('1軍・2軍タブが存在する', async () => {
    const wrapper = await mountView()
    const text = wrapper.text()
    expect(text).toContain('1軍')
    expect(text).toContain('2軍')
  })

  it('GET /roster のAPIモック → 選手一覧が表示される', async () => {
    const wrapper = await mountView()
    const text = wrapper.text()
    expect(text).toContain('博麗霊夢')
    expect(vi.mocked(axios.get)).toHaveBeenCalledWith(
      expect.stringContaining('/roster'),
      expect.objectContaining({ params: expect.objectContaining({ team_id: expect.any(String) }) }),
    )
  })

  it('コスト超過時のエラー表示（v-alert が表示）', async () => {
    const wrapper = await mountView(mockCostCheckError)
    const alert = wrapper.find('[data-testid="cost-error-alert"]')
    expect(alert.exists()).toBe(true)
    expect(wrapper.text()).toContain('コストが上限を超えています')
  })

  it('除外ボタンクリック → DELETE API が呼ばれる', async () => {
    vi.mocked(axios.delete).mockResolvedValue({ data: {} })
    const wrapper = await mountView()

    const removeBtns = wrapper.findAll('[data-testid="remove-btn"]')
    expect(removeBtns.length).toBeGreaterThan(0)
    await removeBtns[0].trigger('click')
    await flushPromises()

    expect(vi.mocked(axios.delete)).toHaveBeenCalledWith(
      expect.stringContaining('/roster/players/'),
    )
  })
})
