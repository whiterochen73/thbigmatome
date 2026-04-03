import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import LineupTemplateEditor from '../LineupTemplateEditor.vue'

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

import axios from 'axios'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      lineupTemplate: {
        title: '打順テンプレート',
        patterns: {
          dhRight: 'DH有・対右',
          dhLeft: 'DH有・対左',
          noDhRight: 'DH無・対右',
          noDhLeft: 'DH無・対左',
        },
        battingOrder: '打順',
        position: 'ポジション',
        player: '選手',
        save: '保存',
        delete: '削除',
        saved: '保存しました',
        deleted: '削除しました',
        saveError: '保存に失敗しました',
        deleteError: '削除に失敗しました',
        noFirstSquad: '1軍メンバーなし',
        confirmDelete: '削除しますか？',
      },
    },
  },
})

const mockTemplates = [
  {
    id: 1,
    dh_enabled: true,
    opponent_pitcher_hand: 'right',
    entries: [
      {
        id: 10,
        batting_order: 1,
        player_id: 100,
        position: 'RF',
        player_name: '霊夢',
        player_number: '01',
      },
      {
        id: 11,
        batting_order: 2,
        player_id: 101,
        position: '3B',
        player_name: '魔理沙',
        player_number: '02',
      },
    ],
  },
]

const mockRoster = [
  {
    team_membership_id: 1,
    player_id: 100,
    number: '01',
    player_name: '霊夢',
    squad: 'first',
    cost: 10,
    selected_cost_type: 'normal',
    position: 'RF',
    throwing_hand: 'R',
    batting_hand: 'R',
    player_types: [],
  },
  {
    team_membership_id: 2,
    player_id: 101,
    number: '02',
    player_name: '魔理沙',
    squad: 'first',
    cost: 10,
    selected_cost_type: 'normal',
    position: '3B',
    throwing_hand: 'R',
    batting_hand: 'R',
    player_types: [],
  },
  {
    team_membership_id: 3,
    player_id: 102,
    number: '03',
    player_name: 'アリス',
    squad: 'second',
    cost: 8,
    selected_cost_type: 'normal',
    position: 'LF',
    throwing_hand: 'R',
    batting_hand: 'L',
    player_types: [],
  },
]

function mountEditor() {
  return mount(LineupTemplateEditor, {
    props: { teamId: 1 },
    global: {
      plugins: [vuetify, i18n],
      stubs: { transition: false },
    },
  })
}

describe('LineupTemplateEditor.vue', () => {
  beforeEach(() => {
    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (url.includes('lineup_templates')) return Promise.resolve({ data: mockTemplates })
      if (url.includes('roster')) return Promise.resolve({ data: mockRoster })
      return Promise.resolve({ data: [] })
    })
    vi.mocked(axios.post).mockResolvedValue({
      data: { id: 2, dh_enabled: true, opponent_pitcher_hand: 'left', entries: [] },
    })
    vi.mocked(axios.put).mockResolvedValue({ data: mockTemplates[0] })
    vi.mocked(axios.delete).mockResolvedValue({})
  })

  it('4パターンタブが表示される', async () => {
    const wrapper = mountEditor()
    await flushPromises()

    const tabs = wrapper.findAll('.v-tab')
    expect(tabs.length).toBe(4)
    expect(tabs[0].text()).toContain('DH有')
    expect(tabs[1].text()).toContain('DH有')
    expect(tabs[2].text()).toContain('DH無')
    expect(tabs[3].text()).toContain('DH無')
  })

  it('マウント時にAPIが呼ばれる', async () => {
    mountEditor()
    await flushPromises()

    expect(axios.get).toHaveBeenCalledWith('/teams/1/lineup_templates')
    expect(axios.get).toHaveBeenCalledWith('/teams/1/roster')
  })

  it('打順リストが9行表示される', async () => {
    const wrapper = mountEditor()
    await flushPromises()

    const rows = wrapper.find('tbody').findAll('tr')
    expect(rows.length).toBe(9)
  })

  it('保存ボタンが存在する', async () => {
    const wrapper = mountEditor()
    await flushPromises()

    const saveBtn = wrapper.find('button[type="button"]')
    expect(saveBtn.exists()).toBe(true)
  })

  it('テンプレートが存在する場合は削除ボタンが表示される', async () => {
    const wrapper = mountEditor()
    await flushPromises()

    // DH有・対右のパターン1はテンプレートが存在する
    const buttons = wrapper.findAll('.v-btn')
    const buttonTexts = buttons.map((b) => b.text())
    expect(buttonTexts.some((t) => t.includes('削除'))).toBe(true)
  })

  it('テンプレートが存在しないパターンでは削除ボタンが非表示', async () => {
    const wrapper = mountEditor()
    await flushPromises()

    // DH有・対左タブに切替（テンプレートなし）
    const tabs = wrapper.findAll('.v-tab')
    await tabs[1].trigger('click')
    await flushPromises()

    const buttons = wrapper.findAll('.v-btn')
    const buttonTexts = buttons.map((b) => b.text())
    expect(buttonTexts.some((t) => t === '削除')).toBe(false)
  })
})
