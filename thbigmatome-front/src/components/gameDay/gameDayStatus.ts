// 試合日ページ（cmd_1783 段B）の「段ごとの状態」を決める純関数。
// 設計: context/thbig-dugout-game-day-flow-design.md §5.2。画面（GameResult・SeasonPortal）は結果をここから受け取るだけにする。
//
// 判定に使う値は「保存済みの値」。入力中（未保存）の値は dirty（編集中）として別に扱う。
// 保存前の入力で赤・済を出すと、保存し忘れて離れた時に「済」のまま残って見えるため。

export type StageState =
  | 'done' // 済 / 保存済み
  | 'none' // なし / 変更なし（無いことが正しい段。入力を求めない）
  | 'editing' // 編集中（未保存の入力がある）
  | 'todo' // 未入力（試合日が来ていて、入力が要る段）
  | 'warn' // 要確認（赤）
  | 'upcoming' // まだ（試合日が来ていない。急かさない）
  | 'info' // 別画面で行う段。状態は出さず、入口だけ置く

// 得点と登板記録の食い違い
export type RecordMismatch =
  | 'score_without_appearances' // 得点は保存済みだが登板記録が無い
  | 'appearances_without_score' // 登板記録はあるが得点が無い（ノーゲームを除く）
  | null

export interface SavedGameRecord {
  score: number | string | null | undefined
  opponentScore: number | string | null | undefined
  noGame: boolean | null | undefined
  appearanceCount: number
}

// 画面の入力欄は空欄を '' で持つことがある。0 は正当な得点なので、真偽で判定せず「数として読めるか」で見る
function isFilled(value: number | string | null | undefined): boolean {
  if (value === null || value === undefined) return false
  if (typeof value === 'string' && value.trim() === '') return false
  return Number.isFinite(Number(value))
}

// サーバ（SeasonSchedule#game_result_hash）は score と opponent_score の両方が入って初めて勝敗を出す。同じ条件にそろえる
export function hasSavedScore(
  score: number | string | null | undefined,
  opponentScore: number | string | null | undefined,
): boolean {
  return isFilled(score) && isFilled(opponentScore)
}

// 得点と登板記録の食い違い。ノーゲームは疲労・負傷は計算するが成績に入れない扱い（台帳 D-11）なので、
// 得点が無くても登板があれば正常。登板が無くても、ノーゲームで登板前に打ち切られた試合がありうるので食い違いにしない
function mismatchOf(scored: boolean, noGame: boolean, appearanceCount: number): RecordMismatch {
  if (noGame) return null
  const hasAppearances = appearanceCount > 0
  if (scored && !hasAppearances) return 'score_without_appearances'
  if (!scored && hasAppearances) return 'appearances_without_score'
  return null
}

export function detectRecordMismatch(record: SavedGameRecord): RecordMismatch {
  return mismatchOf(
    hasSavedScore(record.score, record.opponentScore),
    !!record.noGame,
    record.appearanceCount,
  )
}

interface StageContext {
  // 未保存の入力がある
  dirty: boolean
  // 試合日が来ている（試合日 <= シーズンの現在日）。来るまでは入力を急かさない
  arrived: boolean
}

// 結果（得点・ノーゲーム）の段
export function resultStageState(record: SavedGameRecord, ctx: StageContext): StageState {
  if (ctx.dirty) return 'editing'
  if (detectRecordMismatch(record) === 'appearances_without_score') return 'warn'
  if (record.noGame) return 'done'
  if (hasSavedScore(record.score, record.opponentScore)) return 'done'
  return ctx.arrived ? 'todo' : 'upcoming'
}

// 登板記録の段
export function pitcherStageState(record: SavedGameRecord, ctx: StageContext): StageState {
  if (ctx.dirty) return 'editing'
  if (detectRecordMismatch(record) !== null) return 'warn'
  if (record.appearanceCount > 0) return 'done'
  // ノーゲームで登板が無いのは、登板前に打ち切られた試合として正常（入力を求めない）
  if (record.noGame) return 'none'
  return ctx.arrived ? 'todo' : 'upcoming'
}

export interface SetupInput {
  announcedStarterId: number | null | undefined
  opponentTeamId: number | null | undefined
  // 結果（得点・ノーゲーム）が保存済みか
  resultSaved: boolean
}

// 予告先発・対戦設定の段。予告先発と相手が入っていれば済
export function setupStageState(input: SetupInput, ctx: StageContext): StageState {
  if (ctx.dirty) return 'editing'
  if (input.announcedStarterId && input.opponentTeamId) return 'done'
  // 結果まで保存済みの試合で、予告先発だけ空なのは今さら入れる意味が薄い。黄色で急かさない
  if (input.resultSaved) return 'none'
  return ctx.arrived ? 'todo' : 'upcoming'
}

export function mismatchMessageKey(mismatch: RecordMismatch): string | null {
  if (mismatch === 'score_without_appearances') return 'gameDay.mismatch.scoreWithoutAppearances'
  if (mismatch === 'appearances_without_score') return 'gameDay.mismatch.appearancesWithoutScore'
  return null
}

// 状態チップの色・文字。色だけで状態を伝えないため、文字は必ず付ける
export const STAGE_STATE_LABEL_KEY: Record<StageState, string> = {
  done: 'gameDay.state.done',
  none: 'gameDay.state.none',
  editing: 'gameDay.state.editing',
  todo: 'gameDay.state.todo',
  warn: 'gameDay.state.warn',
  upcoming: 'gameDay.state.upcoming',
  info: 'gameDay.state.info',
}

// 試合日ヘッダの進み具合。「予告先発・対戦設定」「結果」「登板記録」の 3 つだけが状態を持つ
export type ProgressMark = 'on' | 'warn' | 'off'

export function progressMarks(states: StageState[]): ProgressMark[] {
  return states.map((state) => {
    if (state === 'done' || state === 'none') return 'on'
    if (state === 'warn') return 'warn'
    return 'off'
  })
}

// 日付文字列（"2026-05-07" または "2026-05-07T00:00:00.000Z"）→ 日付部分。比較用
export function dateKey(value: string | null | undefined): string {
  return value ? value.slice(0, 10) : ''
}

// 試合日が来ているか。現在日が分からない時は来ていない扱い（急かさない側に倒す）
export function hasGameDayArrived(
  gameDate: string | null | undefined,
  currentDate: string | null | undefined,
): boolean {
  const game = dateKey(gameDate)
  const current = dateKey(currentDate)
  if (!game || !current) return false
  return game <= current
}

// カレンダーのセルの印（試合日のセルだけ）。warn = 要確認（赤）、todo = 未入力（黄）、null = 印なし
// シーズン画面は得点を「勝敗の印」（game_result）で持つ。得点が入っていれば game_result があり、ノーゲームは result が no_game。
// appearanceCount が undefined（古いサーバで項目が無い）の時は登板の有無が分からないので、食い違いは出さない
export interface CalendarDayMarkInput {
  gameResult: { result: string } | null | undefined
  appearanceCount: number | undefined
  arrived: boolean
}

export function calendarDayMark(input: CalendarDayMarkInput): 'warn' | 'todo' | null {
  const noGame = input.gameResult?.result === 'no_game'
  const scored = !!input.gameResult && !noGame
  if (input.appearanceCount !== undefined) {
    if (mismatchOf(scored, noGame, input.appearanceCount) !== null) return 'warn'
  }
  if (noGame || scored) return null
  return input.arrived ? 'todo' : null
}
