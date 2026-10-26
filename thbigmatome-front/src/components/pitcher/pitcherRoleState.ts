// 投手ごとの「先発なら」「リリーフなら」「オープナーなら」の登板時の状態の表示（投手状態一覧・投手状態タブで共有）。
// サーバ（PitcherRestStatus.role_states）が返す status / notes の意味はそちらのコメントが正本。

export interface PitcherRoleState {
  status: string
  notes: string[]
}

// 「先発なら」「リリーフなら」「オープナーなら」を出さない理由（サーバが決める。null なら出す）
export type PitcherRoleOmittedReason =
  | 'relief_only_card'
  | 'relief_only_contract'
  | 'no_relief_stamina'
  | 'no_opener_ability' // 「オープナー可」アビリティを持たない（rulebook 08 §8.4.1）
  | null

export function roleStatusLabel(status: string): string {
  if (status === 'full') return '✅ 全快'
  if (status === 'injury_check') return '⚠️ 負傷CK'
  if (status === 'unavailable') return '🚫 不可'
  if (status === 'injured') return '🏥 負傷中'
  // 登板の最初から疲労状態（AMB-19 追補）。疲労P0（reduced_0）とは別の状態
  if (status === 'fatigued_start') return '🔥 最初から疲労'
  if (status === 'fatigued_start_check') return '🔥 最初から疲労 + ⚠️ 負傷CK'
  if (status.startsWith('reduced_')) {
    const n = status.replace('reduced_', '')
    return n === '0' ? '⚡ P0' : `⚡ P-${n}`
  }
  return status
}

export function roleStatusColor(status: string): string {
  if (status === 'full') return 'success'
  if (status === 'injury_check') return 'warning'
  if (status === 'unavailable' || status === 'injured') return 'error'
  if (status === 'fatigued_start') return 'deep-orange'
  if (status === 'fatigued_start_check') return 'deep-orange-darken-2'
  if (status.startsWith('reduced_')) return 'info'
  return 'default'
}

export function roleNoteLabel(note: string): string {
  // 「オープナーなら」列の負傷チェックの理由（rulebook 08 §8.4.3）。累積イニングは単位を付けない
  if (note === 'opener_check_consecutive') return '中2日以内の連続オープナー登板のため負傷チェック'
  if (note === 'opener_check_previous_day') return '前日登板のため負傷チェック'
  if (note === 'opener_check_cumulative') return '累積1以上のため負傷チェック'
  if (note === 'previous_day_one_inning_only')
    return '前日の負傷チェックに合格していれば1イニング限定で登板可'
  return note
}

// 「オープナーなら」の出し分けの根拠（サーバの opener_capable_source）。
// fallback_all_relievers = 「オープナー可」のデータが未取込のため、リリーフで投げられる投手全員に出している / card_ability = カードの記載どおり
export type OpenerCapableSource = 'fallback_all_relievers' | 'card_ability'

export const OPENER_FALLBACK_NOTICE =
  'オープナー可のデータ未取込のため、リリーフ可能な投手すべてに表示'

// フォールバック中なら「オープナーなら」見出しのツールチップ文言、そうでなければ undefined
export function openerHeaderTitle(
  rows: { opener_capable_source?: OpenerCapableSource }[],
): string | undefined {
  return rows.some((r) => r.opener_capable_source === 'fallback_all_relievers')
    ? OPENER_FALLBACK_NOTICE
    : undefined
}
