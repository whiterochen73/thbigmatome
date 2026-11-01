import { afterEach, describe, expect, it } from 'vitest'
import { defineComponent, h, nextTick, ref } from 'vue'
import { mount } from '@vue/test-utils'
import {
  appBarTitle,
  clearAppBarTitle,
  setAppBarTitle,
  useAppBarTitle,
  type AppBarTitle,
} from '../useAppBarTitle'

function mountWith(source: () => AppBarTitle | null) {
  return mount(
    defineComponent({
      setup() {
        useAppBarTitle(source)
        return () => h('div')
      },
    }),
  )
}

afterEach(() => {
  appBarTitle.value = null
})

// Test Basis: subtask_1783q finding「owner 照合の変異が生存」（旧 useAppBarBreadcrumbs から引き継ぎ）
describe('appBarTitle の所有者管理', () => {
  it('新ページの登録後に旧ページの解除が走っても、新ページのタイトルを残す', () => {
    const oldOwner = Symbol('old-page')
    const newOwner = Symbol('new-page')
    const oldTitle = { title: '旧ページ', subtitle: 'a' }
    const newTitle = { title: '新ページ', subtitle: 'b' }

    setAppBarTitle(oldOwner, oldTitle)
    setAppBarTitle(newOwner, newTitle)
    clearAppBarTitle(oldOwner)
    expect(appBarTitle.value).toEqual(newTitle)

    clearAppBarTitle(newOwner)
    expect(appBarTitle.value).toBeNull()
  })
})

// Test Basis: thbig-dugout-ui-unification-design.md §4.1 useAppBarTitle（タイトル・サブタイトル・戻り先を AppBar に渡す）
describe('useAppBarTitle', () => {
  it('マウントで宣言し、値の変化に追従し、アンマウントで消す', async () => {
    const title = ref('豊玉')
    const wrapper = mountWith(() => ({
      title: title.value,
      subtitle: 'シーズン',
      back: { to: '/season', label: 'シーズン' },
    }))
    expect(appBarTitle.value).toEqual({
      title: '豊玉',
      subtitle: 'シーズン',
      back: { to: '/season', label: 'シーズン' },
    })
    title.value = '別チーム'
    await nextTick()
    expect(appBarTitle.value?.title).toBe('別チーム')
    wrapper.unmount()
    expect(appBarTitle.value).toBeNull()
  })

  it('source が null の間は宣言しない（自分が出していたタイトルも消す）', async () => {
    const ready = ref(false)
    const wrapper = mountWith(() => (ready.value ? { title: '豊玉' } : null))
    expect(appBarTitle.value).toBeNull()
    ready.value = true
    await nextTick()
    expect(appBarTitle.value).toEqual({ title: '豊玉' })
    ready.value = false
    await nextTick()
    expect(appBarTitle.value).toBeNull()
    wrapper.unmount()
  })

  it('画面を移る時、新しい画面の宣言を古い画面のアンマウントが消さない', () => {
    const oldPage = mountWith(() => ({ title: '旧' }))
    const newPage = mountWith(() => ({ title: '新' }))
    oldPage.unmount()
    expect(appBarTitle.value).toEqual({ title: '新' })
    newPage.unmount()
    expect(appBarTitle.value).toBeNull()
  })
})
