import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import AsOfDateBar from '../AsOfDateBar.vue'
import ja from '@/locales/ja.json'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

// Test Basis: Operator 2026-11-01「過去分の修正の説明文は意味が取りづらく、AI がやりがちな余計な説明に見える」
describe('AsOfDateBar', () => {
  it('操作の仕組みを説明する文を出さない。日付・区分・現在日に戻すは残る', () => {
    const wrapper = mount(AsOfDateBar, {
      props: { date: '2026-05-01', phase: 'pre_game', showPhase: true, currentDate: '2026-05-09' },
      global: { plugins: [vuetify, i18n] },
    })
    const text = wrapper.text()
    expect(text).not.toContain('選んだ日付')
    expect(text).not.toContain('違反した日付が出ます')
    expect(wrapper.find('.text-caption').exists()).toBe(false)
    expect(text).toContain('過去分の修正')
    expect(wrapper.find('[data-testid="as-of-date"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="as-of-phase"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="as-of-reset"]').exists()).toBe(true)
  })

  it('i18n キー asOfBar.hint ごと消えている（ロケールにもソースにも残さない）', () => {
    expect(ja.asOfBar).not.toHaveProperty('hint')
    const source = readFileSync(
      resolve(process.cwd(), 'src/components/season/AsOfDateBar.vue'),
      'utf8',
    )
    expect(source).not.toContain('asOfBar.hint')
  })
})
