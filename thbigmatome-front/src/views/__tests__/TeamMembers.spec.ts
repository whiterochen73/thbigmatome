import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import TeamMembers from '../TeamMembers.vue'

// Mock axios (via @/plugins/axios) — factory must not reference outer variables (hoisting)
vi.mock('@/plugins/axios', () => {
  return {
    default: {
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
    },
  }
})

// Mock useSnackbar
vi.mock('@/composables/useSnackbar', () => ({
  useSnackbar: () => ({
    showSnackbar: vi.fn(),
  }),
}))

import axios from '@/plugins/axios'

// Stub child components
const CostListSelectStub = {
  template: '<div class="cost-list-select-stub"><slot /></div>',
  props: ['modelValue', 'label'],
  emits: ['update:modelValue'],
}
const TeamNavigationStub = {
  template: '<div class="team-nav-stub" />',
  props: ['teamId'],
}

const vuetify = createVuetify({ components, directives })

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: {
    ja: {
      teamMembers: {
        title: 'チーム「{teamName}」の選手登録',
        selectCostList: 'コスト一覧表を選択',
        selectPlayer: '選手を選択して追加',
        addPlayer: '追加',
        noData: '選手が登録されていません。',
        headers: {
          number: '背番号',
          name: '名前',
          position: 'ポジション',
          throws: '投',
          bats: '打',
          player_types: '選手タイプ',
          cost: 'コスト',
          excluded: '除外',
          actions: '操作',
        },
        teamMembersTitle: 'チームメンバー',
        totalCount: '合計人数: {count} / {max}人',
        totalCost: '合計コスト: {cost} / {max}',
        outsideWorldCount: '外の世界枠: {count} / {max}人',
        costTypes: {
          normal_cost: '通常',
          relief_only_cost: 'リリーフ契約',
          pitcher_only_cost: '投手専念',
          fielder_only_cost: '野手専念',
          two_way_cost: '二刀流',
        },
        notifications: {
          fetchTeamFailed: 'チーム情報の取得に失敗しました。',
          fetchPlayersFailed: '選手一覧の取得に失敗しました。',
          fetchTeamPlayersFailed: 'チームの選手一覧の取得に失敗しました。',
          fetchPlayerTypesFailed: '選手タイプの取得に失敗しました。',
          playerAlreadyAdded: 'この選手は既に追加されています。',
          maxPlayersExceeded: '登録人数が上限（{max}人）を超えています。',
          costLimitExceeded: '合計コスト（{cost}）がコスト上限（{limit}）を超えています。',
          selectCostList: 'コスト一覧表を選択してください。',
          saveSuccess: '選手情報を保存しました。',
          saveFailed: '選手情報の保存に失敗しました。',
        },
      },
      baseball: {
        positions: {
          pitcher: '投手',
          catcher: '捕手',
          infielder: '内野手',
          outfielder: '外野手',
        },
        throwingHands: {
          right_throw: '右',
          left_throw: '左',
        },
        battingHands: {
          right_bat: '右',
          left_bat: '左',
          switch_hitter: '両',
        },
      },
      actions: {
        save: '保存',
        cancel: 'キャンセル',
      },
    },
  },
})

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/teams/:teamId/members',
        name: 'TeamMembers',
        component: { template: '<div />' },
      },
      {
        path: '/menu',
        name: 'Menu',
        component: { template: '<div />' },
      },
    ],
  })
}

function makeTeamPlayer(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    name: 'テスト選手',
    short_name: 'テスト',
    number: '10',
    position: 'pitcher',
    throwing_hand: 'right_throw',
    batting_hand: 'right_bat',
    player_type_ids: [],
    cost_players: [
      {
        id: 1,
        cost_id: 100,
        player_id: 1,
        normal_cost: 5,
        relief_only_cost: null,
        pitcher_only_cost: null,
        fielder_only_cost: null,
        two_way_cost: null,
      },
    ],
    selected_cost_type: 'normal_cost',
    current_cost: 5,
    excluded_from_team_total: false,
    ...overrides,
  }
}

function setupDefaultMocks(teamPlayers: Record<string, unknown>[] = []) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url.includes('/teams/') && url.endsWith('/team_players')) {
      return Promise.resolve({ data: teamPlayers })
    }
    if (url.match(/\/teams\/\d+$/)) {
      return Promise.resolve({
        data: { id: 1, name: '紅魔館', short_name: 'KMK', is_active: true, has_season: true },
      })
    }
    if (url === '/team_registration_players') {
      return Promise.resolve({ data: [] })
    }
    if (url === '/player-types') {
      return Promise.resolve({
        data: [
          { id: 1, name: '東方キャラ', description: null, category: 'touhou' },
          { id: 2, name: '二刀流', description: null, category: 'cost_regulation' },
        ],
      })
    }
    return Promise.resolve({ data: {} })
  })
}

async function mountTeamMembers(teamPlayers: Record<string, unknown>[] = []) {
  setupDefaultMocks(teamPlayers)
  const router = createTestRouter()
  router.push('/teams/1/members')
  await router.isReady()
  const wrapper = mount(TeamMembers, {
    global: {
      plugins: [vuetify, i18n, router],
      stubs: {
        CostListSelect: CostListSelectStub,
        TeamNavigation: TeamNavigationStub,
      },
    },
  })
  await flushPromises()
  return wrapper
}

describe('TeamMembers.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('チームメンバー一覧のタイトルが表示される', async () => {
    const wrapper = await mountTeamMembers()

    expect(wrapper.text()).toContain('チームメンバー')
  })

  it('チーム名がタイトルに表示される', async () => {
    const wrapper = await mountTeamMembers()

    // Team name fetched from API should be in the title
    expect(wrapper.text()).toContain('紅魔館')
  })

  it('選手がいない場合にnoDataメッセージが表示される', async () => {
    const wrapper = await mountTeamMembers([])

    expect(wrapper.text()).toContain('選手が登録されていません')
  })

  it('合計人数が表示される', async () => {
    const players = [
      makeTeamPlayer({ id: 1, name: '選手A', number: '1' }),
      makeTeamPlayer({ id: 2, name: '選手B', number: '2' }),
    ]
    // Simulate that CostListSelect triggers a watch by manually rendering with data
    setupDefaultMocks(players)
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: {
          CostListSelect: {
            template:
              '<div class="cost-list-select-stub" @click="$emit(\'update:modelValue\', {id: 100, name: \'コスト表1\'})" />',
            props: ['modelValue', 'label'],
            emits: ['update:modelValue'],
          },
          TeamNavigation: TeamNavigationStub,
        },
      },
    })
    await flushPromises()

    // Trigger cost list selection to load team players
    const costListStub = wrapper.find('.cost-list-select-stub')
    await costListStub.trigger('click')
    await flushPromises()

    // Should display total count (合計人数: 2 / 50人)
    expect(wrapper.text()).toContain('合計人数')
    expect(wrapper.text()).toContain('50')
  })

  it('合計コストが表示される', async () => {
    const players = [
      makeTeamPlayer({
        id: 1,
        name: '選手A',
        cost_players: [
          {
            id: 1,
            cost_id: 100,
            player_id: 1,
            normal_cost: 8,
            relief_only_cost: null,
            pitcher_only_cost: null,
            fielder_only_cost: null,
            two_way_cost: null,
          },
        ],
      }),
      makeTeamPlayer({
        id: 2,
        name: '選手B',
        cost_players: [
          {
            id: 2,
            cost_id: 100,
            player_id: 2,
            normal_cost: 12,
            relief_only_cost: null,
            pitcher_only_cost: null,
            fielder_only_cost: null,
            two_way_cost: null,
          },
        ],
      }),
    ]
    setupDefaultMocks(players)
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: {
          CostListSelect: {
            template:
              '<div class="cost-list-select-stub" @click="$emit(\'update:modelValue\', {id: 100, name: \'コスト表1\'})" />',
            props: ['modelValue', 'label'],
            emits: ['update:modelValue'],
          },
          TeamNavigation: TeamNavigationStub,
        },
      },
    })
    await flushPromises()

    // Trigger cost list selection
    await wrapper.find('.cost-list-select-stub').trigger('click')
    await flushPromises()

    // Should display total cost and max (合計コスト: X / 200)
    expect(wrapper.text()).toContain('合計コスト')
    expect(wrapper.text()).toContain('200')
  })

  it('excluded_from_team_totalチェックボックスが存在する', async () => {
    const players = [makeTeamPlayer({ id: 1, name: '選手A' })]
    setupDefaultMocks(players)
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: {
          CostListSelect: {
            template:
              '<div class="cost-list-select-stub" @click="$emit(\'update:modelValue\', {id: 100, name: \'コスト表1\'})" />',
            props: ['modelValue', 'label'],
            emits: ['update:modelValue'],
          },
          TeamNavigation: TeamNavigationStub,
        },
      },
    })
    await flushPromises()

    // Trigger cost list selection to load players
    await wrapper.find('.cost-list-select-stub').trigger('click')
    await flushPromises()

    // The "除外" header should exist
    expect(wrapper.text()).toContain('除外')

    // Checkbox should exist in the table
    const checkboxes = wrapper.findAll('.v-checkbox')
    expect(checkboxes.length).toBeGreaterThanOrEqual(1)
  })

  it('コスト選択ドロップダウンのヘッダーが表示される', async () => {
    const wrapper = await mountTeamMembers()

    // Cost column header should be present
    expect(wrapper.text()).toContain('コスト')
  })

  it('保存ボタンが存在する', async () => {
    const wrapper = await mountTeamMembers()

    const saveBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('保存'))
    expect(saveBtn).toBeTruthy()
  })
})
