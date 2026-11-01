import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import PageLayout from '../PageLayout.vue'

const vuetify = createVuetify({ components, directives })
const mountLayout = (props: Record<string, unknown> = {}, slots: Record<string, string> = {}) =>
  mount(PageLayout, { props, slots, global: { plugins: [vuetify] } })

// Test Basis: thbig-dugout-ui-unification-design.md §2.1（A〜E の骨格）/ §2.3（幅 3 段・余白）/ §2.4（主操作は右端）
describe('PageLayout', () => {
  it('既定の幅は default。width で narrow / wide に切り替わる', () => {
    expect(mountLayout().classes()).toContain('page-layout--default')
    expect(mountLayout({ width: 'narrow' }).classes()).toContain('page-layout--narrow')
    expect(mountLayout({ width: 'wide' }).classes()).toContain('page-layout--wide')
  })

  it('幅と余白の値は設計どおり（narrow 720 / default 1080 / wide 1440、左右 24px・スマホ 12px、ブロック間 16px）', () => {
    const source = readFileSync(
      resolve(process.cwd(), 'src/components/shared/PageLayout.vue'),
      'utf8',
    )
    const css = source.match(/<style scoped>([\s\S]*)<\/style>/)![1]!
    expect(css).toMatch(/--page-gutter:\s*24px/)
    expect(css).toMatch(/--page-width:\s*1080px/)
    expect(css).toMatch(/page-layout--narrow\s*\{\s*--page-width:\s*720px/)
    expect(css).toMatch(/page-layout--wide\s*\{\s*--page-width:\s*1440px/)
    expect(css).toMatch(/gap:\s*16px/)
    expect(css).toMatch(/@media \(max-width: 599\.98px\)[\s\S]*--page-gutter:\s*12px/)
  })

  it('スロットが無ければタブもツールバー行も出さず、本文だけを出す', () => {
    const wrapper = mountLayout({}, { default: '<p class="body">本文</p>' })
    expect(wrapper.find('[data-testid="page-tabs"]').exists()).toBe(false)
    expect(wrapper.find('[data-testid="page-toolbar"]').exists()).toBe(false)
    expect(wrapper.find('.body').exists()).toBe(true)
    expect(wrapper.find('h1').exists()).toBe(false)
  })

  it('タブ → ツールバー行（左=絞り込み、右=操作）→ 本文の順に並べる。帯（lead）はタブの前', () => {
    const wrapper = mountLayout(
      {},
      {
        lead: '<div id="lead" />',
        tabs: '<div id="tabs" />',
        filters: '<input id="filters" />',
        actions: '<button id="actions">追加</button>',
        default: '<div id="body" />',
      },
    )
    const html = wrapper.html()
    const order = ['id="lead"', 'id="tabs"', 'id="filters"', 'id="actions"', 'id="body"'].map((k) =>
      html.indexOf(k),
    )
    expect(order.every((i) => i >= 0)).toBe(true)
    expect([...order].sort((a, b) => a - b)).toEqual(order)
    const toolbar = wrapper.find('[data-testid="page-toolbar"]')
    expect(toolbar.find('.page-layout__filters #filters').exists()).toBe(true)
    expect(toolbar.find('.page-layout__actions #actions').exists()).toBe(true)
  })

  it('filters だけ・actions だけでもツールバー行を出し、無い側の枠は作らない', () => {
    const onlyActions = mountLayout({}, { actions: '<button>追加</button>' })
    expect(onlyActions.find('[data-testid="page-toolbar"]').exists()).toBe(true)
    expect(onlyActions.find('.page-layout__filters').exists()).toBe(false)
    const onlyFilters = mountLayout({}, { filters: '<input />' })
    expect(onlyFilters.find('.page-layout__actions').exists()).toBe(false)
  })

  it('骨格の中の v-card だけ縁つき・影なしにする（既定の変更は全画面に及ぶので当てない）', () => {
    const source = readFileSync(
      resolve(process.cwd(), 'src/components/shared/PageLayout.vue'),
      'utf8',
    )
    expect(source).toMatch(/:deep\(\.v-card\.v-card--variant-elevated\)[^}]*box-shadow:\s*none/)
    expect(source).toMatch(/:deep\(\.v-card\.v-card--variant-elevated\)[^}]*border:\s*1px solid/)
    const plugin = readFileSync(resolve(process.cwd(), 'src/plugins/vuetify.ts'), 'utf8')
    expect(plugin).toContain('VCard: { elevation: 1 }')
  })

  // Test Basis: cmd_1791 段 1 の実描画（スマホ幅の縦積み表: ソート方式の select が light で 3.45 だった）
  it('スマホの縦積み表の「ソート方式」ラベルは文字色と不透明度を決め、見出しの地色変更はその見出しに当てない', () => {
    const source = readFileSync(
      resolve(process.cwd(), 'src/components/shared/PageLayout.vue'),
      'utf8',
    )
    expect(source).toMatch(
      /\.v-data-table__td-sort-select \.v-field-label[^{]*\{[^}]*color:\s*rgb\(var\(--v-theme-on-surface-variant\)\);[^}]*opacity:\s*1/,
    )
    expect(source).toMatch(
      /\.ui-table \.v-data-table__th:not\(:has\(\.v-data-table__td-sort-select\)\)/,
    )
  })
})
