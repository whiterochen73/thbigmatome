import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import PitcherRoleStateCell from '../PitcherRoleStateCell.vue'
import { roleStatusColor, roleStatusLabel } from '../pitcherRoleState'

const vuetify = createVuetify({ components, directives })

const mountCell = (state: { status: string; notes: string[] } | null) =>
  mount(PitcherRoleStateCell, {
    props: { state, testId: 'cell' },
    global: { plugins: [vuetify] },
  })

// 台帳 AMB-19 追補: 疲労P 0 と「最初から疲労状態」は別の状態。画面でも区別して出す（cmd_1775 第3段 E9）
describe('roleStatusLabel / roleStatusColor', () => {
  it('疲労P0（reduced_0）と最初から疲労状態（fatigued_start）は、ラベルも色も別', () => {
    expect(roleStatusLabel('reduced_0')).toBe('⚡ P0')
    expect(roleStatusLabel('fatigued_start')).toBe('🔥 最初から疲労')
    expect(roleStatusLabel('reduced_0')).not.toBe(roleStatusLabel('fatigued_start'))
    expect(roleStatusColor('reduced_0')).not.toBe(roleStatusColor('fatigued_start'))
  })

  it('累積3以上（fatigued_start_check）は「最初から疲労」と「負傷CK」の両方が見える', () => {
    const label = roleStatusLabel('fatigued_start_check')
    expect(label).toContain('最初から疲労')
    expect(label).toContain('負傷CK')
  })

  it('既存の値のラベル: full / injury_check / unavailable / injured / reduced_N', () => {
    expect(roleStatusLabel('full')).toBe('✅ 全快')
    expect(roleStatusLabel('injury_check')).toBe('⚠️ 負傷CK')
    expect(roleStatusLabel('unavailable')).toBe('🚫 不可')
    expect(roleStatusLabel('injured')).toBe('🏥 負傷中')
    expect(roleStatusLabel('reduced_3')).toBe('⚡ P-3')
  })

  // 台帳 AMB-22（2026-10-26 Operator）: 先発→リリーフの表より短い間隔はリリーフも登板不可。「規定なし」という状態は無い
  it('表より短い間隔は「不可」と同じ表示（規定なしの表示は無い）', () => {
    expect(roleStatusLabel('unavailable')).toBe('🚫 不可')
    expect(roleStatusLabel('no_rule')).toBe('no_rule')
    expect(roleStatusColor('unavailable')).toBe('error')
  })

  it('未知の値はそのまま返す（握りつぶさない）', () => {
    expect(roleStatusLabel('whatever')).toBe('whatever')
  })
})

describe('PitcherRoleStateCell', () => {
  it('状態のチップを出す', () => {
    const wrapper = mountCell({ status: 'fatigued_start', notes: [] })
    expect(wrapper.find('[data-testid="cell"]').text()).toContain('🔥 最初から疲労')
  })

  it('オープナーの負傷チェックの注記を出す（リリーフなら側）', () => {
    const wrapper = mountCell({ status: 'reduced_0', notes: ['opener_injury_check'] })
    expect(wrapper.text()).toContain('オープナーなら')
    expect(wrapper.text()).toContain('負傷チェック')
  })

  it('累積4以上で前日登板: 前日の負傷チェックに合格していれば1イニング限定で登板可、の注意書き', () => {
    const wrapper = mountCell({
      status: 'fatigued_start_check',
      notes: ['opener_injury_check', 'previous_day_one_inning_only'],
    })
    expect(wrapper.text()).toContain('前日の負傷チェックに合格していれば1イニング限定で登板可')
  })

  it('注記が無ければ注意書きは出ない', () => {
    const wrapper = mountCell({ status: 'full', notes: [] })
    expect(wrapper.text()).not.toContain('前日の負傷チェック')
    expect(wrapper.text()).not.toContain('オープナーなら')
  })

  it('省略（state が null）はチップを出さず「—」だけ', () => {
    const wrapper = mountCell(null)
    expect(wrapper.find('[data-testid="cell"]').text()).toBe('—')
    expect(wrapper.findComponent({ name: 'VChip' }).exists()).toBe(false)
  })
})
