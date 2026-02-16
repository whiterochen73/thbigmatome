import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import ActiveRoster from '../ActiveRoster.vue'
import type { RosterPlayer } from '@/types/rosterPlayer'

// Mock axios
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

vi.mock('@/plugins/axios', () => {
  return { default: {} }
})

import axios from 'axios'

// Stub child components
const AbsenceInfoStub = {
  template: '<div class="absence-info-stub" />',
  props: ['seasonId', 'currentDate'],
}
const PromotionCooldownInfoStub = {
  template: '<div class="cooldown-info-stub" />',
  props: ['cooldownPlayers', 'currentDate'],
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
      activeRoster: {
        title: '出場選手登録',
        firstSquad: '1軍',
        secondSquad: '2軍',
        firstSquadCount: '1軍人数',
        firstSquadCost: '1軍コスト',
        saveRoster: '選手登録を保存',
        costLimitExceeded: '1軍コスト（{cost}）が上限（{limit}）を超えています。',
        belowMinimumPlayers: '1軍登録人数が最低人数（{min}人）に達していません。',
        outsideWorldCount: '外の世界枠: {count}/{max}',
        outsideWorldLimitExceeded:
          '1軍の外の世界枠の選手が上限（{limit}人）を超えています（現在{count}人）。',
        keyPlayerSelection: '特例選手選択',
        selectKeyPlayer: '特例選手を選択',
        selectKeyPlayerHint: '特例選手のヒント',
        saveKeyPlayer: '特例選手を保存',
        keyPlayerLocked: '特例選手（抹消不可）',
        promoteButton: '昇格',
        demoteButton: '降格',
        reconditioningBlocked: '再調整中のため1軍登録不可',
        absenceEndingSoon: '離脱終了間近の選手',
        remainingDays: '残り{days}日',
        cooldownTooltip: '{date}まで昇格不可',
        absenceDaysTooltip: '離脱中（{type}: {reason}残り{days}日）',
        absenceGamesTooltip: '離脱中（{type}: {reason}残り{days}日相当）',
        saveSuccess: '選手登録を保存しました。',
        saveFailed: '選手登録の保存に失敗しました。',
        keyPlayerSaveSuccess: '特例選手を保存しました。',
        keyPlayerSaveFailed: '特例選手の保存に失敗しました。',
        headers: {
          number: '背番',
          name: '名前',
          position: '位置',
          player_types: '属性',
          throws: '投',
          bats: '打',
          cost_type: '契約',
          cost: 'コスト',
          actions: '',
        },
        chip: {
          reconditioning: '再調整中',
          cooldown: '昇格待ち',
          special: '特例',
        },
        legend: {
          cooldown: '昇格待ち',
          injury: '負傷離脱',
          suspension: '出場停止',
          reconditioning: '再調整',
        },
        absenceWarning: {
          title: '離脱中選手の昇格確認',
          message: '{name}は現在離脱中です（{type}: {remaining}）。1軍に登録しますか？',
          remaining: '残り{days}日',
          unknownEnd: '終了日未定',
        },
      },
      seasonPortal: {
        currentDate: '現在の日付',
      },
      baseball: {
        shortPositions: {
          pitcher: '投',
          catcher: '捕',
          infielder: '内',
          outfielder: '外',
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
        construction: {
          normal_cost: '通常',
          relief_only_cost: '中継',
          pitcher_only_cost: '投手',
          fielder_only_cost: '野手',
          two_way_cost: '２Ｗ',
        },
      },
      enums: {
        player_absence: {
          absence_type: {
            injury: '負傷',
            suspension: '出場停止',
            reconditioning: '再調整',
          },
        },
      },
      actions: {
        cancel: 'キャンセル',
        ok: 'OK',
      },
    },
  },
})

// Helper: create a basic roster player
function makePlayer(overrides: Partial<RosterPlayer> = {}): RosterPlayer {
  return {
    team_membership_id: 1,
    player_id: 101,
    number: '1',
    player_name: 'テスト選手',
    squad: 'first',
    cost: 5,
    selected_cost_type: 'normal_cost',
    position: 'pitcher',
    throwing_hand: 'right_throw',
    batting_hand: 'right_bat',
    player_types: ['投手'],
    ...overrides,
  }
}

function createTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/teams/:teamId/roster',
        name: 'ActiveRoster',
        component: { template: '<div />' },
      },
    ],
  })
}

function setupRosterResponse(roster: RosterPlayer[], extra: Record<string, unknown> = {}) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (typeof url === 'string' && url.includes('/roster')) {
      return Promise.resolve({
        data: {
          roster,
          season_id: 1,
          current_date: '2026-06-15',
          season_start_date: '2026-04-01',
          key_player_id: null,
          ...extra,
        },
      })
    }
    return Promise.resolve({ data: {} })
  })
}

async function mountActiveRoster(roster: RosterPlayer[], extra: Record<string, unknown> = {}) {
  setupRosterResponse(roster, extra)
  const router = createTestRouter()
  router.push('/teams/1/roster')
  await router.isReady()
  const wrapper = mount(ActiveRoster, {
    global: {
      plugins: [vuetify, i18n, router],
      stubs: {
        AbsenceInfo: AbsenceInfoStub,
        PromotionCooldownInfo: PromotionCooldownInfoStub,
        TeamNavigation: TeamNavigationStub,
      },
    },
  })
  await flushPromises()
  return wrapper
}

describe('ActiveRoster.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('テーブル描画', () => {
    it('1軍テーブルが正しく描画される', async () => {
      const players = [
        makePlayer({ team_membership_id: 1, player_name: '博麗霊夢', squad: 'first' }),
        makePlayer({ team_membership_id: 2, player_name: '霧雨魔理沙', squad: 'first' }),
      ]
      const wrapper = await mountActiveRoster(players)

      expect(wrapper.text()).toContain('1軍')
      expect(wrapper.text()).toContain('博麗霊夢')
      expect(wrapper.text()).toContain('霧雨魔理沙')
    })

    it('2軍テーブルが正しく描画される', async () => {
      const players = [
        makePlayer({ team_membership_id: 3, player_name: '十六夜咲夜', squad: 'second' }),
      ]
      const wrapper = await mountActiveRoster(players)

      expect(wrapper.text()).toContain('2軍')
      expect(wrapper.text()).toContain('十六夜咲夜')
    })

    it('選手情報（名前、背番号、コスト等）が表示される', async () => {
      const players = [
        makePlayer({
          team_membership_id: 1,
          player_name: 'レミリア',
          number: '99',
          cost: 8,
          squad: 'first',
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      expect(wrapper.text()).toContain('レミリア')
      expect(wrapper.text()).toContain('99')
      expect(wrapper.text()).toContain('8')
    })
  })

  describe('ステータスチップ表示条件', () => {
    it('特例選手 → 鍵マーク+deep-purpleチップ', async () => {
      const players = [
        makePlayer({ team_membership_id: 10, player_name: '特例選手A', squad: 'first' }),
      ]
      const wrapper = await mountActiveRoster(players, { key_player_id: 10 })

      // Key player chip should exist
      const chips = wrapper.findAll('.v-chip')
      const specialChip = chips.find((c) => c.text().includes('特例'))
      expect(specialChip).toBeTruthy()

      // Star icon on player name
      const starIcons = wrapper.findAll('.mdi-star')
      expect(starIcons.length).toBeGreaterThanOrEqual(1)
    })

    it('再調整中 → 再調整チップが表示される（2軍側）', async () => {
      const players = [
        makePlayer({
          team_membership_id: 5,
          player_name: '再調整選手',
          squad: 'second',
          is_absent: true,
          absence_info: {
            absence_type: 'reconditioning',
            reason: null,
            effective_end_date: null,
            remaining_days: null,
            duration_unit: 'days',
          },
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      const chips = wrapper.findAll('.v-chip')
      const reconChip = chips.find((c) => c.text().includes('再調整中'))
      expect(reconChip).toBeTruthy()

      // No promote button for reconditioning players
      const promoteButtons = wrapper.findAll('.promote-btn')
      expect(promoteButtons.length).toBe(0)
    })

    it('昇格クールダウン → 砂時計+黄色チップ（2軍側）', async () => {
      const players = [
        makePlayer({
          team_membership_id: 6,
          player_name: 'クールダウン選手',
          squad: 'second',
          cooldown_until: '2026-12-31',
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      const chips = wrapper.findAll('.v-chip')
      const cooldownChip = chips.find((c) => c.text().includes('昇格待ち'))
      expect(cooldownChip).toBeTruthy()
    })

    it('負傷中 → 降格ボタンが有効（1軍側）', async () => {
      const players = [
        makePlayer({
          team_membership_id: 7,
          player_name: '負傷選手',
          squad: 'first',
          is_absent: true,
          absence_info: {
            absence_type: 'injury',
            reason: '骨折',
            effective_end_date: '2026-07-01',
            remaining_days: 10,
            duration_unit: 'days',
          },
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      // Demote button should exist (for injured player in 1st squad)
      const demoteButtons = wrapper.findAll('.demote-btn')
      expect(demoteButtons.length).toBe(1)
    })

    it('出場停止 → 昇格ボタンが有効（2軍側）', async () => {
      const players = [
        makePlayer({
          team_membership_id: 8,
          player_name: '出場停止選手',
          squad: 'second',
          is_absent: true,
          absence_info: {
            absence_type: 'suspension',
            reason: '乱闘',
            effective_end_date: '2026-07-15',
            remaining_days: 5,
            duration_unit: 'days',
          },
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      // Promote button should exist for suspended player
      const promoteButtons = wrapper.findAll('.promote-btn')
      expect(promoteButtons.length).toBe(1)
    })
  })

  describe('枠・上限表示', () => {
    it('外の世界枠カウント表示（X/4）', async () => {
      const players = [
        makePlayer({
          team_membership_id: 1,
          squad: 'first',
          is_outside_world: true,
        }),
        makePlayer({
          team_membership_id: 2,
          squad: 'first',
          is_outside_world: true,
        }),
        makePlayer({
          team_membership_id: 3,
          squad: 'first',
          is_outside_world: false,
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      // Should show "外の世界枠: 2/4"
      expect(wrapper.text()).toContain('2/4')
    })

    it('コスト上限表示（現在/上限）', async () => {
      // 28+ players → cost limit 120
      const players = Array.from({ length: 28 }, (_, i) =>
        makePlayer({
          team_membership_id: i + 1,
          player_name: `選手${i + 1}`,
          squad: 'first',
          cost: 4,
        }),
      )
      const wrapper = await mountActiveRoster(players)

      // Total cost = 28 * 4 = 112, limit = 120
      expect(wrapper.text()).toContain('112')
      expect(wrapper.text()).toContain('120')
    })

    it('上限超過時の警告表示', async () => {
      // 28 players each with cost 5 → total 140 > 120 limit
      const players = Array.from({ length: 28 }, (_, i) =>
        makePlayer({
          team_membership_id: i + 1,
          player_name: `選手${i + 1}`,
          squad: 'first',
          cost: 5,
        }),
      )
      const wrapper = await mountActiveRoster(players)

      // Warning alert should appear
      const alerts = wrapper.findAll('.v-alert')
      const warningAlert = alerts.find(
        (a) => a.text().includes('上限') && a.text().includes('超え'),
      )
      expect(warningAlert).toBeTruthy()
    })
  })

  describe('ボタン動作', () => {
    it('降格ボタンクリックで選手が2軍に移動する', async () => {
      const players = [
        makePlayer({
          team_membership_id: 1,
          player_name: '降格対象選手',
          squad: 'first',
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      const demoteBtn = wrapper.find('.demote-btn')
      expect(demoteBtn.exists()).toBe(true)
      await demoteBtn.trigger('click')
      await flushPromises()

      // After demotion, the player should appear in 2nd squad section
      // The promote button should now appear instead
      const promoteButtons = wrapper.findAll('.promote-btn')
      expect(promoteButtons.length).toBe(1)
    })

    it('昇格ボタンクリックで選手が1軍に移動する', async () => {
      const players = [
        makePlayer({
          team_membership_id: 1,
          player_name: '昇格対象選手',
          squad: 'second',
        }),
      ]
      const wrapper = await mountActiveRoster(players)

      const promoteBtn = wrapper.find('.promote-btn')
      expect(promoteBtn.exists()).toBe(true)
      await promoteBtn.trigger('click')
      await flushPromises()

      // After promotion, demote button should appear instead
      const demoteButtons = wrapper.findAll('.demote-btn')
      expect(demoteButtons.length).toBe(1)
    })

    it('ロスター保存ボタンクリックでAPIが呼ばれる', async () => {
      const players = [
        makePlayer({
          team_membership_id: 1,
          squad: 'first',
        }),
      ]
      vi.mocked(axios.post).mockResolvedValue({ data: {} })
      // Mock alert to prevent test noise
      vi.stubGlobal('alert', vi.fn())

      const wrapper = await mountActiveRoster(players)

      const saveBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('選手登録を保存'))
      expect(saveBtn).toBeTruthy()
      await saveBtn!.trigger('click')
      await flushPromises()

      expect(vi.mocked(axios.post)).toHaveBeenCalledWith(
        '/teams/1/roster',
        expect.objectContaining({
          roster_updates: expect.any(Array),
          target_date: expect.any(String),
        }),
      )
    })
  })
})
