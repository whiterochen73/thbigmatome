import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import StatusChip from '../StatusChip.vue'

const vuetify = createVuetify({ components, directives })

describe('StatusChip', () => {
  it('labelプロップが表示されること', () => {
    const wrapper = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'active', label: 'アクティブ' },
    })
    expect(wrapper.text()).toContain('アクティブ')
  })

  it('デフォルトスロットが使われること', () => {
    const wrapper = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'active' },
      slots: { default: 'スロットテキスト' },
    })
    expect(wrapper.text()).toContain('スロットテキスト')
  })

  it('既知のstatusに対して正しいcolorが適用されること（active→success）', () => {
    const wrapper = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'active', label: 'active' },
    })
    const chip = wrapper.findComponent({ name: 'VChip' })
    expect(chip.props('color')).toBe('success')
  })

  it('未知のstatusはdefaultカラーになること', () => {
    const wrapper = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'unknown_status', label: 'unknown' },
    })
    const chip = wrapper.findComponent({ name: 'VChip' })
    expect(chip.props('color')).toBe('default')
  })

  // Test Basis: thbig-dugout-visual-refresh-design.md §6.1, §6.5, §7 段3
  it('負傷と出場停止は同じ absence-out で、アイコンと文字で見分ける', () => {
    const wrapper = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'injury', label: '負傷' },
    })
    const chip = wrapper.findComponent({ name: 'VChip' })
    expect(chip.props('color')).toBe('absence-out')
    expect(chip.props('prependIcon')).toBe('mdi-hospital-box')
    expect(chip.props('variant')).toBe('flat')
    expect(wrapper.text()).toContain('負傷')

    const suspended = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'suspension', label: '出場停止' },
    })
    const suspendedChip = suspended.findComponent({ name: 'VChip' })
    expect(suspendedChip.props('color')).toBe('absence-out')
    expect(suspendedChip.props('prependIcon')).toBe('mdi-gavel')
    expect(suspended.text()).toContain('出場停止')
  })

  it('commissioner→primaryマッピングが正しいこと', () => {
    const wrapper = mount(StatusChip, {
      global: { plugins: [vuetify] },
      props: { status: 'commissioner', label: 'コミッショナー' },
    })
    const chip = wrapper.findComponent({ name: 'VChip' })
    expect(chip.props('color')).toBe('primary')
  })
})
