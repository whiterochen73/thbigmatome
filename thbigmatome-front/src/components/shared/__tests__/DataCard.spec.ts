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
})
