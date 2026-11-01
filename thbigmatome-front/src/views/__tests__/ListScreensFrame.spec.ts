import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia } from 'pinia'
import { createI18n } from 'vue-i18n'
import type { Component } from 'vue'
import ja from '@/locales/ja.json'

import ManagerList from '../ManagerList.vue'
import TeamList from '../TeamList.vue'
import StadiumsView from '../commissioner/StadiumsView.vue'
import CompetitionsView from '../commissioner/CompetitionsView.vue'
import UsersView from '../commissioner/UsersView.vue'
import CardSetsView from '../commissioner/CardSetsView.vue'
import PlayerCardsView from '../PlayerCardsView.vue'

// 2 つの axios（直接 / プラグイン）を同じ関数にして、画面ごとの違いを吸収する
const api = vi.hoisted(() => ({ get: vi.fn() }))
const snackbar = vi.hoisted(() => ({ showSnackbar: vi.fn() }))

vi.mock('axios', () => ({
  default: {
    get: api.get,
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))
vi.mock('@/plugins/axios', () => ({
  default: {
    get: api.get,
    post: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))
vi.mock('@/composables/useSnackbar', () => ({ useSnackbar: () => snackbar }))
vi.mock('@/components/ManagerDialog.vue', () => ({ default: { template: '<div />' } }))
vi.mock('@/components/TeamDialog.vue', () => ({ default: { template: '<div />' } }))

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const router = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/:pathMatch(.*)*', component: { template: '<div />' } }],
  })

interface Screen {
  name: string
  component: Component
  /** 一覧の行 1 件ぶんの API 応答 */
  rows: unknown
  /** 0 件の API 応答 */
  none: unknown
  /** 空状態に出る文言（の一部） */
  emptyText: string
  /** 行があるときに表に出る文字 */
  rowText: string
  /** ツールバー右に置く主ボタンの文言（無ければ null） */
  primary: string | null
  /** ツールバー左に置く検索欄の data-testid（無ければ null） */
  search: string | null
  /** 本題の一覧を取る URL（補助で呼ぶ一覧と区別する。配列を返す画面だけ） */
  mainUrl?: string
}

const screens: Screen[] = [
  {
    name: '監督一覧',
    component: ManagerList,
    rows: {
      data: [
        {
          id: 1,
          name: '依田監督',
          short_name: 'よ',
          irc_name: 'yoda',
          user_id: 1,
          active_director_team_count: 1,
          teams: [],
        },
      ],
      meta: { total_count: 1, current_page: 1, per_page: 25 },
    },
    none: { data: [], meta: { total_count: 0, current_page: 1, per_page: 25 } },
    emptyText: ja.managerList.noData,
    rowText: '依田監督',
    primary: ja.managerList.addManager,
    search: null,
  },
  {
    name: 'チーム一覧',
    component: TeamList,
    mainUrl: '/teams',
    rows: [
      {
        id: 1,
        name: '豊玉シャークス',
        short_name: '豊玉',
        team_type: 'normal',
        is_active: true,
        director: { name: '依田監督' },
      },
    ],
    none: [],
    emptyText: 'チームが登録されていません',
    rowText: '豊玉シャークス',
    primary: ja.teamList.addTeam,
    search: null,
  },
  {
    name: '球場管理',
    component: StadiumsView,
    rows: [{ id: 1, name: '甲子園', code: 'koshien', indoor: false, up_table_ids: [] }],
    none: [],
    emptyText: '球場が登録されていません',
    rowText: '甲子園',
    primary: '新規球場作成',
    search: 'stadiums-search',
  },
  {
    name: '大会管理',
    component: CompetitionsView,
    mainUrl: '/competitions',
    rows: [{ id: 1, name: '春季大会', year: 2026, competition_type: 'league', entry_count: 6 }],
    none: [],
    emptyText: '大会が登録されていません',
    rowText: '春季大会',
    primary: '新規大会作成',
    search: 'competitions-search',
  },
  {
    name: 'ユーザー管理',
    component: UsersView,
    rows: [{ id: 1, name: 'admin', display_name: '管理者', role: 'commissioner' }],
    none: [],
    emptyText: 'ユーザーが登録されていません',
    rowText: '管理者',
    primary: '新規ユーザー作成',
    search: 'users-search',
  },
  {
    name: 'カードセット',
    component: CardSetsView,
    mainUrl: '/card_sets',
    rows: [{ id: 1, year: 2026, set_type: 'annual', name: '2026年度版' }],
    none: [],
    emptyText: 'カードセットが登録されていません',
    rowText: '2026年度版',
    primary: null,
    search: null,
  },
  {
    name: '選手カード',
    component: PlayerCardsView,
    rows: {
      player_cards: [
        {
          id: 1,
          card_set_id: 1,
          player_id: 1,
          card_type: 'pitcher',
          player_name: '博麗霊夢',
          player_number: '1',
          card_set_name: '2026',
          speed: 3,
          steal_start: 1,
          steal_end: 2,
          injury_rate: 1,
          primary_position: 'P',
        },
      ],
      meta: { total: 1 },
    },
    none: { player_cards: [], meta: { total: 0 } },
    emptyText: '該当する選手カードがありません',
    rowText: '博麗霊夢',
    primary: null,
    search: 'player-cards-search',
  },
]

// 画面が補助で呼ぶ一覧（カードセット・大会・チーム）は空配列で返し、本題の応答だけを差し替える
const respond = (screen: Screen, data: unknown) => {
  api.get.mockImplementation((url: string) =>
    Promise.resolve({
      data:
        ['/card_sets', '/competitions', '/teams'].includes(url) && url !== screen.mainUrl
          ? []
          : data,
    }),
  )
}

const mountScreen = async (screen: Screen) => {
  const wrapper = mount(screen.component, {
    global: { plugins: [i18n, vuetify, router(), createPinia()] },
    attachTo: document.body,
  })
  await flushPromises()
  return wrapper
}

const has = (w: VueWrapper, id: string) => w.find(`[data-testid="${id}"]`).exists()

let mounted: VueWrapper | null = null
afterEach(() => {
  mounted?.unmount()
  mounted = null
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.1 骨格 / §2.4 操作の置き場 / §2.7 状態 / §4.2 段 2（一覧系を PageLayout へ）
describe.each(screens)('一覧系の骨格: $name', (screen) => {
  beforeEach(() => {
    api.get.mockReset()
    snackbar.showSnackbar.mockReset()
  })

  it('画面タイトルの見出しを本文に持たず、骨格の中で描く', async () => {
    respond(screen, screen.rows)
    const w = (mounted = await mountScreen(screen))
    expect(has(w, 'page-layout')).toBe(true)
    expect(w.find('h1').exists()).toBe(false)
    expect(w.find('.v-container').exists()).toBe(false)
  })

  it('読み込み中はスケルトンを出し、空状態を出さない', async () => {
    api.get.mockReturnValue(new Promise(() => {}))
    const w = (mounted = await mountScreen(screen))
    expect(has(w, 'state-loading')).toBe(true)
    expect(has(w, 'state-empty')).toBe(false)
    expect(has(w, 'state-error')).toBe(false)
  })

  it('0 件なら空状態を出す（読み込みが終わってから）', async () => {
    respond(screen, screen.none)
    const w = (mounted = await mountScreen(screen))
    expect(has(w, 'state-loading')).toBe(false)
    expect(w.find('[data-testid="state-empty"]').text()).toContain(screen.emptyText)
    expect(has(w, 'state-error')).toBe(false)
  })

  it('取得に失敗したらページ内のアラートと再読み込みを出し、空状態もスナックバーも出さない', async () => {
    api.get.mockRejectedValue(new Error('network'))
    const w = (mounted = await mountScreen(screen))
    expect(has(w, 'state-error')).toBe(true)
    expect(has(w, 'state-empty')).toBe(false)
    expect(snackbar.showSnackbar).not.toHaveBeenCalled()

    // 再読み込みで取り直し、成功したら内容に替わる
    api.get.mockReset()
    respond(screen, screen.rows)
    await w.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(api.get).toHaveBeenCalled()
    expect(has(w, 'state-error')).toBe(false)
    expect(w.text()).toContain(screen.rowText)
  })

  it('行があれば表を出し、空状態を出さない。塗りの緑（主ボタン）は 1 つまで', async () => {
    respond(screen, screen.rows)
    const w = (mounted = await mountScreen(screen))
    expect(w.text()).toContain(screen.rowText)
    expect(has(w, 'state-empty')).toBe(false)
    const filled = w
      .findAllComponents(components.VBtn)
      .filter((b) => b.props('color') === 'action' && b.props('variant') === 'flat')
    expect(filled.length).toBeLessThanOrEqual(1)
  })

  if (screen.primary) {
    it('主ボタンはツールバー行の右（actions）に置く', async () => {
      respond(screen, screen.rows)
      const w = (mounted = await mountScreen(screen))
      const actions = w.find('.page-layout__actions')
      expect(actions.exists()).toBe(true)
      expect(actions.text()).toContain(screen.primary!)
      expect(
        w.find('.page-layout__filters').exists() ? w.find('.page-layout__filters').text() : '',
      ).not.toContain(screen.primary!)
    })

    it('0 件のときも主ボタンはツールバー右に残る（空状態に同じボタンを重ねない）', async () => {
      respond(screen, screen.none)
      const w = (mounted = await mountScreen(screen))
      expect(w.find('.page-layout__actions').text()).toContain(screen.primary!)
      expect(w.find('[data-testid="state-empty"]').find('button').exists()).toBe(false)
    })
  } else {
    it('主ボタンを持たない画面はツールバー右を作らない', async () => {
      respond(screen, screen.rows)
      const w = (mounted = await mountScreen(screen))
      expect(w.find('.page-layout__actions').exists()).toBe(false)
    })
  }

  if (screen.search) {
    it('検索欄はツールバー行の左（filters）に置く', async () => {
      respond(screen, screen.rows)
      const w = (mounted = await mountScreen(screen))
      const filters = w.find('.page-layout__filters')
      expect(filters.exists()).toBe(true)
      expect(filters.find(`[data-testid="${screen.search!}"]`).exists()).toBe(true)
    })
  }
})

describe('監督一覧: 最初の取得は 1 回', () => {
  // 表は取得が済んでから描かれ、その時の更新通知で同じ条件を取り直さない
  it('行があっても初回の GET は 1 回だけ。ページを変えた時は取り直す', async () => {
    api.get.mockReset()
    respond(screens[0]!, screens[0]!.rows)
    const w = (mounted = await mountScreen(screens[0]!))
    expect(w.text()).toContain('依田監督')
    expect(api.get).toHaveBeenCalledTimes(1)
    const vm = w.vm as unknown as {
      onOptionsUpdate: (o: { page: number; itemsPerPage: number }) => void
    }
    vm.onOptionsUpdate({ page: 2, itemsPerPage: 25 })
    await flushPromises()
    expect(api.get).toHaveBeenCalledTimes(2)
  })
})

describe('行の操作は名前を持つアイコンボタン', () => {
  beforeEach(() => {
    api.get.mockReset()
  })

  const labels = (w: VueWrapper) =>
    w.findAll('button[aria-label]').map((b) => b.attributes('aria-label'))

  it('球場: 編集', async () => {
    api.get.mockResolvedValue({ data: screens[2]!.rows })
    const w = (mounted = await mountScreen(screens[2]!))
    expect(labels(w)).toContain('甲子園を編集')
  })

  it('大会: 編集・ロスター管理・削除（削除は danger-ink）', async () => {
    api.get.mockResolvedValue({ data: screens[3]!.rows })
    const w = (mounted = await mountScreen(screens[3]!))
    expect(labels(w)).toEqual(
      expect.arrayContaining(['春季大会を編集', '春季大会のロスター管理', '春季大会を削除']),
    )
    const del = w
      .findAllComponents(components.VBtn)
      .find((b) => b.attributes('aria-label') === '春季大会を削除')
    expect(del?.props('color')).toBe('danger-ink')
    expect(del?.props('variant')).toBe('text')
  })

  it('ユーザー: ロール変更・パスワードリセット', async () => {
    api.get.mockResolvedValue({ data: screens[4]!.rows })
    const w = (mounted = await mountScreen(screens[4]!))
    expect(labels(w)).toEqual(
      expect.arrayContaining(['adminのロール変更', 'adminのパスワードリセット']),
    )
  })

  it('チーム一覧: 4 つの操作が名前を持ち、折り返さない（row-actions）', async () => {
    api.get.mockResolvedValue({ data: screens[1]!.rows })
    const w = (mounted = await mountScreen(screens[1]!))
    expect(labels(w)).toEqual(
      expect.arrayContaining([
        '豊玉シャークスのシーズンポータル',
        '豊玉シャークスのメンバー編集',
        '豊玉シャークスを編集',
        '豊玉シャークスを削除',
      ]),
    )
    expect(w.find('.row-actions').exists()).toBe(true)
  })

  it.each([
    ['監督一覧', 0, 2],
    ['大会管理', 3, 3],
    ['ユーザー管理', 4, 2],
    ['チーム一覧', 1, 4],
  ])(
    '%s: 行の操作 %i 個を 1 つの row-actions（折り返さない列）にまとめる',
    async (_n, i, count) => {
      respond(screens[i]!, screens[i]!.rows)
      const w = (mounted = await mountScreen(screens[i]!))
      const groups = w.findAll('.row-actions')
      expect(groups).toHaveLength(1)
      expect(groups[0]!.findAll('button[aria-label]')).toHaveLength(count)
    },
  )

  it('監督一覧: 編集・削除', async () => {
    api.get.mockResolvedValue({ data: screens[0]!.rows })
    const w = (mounted = await mountScreen(screens[0]!))
    expect(labels(w)).toEqual(expect.arrayContaining(['依田監督を編集', '依田監督を削除']))
  })

  it('カードセット: 詳細を開くと詳細パネルが出て、閉じるボタンで消える', async () => {
    api.get.mockImplementation((url: string) =>
      Promise.resolve({
        data: url === '/card_sets' ? screens[5]!.rows : (screens[5]!.rows as unknown[])[0],
      }),
    )
    const w = (mounted = await mountScreen(screens[5]!))
    expect(has(w, 'card-set-detail')).toBe(false)
    await w.find('button[aria-label="2026年度版の詳細"]').trigger('click')
    await flushPromises()
    expect(has(w, 'card-set-detail')).toBe(true)
    expect(w.find('[data-testid="card-set-detail"]').text()).toContain('2026年度版')
    await w.find('button[aria-label="詳細を閉じる"]').trigger('click')
    expect(has(w, 'card-set-detail')).toBe(false)
  })

  it('カードセット: 詳細の取得に失敗したら一覧は残し、スナックバーで知らせる', async () => {
    api.get.mockImplementation((url: string) =>
      url === '/card_sets'
        ? Promise.resolve({ data: screens[5]!.rows })
        : Promise.reject(new Error('x')),
    )
    snackbar.showSnackbar.mockReset()
    const w = (mounted = await mountScreen(screens[5]!))
    await w.find('button[aria-label="2026年度版の詳細"]').trigger('click')
    await flushPromises()
    expect(has(w, 'card-set-detail')).toBe(false)
    expect(has(w, 'state-error')).toBe(false)
    expect(w.text()).toContain('2026年度版')
    expect(snackbar.showSnackbar).toHaveBeenCalledWith(
      'カードセット詳細の取得に失敗しました',
      'error',
    )
  })
})

describe('絞り込み・検索の結果が 0 件でも、条件欄（ツールバー）は残る', () => {
  beforeEach(() => api.get.mockReset())

  it('選手カード: 並び替えの表示切替と件数もツールバーに残る', async () => {
    respond(screens[6]!, screens[6]!.none)
    const w = (mounted = await mountScreen(screens[6]!))
    const filters = w.find('.page-layout__filters')
    expect(filters.text()).toContain('0件')
    expect(filters.find('button[aria-label="グリッド表示"]').exists()).toBe(true)
  })
})
