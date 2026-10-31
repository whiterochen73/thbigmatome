import { expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import PitchingSkillDialog from '../PitchingSkillDialog.vue'
import BattingSkillDialog from '../BattingSkillDialog.vue'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', missingWarn: false, messages: { ja: {} } })

// Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b7-14〜b7-16, b7-21〜b7-23
it.each([PitchingSkillDialog, BattingSkillDialog])(
  '能力フォームの背景色は能力種別のトークンを返す',
  async (component) => {
    const wrapper = mount(component, {
      props: { modelValue: true, item: null },
      global: { plugins: [vuetify, i18n] },
    })
    for (const [skill_type, color] of [
      ['positive', 'state-info'],
      ['negative', 'state-todo'],
      ['neutral', 'state-neutral'],
    ]) {
      await wrapper.setProps({ item: { id: 1, name: 'テスト', description: null, skill_type } })
      expect(wrapper.findComponent(components.VSelect).props('bgColor')).toBe(color)
    }
  },
)
