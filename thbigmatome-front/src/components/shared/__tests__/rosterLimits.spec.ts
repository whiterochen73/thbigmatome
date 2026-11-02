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
  outsideWorldBreakdownFromKinds,
  formatOutsideWorldBreakdown,
  outsideWorldImbalance,
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

// Test Basis: Operator 決定 2026-11-02（cmd_1808）AMB-29 再改訂。4 人以上のとき投手側・野手側が 1 人以上ずつ。3 人以下は内訳を問わない
describe('outsideWorldLimitState（内訳つき）', () => {
  it('人数が上限以下でも内訳が外れたら ng', () => {
    expect(outsideWorldLimitState(4, 4, false)).toBe('ng')
    expect(outsideWorldLimitState(4, 4, true)).toBe('ok')
  })
  it('人数が上限超えなら内訳が良くても ng', () => {
    expect(outsideWorldLimitState(5, 4, true)).toBe('ng')
  })
  it('内訳を渡さない時は人数だけ', () => {
    expect(outsideWorldLimitState(4)).toBe('ok')
  })
})

describe('outsideWorldBreakdownFromKinds（1軍の入れ替えで数え直す）', () => {
  it('投・野・二刀流の数を数える。カードの無い選手（null）はどれにも数えない', () => {
    const b = outsideWorldBreakdownFromKinds(['pitcher_only', 'pitcher_only', 'fielder_only', null])
    expect(b).toMatchObject({ pitcher_only: 2, fielder_only: 1, two_way: 0 })
  })
  it('4 人全員が投手 → balance_ok false', () => {
    const b = outsideWorldBreakdownFromKinds(Array(4).fill('pitcher_only'))
    expect(b.balance_ok).toBe(false)
  })
  it('4 人全員が野手 → balance_ok false', () => {
    expect(outsideWorldBreakdownFromKinds(Array(4).fill('fielder_only')).balance_ok).toBe(false)
  })
  it('4 人で二刀流が 1 人いれば、残りが全員投手でも balance_ok true', () => {
    const b = outsideWorldBreakdownFromKinds([
      'two_way',
      'pitcher_only',
      'pitcher_only',
      'pitcher_only',
    ])
    expect(b.balance_ok).toBe(true)
  })
  it('投手 3・野手 1 → ok', () => {
    const b = outsideWorldBreakdownFromKinds([
      'pitcher_only',
      'pitcher_only',
      'pitcher_only',
      'fielder_only',
    ])
    expect(b.balance_ok).toBe(true)
  })
  it('3 人以下は内訳を問わず ok（全員投手でも）', () => {
    expect(outsideWorldBreakdownFromKinds(Array(3).fill('pitcher_only')).balance_ok).toBe(true)
    expect(outsideWorldBreakdownFromKinds([]).balance_ok).toBe(true)
  })
  it('4 人のうち 1 人がカード無し（null）で残り 3 人が投手 → 野手側が 0 で ng', () => {
    const b = outsideWorldBreakdownFromKinds(['pitcher_only', 'pitcher_only', 'pitcher_only', null])
    expect(b.balance_ok).toBe(false)
  })
})

describe('formatOutsideWorldBreakdown / outsideWorldImbalance', () => {
  const b = (pitcher_only: number, fielder_only: number, two_way: number, balance_ok: boolean) => ({
    pitcher_only,
    fielder_only,
    two_way,
    balance_ok,
  })
  it('全部の内訳は「投：n/野：n/二刀流：n」', () => {
    expect(formatOutsideWorldBreakdown(b(2, 1, 1, true))).toBe('投：2/野：1/二刀流：1')
    expect(formatOutsideWorldBreakdown(b(0, 0, 0, true))).toBe('投：0/野：0/二刀流：0')
  })
  it('投手 4 人 → 「投 4」、野手 4 人 → 「野 4」。足りない側（野 0）は出さない', () => {
    expect(outsideWorldImbalance(b(4, 0, 0, false))).toMatchObject({
      side: 'pitcher',
      label: '投 4',
    })
    expect(outsideWorldImbalance(b(0, 4, 0, false))).toMatchObject({
      side: 'fielder',
      label: '野 4',
    })
  })
  it('規定内は null（ふだんは内訳を出さない）', () => {
    expect(outsideWorldImbalance(b(4, 0, 0, true))).toBeNull()
    expect(outsideWorldImbalance(b(2, 2, 0, true))).toBeNull()
  })
  it('どちらにも数えられる人がいない（全員カード無し）は添える側が無いので null', () => {
    expect(outsideWorldImbalance(b(0, 0, 0, false))).toBeNull()
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
