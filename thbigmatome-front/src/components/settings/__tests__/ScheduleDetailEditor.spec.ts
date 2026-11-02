import { expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import axios from '@/plugins/axios'
import ScheduleDetailEditor from '../ScheduleDetailEditor.vue'

vi.mock('@/plugins/axios', () => ({ default: { get: vi.fn(), post: vi.fn() } }))

const vuetify = createVuetify({ components, directives, defaults: { VBtn: { variant: 'tonal' } } })
const i18n = createI18n({ legacy: false, locale: 'ja', missingWarn: false, messages: { ja: {} } })

// Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b7-2〜b7-9
it('日付凡例の七種を対応する flat チップとアイコンで示す', async () => {
  const wrapper = mount(ScheduleDetailEditor, {
    props: { modelValue: true, schedule: null },
    global: { plugins: [vuetify, i18n] },
  })
  await wrapper.vm.$nextTick()
  const chips = wrapper.findAllComponents(components.VChip)
  expect(chips).toHaveLength(7)
  expect(chips.map((chip) => chip.props('color'))).toEqual([
    'date-game',
    'date-interleague',
    'date-game',
    'date-travel',
    'date-reserve',
    'date-interleague',
    'state-neutral',
  ])
  expect(chips.map((chip) => chip.props('prependIcon'))).toEqual([
    'mdi-baseball-diamond',
    'mdi-swap-horizontal',
    'mdi-trophy',
    'mdi-bus',
    'mdi-calendar-clock',
    'mdi-swap-horizontal',
    'mdi-minus-circle-outline',
  ])
  chips.forEach((chip) => expect(chip.props('variant')).toBe('flat'))
})

// Test Basis: thbig-dugout-visual-stage5-mapping.md §7 b7-2〜b7-9
it('登録済みと未登録の日ボタンを flat variant で表示する', async () => {
  const today = new Date()
  const year = today.getFullYear()
  const month = today.getMonth()
  const startDate = new Date(year, month, 1)
  const endDate = new Date(year, month + 1, 0)
  const registeredDate = `${year}-${String(month + 1).padStart(2, '0')}-15`
  vi.mocked(axios.get).mockResolvedValue({
    data: [{ date: registeredDate, date_type: 'game_day' }],
  } as Awaited<ReturnType<typeof axios.get>>)

  const wrapper = mount(ScheduleDetailEditor, {
    props: {
      modelValue: true,
      schedule: {
        id: 1,
        name: 'test',
        start_date: startDate,
        end_date: endDate,
        effective_date: null,
      },
    },
    global: { plugins: [vuetify, i18n] },
  })
  await wrapper.vm.$nextTick()
  await new Promise((resolve) => setTimeout(resolve, 0))
  await wrapper.vm.$nextTick()

  const dayButtons = wrapper
    .findAllComponents(components.VBtn)
    .filter((button) => ['date-game', 'transparent'].includes(button.props('color') as string))
  const registeredButton = dayButtons.find((button) => button.props('color') === 'date-game')
  const unregisteredButton = dayButtons.find((button) => button.props('color') === 'transparent')
  expect(registeredButton).toBeDefined()
  expect(unregisteredButton).toBeDefined()
  expect(registeredButton?.props('variant')).toBe('flat')
  expect(unregisteredButton?.props('variant')).toBe('flat')
})
