import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { nextTick } from 'vue'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createWebHistory } from 'vue-router'
import PitcherStatusTab from '../PitcherStatusTab.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: { template: '<div />' } },
    { path: '/player-cards/:id', name: 'PlayerCardDetail', component: { template: '<div />' } },
  ],
})

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'

const vuetify = createVuetify({ components, directives })

const mockPitchers = [
  {
    player_id: 1,
    player_name: '霊夢',
    last_role: 'starter',
    rest_days: 6,
    cumulative_innings: null,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'full',
    as_starter: { status: 'full', notes: [] },
    as_reliever: { status: 'full', notes: [] },
    as_opener: null,
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
    as_opener_omitted_reason: 'no_opener_ability',
  },
  {
    player_id: 2,
    player_name: '魔理沙',
    last_role: 'starter',
    rest_days: 3,
    cumulative_innings: null,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'injury_check',
    as_starter: { status: 'injury_check', notes: [] },
    as_reliever: { status: 'reduced_0', notes: [] },
    as_opener: null,
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
    as_opener_omitted_reason: 'no_opener_ability',
  },
  {
    player_id: 3,
    player_name: 'チルノ',
    last_role: 'reliever',
    rest_days: 1,
    cumulative_innings: 2,
    is_injured: false,
    is_unavailable: false,
    projected_status: 'fatigued_start',
    as_starter: { status: 'unavailable', notes: [] },
    as_reliever: { status: 'fatigued_start', notes: [] },
    // オープナー可（アビリティあり）の投手だけ「オープナーなら」を持つ
    as_opener: {
      status: 'fatigued_start',
      notes: ['opener_check_consecutive', 'opener_check_cumulative'],
    },
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
    as_opener_omitted_reason: null,
  },
  {
    player_id: 4,
    player_name: '妖夢',
    last_role: 'reliever',
    rest_days: null,
    cumulative_innings: 0,
    is_injured: true,
    is_unavailable: false,
    projected_status: 'injured',
    as_starter: { status: 'injured', notes: [] },
    as_reliever: { status: 'injured', notes: [] },
    as_opener: null,
    as_starter_omitted_reason: null,
    as_reliever_omitted_reason: null,
    as_opener_omitted_reason: 'no_opener_ability',
  },
]

const mountComponent = (props = {}) =>
  mount(PitcherStatusTab, {
    props: {
      teamId: 1,
      scheduleDate: '2026-03-22',
      competitionId: null,
      ...props,
    },
    global: {
      plugins: [vuetify, router],
    },
  })

describe('PitcherStatusTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    localStorage.clear()
    vi.mocked(axios.get).mockResolvedValue({ data: mockPitchers })
  })

  it('コンポーネントがマウントされること', () => {
    const wrapper = mountComponent()
    expect(wrapper.exists()).toBe(true)
  })

  it('APIから投手状態を取得してロードすること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(axios.get).toHaveBeenCalledWith('/teams/1/pitcher_game_states/fatigue_summary', {
      params: { date: '2026-03-22' },
    })
    expect(wrapper.text()).toContain('霊夢')
    expect(wrapper.text()).toContain('魔理沙')
  })

  it('先発投手セクションとリリーフ投手セクションが表示されること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).toContain('先発投手')
    expect(wrapper.text()).toContain('リリーフ投手')
  })

  it('先発投手が中日数降順でデフォルトソートされること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    // 霊夢(中6日)が魔理沙(中3日)より先に来る
    const text = wrapper.text()
    const reimuIdx = text.indexOf('霊夢')
    const marisaIdx = text.indexOf('魔理沙')
    expect(reimuIdx).toBeLessThan(marisaIdx)
  })

  it('ステータスバッジが正しく表示されること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).toContain('✅ 全快')
    expect(wrapper.text()).toContain('⚠️ 負傷CK')
    expect(wrapper.text()).toContain('⚡ P0')
    expect(wrapper.text()).toContain('🏥 負傷中')
  })

  // cmd_1775 第3段 E10: 投手ごとに「先発なら」「リリーフなら」の 2 つを並べて出す
  it('「先発なら」「リリーフなら」の列見出しが先発・リリーフ両方の表に出る', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    for (const table of wrapper.findAll('table')) {
      expect(table.text()).toContain('先発なら')
      expect(table.text()).toContain('リリーフなら')
    }
  })

  it('投手ごとに 2 つの状態を出す（魔理沙: 先発なら 負傷CK / リリーフなら P0）', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.find('[data-testid="as-starter-2"]').text()).toContain('⚠️ 負傷CK')
    expect(wrapper.find('[data-testid="as-reliever-2"]').text()).toContain('⚡ P0')
  })

  it('最初から疲労状態は疲労P0 と別のバッジで出る（チルノ: 累積2）', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const cell = wrapper.find('[data-testid="as-reliever-3"]')
    expect(cell.text()).toContain('🔥 最初から疲労')
    expect(cell.text()).not.toContain('⚡ P0')
    // オープナーの負傷チェックの理由は「リリーフなら」ではなく「オープナーなら」列に出る
    expect(cell.text()).not.toContain('オープナー')
    expect(cell.text()).not.toContain('負傷チェック')
  })

  // Operator 2026-10-27: 「リリーフなら」の隣に「オープナーなら」列を 1 つ増やす（先発・リリーフ両方の表）
  it('「オープナーなら」列見出しが先発・リリーフ両方の表に 1 つずつ、「リリーフなら」の次に出る', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const tables = wrapper.findAll('table')
    expect(tables).toHaveLength(2)
    for (const table of tables) {
      const headers = table.findAll('th').map((th) => th.text())
      expect(headers.filter((h) => h === 'オープナーなら')).toHaveLength(1)
      expect(headers.indexOf('オープナーなら')).toBe(headers.indexOf('リリーフなら') + 1)
    }
  })

  it('オープナー可の投手（チルノ）には状態と負傷チェックの理由を出す', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    const cell = wrapper.find('[data-testid="as-opener-3"]')
    expect(cell.text()).toContain('🔥 最初から疲労')
    expect(cell.text()).toContain('中2日以内の連続オープナー登板のため負傷チェック')
    expect(cell.text()).toContain('累積1以上のため負傷チェック')
  })

  it('オープナー可でない投手は「—」だけでバッジを出さない', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    for (const id of [1, 2, 4]) {
      const cell = wrapper.find(`[data-testid="as-opener-${id}"]`)
      expect(cell.text()).toBe('—')
      expect(cell.findComponent({ name: 'VChip' }).exists()).toBe(false)
    }
  })

  // Operator 2026-10-27: オープナー可のデータが未取込の間は、リリーフ可能な投手すべてに出す。その旨を見出しのツールチップで伝える
  describe('「オープナーなら」列: フォールバック中の注記', () => {
    const withSource = (source: string | undefined) =>
      mockPitchers.map((p) => ({ ...p, opener_capable_source: source }))
    const NOTICE = 'オープナー可のデータ未取込のため、リリーフ可能な投手すべてに表示'

    it('フォールバック中（fallback_all_relievers）は、見出しのツールチップで未取込を伝える（先発・リリーフ両方の表）', async () => {
      vi.mocked(axios.get).mockResolvedValue({ data: withSource('fallback_all_relievers') })
      const wrapper = mountComponent()
      await flushPromises()
      const heads = wrapper.findAll('[data-testid="opener-column-header"]')
      expect(heads).toHaveLength(2)
      for (const head of heads) {
        expect(head.attributes('title')).toBe(NOTICE)
        expect(head.text()).toBe('オープナーなら')
      }
    })

    it('カードの記載どおり（card_ability）に切り替わったらツールチップを出さない', async () => {
      vi.mocked(axios.get).mockResolvedValue({ data: withSource('card_ability') })
      const wrapper = mountComponent()
      await flushPromises()
      for (const head of wrapper.findAll('[data-testid="opener-column-header"]')) {
        expect(head.attributes('title')).toBeUndefined()
      }
    })

    it('opener_capable_source が無い応答（旧 API）でもツールチップを出さない', async () => {
      vi.mocked(axios.get).mockResolvedValue({ data: withSource(undefined) })
      const wrapper = mountComponent()
      await flushPromises()
      for (const head of wrapper.findAll('[data-testid="opener-column-header"]')) {
        expect(head.attributes('title')).toBeUndefined()
      }
    })
  })

  // Operator 2026-10-27: 累積イニングは単位を付けない。列見出しは「累積」（「累積IP」ではない）
  it('累積の列見出しは「累積」で、「IP」の単位を付けない（先発・リリーフ両方の表）', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    for (const table of wrapper.findAll('table')) {
      const headers = table.findAll('th').map((th) => th.text())
      expect(headers).toContain('累積')
      expect(table.text()).not.toContain('IP')
    }
  })

  it('前回リリーフの中1日は「先発なら」が不可', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.find('[data-testid="as-starter-3"]').text()).toContain('🚫 不可')
  })

  it('省略された「先発なら」「リリーフなら」は「—」だけでバッジを出さない', async () => {
    vi.mocked(axios.get).mockResolvedValue({
      data: [
        {
          ...mockPitchers[0],
          as_starter: null,
          as_starter_omitted_reason: 'relief_only_contract',
          as_reliever: null,
          as_reliever_omitted_reason: 'no_relief_stamina',
        },
      ],
    })
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.find('[data-testid="as-starter-1"]').text()).toBe('—')
    expect(wrapper.find('[data-testid="as-reliever-1"]').text()).toBe('—')
    expect(wrapper.find('[data-testid="as-opener-1"]').text()).toBe('—')
    expect(
      wrapper.find('[data-testid="as-starter-1"]').findComponent({ name: 'VChip' }).exists(),
    ).toBe(false)
  })

  it('先発投手の累積は"-"が表示されること', async () => {
    const wrapper = mountComponent()
    await flushPromises()
    // starters table: 累積列は"-"
    const starterSection = wrapper.findAll('v-table, table').at(0)
    expect(starterSection?.text()).toContain('-')
  })

  it('APIエラー時にエラーメッセージが表示されること', async () => {
    vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))
    const wrapper = mountComponent()
    await flushPromises()
    expect(wrapper.text()).toContain('投手状態の取得に失敗しました')
  })

  it('localStorageに保存した並び順が復元されること', async () => {
    // 逆順を保存 (魔理沙→霊夢)
    localStorage.setItem(
      'pitcher_status_order_1',
      JSON.stringify({ starters: [2, 1], relievers: [] }),
    )
    const wrapper = mountComponent()
    await flushPromises()
    const text = wrapper.text()
    const reimuIdx = text.indexOf('霊夢')
    const marisaIdx = text.indexOf('魔理沙')
    expect(marisaIdx).toBeLessThan(reimuIdx)
  })

  it('ローディング中はスピナーが表示されること', async () => {
    vi.mocked(axios.get).mockReturnValue(new Promise(() => {}))
    const wrapper = mountComponent()
    await nextTick()
    expect(wrapper.find('[data-testid="loading-spinner"]').exists()).toBe(true)
  })

  it('teamIdが変わると再フェッチすること', async () => {
    const wrapper = mountComponent({ teamId: 1 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(1)
    await wrapper.setProps({ teamId: 2 })
    await flushPromises()
    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(axios.get).toHaveBeenLastCalledWith('/teams/2/pitcher_game_states/fatigue_summary', {
      params: { date: '2026-03-22' },
    })
  })
})
