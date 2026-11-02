import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import FilterBar from '../FilterBar.vue'

const vuetify = createVuetify({ components, directives })

describe('FilterBar', () => {
  it('searchスロットが描画されること', () => {
    const wrapper = mount(FilterBar, {
      global: { plugins: [vuetify] },
      slots: { search: '<input placeholder="検索" />' },
    })
    expect(wrapper.find('input').exists()).toBe(true)
  })

  it('filtersスロットが描画されること', () => {
    const wrapper = mount(FilterBar, {
      global: { plugins: [vuetify] },
      slots: { filters: '<span>フィルタ</span>' },
    })
    expect(wrapper.text()).toContain('フィルタ')
  })

  it('togglesスロットが描画されること', () => {
    const wrapper = mount(FilterBar, {
      global: { plugins: [vuetify] },
      slots: { toggles: '<button>切替</button>' },
    })
    expect(wrapper.text()).toContain('切替')
  })

  it('スロットなしの場合、v-colが表示されないこと', () => {
    const wrapper = mount(FilterBar, {
      global: { plugins: [vuetify] },
    })
    expect(wrapper.findAll('.v-col').length).toBe(0)
  })

  it('複数スロット同時指定で全て描画されること', () => {
    const wrapper = mount(FilterBar, {
      global: { plugins: [vuetify] },
      slots: {
        search: '<span>検索欄</span>',
        filters: '<span>フィルタ欄</span>',
        toggles: '<span>トグル欄</span>',
      },
    })
    expect(wrapper.text()).toContain('検索欄')
    expect(wrapper.text()).toContain('フィルタ欄')
    expect(wrapper.text()).toContain('トグル欄')
  })

  // Test Basis: subtask_1791o 申し送り（FilterBar が base.css の独自変数に頼る）/ docs: 色はテーマのトークンから取る
  it('色と縁はテーマのトークンから取り、base.css の独自変数（--bg-elevated など）に頼らない', () => {
    const source = readFileSync(
      resolve(process.cwd(), 'src/components/shared/FilterBar.vue'),
      'utf8',
    )
    const css = source.match(/<style scoped>([\s\S]*)<\/style>/)![1]!
    expect(css).not.toMatch(/var\(--(bg-elevated|border-light|shadow-card)\)/)
    expect(css).toMatch(/background:\s*rgb\(var\(--v-theme-surface\)\)/)
    expect(css).toMatch(
      /border:\s*1px solid rgba\(var\(--v-border-color\), var\(--v-border-opacity\)\)/,
    )
  })

  it('入力欄のラベルは on-surface-variant・不透明（既定の 0.6 は light で 3.57 まで落ちる）', () => {
    const source = readFileSync(
      resolve(process.cwd(), 'src/components/shared/FilterBar.vue'),
      'utf8',
    )
    const css = source.match(/<style scoped>([\s\S]*)<\/style>/)![1]!
    expect(css).toMatch(
      /\.filter-bar-wrap :deep\(\.v-field \.v-label\.v-field-label\)\s*\{\s*color:\s*rgb\(var\(--v-theme-on-surface-variant\)\);\s*opacity:\s*1/,
    )
  })
})
