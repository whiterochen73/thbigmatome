import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createWebHistory } from 'vue-router'
import PageHeader from '../PageHeader.vue'

const vuetify = createVuetify({ components, directives })
const router = createRouter({
  history: createWebHistory(),
  routes: [{ path: '/', component: { template: '<div />' } }],
})

describe('PageHeader', () => {
  it('タイトルが表示されること', () => {
    const wrapper = mount(PageHeader, {
      global: { plugins: [vuetify, router] },
      props: { title: 'テストページ' },
    })
    expect(wrapper.text()).toContain('テストページ')
  })

  it('backToなしの場合、戻るボタンが表示されないこと', () => {
    const wrapper = mount(PageHeader, {
      global: { plugins: [vuetify, router] },
      props: { title: 'テストページ' },
    })
    const btn = wrapper.findComponent({ name: 'VBtn' })
    expect(btn.exists()).toBe(false)
  })

  it('backTo指定時に戻るボタンが表示されること', () => {
    const wrapper = mount(PageHeader, {
      global: { plugins: [vuetify, router] },
      props: { title: 'テストページ', backTo: '/' },
    })
    const btn = wrapper.findComponent({ name: 'VBtn' })
    expect(btn.exists()).toBe(true)
  })

  it('actionsスロットが描画されること', () => {
    const wrapper = mount(PageHeader, {
      global: { plugins: [vuetify, router] },
      props: { title: 'テストページ' },
      slots: { actions: '<button>アクション</button>' },
    })
    expect(wrapper.text()).toContain('アクション')
  })
})
