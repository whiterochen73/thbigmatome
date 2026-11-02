import { describe, it, expect } from 'vitest'
import { defineComponent, h } from 'vue'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import { useColumnMinWidth } from '../useColumnMinWidth'

// Test Basis: thbig-dugout-ui-unification-design.md §2.5（列を落とせない表は横スクロール）。PC では指定せず、不要な横スクロールを出さない
const widthOf = (innerWidth: number) => {
  const original = window.innerWidth
  Object.defineProperty(window, 'innerWidth', { value: innerWidth, configurable: true })
  let result: number | undefined
  const wrapper = mount(
    defineComponent({
      setup() {
        result = useColumnMinWidth()(120)
        return () => h('div')
      },
    }),
    { global: { plugins: [createVuetify()] } },
  )
  wrapper.unmount()
  Object.defineProperty(window, 'innerWidth', { value: original, configurable: true })
  return result
}

describe('useColumnMinWidth', () => {
  it('Vuetify 4 の lg（1145px）未満（スマホ・タブレット・狭い PC）では指定した最小幅を返す', () => {
    expect(widthOf(390)).toBe(120)
    expect(widthOf(1144)).toBe(120)
  })

  it('lg（1145px）以上では undefined（列を詰めて収める）', () => {
    expect(widthOf(1145)).toBeUndefined()
    expect(widthOf(1280)).toBeUndefined()
    expect(widthOf(1920)).toBeUndefined()
  })
})
