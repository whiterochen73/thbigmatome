// ロスター・チーム編成の保存が後の日付の検査で止まった時（422）の違反 1 件。
// サーバ: RosterConstraintChecker::Violation#to_h（date は "YYYY-MM-DD"、phase は pre_game | in_game | post_game）
export interface RosterViolation {
  date: string
  phase: string
  kind: string
  message: string
  severity: string
  player_id: number | null
}
