import { expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ConfirmDialog from '../ConfirmDialog.vue'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({
  legacy: false,
  locale: 'ja',
  messages: { ja: { actions: { cancel: '取消', ok: '確定' } } },
})

// Test Basis: thbig-dugout-visual-stage5-mapping.md §5.5 / §7 b2-15〜b2-26
it('通常は action flat、削除は danger-ink outlined と削除アイコンを使う', async () => {
  const wrapper = mount(ConfirmDialog, { global: { plugins: [vuetify, i18n] } })
  const dialog = wrapper.vm as unknown as {
    open: (title: string, message?: string, options?: { destructive?: boolean }) => Promise<boolean>
  }
  dialog.open('通常')
  await wrapper.vm.$nextTick()
  let button = wrapper.findAllComponents(components.VBtn).find((item) => item.text() === '確定')!
  expect(button.props('color')).toBe('action')
  expect(button.props('variant')).toBe('flat')
  expect(button.props('prependIcon')).toBeUndefined()
  dialog.open('削除', undefined, { destructive: true })
  await wrapper.vm.$nextTick()
  button = wrapper.findAllComponents(components.VBtn).find((item) => item.text() === '確定')!
  expect(button.props('color')).toBe('danger-ink')
  expect(button.props('variant')).toBe('outlined')
  expect(button.props('prependIcon')).toBe('mdi-delete-outline')
  dialog.open('次の通常確認')
  await wrapper.vm.$nextTick()
  button = wrapper.findAllComponents(components.VBtn).find((item) => item.text() === '確定')!
  expect(button.props('color')).toBe('action')
  expect(button.props('variant')).toBe('flat')
  expect(button.props('prependIcon')).toBeUndefined()
})
