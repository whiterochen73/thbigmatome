import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import vuetifyPlugin from '@/plugins/vuetify'
import {
  FIRST_SQUAD_MIN_PLAYERS,
  MAX_FIRST_SQUAD_PLAYERS,
  OUTSIDE_WORLD_LIMIT,
  costLimitForCount,
  costLimitState,
  countLimitState,
  outsideWorldLimitState,
  LIMIT_APPEARANCE,
} from '../rosterLimits'
import LimitMark from '../LimitMark.vue'

// Test Basis: cmd_1804 subtask_1804a Operator 要望 2026-11-02
// 規定の値は RosterConstraintChecker（FIRST_SQUAD_MAX=29・OUTSIDE_WORLD_LIMIT=4）と config/cost_limits.yml
describe('規定の値', () => {
  it('人数は 25〜29、外の世界枠は 4 まで', () => {
    expect(FIRST_SQUAD_MIN_PLAYERS).toBe(25)
    expect(MAX_FIRST_SQUAD_PLAYERS).toBe(29)
    expect(OUTSIDE_WORLD_LIMIT).toBe(4)
  })
  it('コスト上限は人数別。25 人 114・28 人以上 120。25 人未満は無し', () => {
    expect(costLimitForCount(24)).toBeNull()
    expect(costLimitForCount(25)).toBe(114)
    expect(costLimitForCount(26)).toBe(117)
    expect(costLimitForCount(27)).toBe(119)
    expect(costLimitForCount(28)).toBe(120)
    expect(costLimitForCount(29)).toBe(120)
  })
})

describe('costLimitState（上限ちょうどまで ok・超えたら ng）', () => {
  it('上限ちょうど=ok・上限+1=ng・上限-1=ok', () => {
    expect(costLimitState(114, 114)).toBe('ok')
    expect(costLimitState(115, 114)).toBe('ng')
    expect(costLimitState(113, 114)).toBe('ok')
  })
  it('途中の段階は無い（95% でも 99% でも ok）', () => {
    expect(costLimitState(109, 114)).toBe('ok')
    expect(costLimitState(113, 114)).toBe('ok')
  })
  it('上限が無い（null・0）時は判定しない', () => {
    expect(costLimitState(50, null)).toBeNull()
    expect(costLimitState(50, undefined)).toBeNull()
    expect(costLimitState(50, 0)).toBeNull()
  })
})

describe('countLimitState（下限 25・上限 29）', () => {
  it.each([
    [24, 'ng'],
    [25, 'ok'],
    [29, 'ok'],
    [30, 'ng'],
    [0, 'ng'],
  ])('%i 人 → %s', (n, expected) => {
    expect(countLimitState(n)).toBe(expected)
  })
})

describe('outsideWorldLimitState（0〜上限 4）', () => {
  it.each([
    [0, 'ok'],
    [3, 'ok'],
    [4, 'ok'],
    [5, 'ng'],
  ])('%i 人 → %s', (n, expected) => {
    expect(outsideWorldLimitState(n)).toBe(expected)
  })
  it('上限を引数で渡せる（API の outside_world_limit）', () => {
    expect(outsideWorldLimitState(2, 2)).toBe('ok')
    expect(outsideWorldLimitState(3, 2)).toBe('ng')
  })
})

describe('見た目', () => {
  it('ok=緑のチェック・ng=赤の✕で、記号が違う', () => {
    expect(LIMIT_APPEARANCE.ok.icon).toBe('mdi-check-circle')
    expect(LIMIT_APPEARANCE.ng.icon).toBe('mdi-close-circle')
    expect(LIMIT_APPEARANCE.ok.color).toBe('meter-ok')
    expect(LIMIT_APPEARANCE.ng.color).toBe('meter-ng')
  })
  // v-progress-linear・v-icon の color は bg-* / text-* のクラスになる。Vuetify が生成しない名前（on-* など）だと
  // 色が付かず、名前の文字列だけ見る spec をすり抜ける
  it.each(['ok', 'ng'] as const)('%s の色名はテーマ CSS に .bg-* と .text-* がある', (state) => {
    const css = vuetifyPlugin.theme.styles.value
    const name = LIMIT_APPEARANCE[state].color
    expect(name.startsWith('on-')).toBe(false)
    expect(css).toContain(`.bg-${name} `)
    expect(css).toContain(`.text-${name} `)
  })
})

describe('LimitMark', () => {
  const mountMark = (state: 'ok' | 'ng' | null) =>
    mount(LimitMark, {
      props: { state },
      global: { plugins: [createVuetify({ components })] },
    })
  it('ok はチェック、ng は ✕ のアイコンとクラス。色以外にも記号で区別できる', () => {
    const ok = mountMark('ok')
    expect(ok.attributes('data-state')).toBe('ok')
    expect(ok.classes()).toContain('mdi-check-circle')
    expect(ok.classes()).toContain('text-meter-ok')
    const ng = mountMark('ng')
    expect(ng.attributes('data-state')).toBe('ng')
    expect(ng.classes()).toContain('mdi-close-circle')
    expect(ng.classes()).toContain('text-meter-ng')
  })
  it('state が null なら何も描かない', () => {
    expect(mountMark(null).find('[data-testid="limit-mark"]').exists()).toBe(false)
  })
})
