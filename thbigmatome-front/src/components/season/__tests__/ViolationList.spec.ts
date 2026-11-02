import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'
import ViolationList from '../ViolationList.vue'
import type { RosterViolation } from '@/types/rosterViolation'

const vuetify = createVuetify({ components, directives })
const i18n = createI18n({ legacy: false, locale: 'ja', messages: { ja } })

const violation = (over: Partial<RosterViolation> = {}): RosterViolation => ({
  date: '2026-05-03',
  phase: 'pre_game',
  kind: 'first_squad_min',
  message: '1軍が 24 人です',
  severity: 'error',
  player_id: null,
  ...over,
})

const mountList = (violations: RosterViolation[]) =>
  mount(ViolationList, { props: { violations }, global: { plugins: [vuetify, i18n] } })

// 保存が後の日付の検査で止まった時（422 の violations）に、違反した日付・区分・内容をそのまま出す。
// Test Basis: queue/reviews/subtask_1784i.yaml（後の日付を検査し直す仕組み）、cmd_1784 段2b の依頼（違反した日付と内容を画面に出す）
describe('ViolationList', () => {
  it('違反が無ければ何も出さない', () => {
    expect(mountList([]).find('[data-testid="violation-list"]').exists()).toBe(false)
  })

  it('日付は月/日（ゼロ埋めなし）、区分は試合前・試合中・試合後の文言で、内容を添えて 1 件 1 行で出す', () => {
    const wrapper = mountList([
      violation({ date: '2026-05-03', phase: 'pre_game', message: 'A' }),
      violation({ date: '2026-12-10', phase: 'in_game', message: 'B' }),
      violation({ date: '2026-06-01', phase: 'post_game', message: 'C' }),
    ])
    const lines = wrapper.findAll('li').map((li) => li.text().replace(/\s+/g, ' '))
    expect(lines).toEqual(['5/3（試合前）: A', '12/10（試合中）: B', '6/1（試合後）: C'])
  })

  it('知らない区分はそのまま出す', () => {
    const wrapper = mountList([violation({ phase: 'midnight' })])
    expect(wrapper.find('li').text()).toContain('（midnight）')
  })

  it('見出しで、保存できなかったことと後の日付が規定を外れることを伝える', () => {
    const wrapper = mountList([violation()])
    expect(wrapper.find('[data-testid="violation-list"]').text()).toContain(
      '保存できませんでした。後の日付が規定を外れます',
    )
  })
})
