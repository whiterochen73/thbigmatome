import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import GameDayRangeNote from '../GameDayRangeNote.vue'

// 範囲外の日の案内の配色。tonal の下地は兄弟要素で、light で 3.33:1 になり AA に届かなかった（cmd_1784 QC）。
// 役割色トークンの塗りつぶし（flat）は実測で light 7.04 / dark 7.46。文字・枠は on-state-info で揃える。
// 配色は jsdom では測れないので、ここでは作り（variant・トークン）が戻らないことだけを固定する。
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const mountNote = (props: Record<string, unknown>) =>
  mount(GameDayRangeNote, {
    props: props as { message: string },
    global: {
      plugins: [createVuetify({ components, directives }), i18n],
      stubs: { RouterLink: true },
    },
  })

describe('GameDayRangeNote', () => {
  it('message が空なら何も出さない', () => {
    expect(mountNote({ message: '' }).find('[data-testid="range-note"]').exists()).toBe(false)
  })

  it('state-info の塗りつぶし（flat）で出す。tonal には戻さない', () => {
    const alert = mountNote({ message: '範囲の外です' }).find('[data-testid="range-note"]')
    expect(alert.classes()).toContain('bg-state-info')
    expect(alert.classes()).toContain('v-alert--variant-flat')
    expect(alert.classes()).not.toContain('v-alert--variant-tonal')
  })

  it('リンクは to がある時だけ出し、枠は文字と同じ on-state-info にする', () => {
    expect(
      mountNote({ message: '範囲の外です' }).find('[data-testid="range-note-link"]').exists(),
    ).toBe(false)
    const link = mountNote({ message: '範囲の外です', to: { name: 'SeasonPortal' } }).find(
      '[data-testid="range-note-link"]',
    )
    expect(link.text()).toBe('シーズン画面で修正する')
    expect(link.attributes('style')).toContain('--v-theme-on-state-info')
  })
})
