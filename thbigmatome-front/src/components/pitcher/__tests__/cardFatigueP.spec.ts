import { describe, it, expect } from 'vitest'
import { cardFatiguePLabel } from '../pitcherRoleState'

// 表記の正本: thbig-rules/sources/card-structure.md §3（fatigue_p の全パターン）
describe('cardFatiguePLabel', () => {
  it('先発/リリーフ両用はスラッシュ形式「6/1」', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: 6, relief_stamina: 1, is_relief_only: false }),
    ).toBe('6/1')
  })

  it('リリーフ値 0 もスラッシュ形式で落とさない「7/0」', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: 7, relief_stamina: 0, is_relief_only: false }),
    ).toBe('7/0')
  })

  it('リリーフ専任（R 付き）は「1R」「0R」', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: null, relief_stamina: 1, is_relief_only: true }),
    ).toBe('1R')
    expect(
      cardFatiguePLabel({ starter_stamina: null, relief_stamina: 0, is_relief_only: true }),
    ).toBe('0R')
  })

  it('リリーフ専任なら starter_stamina が入っていても R 表記（リリーフ専任が優先）', () => {
    expect(cardFatiguePLabel({ starter_stamina: 5, relief_stamina: 2, is_relief_only: true })).toBe(
      '2R',
    )
  })

  it('先発のみは「6」', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: 6, relief_stamina: null, is_relief_only: false }),
    ).toBe('6')
  })

  it('リリーフ値だけ（R なし・0〜3 の単独記載）は「2」', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: null, relief_stamina: 2, is_relief_only: false }),
    ).toBe('2')
  })

  it('リリーフ専任だが relief_stamina が無いカードは「R」（数値を捏造しない）', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: null, relief_stamina: null, is_relief_only: true }),
    ).toBe('R')
  })

  it('値がどれも無い（野手・旧 API）は「-」', () => {
    expect(
      cardFatiguePLabel({ starter_stamina: null, relief_stamina: null, is_relief_only: false }),
    ).toBe('-')
    expect(cardFatiguePLabel({})).toBe('-')
  })
})
