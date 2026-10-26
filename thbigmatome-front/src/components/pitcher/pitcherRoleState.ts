// 投手ごとの「先発なら」「リリーフなら」の登板時の状態の表示（投手状態一覧・投手状態タブで共有）。
// サーバ（PitcherRestStatus.role_states）が返す status / notes の意味はそちらのコメントが正本。

export interface PitcherRoleState {
  status: string
  notes: string[]
}

// 「先発なら」「リリーフなら」を出さない理由（サーバが決める。null なら出す）
export type PitcherRoleOmittedReason =
  | 'relief_only_card'
  | 'relief_only_contract'
  | 'no_relief_stamina'
  | null

export function roleStatusLabel(status: string): string {
  if (status === 'full') return '✅ 全快'
  if (status === 'injury_check') return '⚠️ 負傷CK'
  if (status === 'unavailable') return '🚫 不可'
  if (status === 'injured') return '🏥 負傷中'
  // 登板の最初から疲労状態（AMB-19 追補）。疲労P0（reduced_0）とは別の状態
  if (status === 'fatigued_start') return '🔥 最初から疲労'
  if (status === 'fatigued_start_check') return '🔥 最初から疲労 + ⚠️ 負傷CK'
  // 表に載っていない中日数（§8.3.3 の P0 になる日より短い）。ルールに規定が無いので推測しない
  if (status === 'no_rule') return '規定なし'
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
  if (status === 'no_rule') return 'grey'
  if (status.startsWith('reduced_')) return 'info'
  return 'default'
}

export function roleNoteLabel(note: string): string {
  if (note === 'opener_injury_check') return 'オープナーなら: 累積1I以上のため負傷チェック'
  if (note === 'previous_day_one_inning_only')
    return '前日の負傷チェックに合格していれば1イニング限定で登板可'
  return note
}
