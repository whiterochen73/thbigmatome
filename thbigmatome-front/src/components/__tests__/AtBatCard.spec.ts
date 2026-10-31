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

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b8-1〜b8-20
  it.each([
    [null, 'state-neutral'],
    ['K', 'state-warn'],
    ['K3', 'state-warn'],
    ['BB', 'state-info'],
    ['IBB', 'state-info'],
    ['HR', 'zone-game'],
    ['本塁打', 'zone-game'],
    ['H', 'state-done'],
    ['1B', 'state-done'],
    ['2B', 'state-done'],
    ['3B', 'state-done'],
    ['GO', 'state-neutral'],
  ])('結果 %s のヘッダーと展開部を %s flat で表示する', (result, color) => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: { ab: { ...mockAb, result_code: result }, gameStatus: 'draft' },
    })
    const chips = wrapper
      .findAllComponents(components.VChip)
      .filter((chip) => chip.text() === (result || '-'))
    expect(chips).toHaveLength(2)
    chips.forEach((chip) => {
      expect(chip.props('color')).toBe(color)
      expect(chip.props('variant')).toBe('flat')
    })
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b8-1〜b8-8, b8-15〜b8-20
  it.each([
    ['parser_misread', 'state-todo'],
    ['human_error', 'absence-cooldown'],
    ['gsm_limitation', 'state-info'],
    ['ambiguous', 'state-neutral'],
    ['unknown', 'state-warn'],
    ['other', 'state-neutral'],
  ] as const)('差異原因 %s を %s flat で表示する', (cause, color) => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: {
        ab: {
          ...mockAb,
          is_reviewed: true,
          is_modified: true,
          discrepancies: [
            { field: 'result_code', text_value: 'K', gsm_value: 'H', cause, resolution: null },
          ],
        },
        gameStatus: 'draft',
      },
    })
    const chips = wrapper.findAllComponents(components.VChip)
    const discrepancy = chips.find((chip) =>
      chip.text().includes(
        cause === 'other'
          ? 'other'
          : {
              parser_misread: 'パーサー誤読',
              human_error: 'ヒューマンエラー',
              gsm_limitation: 'GSM制限',
              ambiguous: '判定不能',
              unknown: '未分類',
            }[cause],
      ),
    )
    expect(discrepancy?.props('color')).toBe(color)
    expect(discrepancy?.props('variant')).toBe('flat')
    const warning = chips.find((chip) => chip.text().includes('差異あり'))
    expect(warning?.props('color')).toBe('state-warn')
    expect(warning?.props('variant')).toBe('flat')
    const reviewed = chips.find((chip) => chip.text().includes('確認済'))
    expect(reviewed?.props('color')).toBe('state-done')
    expect(reviewed?.props('variant')).toBe('flat')
    expect(
      wrapper
        .findAllComponents(components.VIcon)
        .find((icon) => icon.attributes('title') === '修正済み')
        ?.classes(),
    ).toContain('on-state-info')
    expect(
      wrapper
        .findAllComponents(components.VBtn)
        .find((button) => button.text() === '編集')
        ?.props('color'),
    ).toBe('link')
  })

  // Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b8-6〜b8-7
  it('解決済み差異は state-info flat のチップを表示する', () => {
    const wrapper = mount(AtBatCard, {
      global: { plugins: [vuetify] },
      props: {
        ab: {
          ...mockAb,
          discrepancies: [
            {
              field: 'result_code',
              text_value: 'K',
              gsm_value: 'H',
              cause: 'unknown' as const,
              resolution: 'manual',
            },
          ],
        },
        gameStatus: 'draft',
      },
    })
    const resolution = wrapper
      .findAllComponents(components.VChip)
      .find((chip) => chip.text() === '手動修正済')
    expect(resolution?.props('color')).toBe('state-info')
    expect(resolution?.props('variant')).toBe('flat')
  })
})
