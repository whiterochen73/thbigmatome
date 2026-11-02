import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import SeasonAbsenceTab from '../SeasonAbsenceTab.vue'
import type { PlayerAbsence } from '@/types/playerAbsence'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'
import { dataTables, stackedLayout } from '@/components/shared/__tests__/tableLayout'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  missingWarn: false,
  fallbackWarn: false,
  messages: { ja: {} },
})

const season = {
  id: 1,
  name: '2026',
  current_date: '2026-04-11',
  start_date: '2026-04-01',
  end_date: '2026-10-31',
  key_player_id: null,
  key_player_name: null,
  season_schedules: [],
}

const makeAbsence = (
  id: number,
  playerName: string,
  effectiveEndDate: string | null,
): PlayerAbsence => ({
  id,
  team_membership_id: id,
  season_id: 1,
  absence_type: 'injury',
  reason: 'テスト',
  start_date: '2026-04-01',
  duration: 10,
  duration_unit: 'days',
  phase: 'pre_game',
  effective_start_date: '2026-04-01',
  effective_end_date: effectiveEndDate,
  created_at: '2026-04-01T00:00:00+09:00',
  updated_at: '2026-04-01T00:00:00+09:00',
  player_name: playerName,
  player_id: id,
})

const injured = makeAbsence(1, '怪我中', '2026-04-12')
const returnDay = makeAbsence(2, '復帰当日', '2026-04-11')
const recovered = makeAbsence(3, '復帰後', '2026-04-10')
const permanent = makeAbsence(4, '永続離脱', null)

async function mountComponent(
  absences: PlayerAbsence[],
  extraProps: Record<string, unknown> = {},
  seasonOverride: Record<string, unknown> = {},
) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url === '/teams/1/season') {
      return Promise.resolve({ data: { ...season, ...seasonOverride } })
    }
    if (url === '/player_absences') {
      return Promise.resolve({ data: absences })
    }
    return Promise.reject(new Error(`Unexpected GET ${url}`))
  })

  const wrapper = mount(SeasonAbsenceTab, {
    props: { teamId: 1, ...extraProps },
    global: {
      plugins: [vuetify, i18n],
      stubs: {
        PlayerAbsenceFormDialog: true,
        PlayerNameLink: {
          props: ['playerName'],
          template: '<span>{{ playerName }}</span>',
        },
      },
    },
  })
  await flushPromises()
  return wrapper
}

function tableText(wrapper: Awaited<ReturnType<typeof mountComponent>>, index: number) {
  return wrapper.findAll('.v-data-table')[index].text()
}

// 現在の離脱者が 0 件の時は表を出さず、空状態（AsyncState）を出す。その時は表の文字を空にする
function currentText(wrapper: Awaited<ReturnType<typeof mountComponent>>) {
  return wrapper.find('[data-testid="state-empty"]').exists() ? '' : tableText(wrapper, 0)
}

// 過去の履歴の表は常に最後の表（現在の離脱者が空状態の時は 1 つ目になる）
function pastText(wrapper: Awaited<ReturnType<typeof mountComponent>>) {
  const tables = wrapper.findAll('.v-data-table')
  return tables[tables.length - 1]!.text()
}

async function expandPastAbsences(wrapper: Awaited<ReturnType<typeof mountComponent>>) {
  await wrapper.find('.v-expansion-panel-title').trigger('click')
  await flushPromises()
}

describe('SeasonAbsenceTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // Test Basis: thbig-dugout-visual-refresh-design.md §6.1, §6.5, §7 段3
  it('離脱種別は共通の役割色と固有アイコン、時期は区分色で示す', async () => {
    const entries = [
      makeAbsence(1, '負傷', '2026-04-15'),
      {
        ...makeAbsence(2, '出場停止', '2026-04-15'),
        absence_type: 'suspension' as const,
        phase: 'in_game' as const,
      },
      { ...makeAbsence(3, '再調整', '2026-04-15'), absence_type: 'reconditioning' as const },
    ]
    const wrapper = await mountComponent(entries)
    const chips = wrapper.findAll('.v-data-table')[0]!.findAll('.v-chip')
    expect(
      chips.some(
        (chip) =>
          chip.classes().includes('bg-absence-out') && chip.find('.mdi-hospital-box').exists(),
      ),
    ).toBe(true)
    expect(
      chips.some(
        (chip) => chip.classes().includes('bg-absence-out') && chip.find('.mdi-gavel').exists(),
      ),
    ).toBe(true)
    expect(
      chips.some(
        (chip) => chip.classes().includes('bg-absence-adjust') && chip.find('.mdi-wrench').exists(),
      ),
    ).toBe(true)
    expect(wrapper.find('[data-testid="phase-1"]').classes()).toContain('bg-zone-roster')
    expect(wrapper.find('[data-testid="phase-2"]').classes()).toContain('bg-zone-game')
  })

  // Test Basis: subtask_1787d 差し戻し修正（r2） 3
  it('試合日の新規登録ボタンは action の塗りと追加アイコンを持つ', async () => {
    const wrapper = await mountComponent([], { gameDayActions: true })
    const button = wrapper.find('.v-btn.bg-action')
    expect(button.exists()).toBe(true)
    expect(button.classes()).toContain('v-btn--variant-flat')
    expect(button.find('.mdi-plus').exists()).toBe(true)
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b1-22〜b1-24
  it('残り2以下は復帰間近の色、アイコン、行 class を使い、削除は danger-ink', async () => {
    const wrapper = await mountComponent([
      makeAbsence(1, '復帰間近', '2026-04-13'),
      makeAbsence(2, 'まだ離脱中', '2026-04-14'),
    ])
    const rows = wrapper.findAll('.v-data-table tbody tr')
    const near = rows.find((row) => row.text().includes('復帰間近'))!
    const far = rows.find((row) => row.text().includes('まだ離脱中'))!
    const nearChip = near
      .findAllComponents(components.VChip)
      .find((chip) => chip.text().includes('2'))!
    const farChip = far
      .findAllComponents(components.VChip)
      .find((chip) => chip.text().includes('3'))!
    expect(nearChip.props('color')).toBe('state-done')
    expect(nearChip.props('variant')).toBe('flat')
    expect(nearChip.props('prependIcon')).toBe('mdi-clock-check-outline')
    expect(near.classes()).toContain('bg-state-done')
    expect(farChip.props('color')).toBeUndefined()
    expect(farChip.props('variant')).toBe('text')
    expect(far.classes()).not.toContain('bg-state-done')
    expect(
      near
        .findAllComponents(components.VBtn)
        .find((button) => button.props('color') === 'danger-ink'),
    ).toBeDefined()
  })

  it('怪我中はactiveに分類すること', async () => {
    const wrapper = await mountComponent([injured])

    expect(tableText(wrapper, 0)).toContain('怪我中')
    await expandPastAbsences(wrapper)
    expect(tableText(wrapper, 1)).not.toContain('怪我中')
  })

  it('復帰当日はpastに分類すること', async () => {
    const wrapper = await mountComponent([returnDay])

    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(true)
    expect(currentText(wrapper)).not.toContain('復帰当日')
    await expandPastAbsences(wrapper)
    expect(pastText(wrapper)).toContain('復帰当日')
  })

  it('復帰後はpastに分類すること', async () => {
    const wrapper = await mountComponent([recovered])

    expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(true)
    expect(currentText(wrapper)).not.toContain('復帰後')
    await expandPastAbsences(wrapper)
    expect(pastText(wrapper)).toContain('復帰後')
  })

  it('終了日不明の離脱はactiveに分類すること', async () => {
    const wrapper = await mountComponent([permanent])

    expect(tableText(wrapper, 0)).toContain('永続離脱')
    await expandPastAbsences(wrapper)
    expect(tableText(wrapper, 1)).not.toContain('永続離脱')
  })

  // 離脱の区分（試合前 / 試合中。裁定 AMB-25）
  describe('区分（phase）', () => {
    const dialogProps = (wrapper: Awaited<ReturnType<typeof mountComponent>>) =>
      wrapper.findComponent({ name: 'PlayerAbsenceFormDialog' }).props() as Record<string, unknown>

    it('追加ダイアログへ渡す区分の既定値は試合前', async () => {
      const wrapper = await mountComponent([])
      expect(dialogProps(wrapper).initialPhase).toBe('pre_game')
    })

    it('defaultPhase=in_game を渡すと、ダイアログへ試合中が渡る', async () => {
      const wrapper = await mountComponent([], { defaultPhase: 'in_game' })
      expect(dialogProps(wrapper).initialPhase).toBe('in_game')
    })

    it('一覧に区分（試合前 / 試合中）が出る。現在の離脱者・過去の履歴の両方', async () => {
      const mid: PlayerAbsence = {
        ...makeAbsence(5, '試合中の人', '2026-04-14'),
        phase: 'in_game',
        effective_start_date: '2026-04-11',
      }
      const wrapper = await mountComponent([mid, { ...recovered, phase: 'in_game' }])
      expect(tableText(wrapper, 0)).toContain('enums.player_absence.phase.in_game')
      expect(tableText(wrapper, 0)).not.toContain('enums.player_absence.phase.pre_game')

      await expandPastAbsences(wrapper)
      expect(tableText(wrapper, 1)).toContain('enums.player_absence.phase.in_game')
      expect(tableText(wrapper, 0)).toContain('playerAbsenceHistory.tableHeaders.phase')
    })

    it('試合前の離脱は試合前と表示される', async () => {
      const wrapper = await mountComponent([injured])
      expect(wrapper.find('[data-testid="phase-1"]').text()).toBe(
        'enums.player_absence.phase.pre_game',
      )
    })

    // 現在日 4/11、試合日 D=4/11 に N=3 日（試合前なら 4/11〜4/13 で 4/14 復帰、試合中なら 4/12〜4/14 で 4/15 復帰）
    const remaining = async (absence: PlayerAbsence, currentDate: string) => {
      const wrapper = await mountComponent([absence], {}, { current_date: currentDate })
      return tableText(wrapper, 0).match(/(\d+)enums\.player_absence\.duration_unit\.days/)?.[1]
    }
    const base = makeAbsence(7, '残り日数', '2026-04-14')

    it('残り日数: 試合前は現在日から復帰日まで（D で 3）', async () => {
      expect(
        await remaining(
          { ...base, start_date: '2026-04-11', effective_start_date: '2026-04-11' },
          '2026-04-11',
        ),
      ).toBe('3')
    })

    it('残り日数: 試合中は試合日 D に見ても N（D を離脱に数えない）、D+1 でも N、D+2 で N-1', async () => {
      const mid = {
        ...base,
        phase: 'in_game' as const,
        start_date: '2026-04-11',
        effective_start_date: '2026-04-12',
        effective_end_date: '2026-04-15',
      }
      expect(await remaining(mid, '2026-04-11')).toBe('3')
      expect(await remaining(mid, '2026-04-12')).toBe('3')
      expect(await remaining(mid, '2026-04-13')).toBe('2')
      expect(await remaining(mid, '2026-04-14')).toBe('1')
    })
  })

  // 過去分の修正・操作範囲（cmd_1784 段2b）と、変更の通知（emit('changed')。試合日ページの段の件数が取り直す）
  // Test Basis: context/thbig-dugout-season-record-restructure-design.md の 2026-11-01 の追記 2 本、queue/reviews/subtask_1783v.yaml（M15）
  describe('日付の指定・読み取り専用・変更の通知', () => {
    const dialogProps = (wrapper: Awaited<ReturnType<typeof mountComponent>>) =>
      wrapper.findComponent({ name: 'PlayerAbsenceFormDialog' }).props() as Record<string, unknown>

    it('asOfDate の日に有効な離脱を「現在の離脱者」に出す（シーズンの現在日ではない）', async () => {
      // 4/12 が復帰日の離脱: 現在日(4/11)なら現在の離脱者、4/12 以降なら過去の履歴
      const wrapper = await mountComponent([injured], { asOfDate: '2026-04-12' })
      expect(wrapper.find('[data-testid="state-empty"]').exists()).toBe(true)
      expect(currentText(wrapper)).not.toContain('怪我中')
      const earlier = await mountComponent([injured], { asOfDate: '2026-04-05' })
      expect(tableText(earlier, 0)).toContain('怪我中')
    })

    it('新規登録の開始日の既定は asOfDate（無ければシーズンの現在日）', async () => {
      const withDate = await mountComponent([], { asOfDate: '2026-04-05' })
      expect(dialogProps(withDate).initialStartDate).toBe('2026-04-05')
      const withoutDate = await mountComponent([])
      expect(dialogProps(withoutDate).initialStartDate).toBe('2026-04-11')
    })

    it('readonly: 追加・編集・削除のボタンを出さず、離脱者の一覧は見える', async () => {
      const wrapper = await mountComponent([injured], { readonly: true })
      expect(wrapper.find('[data-testid="add-absence"]').exists()).toBe(false)
      expect(wrapper.find('[data-testid="edit-absence"]').exists()).toBe(false)
      expect(wrapper.find('[data-testid="delete-absence"]').exists()).toBe(false)
      expect(tableText(wrapper, 0)).toContain('怪我中')
    })

    it('readonly でなければ、追加・編集・削除のボタンがある（対照）', async () => {
      const wrapper = await mountComponent([injured])
      expect(wrapper.find('[data-testid="add-absence"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="edit-absence"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="delete-absence"]').exists()).toBe(true)
    })

    it('離脱を削除したら changed を出し、離脱の一覧を取り直す', async () => {
      vi.stubGlobal(
        'confirm',
        vi.fn(() => true),
      )
      vi.mocked(axios.delete).mockResolvedValue({ data: {} })
      const wrapper = await mountComponent([injured])
      const listCalls = () =>
        vi.mocked(axios.get).mock.calls.filter(([url]) => url === '/player_absences').length
      const before = listCalls()

      await wrapper.find('[data-testid="delete-absence"]').trigger('click')
      await flushPromises()

      expect(axios.delete).toHaveBeenCalledWith('/player_absences/1')
      expect(wrapper.emitted('changed')).toHaveLength(1)
      expect(listCalls()).toBe(before + 1)
      vi.unstubAllGlobals()
    })

    it('削除の確認で取り消したら、何も消さず changed も出さない', async () => {
      vi.stubGlobal(
        'confirm',
        vi.fn(() => false),
      )
      const wrapper = await mountComponent([injured])

      await wrapper.find('[data-testid="delete-absence"]').trigger('click')
      await flushPromises()

      expect(axios.delete).not.toHaveBeenCalled()
      expect(wrapper.emitted('changed')).toBeUndefined()
      vi.unstubAllGlobals()
    })

    it('離脱の保存（ダイアログの saved）でも changed を出す', async () => {
      const wrapper = await mountComponent([injured])

      wrapper.findComponent({ name: 'PlayerAbsenceFormDialog' }).vm.$emit('saved')
      await flushPromises()

      expect(wrapper.emitted('changed')).toHaveLength(1)
    })
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（<600px は縦積み）/ §2.4（行の操作はアイコンボタン）/ §2.7（状態）/ §4.2 段 4
describe('SeasonAbsenceTab 表のスマホ対応と状態（段 4）', () => {
  it('現在の離脱者: 縦積み（選手名=title・種別=sub1・区分=sub2・残り=note（見出し付き）・操作=act）', async () => {
    const wrapper = await mountComponent([injured])
    expect(stackedLayout(wrapper, 'remaining')).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: {
        player_name: 'title',
        absence_type: 'sub1',
        phase: 'sub2',
        remaining: 'note',
        actions: 'act',
      },
    })
  })

  it('残り・復帰日は値だけでは何か分からないので、見出しを値の前に出す（labeled）', async () => {
    const wrapper = await mountComponent([injured, recovered])
    await expandPastAbsences(wrapper)
    const labeled = (key: string) =>
      (
        dataTables(wrapper)
          .map((t) => t.props('headers') as { key: string; cellProps?: { class: string } }[])
          .flat()
          .find((h) => h.key === key)?.cellProps?.class ?? ''
      ).includes('ui-cell--labeled')
    expect(labeled('remaining')).toBe(true)
    expect(labeled('effective_end_date')).toBe(true)
    expect(labeled('absence_type')).toBe(false)
  })

  it('過去の履歴: 縦積み（選手名=title・種別=sub1・区分=sub2・復帰日=note）', async () => {
    const wrapper = await mountComponent([injured, recovered])
    await expandPastAbsences(wrapper)
    expect(stackedLayout(wrapper, 'effective_end_date')).toEqual({
      mobileBreakpoint: 'sm',
      rows: true,
      roles: {
        player_name: 'title',
        absence_type: 'sub1',
        phase: 'sub2',
        effective_end_date: 'note',
      },
    })
  })

  it('編集・削除は .row-actions のアイコンボタン（名前つき・削除は danger）。既存の data-testid は保つ', async () => {
    const wrapper = await mountComponent([injured])
    const actions = wrapper.find('.row-actions')
    const edit = actions.find('[data-testid="edit-absence"]')
    const del = actions.find('[data-testid="delete-absence"]')
    expect(edit.attributes('aria-label')).toContain('seasonAbsenceTab.editAbsence')
    expect(del.attributes('aria-label')).toContain('seasonAbsenceTab.deleteAbsence')
    expect(del.classes().join(' ')).toContain('text-danger-ink')
  })

  it('取得中はスケルトン、現在の離脱者が 0 件なら空状態、取得に失敗したらアラート＋再読み込み', async () => {
    vi.mocked(axios.get).mockReturnValue(new Promise(() => {}))
    const loading = mount(SeasonAbsenceTab, {
      props: { teamId: 1 },
      global: { plugins: [vuetify, i18n] },
    })
    await flushPromises()
    expect(loading.find('[data-testid="state-loading"]').exists()).toBe(true)
    expect(loading.find('[data-testid="state-empty"]').exists()).toBe(false)

    const empty = await mountComponent([])
    expect(empty.find('[data-testid="state-empty"]').exists()).toBe(true)

    vi.mocked(axios.get).mockRejectedValueOnce(new Error('network'))
    const failed = mount(SeasonAbsenceTab, {
      props: { teamId: 1 },
      global: { plugins: [vuetify, i18n] },
    })
    await flushPromises()
    expect(failed.find('[data-testid="state-error"]').exists()).toBe(true)
    expect(failed.find('[data-testid="state-empty"]').exists()).toBe(false)
  })

  it('再読み込みで取り直して表を出す', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('network'))
    const wrapper = mount(SeasonAbsenceTab, {
      props: { teamId: 1 },
      global: { plugins: [vuetify, i18n], stubs: { PlayerAbsenceFormDialog: true } },
    })
    await flushPromises()
    vi.mocked(axios.get).mockImplementation((url: string) =>
      Promise.resolve({ data: url === '/teams/1/season' ? season : [injured] }),
    )
    await wrapper.find('[data-testid="state-retry"]').trigger('click')
    await flushPromises()
    expect(wrapper.find('[data-testid="state-error"]').exists()).toBe(false)
    expect(wrapper.text()).toContain('怪我中')
  })
})
