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

// Test Basis: thbig-dugout-visual-refresh-design.md §6.1, §6.5, §7 段3
// 離脱・時期のチップと、同じ意味を示す操作色はこの表を共用する。
export const ABSENCE_APPEARANCE: Record<string, { color: string; icon: string }> = {
  injury: { color: 'absence-out', icon: 'mdi-hospital-box' },
  suspension: { color: 'absence-out', icon: 'mdi-gavel' },
  reconditioning: { color: 'absence-adjust', icon: 'mdi-wrench' },
  cooldown: { color: 'absence-cooldown', icon: 'mdi-timer-sand' },
}

export const ABSENCE_PHASE_APPEARANCE = {
  pre_game: { color: 'zone-roster', icon: 'mdi-account-switch' },
  in_game: { color: 'zone-game', icon: 'mdi-baseball-diamond' },
} as const

// SeasonPortal と試合日ページで共用する日付種類・試合日判定
export const SCHEDULE_DATE_TYPES = [
  'game_day',
  'interleague_game_day',
  'playoff_day',
  'travel_day',
  'reserve_day',
  'interleague_reserve_day',
  'no_game_day',
  'postponed',
] as const

// 試合日とみなす種別かどうか。種別の集合はサーバが決める（GET /teams/:id/season の game_date_types。
// SeasonSchedule::GAME_DATE_TYPES）。ノーゲームは種別ではなく真偽値 no_game で表すので、種別 no_game は日付の種類に無い
export function isGameType(
  dateType: string | null | undefined,
  gameDateTypes: readonly string[],
): boolean {
  return !!dateType && gameDateTypes.includes(dateType)
}

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
  // その試合日の試合中に 1軍にいなかった投手の登板の件数（登板は保存済み。要確認の帯に出す）。分からない時は省略（0 扱い）
  offRosterCount?: number
}

// 1軍でない投手の登板か（roster_status が first 以外。取れていない null・省略は要確認にしない）
export function isOffRoster(status: string | null | undefined): boolean {
  return status === 'second' || status === 'not_on_team' || status === 'no_membership'
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
// 得点が無くても登板があれば正常。ノーゲームの登板なしは食い違い（赤）にはしないが、登板記録の段は未入力（黄）で促す
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
  if ((record.offRosterCount ?? 0) > 0) return 'warn'
  if (record.appearanceCount > 0) return 'done'
  // ノーゲームでも疲労・負傷は計算する（台帳 D-11）ので、登板は記録されている必要がある。
  // 登板が無ければ通常の試合と同じく未入力（試合日前は急かさない）。赤（要確認）にはしない。雨天中止は試合自体が無い扱い
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

// Test Basis: thbig-dugout-visual-refresh-design.md §6.5。
// チップ・タブバッジ・進み具合が同じ色、アイコン、ラベルを使う。
export const STAGE_STATE_APPEARANCE: Record<
  StageState,
  {
    color: string
    icon: string
    labelKey: string
  }
> = {
  done: { color: 'state-done', icon: 'mdi-check-circle', labelKey: 'gameDay.state.done' },
  none: {
    color: 'state-neutral',
    icon: 'mdi-minus-circle-outline',
    labelKey: 'gameDay.state.none',
  },
  editing: { color: 'state-edit', icon: 'mdi-pencil', labelKey: 'gameDay.state.editing' },
  todo: { color: 'state-todo', icon: 'mdi-circle-outline', labelKey: 'gameDay.state.todo' },
  warn: { color: 'state-warn', icon: 'mdi-alert', labelKey: 'gameDay.state.warn' },
  upcoming: {
    color: 'state-neutral',
    icon: 'mdi-clock-outline',
    labelKey: 'gameDay.state.upcoming',
  },
  info: { color: 'state-info', icon: 'mdi-open-in-new', labelKey: 'gameDay.state.info' },
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

// 今の範囲（最後に結果が入った試合日の翌日〜次の試合日）。サーバが日程の結果から導く（GET /teams/:id/season の current_range）
export interface CurrentRange {
  start_date: string
  end_date: string
}

// 登録・昇降格・負傷・出場停止（試合日ページの登録・離脱の 3 段）を操作できる日か。今の範囲の中の日だけ（両端を含む）。
// 範囲が無い（最終試合日の後）・分からない時はどの日も操作できない（誤った日付での保存を避ける側に倒す）
export function isInCurrentRange(
  date: string | null | undefined,
  range: CurrentRange | null | undefined,
): boolean {
  const day = dateKey(date)
  if (!day || !range) return false
  return dateKey(range.start_date) <= day && day <= dateKey(range.end_date)
}

// カレンダーのセルの印（試合日のセルだけ）。warn = 要確認（赤）、todo = 未入力（黄）、null = 印なし
// ノーゲームは結果の入力は済だが、登板が 0 件と分かっている時は登板記録が未入力なので、試合日到来後は黄（登板記録の段と同じ結果）
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
  if (noGame) {
    return input.appearanceCount === 0 && input.arrived ? 'todo' : null
  }
  if (scored) return null
  return input.arrived ? 'todo' : null
}

// 試合日ページ上の段の 1 行（cmd_1812・もっく案1＋予告先発）。相手・得点・勝敗の札を大きく、ホーム/ビジター・DH を小さな印、予告先発を添える。
// 渡す値はすべて「保存済み」の値（入力途中の値で揺れない）。決まっていないものは null にして出さない。何も決まっていなければ null（行ごと出さない）
export type GameResultKind = 'win' | 'lose' | 'draw' | 'no_game'

export interface GameDayHeadInput {
  opponentName: string | null | undefined
  score: number | string | null | undefined
  opponentScore: number | string | null | undefined
  noGame: boolean | null | undefined
  homeAway: string | null | undefined
  designatedHitter: boolean | null | undefined
  starterName: string | null | undefined
}

export interface GameDayHead {
  opponent: string | null
  // 「得点 - 失点」。ノーゲームと、得点・失点のどちらかが空の時は null
  score: string | null
  result: GameResultKind | null
  homeAway: 'home' | 'visitor' | null
  // true = DH あり、false = DH なし、null = 未定
  dh: boolean | null
  starter: string | null
}

const textOrNull = (value: string | null | undefined): string | null => {
  const text = typeof value === 'string' ? value.trim() : ''
  return text === '' ? null : text
}

export function buildGameDayHead(input: GameDayHeadInput): GameDayHead | null {
  // ノーゲームは得点では表せない（得点が残っていても出さない）。勝敗は得点と失点の両方が入って初めて出す（hasSavedScore と同じ条件）
  const noGame = !!input.noGame
  const scored = !noGame && hasSavedScore(input.score, input.opponentScore)
  const mine = Number(input.score)
  const theirs = Number(input.opponentScore)
  const head: GameDayHead = {
    opponent: textOrNull(input.opponentName),
    score: scored ? `${mine} - ${theirs}` : null,
    result: noGame
      ? 'no_game'
      : scored
        ? mine > theirs
          ? 'win'
          : mine < theirs
            ? 'lose'
            : 'draw'
        : null,
    homeAway: input.homeAway === 'home' || input.homeAway === 'visitor' ? input.homeAway : null,
    dh: typeof input.designatedHitter === 'boolean' ? input.designatedHitter : null,
    starter: textOrNull(input.starterName),
  }
  return Object.values(head).every((value) => value === null) ? null : head
}
