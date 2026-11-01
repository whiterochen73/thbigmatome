import { describe, it, expect, afterEach } from 'vitest'
import { nextTick } from 'vue'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createRouter, createWebHistory } from 'vue-router'
import PageHeader from '../PageHeader.vue'
import { appBarShownTitle } from '@/composables/useAppBarTitle'

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

// Test Basis: cmd_1791 段 1「移していない画面の本文タイトルがバーと二重になる件」（バーが題を出している間は h1 を省く）
describe('PageHeader とヘッダーバーのタイトル', () => {
  afterEach(() => {
    appBarShownTitle.value = ''
  })

  const mountHeader = () =>
    mount(PageHeader, {
      global: { plugins: [vuetify, router] },
      props: { title: 'テストページ', backTo: '/' },
      slots: { actions: '<button id="act">アクション</button>' },
    })

  it('バーがタイトルを出している間は本文の h1 を省き、戻る・操作は残す', () => {
    appBarShownTitle.value = 'テストページ'
    const wrapper = mountHeader()
    expect(wrapper.find('h1').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('テストページ')
    expect(wrapper.find('#act').exists()).toBe(true)
    expect(wrapper.findComponent({ name: 'VBtn' }).exists()).toBe(true)
  })

  it('バーが題を出していない時（バーが無い場所・meta.title が無い画面）は従来どおり h1 を出す', () => {
    const wrapper = mountHeader()
    expect(wrapper.find('h1').text()).toBe('テストページ')
  })

  it('バーの題が変わると追従する', async () => {
    const wrapper = mountHeader()
    expect(wrapper.find('h1').exists()).toBe(true)
    appBarShownTitle.value = 'x'
    await nextTick()
    expect(wrapper.find('h1').exists()).toBe(false)
    appBarShownTitle.value = ''
    await nextTick()
    expect(wrapper.find('h1').exists()).toBe(true)
  })
})
