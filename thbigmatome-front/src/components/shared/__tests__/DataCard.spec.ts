import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import DataCard from '../DataCard.vue'

const vuetify = createVuetify({ components, directives })

describe('DataCard', () => {
  it('タイトルが表示されること', () => {
    const wrapper = mount(DataCard, {
      global: { plugins: [vuetify] },
      props: { title: 'カードタイトル' },
    })
    expect(wrapper.text()).toContain('カードタイトル')
  })

  it('デフォルトスロットのコンテンツが描画されること', () => {
    const wrapper = mount(DataCard, {
      global: { plugins: [vuetify] },
      props: { title: 'カード' },
      slots: { default: '<p>メインコンテンツ</p>' },
    })
    expect(wrapper.text()).toContain('メインコンテンツ')
  })

  it('title-actionsスロットが描画されること', () => {
    const wrapper = mount(DataCard, {
      global: { plugins: [vuetify] },
      props: { title: 'カード' },
      slots: { 'title-actions': '<button>追加</button>' },
    })
    expect(wrapper.text()).toContain('追加')
  })

  it('footerスロットが描画されること', () => {
    const wrapper = mount(DataCard, {
      global: { plugins: [vuetify] },
      props: { title: 'カード' },
      slots: { footer: '<div>フッター</div>' },
    })
    expect(wrapper.text()).toContain('フッター')
  })

  // Test Basis: thbig-dugout-ui-unification-design.md §2.1（タブと同じ語をカード見出しで繰り返さない）
  it('タイトルが空で操作も無ければ、見出しの行を出さない', () => {
    const wrapper = mount(DataCard, {
      global: { plugins: [vuetify] },
      props: { title: '' },
      slots: { default: '<p>本文</p>' },
    })
    expect(wrapper.find('.v-card-title').exists()).toBe(false)
    expect(wrapper.text()).toContain('本文')
  })

  it('タイトルが空でも title-actions があれば、見出しの行を出す', () => {
    const wrapper = mount(DataCard, {
      global: { plugins: [vuetify] },
      props: { title: '' },
      slots: { 'title-actions': '<button>追加</button>' },
    })
    expect(wrapper.find('.v-card-title').exists()).toBe(true)
    expect(wrapper.text()).toContain('追加')
  })
})
