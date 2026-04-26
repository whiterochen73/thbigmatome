import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createI18n } from 'vue-i18n'
import PromotionHistoryTab from '../PromotionHistoryTab.vue'

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
      promotionHistory: {
        noHistory: '履歴なし',
        promote: '昇格',
        demote: '降格',
        headers: { date: '日付', player: '選手', type: '区分' },
      },
    },
  },
})

function mountComponent(props = {}) {
  return mount(PromotionHistoryTab, {
    props: { teamId: 1, seasonId: 2, ...props },
    global: {
      plugins: [i18n],
      stubs: {
        VProgressCircular: true,
        VTable: { template: '<table><slot /></table>' },
        VChip: { template: '<span><slot /></span>' },
        PlayerNameLink: {
          props: ['playerName'],
          template: '<span>{{ playerName }}</span>',
        },
      },
    },
  })
}

describe('PromotionHistoryTab', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('seasonId=nullではfetchせず履歴なしを表示する', async () => {
    const wrapper = mountComponent({ seasonId: null })
    await flushPromises()

    expect(axios.get).not.toHaveBeenCalled()
    expect(wrapper.text()).toContain('履歴なし')
  })

  it('昇格/降格履歴を日付降順で表示する', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: {
        changes: [
          { type: 'promote', player_id: 1, player_name: '霊夢', number: '1', date: '2026-04-01' },
          { type: 'demote', player_id: 2, player_name: '魔理沙', number: '2', date: '2026-04-03' },
        ],
      },
    })
    const wrapper = mountComponent()
    await flushPromises()

    expect(axios.get).toHaveBeenCalledWith('/teams/1/roster_changes', { params: { season_id: 2 } })
    const text = wrapper.text()
    expect(text.indexOf('魔理沙')).toBeLessThan(text.indexOf('霊夢'))
    expect(text).toContain('昇格')
    expect(text).toContain('降格')
  })

  it('日付をmonth/day形式で表示する', async () => {
    vi.mocked(axios.get).mockResolvedValueOnce({
      data: {
        changes: [
          { type: 'promote', player_id: 1, player_name: '霊夢', number: '1', date: '2026-04-09' },
        ],
      },
    })
    const wrapper = mountComponent()
    await flushPromises()

    expect(wrapper.text()).toContain('4月9日')
  })

  it('seasonId変更で再fetchする', async () => {
    vi.mocked(axios.get).mockResolvedValue({ data: { changes: [] } })
    const wrapper = mountComponent({ seasonId: 2 })
    await flushPromises()

    await wrapper.setProps({ seasonId: 3 })
    await flushPromises()

    expect(axios.get).toHaveBeenCalledTimes(2)
    expect(axios.get).toHaveBeenLastCalledWith('/teams/1/roster_changes', {
      params: { season_id: 3 },
    })
  })

  it('APIエラー時もクラッシュせず履歴なしを表示する', async () => {
    vi.mocked(axios.get).mockRejectedValueOnce(new Error('network'))
    const wrapper = mountComponent()
    await flushPromises()

    expect(wrapper.text()).toContain('履歴なし')
  })
})
