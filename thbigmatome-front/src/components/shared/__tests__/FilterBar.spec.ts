import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
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
})
