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

async function mountComponent(absences: PlayerAbsence[]) {
  vi.mocked(axios.get).mockImplementation((url: string) => {
    if (url === '/teams/1/season') {
      return Promise.resolve({ data: season })
    }
    if (url === '/player_absences') {
      return Promise.resolve({ data: absences })
    }
    return Promise.reject(new Error(`Unexpected GET ${url}`))
  })

  const wrapper = mount(SeasonAbsenceTab, {
    props: { teamId: 1 },
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
})
