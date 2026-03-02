import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import BattingTable from '../BattingTable.vue'

describe('BattingTable.vue', () => {
  const vuetify = createVuetify()

  const mockTable = [
    ['H1', 'K', 'G3', 'PO', '2H2'],
    ['BB', 'F9', 'H3a', 'K', 'G4D'],
    ['3H1', 'K', 'UP', 'PO', 'H2'],
  ]

  it('テーブルが正しくレンダリングされる', () => {
    const wrapper = mount(BattingTable, {
      props: {
        table: mockTable,
      },
      global: {
        plugins: [vuetify],
      },
    })

    // テーブルラッパーが存在することを確認
    const tableWrapper = wrapper.find('.batting-table-wrapper')
    expect(tableWrapper.exists()).toBe(true)
  })

  it('正しい行数と列数が表示される', () => {
    const wrapper = mount(BattingTable, {
      props: {
        table: mockTable,
      },
      global: {
        plugins: [vuetify],
      },
    })

    // Vuetify v-tableの場合、body rowsはv-tableの中に含まれる
    const rows = wrapper.findAll('tr')
    // ヘッダー1行 + データ3行 = 4行
    expect(rows.length).toBeGreaterThanOrEqual(4)
  })

  it('凡例が表示される', () => {
    const wrapper = mount(BattingTable, {
      props: {
        table: mockTable,
      },
      global: {
        plugins: [vuetify],
      },
    })

    const legend = wrapper.find('.d-flex.flex-wrap.ga-2')
    expect(legend.exists()).toBe(true)

    // 凡例の項目が存在することを確認
    const legendItems = legend.findAll('span.d-flex')
    expect(legendItems.length).toBeGreaterThan(0)
  })

  it('色分けクラスが適用される', () => {
    const wrapper = mount(BattingTable, {
      props: {
        table: mockTable,
      },
      global: {
        plugins: [vuetify],
      },
    })

    // テーブルのセルが適用される
    const cells = wrapper.findAll('td')
    // セルが存在することを確認
    expect(cells.length).toBeGreaterThan(0)

    // 少なくとも1つのセルに背景色クラスが適用されていることを確認
    const hasColorClass = cells.some((cell) => {
      const classes = cell.classes()
      return (
        classes.includes('bg-orange-lighten-4') ||
        classes.includes('bg-red-lighten-4') ||
        classes.includes('bg-green-lighten-4') ||
        classes.includes('bg-blue-lighten-4') ||
        classes.includes('bg-purple-lighten-4')
      )
    })
    expect(hasColorClass).toBe(true)
  })

  it('空の表でも正しくレンダリングされる', () => {
    const wrapper = mount(BattingTable, {
      props: {
        table: [],
      },
      global: {
        plugins: [vuetify],
      },
    })

    // テーブルラッパーが存在することを確認
    const tableWrapper = wrapper.find('.batting-table-wrapper')
    expect(tableWrapper.exists()).toBe(true)
  })
})
