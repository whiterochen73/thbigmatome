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

async function expandPastAbsences(wrapper: Awaited<ReturnType<typeof mountComponent>>) {
  await wrapper.find('.v-expansion-panel-title').trigger('click')
  await flushPromises()
}

describe('SeasonAbsenceTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('怪我中はactiveに分類すること', async () => {
    const wrapper = await mountComponent([injured])

    expect(tableText(wrapper, 0)).toContain('怪我中')
    await expandPastAbsences(wrapper)
    expect(tableText(wrapper, 1)).not.toContain('怪我中')
  })

  it('復帰当日はpastに分類すること', async () => {
    const wrapper = await mountComponent([returnDay])

    expect(tableText(wrapper, 0)).not.toContain('復帰当日')
    await expandPastAbsences(wrapper)
    expect(tableText(wrapper, 1)).toContain('復帰当日')
  })

  it('復帰後はpastに分類すること', async () => {
    const wrapper = await mountComponent([recovered])

    expect(tableText(wrapper, 0)).not.toContain('復帰後')
    await expandPastAbsences(wrapper)
    expect(tableText(wrapper, 1)).toContain('復帰後')
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
})
