import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import AtBatCard from '../AtBatCard.vue'

vi.mock('@/plugins/axios', () => ({
  default: {
    patch: vi.fn(),
    defaults: { baseURL: '', withCredentials: false, headers: { common: {} } },
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}))

import axios from '@/plugins/axios'

const vuetify = createVuetify({ components, directives })

const mockAb = {
  id: 1,
  game_record_id: 1,
  inning: 1,
  half: 'top' as const,
  ab_num: 1,
  batter_name: '博麗霊夢',
  pitcher_name: '霧雨魔理沙',
  result_code: 'K',
  runs_scored: 0,
  runners_before: [],
  runners_after: [],
  outs_before: 0,
  outs_after: 1,
  strategy: null,
  play_description: '三振',
  is_modified: false,
  is_reviewed: false,
  review_notes: null,
  modified_fields: null,
  discrepancies: [],
  source_events: null,
}

describe('AtBatCard', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('打者名と投手名が表示されること', () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'draft' },
    })
    expect(wrapper.text()).toContain('博麗霊夢')
    expect(wrapper.text()).toContain('霧雨魔理沙')
  })

  it('結果コードが表示されること', () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'draft' },
    })
    expect(wrapper.text()).toContain('K')
  })

  it('draft状態では編集ボタンが表示されること', () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'draft' },
    })
    expect(wrapper.text()).toContain('編集')
  })

  it('confirmed状態では編集ボタンが表示されないこと', () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'confirmed' },
    })
    expect(wrapper.text()).not.toContain('編集')
  })

  it('編集ボタンをクリックすると編集フォームが表示されること', async () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'draft' },
    })
    const editBtn = wrapper.findAll('button').find((b) => b.text().includes('編集'))
    expect(editBtn).toBeDefined()
    if (editBtn) {
      await editBtn.trigger('click')
      expect(wrapper.text()).toContain('保存')
      expect(wrapper.text()).toContain('キャンセル')
    }
  })

  it('キャンセルボタンで編集モードが終了すること', async () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'draft' },
    })
    const editBtn = wrapper.findAll('button').find((b) => b.text().includes('編集'))
    if (editBtn) {
      await editBtn.trigger('click')
      const cancelBtn = wrapper.findAll('button').find((b) => b.text().includes('キャンセル'))
      if (cancelBtn) {
        await cancelBtn.trigger('click')
        expect(wrapper.text()).not.toContain('キャンセル')
      }
    }
  })

  it('保存時にPATCHリクエストが送られ updated イベントが発火すること', async () => {
    const updatedAb = { ...mockAb, result_code: 'H', is_reviewed: true }
    vi.mocked(axios.patch).mockResolvedValue({ data: updatedAb })

    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: mockAb, gameStatus: 'draft' },
    })
    const editBtn = wrapper.findAll('button').find((b) => b.text().includes('編集'))
    if (editBtn) {
      await editBtn.trigger('click')
      const saveBtn = wrapper.findAll('button').find((b) => b.text().includes('保存'))
      if (saveBtn) {
        await saveBtn.trigger('click')
        await flushPromises()
        expect(axios.patch).toHaveBeenCalledWith(
          '/at_bat_records/1',
          expect.objectContaining({
            is_reviewed: true,
          }),
        )
        const emitted = wrapper.emitted('updated')
        expect(emitted).toBeTruthy()
        expect(emitted![0][0]).toEqual(updatedAb)
      }
    }
  })

  it('discrepancyがある場合バナーが表示されること', () => {
    const abWithDisc = {
      ...mockAb,
      discrepancies: [
        {
          field: 'runners_after',
          text_value: [1],
          gsm_value: [2],
          cause: 'unknown' as const,
          resolution: null,
        },
      ],
    }
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: abWithDisc, gameStatus: 'draft' },
    })
    expect(wrapper.text()).toContain('discrepancy 検出')
  })

  it('is_reviewed=trueの場合「確認済」バッジが表示されること', () => {
    const reviewedAb = { ...mockAb, is_reviewed: true }
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: reviewedAb, gameStatus: 'draft' },
    })
    expect(wrapper.text()).toContain('確認済')
  })
})
