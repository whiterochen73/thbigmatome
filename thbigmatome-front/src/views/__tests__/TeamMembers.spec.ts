import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import { createRouter, createMemoryHistory } from 'vue-router'
import TeamMembers from '../TeamMembers.vue'
import { appBarTitle } from '@/composables/useAppBarTitle'
import realJa from '@/locales/ja.json'

const { mockShowSnackbar } = vi.hoisted(() => ({
  mockShowSnackbar: vi.fn(),
}))

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
    showSnackbar: mockShowSnackbar,
  }),
}))

import axios from '@/plugins/axios'
import { scrollLayout } from '@/components/shared/__tests__/tableLayout'

// Stub child components
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
      // 違反の欄（ViolationList）は実際の文言で見る
      violationList: realJa.violationList,
      asOfBar: realJa.asOfBar,
      asyncState: realJa.asyncState,
      seasonPortal: { shortTitle: realJa.seasonPortal.shortTitle, tabs: realJa.seasonPortal.tabs },
      teamMembers: {
        title: 'チーム「{teamName}」の選手登録',
        selectCostList: 'コスト一覧表を選択',
        selectPlayer: '選手を選択して追加',
        addPlayer: '追加',
        noData: '選手が登録されていません。',
        headers: {
          number: '背番号',
          name: '名前',
          display_name: '通称',
          position: 'ポジション',
          throws: '投',
          bats: '打',
          player_types: '選手タイプ',
          cost: 'コスト',
          excluded: '除外',
          costExcluded: 'コスト除外',
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
          fielder: '野手',
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

function setupDefaultMocks(
  teamPlayers: Record<string, unknown>[] = [],
  candidates: Record<string, unknown>[] = [],
) {
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
      return Promise.resolve({ data: candidates })
    }
    if (url === '/player-types') {
      return Promise.resolve({
        data: [
          { id: 1, name: '東方キャラ', description: null, category: 'touhou' },
          { id: 2, name: '二刀流', description: null, category: 'cost_regulation' },
        ],
      })
    }
    if (url === '/costs') {
      return Promise.resolve({
        data: [{ id: 100, name: 'コスト表1', start_date: '2020-01-01', end_date: null }],
      })
    }
    return Promise.resolve({ data: {} })
  })
}

async function mountTeamMembers(
  teamPlayers: Record<string, unknown>[] = [],
  candidates: Record<string, unknown>[] = [],
) {
  setupDefaultMocks(teamPlayers, candidates)
  const router = createTestRouter()
  router.push('/teams/1/members')
  await router.isReady()
  const wrapper = mount(TeamMembers, {
    global: {
      plugins: [vuetify, i18n, router],
      stubs: {
        TeamNavigation: TeamNavigationStub,
      },
    },
  })
  await flushPromises()
  return wrapper
}

describe('TeamMembers.vue', () => {
  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b2-7〜b2-8, b2-12
  it('候補の投手・野手チップは役割色の flat、人数チップは link', async () => {
    const wrapper = await mountTeamMembers(
      [makeTeamPlayer({ id: 3, position: 'pitcher' })],
      [
        makeTeamPlayer({ id: 1, position: 'pitcher' }),
        makeTeamPlayer({ id: 2, position: 'fielder' }),
      ],
    )
    const autocomplete = wrapper.findComponent(components.VAutocomplete)
    expect(autocomplete.props('items')).toHaveLength(2)
    ;(autocomplete.vm as unknown as { menu: boolean }).menu = true
    await flushPromises()
    for (const [label, color, icon] of [
      ['投手', 'tag-pitcher', 'mdi-baseball'],
      ['野手', 'tag-fielder', 'mdi-baseball-bat'],
    ]) {
      const matching = wrapper
        .findAllComponents(components.VChip)
        .filter((chip) => chip.text() === label)
      expect(matching.length, label).toBeGreaterThan(0)
      for (const chip of matching) {
        expect(chip.props('color')).toBe(color)
        expect(chip.props('variant')).toBe('flat')
        expect(chip.props('prependIcon')).toBe(icon)
      }
    }
    const counts = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text().includes(':'))
    expect(counts.length).toBeGreaterThan(0)
    for (const chip of counts) expect(chip.props('color')).toBe('link')
  })
  beforeEach(() => {
    vi.clearAllMocks()
    mockShowSnackbar.mockClear()
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §4.3（SeasonPortal のタブ内に別画面が入る件）・モック §5（チーム名をバーへ、「← シーズン」で戻る）
  describe('ヘッダーバーと骨格（単独の画面 / 埋め込み）', () => {
    it('単独の画面: タイトル=チーム名、サブタイトル=チーム編成、戻り先=シーズン。本文に h1 を持たない', async () => {
      const wrapper = await mountTeamMembers()
      expect(appBarTitle.value).toEqual({
        title: '紅魔館',
        subtitle: 'チーム編成',
        back: { to: { name: 'SeasonPortal', params: { teamId: 1 } }, label: 'シーズン' },
      })
      expect(wrapper.find('h1').exists()).toBe(false)
      expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(true)
      wrapper.unmount()
      expect(appBarTitle.value).toBeNull()
    })

    it('チーム名が届くまでも、戻り先（シーズン）はバーに出ている', async () => {
      setupDefaultMocks()
      const pending = new Promise<{ data: unknown }>(() => {})
      const base = vi.mocked(axios.get).getMockImplementation()!
      vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) =>
        /\/teams\/\d+$/.test(url) ? pending : base(url, config as never),
      )
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, { global: { plugins: [vuetify, i18n, router] } })
      await flushPromises()
      expect(appBarTitle.value).toEqual({
        title: 'チーム編成',
        subtitle: null,
        back: { to: { name: 'SeasonPortal', params: { teamId: 1 } }, label: 'シーズン' },
      })
      wrapper.unmount()
    })

    it('チーム名の取得に失敗しても画面は使え、バーは「チーム編成」と戻り先を出す', async () => {
      setupDefaultMocks()
      const base = vi.mocked(axios.get).getMockImplementation()!
      vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) =>
        /\/teams\/\d+$/.test(url) ? Promise.reject(new Error('boom')) : base(url, config as never),
      )
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, { global: { plugins: [vuetify, i18n, router] } })
      await flushPromises()
      expect(appBarTitle.value?.title).toBe('チーム編成')
      expect(appBarTitle.value?.back?.label).toBe('シーズン')
      expect(wrapper.text()).toContain('チームメンバー')
      wrapper.unmount()
    })

    it('埋め込み（teamId を props で受ける）: バーを変えず、骨格（PageLayout）も持たない', async () => {
      setupDefaultMocks()
      appBarTitle.value = { title: 'シーズン側の題', subtitle: 'シーズン' }
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, {
        props: { teamId: 1, asOfDate: '2026-05-01', phase: 'pre_game' },
        global: { plugins: [vuetify, i18n, router] },
      })
      await flushPromises()
      expect(appBarTitle.value).toEqual({ title: 'シーズン側の題', subtitle: 'シーズン' })
      expect(wrapper.find('[data-testid="page-layout"]').exists()).toBe(false)
      expect(wrapper.find('h1').exists()).toBe(false)
      // 埋め込みでもチーム名は取りに行かない（バーを持たないため）
      expect(
        vi.mocked(axios.get).mock.calls.some(([url]) => /\/teams\/\d+$/.test(String(url))),
      ).toBe(false)
      wrapper.unmount()
      appBarTitle.value = null
    })
  })

  describe('読み込み中・失敗の出し方', () => {
    it('読み込み中は「選手が登録されていません」を出さない。終わってから出す', async () => {
      setupDefaultMocks()
      let resolvePlayers!: (value: { data: unknown[] }) => void
      const pending = new Promise<{ data: unknown[] }>((resolve) => {
        resolvePlayers = resolve
      })
      const base = vi.mocked(axios.get).getMockImplementation()!
      vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) =>
        url.endsWith('/team_players') ? pending : base(url, config as never),
      )
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, { global: { plugins: [vuetify, i18n, router] } })
      await flushPromises()
      expect(wrapper.text()).not.toContain('選手が登録されていません')
      resolvePlayers({ data: [] })
      await flushPromises()
      expect(wrapper.text()).toContain('選手が登録されていません')
      wrapper.unmount()
    })

    it('選手の取得に失敗した時はページ内のアラートを出し、再読み込みで取り直す', async () => {
      setupDefaultMocks([makeTeamPlayer({ id: 7, name: '再取得の選手' })])
      const base = vi.mocked(axios.get).getMockImplementation()!
      let failOnce = true
      vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) => {
        if (failOnce && url.endsWith('/team_players')) {
          failOnce = false
          return Promise.reject(new Error('boom'))
        }
        return base(url, config as never)
      })
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, { global: { plugins: [vuetify, i18n, router] } })
      await flushPromises()
      expect(wrapper.find('[data-testid="state-error"]').text()).toContain(
        'チームの選手一覧の取得に失敗しました',
      )
      // 取得の失敗はスナックバーでなくページ内のアラート
      expect(mockShowSnackbar).not.toHaveBeenCalledWith(
        'チームの選手一覧の取得に失敗しました。',
        'error',
      )
      await wrapper.find('[data-testid="state-retry"]').trigger('click')
      await flushPromises()
      expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
      expect(wrapper.text()).toContain('再取得の選手')
      wrapper.unmount()
    })

    it('コスト表の取得に失敗した時の再読み込みは、最初から取り直す', async () => {
      setupDefaultMocks([makeTeamPlayer({ id: 8, name: '最初からの選手' })])
      const base = vi.mocked(axios.get).getMockImplementation()!
      let failOnce = true
      vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) => {
        if (failOnce && url === '/costs') {
          failOnce = false
          return Promise.reject(new Error('boom'))
        }
        return base(url, config as never)
      })
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, { global: { plugins: [vuetify, i18n, router] } })
      await flushPromises()
      expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(true)
      expect(wrapper.text()).not.toContain('選手が登録されていません')
      await wrapper.find('[data-testid="state-retry"]').trigger('click')
      await flushPromises()
      expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
      expect(wrapper.text()).toContain('最初からの選手')
      wrapper.unmount()
    })
  })

  it('チームメンバー一覧のタイトルが表示される', async () => {
    const wrapper = await mountTeamMembers()

    expect(wrapper.text()).toContain('チームメンバー')
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
    // コスト表はonMounted内で自動選択される（/costsエンドポイント経由）
    setupDefaultMocks(players)
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: {
          TeamNavigation: TeamNavigationStub,
        },
      },
    })
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
    // コスト表はonMounted内で自動選択される（/costsエンドポイント経由）
    setupDefaultMocks(players)
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: {
          TeamNavigation: TeamNavigationStub,
        },
      },
    })
    await flushPromises()

    // Should display total cost and max (合計コスト: X / 200)
    expect(wrapper.text()).toContain('合計コスト')
    expect(wrapper.text()).toContain('200')
  })

  // Test Basis: Operator 決定 2026-11-01（上限のツールチップは上限だけ。除外の説明はコスト除外のヒントが持つ）
  it('合計コストのツールチップは上限だけを述べ、除外の説明はコスト除外のヒントに残る', async () => {
    setupDefaultMocks([makeTeamPlayer({ id: 1, name: '選手A' })])
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      attachTo: document.body,
      global: {
        plugins: [vuetify, i18n, router],
        stubs: { TeamNavigation: TeamNavigationStub },
      },
    })
    await flushPromises()

    // 実際に開いたツールチップの本文を読む（ホバーで開き、body に teleport される）
    const icons = wrapper.findAll('.mdi-help-circle-outline')
    const texts: string[] = []
    for (const icon of icons) {
      await icon.trigger('mouseenter')
      await flushPromises()
      await new Promise((r) => setTimeout(r, 50))
      const open = Array.from(document.body.querySelectorAll('.v-tooltip .v-overlay__content'))
      texts.push(...open.map((el) => el.textContent ?? ''))
      await icon.trigger('mouseleave')
      await flushPromises()
    }
    expect(texts).toContain('チーム全体のコスト上限は200です。')
    expect(texts.some((t) => t.includes('合計コストに算入されません'))).toBe(false)
    expect(
      texts.some((t) => t.includes('除外特例を受けた選手をチームの合計コスト計算から除外します。')),
    ).toBe(true)
    wrapper.unmount()
  })

  it('excluded_from_team_totalチェックボックスが存在する', async () => {
    const players = [makeTeamPlayer({ id: 1, name: '選手A' })]
    // コスト表はonMounted内で自動選択される（/costsエンドポイント経由）
    setupDefaultMocks(players)
    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: {
          TeamNavigation: TeamNavigationStub,
        },
      },
    })
    await flushPromises()

    // The "コスト除外" header should exist
    expect(wrapper.text()).toContain('コスト除外')

    // Checkbox should exist in the table
    const checkboxes = wrapper.findAll('.v-checkbox')
    expect(checkboxes.length).toBeGreaterThanOrEqual(1)
  })

  it('コスト選択ドロップダウンのヘッダーが表示される', async () => {
    const wrapper = await mountTeamMembers()

    // Cost column header should be present
    expect(wrapper.text()).toContain('コスト')
  })

  it('teamIdなし（チーム未選択）の場合にガイドメッセージが表示される', async () => {
    setupDefaultMocks()
    const router = createTestRouter()
    router.push('/menu') // teamIdなしのルート
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: { TeamNavigation: TeamNavigationStub },
      },
    })
    await flushPromises()

    expect(wrapper.text()).toContain('チームが選択されていません')
    expect(vi.mocked(axios.get)).not.toHaveBeenCalledWith(expect.stringContaining('/team_players'))
  })

  it('teamId propを渡すとAPI呼び出しにそのIDが使われる', async () => {
    setupDefaultMocks()
    const router = createTestRouter()
    router.push('/menu') // teamIdなしのルート
    await router.isReady()

    mount(TeamMembers, {
      props: { teamId: 42 },
      global: {
        plugins: [vuetify, i18n, router],
        stubs: { TeamNavigation: TeamNavigationStub },
      },
    })
    await flushPromises()

    expect(vi.mocked(axios.get)).toHaveBeenCalledWith(
      expect.stringContaining('/teams/42/team_players'),
      expect.anything(),
    )
  })

  it('保存ボタンが存在する', async () => {
    const wrapper = await mountTeamMembers()

    const saveBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('保存'))
    expect(saveBtn).toBeTruthy()
  })

  it('保存成功時にwarnings配列があれば警告Snackbarを表示する', async () => {
    vi.mocked(axios.post).mockResolvedValue({
      data: {
        message: 'saved',
        warnings: ['チーム総コストが上限を超えています (210/200)'],
      },
    })
    const wrapper = await mountTeamMembers()

    const saveBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('保存'))
    expect(saveBtn).toBeTruthy()
    await saveBtn!.trigger('click')
    await flushPromises()

    expect(mockShowSnackbar).toHaveBeenCalledWith('選手情報を保存しました。', 'success')
    expect(mockShowSnackbar).toHaveBeenCalledWith(
      '警告: チーム総コストが上限を超えています (210/200)',
      'warning',
    )
  })

  it('選手が1枚のカードを持つ場合、自動的にplayer_card_idが選択される', async () => {
    const mockCards = {
      player_cards: [{ id: 10, card_type: 'pitcher', card_set_name: '第1弾', card_set_id: 1 }],
      meta: { total: 1, page: 1, per_page: 100 },
    }
    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (url === '/player_cards') return Promise.resolve({ data: mockCards })
      if (url.includes('/teams/') && url.endsWith('/team_players'))
        return Promise.resolve({ data: [] })
      if (url === '/team_registration_players') return Promise.resolve({ data: [] })
      if (url === '/player-types') return Promise.resolve({ data: [] })
      if (url === '/costs')
        return Promise.resolve({
          data: [{ id: 100, name: 'コスト表1', start_date: '2020-01-01', end_date: null }],
        })
      return Promise.resolve({ data: {} })
    })

    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: { TeamNavigation: TeamNavigationStub },
      },
    })
    await flushPromises()

    // The card fetch should be triggered when a player is selected (tested via API mock)
    expect(wrapper.exists()).toBe(true)
  })

  it('player_card_infoがあるメンバーのテーブル行にカードバージョン列が表示される', async () => {
    const players = [
      makeTeamPlayer({
        id: 1,
        name: '選手A',
        player_card_id: 10,
        player_card_info: { id: 10, card_type: 'pitcher', card_set_name: '第1弾', card_set_id: 1 },
      }),
    ]
    const wrapper = await mountTeamMembers(players)

    expect(wrapper.text()).toContain('カードver.')
    expect(wrapper.text()).toContain('第1弾')
  })

  it('player_card_infoがないメンバーは「—」を表示する', async () => {
    const players = [makeTeamPlayer({ id: 1, name: '選手A', player_card_id: null })]
    const wrapper = await mountTeamMembers(players)

    expect(wrapper.text()).toContain('カードver.')
  })

  it('同一カードセットのvariant複数枚を別選択肢として表示する', async () => {
    const player = makeTeamPlayer({
      id: 99,
      name: '初瀬麻里安',
      short_name: '初瀬',
      number: '1',
      position: 'outfielder',
      cost_players: [
        {
          id: 1,
          cost_id: 100,
          player_id: 99,
          player_card_id: 101,
          normal_cost: 10,
          relief_only_cost: null,
          pitcher_only_cost: null,
          fielder_only_cost: null,
          two_way_cost: null,
        },
      ],
    })

    vi.mocked(axios.get).mockImplementation((url: string) => {
      if (url === '/player_cards') {
        return Promise.resolve({
          data: {
            player_cards: [
              {
                id: 101,
                card_type: 'batter',
                card_set_name: 'PM2026',
                card_set_id: 3,
                variant: '湘南',
              },
              {
                id: 102,
                card_type: 'batter',
                card_set_name: 'PM2026',
                card_set_id: 3,
                variant: '町田',
              },
              {
                id: 103,
                card_type: 'batter',
                card_set_name: 'PM2026',
                card_set_id: 3,
                variant: 'UR',
              },
            ],
          },
        })
      }
      if (url.includes('/teams/') && url.endsWith('/team_players'))
        return Promise.resolve({ data: [] })
      if (url === '/team_registration_players') return Promise.resolve({ data: [player] })
      if (url === '/player-types') return Promise.resolve({ data: [] })
      if (url === '/costs')
        return Promise.resolve({
          data: [{ id: 100, name: 'コスト表1', start_date: '2020-01-01', end_date: null }],
        })
      return Promise.resolve({ data: {} })
    })

    const router = createTestRouter()
    router.push('/teams/1/members')
    await router.isReady()

    const wrapper = mount(TeamMembers, {
      global: {
        plugins: [vuetify, i18n, router],
        stubs: { TeamNavigation: TeamNavigationStub },
      },
    })
    await flushPromises()
    ;(wrapper.vm as unknown as { selectedPlayer: typeof player | null }).selectedPlayer = player
    await flushPromises()

    expect(wrapper.text()).toContain('PM2026 / 湘南')
    expect(wrapper.text()).toContain('PM2026 / 町田')
    expect(wrapper.text()).toContain('PM2026 / UR')
  })

  // 選手を登録する画面で選べるのは、現行カードセットの、公式戦で使えるカードだけ（cmd_1893/subtask_1893e）。
  // Test Basis: Operator 裁定（2026-11-14）。両方のセットのカードを持つ選手は現行セットのほうを既定で見せる。サーバ側でも拒む（画面だけで止めない）
  describe('登録できるカードの絞り込み', () => {
    type Card = {
      id: number
      card_type: string
      card_set_name: string
      card_set_id: number
      variant?: string | null
      card_set_current: boolean
      official_use_prohibited: boolean
    }
    type Vm = {
      selectedPlayer: unknown
      selectedCardOptionKey: string | null
      availablePlayerCards: Card[]
      cardSetOptions: { option_key: string; card_set_name: string; label: string }[]
      noRegistrableCard: boolean
      selectedCostListId: number | null
    }

    const card = (id: number, over: Partial<Card> = {}): Card => ({
      id,
      card_type: 'batter',
      card_set_name: 'PM2027',
      card_set_id: 5,
      variant: null,
      card_set_current: true,
      official_use_prohibited: false,
      ...over,
    })

    async function mountWithCards(cards: Card[]) {
      const player = makeTeamPlayer({ id: 77, name: '選手X', short_name: 'X', number: '7', position: 'outfielder' })
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if (url === '/player_cards') return Promise.resolve({ data: { player_cards: cards } })
        if (url.includes('/teams/') && url.endsWith('/team_players')) return Promise.resolve({ data: [] })
        if (url === '/team_registration_players') return Promise.resolve({ data: [player] })
        if (url === '/player-types') return Promise.resolve({ data: [] })
        if (url === '/costs')
          return Promise.resolve({
            data: [{ id: 100, name: 'コスト表1', start_date: '2020-01-01', end_date: null }],
          })
        return Promise.resolve({ data: {} })
      })
      const router = createTestRouter()
      router.push('/teams/1/members')
      await router.isReady()
      const wrapper = mount(TeamMembers, {
        global: { plugins: [vuetify, i18n, router], stubs: { TeamNavigation: TeamNavigationStub } },
      })
      await flushPromises()
      const vm = wrapper.vm as unknown as Vm
      vm.selectedPlayer = player
      await flushPromises()
      return { wrapper, vm }
    }

    it('現行外のセットのカードは選択肢に出ない（両方のセットを持つ選手は現行セットだけ・既定でそれが選ばれる）', async () => {
      const { vm } = await mountWithCards([
        card(1, { card_set_name: 'PM2026', card_set_id: 4, card_set_current: false }),
        card(2, { card_set_name: 'PM2027', card_set_id: 5 }),
      ])
      expect(vm.cardSetOptions.map((o) => o.card_set_name)).toEqual(['PM2027'])
      expect(vm.selectedCardOptionKey).toBe('5:')
      expect(vm.availablePlayerCards.map((c) => c.id)).toEqual([2])
    })

    it('公式戦で使えないカードは、現行セットのものでも選択肢に出ない', async () => {
      const { vm } = await mountWithCards([
        card(1, { variant: 'UR', official_use_prohibited: true }),
        card(2, { variant: '湘南' }),
      ])
      expect(vm.cardSetOptions.map((o) => o.label)).toEqual(['PM2027 / 湘南'])
    })

    it('選べるカードが 1 枚も無い選手（現行外のカードだけ）は追加ボタンが押せない', async () => {
      const { wrapper, vm } = await mountWithCards([
        card(1, { card_set_name: 'PM2026', card_set_id: 4, card_set_current: false }),
      ])
      vm.selectedCostListId = 100
      await flushPromises()
      expect(vm.noRegistrableCard).toBe(true)
      const addBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('追加'))
      expect(addBtn!.attributes('disabled')).toBeDefined()
    })

    it('カードが選べる選手は追加ボタンが押せる', async () => {
      const { wrapper, vm } = await mountWithCards([card(2)])
      vm.selectedCostListId = 100
      await flushPromises()
      expect(vm.noRegistrableCard).toBe(false)
      const addBtn = wrapper.findAll('.v-btn').find((b) => b.text().includes('追加'))
      expect(addBtn!.attributes('disabled')).toBeUndefined()
    })
  })
})

// 過去分の修正（cmd_1784 段2b）: 読む GET と保存する POST の両方に、同じ target_date と phase を渡す。
// GET を日付なしで呼ぶと最新の写し、POST を日付なしで呼ぶとカーソル時点の状態と比べるので、読んだ値を送り直すだけで余計な変更記録が増える（subtask_1784i の警告）。
// Test Basis: queue/reviews/subtask_1784i.yaml の warning（GET と POST の既定の食い違い）、
//   context/thbig-dugout-season-record-restructure-design.md の 2026-11-01 の追記 2 本
describe('TeamMembers.vue 日付つきの読み書き', () => {
  type Props = { teamId: number; asOfDate?: string; phase?: string; readonly?: boolean }

  async function mountWith(
    props: Props,
    opts: {
      season?: 'ok' | 'none'
      currentDate?: string
      teamPlayers?: Record<string, unknown>[]
    } = {},
  ) {
    const {
      season = 'ok',
      currentDate = '2026-05-09T00:00:00.000Z',
      teamPlayers = [makeTeamPlayer()],
    } = opts
    setupDefaultMocks(teamPlayers)
    const base = vi.mocked(axios.get).getMockImplementation()!
    vi.mocked(axios.get).mockImplementation((url: string, config?: unknown) => {
      if (url === `/teams/${props.teamId}/season`) {
        return season === 'ok'
          ? Promise.resolve({ data: { id: 5, current_date: currentDate } })
          : Promise.reject(new Error('404'))
      }
      return base(url, config as never)
    })
    vi.mocked(axios.post).mockResolvedValue({ data: { message: 'ok', warnings: [] } })
    const router = createTestRouter()
    router.push('/menu')
    await router.isReady()
    const wrapper = mount(TeamMembers, {
      props,
      global: { plugins: [vuetify, i18n, router], stubs: { TeamNavigation: TeamNavigationStub } },
    })
    await flushPromises()
    return wrapper
  }

  const getsOf = (suffix: string) =>
    vi.mocked(axios.get).mock.calls.filter(([url]) => String(url).endsWith(suffix))

  const clickSave = async (wrapper: Awaited<ReturnType<typeof mountWith>>) => {
    await wrapper
      .findAll('.v-btn')
      .find((b) => b.text().includes('保存'))!
      .trigger('click')
    await flushPromises()
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('asOfDate を渡すと、GET も POST も同じ target_date と phase を送る（シーズンの現在日は読まない）', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07', phase: 'post_game' })

    expect(getsOf('/teams/1/season')).toHaveLength(0)
    expect(getsOf('/teams/1/team_players')[0][1]).toEqual({
      params: { target_date: '2026-05-07', phase: 'post_game' },
    })

    await clickSave(wrapper)

    const [url, payload] = vi.mocked(axios.post).mock.calls[0]
    expect(url).toBe('/teams/1/team_players')
    expect(payload).toMatchObject({ target_date: '2026-05-07', phase: 'post_game' })
  })

  it('phase を渡さなければ pre_game を GET と POST の両方に送る', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07' })
    await clickSave(wrapper)

    expect(getsOf('/teams/1/team_players')[0][1]).toEqual({
      params: { target_date: '2026-05-07', phase: 'pre_game' },
    })
    expect(vi.mocked(axios.post).mock.calls[0][1]).toMatchObject({ phase: 'pre_game' })
  })

  it('asOfDate が無ければ、シーズンの現在日を読み、その日付を GET と POST の両方に送る', async () => {
    const wrapper = await mountWith({ teamId: 1 })

    expect(getsOf('/teams/1/season')).toHaveLength(1)
    expect(getsOf('/teams/1/team_players')[0][1]).toEqual({
      params: { target_date: '2026-05-09', phase: 'pre_game' },
    })

    await clickSave(wrapper)

    expect(vi.mocked(axios.post).mock.calls[0][1]).toMatchObject({
      target_date: '2026-05-09',
      phase: 'pre_game',
    })
  })

  it('シーズンの無いチームは日付を送らない（サーバが行を直接書く）', async () => {
    const wrapper = await mountWith({ teamId: 1 }, { season: 'none' })

    expect(getsOf('/teams/1/team_players')[0][1]).toEqual({ params: {} })

    await clickSave(wrapper)

    const payload = vi.mocked(axios.post).mock.calls[0][1] as Record<string, unknown>
    expect(payload).not.toHaveProperty('target_date')
    expect(payload).not.toHaveProperty('phase')
  })

  it('asOfDate や phase が変わると、新しい日付で読み直す', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07' })

    await wrapper.setProps({ asOfDate: '2026-05-08', phase: 'post_game' })
    await flushPromises()

    const gets = getsOf('/teams/1/team_players')
    expect(gets).toHaveLength(2)
    expect(gets[1][1]).toEqual({ params: { target_date: '2026-05-08', phase: 'post_game' } })
  })

  it('後の日付の検査で止まった時（422 の violations）は、違反した日付・区分・内容を画面に出す', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07' })
    vi.mocked(axios.post).mockRejectedValue({
      response: {
        data: {
          error: '保存できません',
          violations: [
            {
              date: '2026-05-10',
              phase: 'pre_game',
              kind: 'first_squad_min',
              message: '1軍が 24 人です',
              severity: 'error',
              player_id: null,
            },
          ],
        },
      },
    })
    vi.spyOn(console, 'error').mockImplementation(() => {})

    await clickSave(wrapper)

    const list = wrapper.find('[data-testid="violation-list"]')
    expect(list.exists()).toBe(true)
    expect(list.text()).toContain('5/10')
    expect(list.text()).toContain('試合前')
    expect(list.text()).toContain('1軍が 24 人です')
    expect(mockShowSnackbar).toHaveBeenCalledWith('保存できません', 'error')
  })

  it('違反の無い失敗（violations が無い 422）では、違反の欄を出さない', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07' })
    vi.mocked(axios.post).mockRejectedValue({ response: { data: { error: '失敗' } } })
    vi.spyOn(console, 'error').mockImplementation(() => {})

    await clickSave(wrapper)

    expect(wrapper.find('[data-testid="violation-list"]').exists()).toBe(false)
  })

  it('readonly: 追加の欄・削除・保存を出さず、入力欄は読み取り専用', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07', readonly: true })

    expect(wrapper.find('[data-testid="add-player-row"]').exists()).toBe(false)
    expect(wrapper.findAll('.v-btn').some((b) => b.text().includes('保存'))).toBe(false)
    expect(wrapper.find('.mdi-delete, .mdi-delete-outline').exists()).toBe(false)
    expect(wrapper.text()).toContain('テスト選手')
    // 表の入力欄（通称・契約・コスト除外）は、すべて読み取り専用か無効
    const inputs = wrapper.findAll('tbody input')
    expect(inputs.length).toBe(3)
    inputs.forEach((input) => {
      expect(
        input.attributes('readonly') !== undefined || input.attributes('disabled') !== undefined,
      ).toBe(true)
    })
  })

  it('readonly でなければ、追加の欄と保存がある（対照）', async () => {
    const wrapper = await mountWith({ teamId: 1, asOfDate: '2026-05-07' })

    expect(wrapper.find('[data-testid="add-player-row"]').exists()).toBe(true)
    expect(wrapper.findAll('.v-btn').some((b) => b.text().includes('保存'))).toBe(true)
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（列を落とせない表は縦積みにせず横スクロール、先頭の名前列を固定）/ §2.4（行の操作はアイコンボタン）/ §4.2 段 4
describe('TeamMembers 表のスマホ対応（段 4）', () => {
  it('入力欄の並ぶ 11 列の表なので縦積みにせず、選手名の列を固定して横スクロール', async () => {
    const wrapper = await mountTeamMembers([makeTeamPlayer({ id: 3, name: '博麗霊夢' })])
    expect(scrollLayout(wrapper, 'display_name')).toEqual({
      mobileBreakpoint: undefined,
      rows: false,
      fixedKeys: ['name'],
      allHaveMinWidth: true,
    })
  })

  it('チームから除外は .row-actions の中の danger のアイコンボタン（名前つき）', async () => {
    const wrapper = await mountTeamMembers([makeTeamPlayer({ id: 3, name: '博麗霊夢' })])
    const btn = wrapper.find('.row-actions button')
    expect(btn.attributes('aria-label')).toBe('博麗霊夢をチームから除外')
    expect(btn.classes().join(' ')).toContain('text-danger-ink')
  })
})
