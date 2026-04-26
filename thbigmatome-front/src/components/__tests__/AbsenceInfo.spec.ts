import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import AbsenceInfo from '../AbsenceInfo.vue'
import type { PlayerAbsence } from '@/types/playerAbsence'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from 'axios'

const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  missingWarn: false,
  fallbackWarn: false,
  messages: {
    ja: {
      seasonPortal: {
        absenceInfo: '離脱情報',
        noAbsenceInfo: '離脱なし',
      },
      enums: {
        player_absence: {
          absence_type: { injury: '怪我', suspension: '出場停止', reconditioning: '再調整' },
          duration_unit: { days: '日', games: '試合' },
        },
      },
    },
  },
})

const absence = (overrides: Partial<PlayerAbsence>): PlayerAbsence => ({
  id: 1,
  team_membership_id: 1,
  season_id: 1,
  absence_type: 'injury',
  reason: '検査',
  start_date: '2026-04-01',
  duration: 10,
  duration_unit: 'days',
  effective_end_date: '2026-04-11',
  created_at: '',
  updated_at: '',
  player_name: '霊夢',
  player_id: 1,
  ...overrides,
})

const mountComponent = (props = {}) =>
  mount(AbsenceInfo, {
    props: { seasonId: 1, currentDate: '2026-04-05', ...props },
    global: {
      plugins: [i18n],
      stubs: {
        VRow: { template: '<div><slot /></div>' },
        VCol: { template: '<div><slot /></div>' },
        VAlert: { template: '<div><slot name="title" /><slot /></div>' },
        VIcon: true,
      },
    },
  })

describe('AbsenceInfo', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('seasonId=nullではfetchしない', async () => {
    mountComponent({ seasonId: null })
    await flushPromises()

    expect(axios.get).not.toHaveBeenCalled()
  })

  it('currentDate時点でactiveなdays離脱だけを表示する', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: [
        absence({
          player_name: '怪我中',
          start_date: '2026-04-01',
          duration: 10,
          duration_unit: 'days',
        }),
        absence({
          id: 2,
          player_name: '復帰済み',
          start_date: '2026-03-01',
          duration: 2,
          duration_unit: 'days',
        }),
      ],
    })
    const wrapper = mountComponent({ currentDate: '2026-04-05' })
    await flushPromises()

    expect(wrapper.text()).toContain('怪我中')
    expect(wrapper.text()).not.toContain('復帰済み')
  })

  it('表示形式に月日ロケールと期間単位を含める', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: [absence({ player_name: '魔理沙', duration: 3 })],
    })
    const wrapper = mountComponent({ currentDate: '2026-04-02' })
    await flushPromises()

    expect(wrapper.text()).toContain('4月2日')
    expect(wrapper.text()).toContain('4月1日から3日')
  })

  it('seasonId変更で再fetchする', async () => {
    vi.mocked(axios.get).mockResolvedValue({ data: [] })
    const wrapper = mountComponent({ seasonId: 1 })
    await flushPromises()

    await wrapper.setProps({ seasonId: 2 })
    await flushPromises()

    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(axios.get).toHaveBeenLastCalledWith('/player_absences', { params: { season_id: 2 } })
  })

  it('games離脱はeffective_end_dateの排他的境界で表示する', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: [absence({ duration_unit: 'games', effective_end_date: '2026-04-06', duration: 2 })],
    })
    const wrapper = mountComponent({ currentDate: '2026-04-06' })
    await flushPromises()

    expect(wrapper.text()).toContain('離脱なし')
  })
})
