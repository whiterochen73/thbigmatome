import { expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import PitchingSkillSettings from '../PitchingSkillSettings.vue'
import BattingSkillSettings from '../BattingSkillSettings.vue'

vi.mock('@/components/settings/GenericMasterSettings.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      setup(_, { slots }) {
        return () =>
          h(
            'div',
            ['positive', 'negative', 'neutral'].flatMap(
              (skill_type) =>
                slots['item.name']?.({ item: { name: skill_type, skill_type } }) ?? [],
            ),
          )
      },
    }),
  }
})

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja: {} } })

// Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b7-10〜b7-13, b7-17〜b7-20
it.each([PitchingSkillSettings, BattingSkillSettings])(
  '能力名の三種を state-info/todo/neutral の flat チップにする',
  (component) => {
    const wrapper = mount(component, { global: { plugins: [vuetify, i18n] } })
    const chips = wrapper.findAllComponents(components.VChip)
    expect(chips).toHaveLength(3)
    expect(chips.map((chip) => chip.props('color'))).toEqual([
      'state-info',
      'state-todo',
      'state-neutral',
    ])
    chips.forEach((chip) => expect(chip.props('variant')).toBe('flat'))
  },
)
