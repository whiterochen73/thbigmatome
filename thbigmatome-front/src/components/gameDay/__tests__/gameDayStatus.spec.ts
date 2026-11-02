import { describe, it, expect } from 'vitest'
import {
  buildGameDayHead,
  calendarDayMark,
  dateKey,
  detectRecordMismatch,
  hasGameDayArrived,
  hasSavedScore,
  isGameType,
  isInCurrentRange,
  isOffRoster,
  mismatchMessageKey,
  pitcherStageState,
  progressMarks,
  resultStageState,
  SCHEDULE_DATE_TYPES,
  setupStageState,
  type SavedGameRecord,
} from '../gameDayStatus'

// Test Basis: context/thbig-dugout-game-day-flow-design.md §5.2（状態の規則）/ 台帳 D-11（ノーゲームは疲労・負傷は計算するが成績に入れない）
const record = (over: Partial<SavedGameRecord> = {}): SavedGameRecord => ({
  score: null,
  opponentScore: null,
  noGame: false,
  appearanceCount: 0,
  ...over,
})
const scored = { score: 4, opponentScore: 2 }
const arrivedCtx = { dirty: false, arrived: true }
const notArrivedCtx = { dirty: false, arrived: false }

describe('hasSavedScore', () => {
  it('両方の得点が入っていれば true（0 - 0 も得点あり）', () => {
    expect(hasSavedScore(4, 2)).toBe(true)
    expect(hasSavedScore(0, 0)).toBe(true)
    expect(hasSavedScore('3', '0')).toBe(true)
  })

  it('片方でも未入力なら false（サーバが勝敗を出す条件と同じ）', () => {
    expect(hasSavedScore(4, null)).toBe(false)
    expect(hasSavedScore(null, 2)).toBe(false)
    expect(hasSavedScore(undefined, undefined)).toBe(false)
  })

  it('空欄（空文字・空白）は未入力。0 とは区別する', () => {
    expect(hasSavedScore('', '')).toBe(false)
    expect(hasSavedScore(' ', 2)).toBe(false)
    expect(hasSavedScore(0, '')).toBe(false)
  })

  it('数として読めない値は未入力', () => {
    expect(hasSavedScore('abc', 2)).toBe(false)
    expect(hasSavedScore(Number.NaN, 2)).toBe(false)
  })
})

describe('detectRecordMismatch（得点と登板記録の食い違い）', () => {
  it('得点あり・登板なし → score_without_appearances', () => {
    expect(detectRecordMismatch(record({ ...scored }))).toBe('score_without_appearances')
  })

  it('登板あり・得点なし → appearances_without_score', () => {
    expect(detectRecordMismatch(record({ appearanceCount: 3 }))).toBe('appearances_without_score')
  })

  it('得点が片方だけでも「得点なし」として扱う（登板ありなら食い違い）', () => {
    expect(detectRecordMismatch(record({ score: 4, appearanceCount: 2 }))).toBe(
      'appearances_without_score',
    )
  })

  it('両方あり → 食い違いなし', () => {
    expect(detectRecordMismatch(record({ ...scored, appearanceCount: 2 }))).toBeNull()
  })

  it('両方なし → 食い違いなし（まだ入力していないだけ）', () => {
    expect(detectRecordMismatch(record())).toBeNull()
  })

  it('0 - 0 でも得点ありとして扱い、登板が無ければ食い違い', () => {
    expect(detectRecordMismatch(record({ score: 0, opponentScore: 0 }))).toBe(
      'score_without_appearances',
    )
  })

  it('ノーゲーム + 登板あり + 得点なし → 正常（D-11: 疲労は計算する）', () => {
    expect(detectRecordMismatch(record({ noGame: true, appearanceCount: 3 }))).toBeNull()
  })

  it('ノーゲーム + 登板なし → 正常（登板前に打ち切られた試合）', () => {
    expect(detectRecordMismatch(record({ noGame: true }))).toBeNull()
  })

  it('ノーゲーム + 得点あり + 登板なし → 正常（ノーゲームは成績に入れないので登板を要求しない）', () => {
    expect(detectRecordMismatch(record({ ...scored, noGame: true }))).toBeNull()
  })
})

describe('resultStageState（結果の段）', () => {
  it('得点が保存済みで登板もある → 済', () => {
    expect(resultStageState(record({ ...scored, appearanceCount: 2 }), arrivedCtx)).toBe('done')
  })

  it('得点が保存済みで登板が無い → 結果の段自体は済（赤は登板記録の段と帯に出す）', () => {
    expect(resultStageState(record({ ...scored }), arrivedCtx)).toBe('done')
  })

  it('登板あり・得点なし → 要確認', () => {
    expect(resultStageState(record({ appearanceCount: 2 }), arrivedCtx)).toBe('warn')
  })

  it('ノーゲーム + 登板あり + 得点なし → 済（要確認にしない）', () => {
    expect(resultStageState(record({ noGame: true, appearanceCount: 2 }), arrivedCtx)).toBe('done')
  })

  it('ノーゲーム + 登板なし → 済', () => {
    expect(resultStageState(record({ noGame: true }), arrivedCtx)).toBe('done')
  })

  it('両方なし・試合日が来ている → 未入力（黄）', () => {
    expect(resultStageState(record(), arrivedCtx)).toBe('todo')
  })

  it('両方なし・試合日が来ていない → まだ（黄にしない）', () => {
    expect(resultStageState(record(), notArrivedCtx)).toBe('upcoming')
  })

  it('未保存の入力があれば、保存済みの値に関わらず編集中', () => {
    expect(resultStageState(record(), { dirty: true, arrived: true })).toBe('editing')
    expect(resultStageState(record({ appearanceCount: 2 }), { dirty: true, arrived: true })).toBe(
      'editing',
    )
  })
})

describe('pitcherStageState（登板記録の段）', () => {
  it('得点あり・登板あり → 済', () => {
    expect(pitcherStageState(record({ ...scored, appearanceCount: 2 }), arrivedCtx)).toBe('done')
  })

  it('得点あり・登板なし → 要確認', () => {
    expect(pitcherStageState(record({ ...scored }), arrivedCtx)).toBe('warn')
  })

  it('得点あり・登板なしは、試合日が来ていなくても要確認（食い違いは時期に依らない）', () => {
    expect(pitcherStageState(record({ ...scored }), notArrivedCtx)).toBe('warn')
  })

  it('登板あり・得点なし → 要確認', () => {
    expect(pitcherStageState(record({ appearanceCount: 1 }), arrivedCtx)).toBe('warn')
  })

  it('ノーゲーム + 登板あり + 得点なし → 済', () => {
    expect(pitcherStageState(record({ noGame: true, appearanceCount: 1 }), arrivedCtx)).toBe('done')
  })

  // 台帳 D-11: ノーゲームでも疲労・負傷は計算するので、登板は記録されている必要がある（雨天中止は試合自体が無い扱い）
  it('ノーゲーム + 登板なし・試合日が来ている → 未入力（黄）。「なし」にも要確認（赤）にもしない', () => {
    expect(pitcherStageState(record({ noGame: true }), arrivedCtx)).toBe('todo')
  })

  it('ノーゲーム + 登板なし・試合日が来ていない → まだ（急かさない）', () => {
    expect(pitcherStageState(record({ noGame: true }), notArrivedCtx)).toBe('upcoming')
  })

  it('ノーゲーム + 登板あり → 済（試合日が来ていなくても）', () => {
    expect(pitcherStageState(record({ noGame: true, appearanceCount: 1 }), notArrivedCtx)).toBe(
      'done',
    )
  })

  it('ノーゲーム + 登板なしでも、食い違い（赤）にはしない', () => {
    expect(pitcherStageState(record({ noGame: true }), arrivedCtx)).not.toBe('warn')
    expect(pitcherStageState(record({ noGame: true }), notArrivedCtx)).not.toBe('warn')
  })

  it('ノーゲーム + 登板なしでも未保存の入力があれば編集中', () => {
    expect(pitcherStageState(record({ noGame: true }), { dirty: true, arrived: true })).toBe(
      'editing',
    )
  })

  it('両方なし・試合日が来ている → 未入力', () => {
    expect(pitcherStageState(record(), arrivedCtx)).toBe('todo')
  })

  it('両方なし・試合日が来ていない → まだ（黄にしない）', () => {
    expect(pitcherStageState(record(), notArrivedCtx)).toBe('upcoming')
  })

  it('未保存の入力があれば編集中', () => {
    expect(pitcherStageState(record(), { dirty: true, arrived: false })).toBe('editing')
  })
})

describe('isOffRoster / 登板記録の段の要確認（1軍でない投手の登板。設計書 §7 判断 5）', () => {
  it('first 以外の 3 状態が要確認で、first・null・未指定は要確認にしない', () => {
    expect(['second', 'not_on_team', 'no_membership'].map(isOffRoster)).toEqual([true, true, true])
    expect([
      isOffRoster('first'),
      isOffRoster(null),
      isOffRoster(undefined),
      isOffRoster(''),
      isOffRoster('unknown'),
    ]).toEqual([false, false, false, false, false])
  })

  it('1軍でない投手の登板が 1 件でもあれば要確認（登板あり・得点ありでも済にしない）', () => {
    expect(
      pitcherStageState(record({ ...scored, appearanceCount: 2, offRosterCount: 1 }), arrivedCtx),
    ).toBe('warn')
  })

  it('0 件・省略なら従来どおり済', () => {
    expect(
      pitcherStageState(record({ ...scored, appearanceCount: 2, offRosterCount: 0 }), arrivedCtx),
    ).toBe('done')
    expect(pitcherStageState(record({ ...scored, appearanceCount: 2 }), arrivedCtx)).toBe('done')
  })

  it('試合日が来ていなくても要確認（食い違いは時期に依らない）', () => {
    expect(
      pitcherStageState(
        record({ ...scored, appearanceCount: 1, offRosterCount: 1 }),
        notArrivedCtx,
      ),
    ).toBe('warn')
  })

  it('入力中（未保存）は編集中が先（保存前の入力で赤を出さない）', () => {
    expect(
      pitcherStageState(record({ ...scored, appearanceCount: 1, offRosterCount: 1 }), {
        dirty: true,
        arrived: true,
      }),
    ).toBe('editing')
  })

  it('ノーゲームの登板でも、1軍でない投手なら要確認', () => {
    expect(
      pitcherStageState(
        record({ noGame: true, appearanceCount: 1, offRosterCount: 1 }),
        arrivedCtx,
      ),
    ).toBe('warn')
  })
})

describe('setupStageState（予告先発・対戦設定の段）', () => {
  const filled = { announcedStarterId: 10, opponentTeamId: 3, resultSaved: false }

  it('予告先発と相手が入っていれば済', () => {
    expect(setupStageState(filled, arrivedCtx)).toBe('done')
    expect(setupStageState(filled, notArrivedCtx)).toBe('done')
  })

  it('予告先発だけ・相手だけでは済にならない（AND 条件の不成立側）', () => {
    expect(setupStageState({ ...filled, opponentTeamId: null }, arrivedCtx)).toBe('todo')
    expect(setupStageState({ ...filled, announcedStarterId: null }, arrivedCtx)).toBe('todo')
  })

  it('空で試合日が来ている → 未入力、来ていない → まだ（急かさない）', () => {
    const empty = { announcedStarterId: null, opponentTeamId: null, resultSaved: false }
    expect(setupStageState(empty, arrivedCtx)).toBe('todo')
    expect(setupStageState(empty, notArrivedCtx)).toBe('upcoming')
  })

  it('空でも結果まで保存済みなら、黄色で急かさない（なし）', () => {
    const empty = { announcedStarterId: null, opponentTeamId: null, resultSaved: true }
    expect(setupStageState(empty, arrivedCtx)).toBe('none')
  })

  it('未保存の入力があれば編集中', () => {
    expect(setupStageState(filled, { dirty: true, arrived: true })).toBe('editing')
  })
})

describe('calendarDayMark（カレンダーのセルの印）', () => {
  const win = { result: 'win' }
  const noGameResult = { result: 'no_game' }

  it('得点あり・登板なし → 赤', () => {
    expect(calendarDayMark({ gameResult: win, appearanceCount: 0, arrived: true })).toBe('warn')
  })

  it('得点なし・登板あり → 赤', () => {
    expect(calendarDayMark({ gameResult: null, appearanceCount: 2, arrived: true })).toBe('warn')
  })

  it('得点あり・登板あり → 印なし', () => {
    expect(calendarDayMark({ gameResult: win, appearanceCount: 2, arrived: true })).toBeNull()
  })

  it('ノーゲーム + 登板あり → 印なし', () => {
    expect(
      calendarDayMark({ gameResult: noGameResult, appearanceCount: 2, arrived: true }),
    ).toBeNull()
  })

  // 登板記録の段（pitcherStageState）と同じ結果になること
  it('ノーゲーム + 登板なし・試合日が来ている → 黄（登板記録が未入力。D-11）', () => {
    expect(calendarDayMark({ gameResult: noGameResult, appearanceCount: 0, arrived: true })).toBe(
      'todo',
    )
  })

  it('ノーゲーム + 登板なし・試合日が来ていない → 印なし（急かさない）', () => {
    expect(
      calendarDayMark({ gameResult: noGameResult, appearanceCount: 0, arrived: false }),
    ).toBeNull()
  })

  it('ノーゲーム + 登板の件数が不明（古いサーバ）→ 印なし（未入力と決めつけない）', () => {
    expect(
      calendarDayMark({ gameResult: noGameResult, appearanceCount: undefined, arrived: true }),
    ).toBeNull()
  })

  it('結果も登板も無く、試合日が来ている → 黄', () => {
    expect(calendarDayMark({ gameResult: null, appearanceCount: 0, arrived: true })).toBe('todo')
  })

  it('結果も登板も無く、試合日が来ていない → 印なし', () => {
    expect(calendarDayMark({ gameResult: null, appearanceCount: 0, arrived: false })).toBeNull()
  })

  it('登板の件数が不明（古いサーバ）なら食い違いは出さない。得点ありは印なし、得点なしで来ていれば黄', () => {
    expect(
      calendarDayMark({ gameResult: win, appearanceCount: undefined, arrived: true }),
    ).toBeNull()
    expect(calendarDayMark({ gameResult: null, appearanceCount: undefined, arrived: true })).toBe(
      'todo',
    )
  })

  it('得点あり・登板なしは、試合日が来ていなくても赤（食い違いは時期に依らない）', () => {
    expect(calendarDayMark({ gameResult: win, appearanceCount: 0, arrived: false })).toBe('warn')
  })
})

describe('hasGameDayArrived / dateKey', () => {
  it('試合日が現在日以前なら来ている（当日を含む）', () => {
    expect(hasGameDayArrived('2026-05-07', '2026-05-07')).toBe(true)
    expect(hasGameDayArrived('2026-05-06', '2026-05-07')).toBe(true)
  })

  it('試合日が現在日より後なら来ていない', () => {
    expect(hasGameDayArrived('2026-05-08', '2026-05-07')).toBe(false)
  })

  it('現在日が取れない・試合日が空なら来ていない扱い（急かさない側）', () => {
    expect(hasGameDayArrived('2026-05-07', null)).toBe(false)
    expect(hasGameDayArrived('', '2026-05-07')).toBe(false)
    expect(hasGameDayArrived(undefined, undefined)).toBe(false)
  })

  it('日時つきの文字列も日付部分だけで比べる', () => {
    expect(dateKey('2026-05-07T00:00:00.000Z')).toBe('2026-05-07')
    expect(hasGameDayArrived('2026-05-07', '2026-05-07T09:00:00.000+09:00')).toBe(true)
  })
})

describe('progressMarks / mismatchMessageKey', () => {
  it('済・なしは点灯、要確認は赤、それ以外は消灯', () => {
    expect(progressMarks(['done', 'none', 'warn', 'todo', 'editing', 'upcoming', 'info'])).toEqual([
      'on',
      'on',
      'warn',
      'off',
      'off',
      'off',
      'off',
    ])
  })

  it('食い違いの種類ごとに別の文を返し、食い違いなしは null', () => {
    expect(mismatchMessageKey('score_without_appearances')).toBe(
      'gameDay.mismatch.scoreWithoutAppearances',
    )
    expect(mismatchMessageKey('appearances_without_score')).toBe(
      'gameDay.mismatch.appearancesWithoutScore',
    )
    expect(mismatchMessageKey(null)).toBeNull()
  })
})

// 今の範囲（最後に結果が入った試合日の翌日〜次の試合日）。登録・昇降格・負傷・出場停止を操作できる日の判定
// Test Basis: context/thbig-dugout-season-record-restructure-design.md の 2026-11-01 の追記 2 本（5/7 試合 → 5/8 移動日 → 5/9 試合なら 5/8 と 5/9 の両方で操作できる）
describe('isInCurrentRange', () => {
  const range = { start_date: '2026-05-08', end_date: '2026-05-09' }

  it('範囲の両端を含む（移動日 5/8 も、次の試合日 5/9 も操作できる）', () => {
    expect(isInCurrentRange('2026-05-08', range)).toBe(true)
    expect(isInCurrentRange('2026-05-09', range)).toBe(true)
  })

  it('範囲の外は操作できない（結果が入った 5/7 も、その次の試合日の後の 5/10 も）', () => {
    expect(isInCurrentRange('2026-05-07', range)).toBe(false)
    expect(isInCurrentRange('2026-05-10', range)).toBe(false)
  })

  it('1 日だけの範囲（連続する試合日）', () => {
    const single = { start_date: '2026-05-08', end_date: '2026-05-08' }
    expect(isInCurrentRange('2026-05-08', single)).toBe(true)
    expect(isInCurrentRange('2026-05-09', single)).toBe(false)
  })

  it('時刻つきの日付でも日付部分で比べる', () => {
    expect(isInCurrentRange('2026-05-09T00:00:00.000Z', range)).toBe(true)
    expect(isInCurrentRange('2026-05-10T00:00:00.000Z', range)).toBe(false)
    expect(
      isInCurrentRange('2026-05-09', {
        start_date: '2026-05-08T00:00:00.000Z',
        end_date: '2026-05-09T00:00:00.000Z',
      }),
    ).toBe(true)
  })

  it('範囲が無い（最終試合日の後）・分からない・日付が無い時は、どの日も操作できない', () => {
    expect(isInCurrentRange('2026-05-08', null)).toBe(false)
    expect(isInCurrentRange('2026-05-08', undefined)).toBe(false)
    expect(isInCurrentRange(null, range)).toBe(false)
    expect(isInCurrentRange('', range)).toBe(false)
  })
})

// Test Basis: cmd_1784 段4。設計書 §4.6（試合日とみなす種別はサーバに 1 つ置き、画面はそれを受け取る。ノーゲームは真偽値で表し、種別 no_game は作れない）
describe('isGameType（試合日とみなす種別はサーバから受け取る）', () => {
  const serverTypes = ['game_day', 'interleague_game_day', 'playoff_day']

  it('サーバが返した種別だけを試合日とみなす（プレーオフ日を含む）', () => {
    for (const type of serverTypes) expect(isGameType(type, serverTypes), type).toBe(true)
    for (const type of [
      'reserve_day',
      'interleague_reserve_day',
      'travel_day',
      'no_game_day',
      'postponed',
    ]) {
      expect(isGameType(type, serverTypes), type).toBe(false)
    }
  })

  it('種別が空・未取得（サーバの値が空）なら試合日ではない', () => {
    expect(isGameType('game_day', [])).toBe(false)
    expect(isGameType(null, serverTypes)).toBe(false)
    expect(isGameType(undefined, serverTypes)).toBe(false)
    expect(isGameType('', serverTypes)).toBe(false)
  })

  it('種別 no_game は試合日とみなさない（サーバの集合に無い）。日付の種類の選択肢にも無い', () => {
    expect(isGameType('no_game', serverTypes)).toBe(false)
    expect(SCHEDULE_DATE_TYPES).not.toContain('no_game')
    expect(SCHEDULE_DATE_TYPES).toContain('playoff_day')
  })

  it('画面は種別の一覧を持たず、サーバの集合が変われば判定も変わる', () => {
    expect(isGameType('reserve_day', [...serverTypes, 'reserve_day'])).toBe(true)
  })
})

// Test Basis: cmd_1812 / context/thbig-dugout-gameday-head-summary-mock.html（案1＋予告先発）。
// 決まっていないものは出さない（null）。勝敗は保存済みの得点と失点から出す。ノーゲームは得点を出さず枠だけの札
describe('buildGameDayHead（試合日ページ上の段の 1 行）', () => {
  const none = {
    opponentName: null,
    score: null,
    opponentScore: null,
    noGame: false,
    homeAway: null,
    designatedHitter: null,
    starterName: null,
  } as const

  it('何も決まっていない日は null（行ごと出さない）。空欄・空白だけの文字も決まっていない扱い', () => {
    expect(buildGameDayHead(none)).toBeNull()
    expect(
      buildGameDayHead({
        ...none,
        opponentName: '',
        starterName: '  ',
        score: '',
        opponentScore: '',
      }),
    ).toBeNull()
  })

  it('済（勝ち）: 相手・得点・勝・ホーム・DH なしがそろう', () => {
    expect(
      buildGameDayHead({
        ...none,
        opponentName: '命懸',
        score: 3,
        opponentScore: 0,
        homeAway: 'home',
        designatedHitter: false,
        starterName: '古明地 さとり',
      }),
    ).toEqual({
      opponent: '命懸',
      score: '3 - 0',
      result: 'win',
      homeAway: 'home',
      dh: false,
      starter: '古明地 さとり',
    })
  })

  it('負け・引き分け', () => {
    expect(buildGameDayHead({ ...none, score: 2, opponentScore: 5 })).toMatchObject({
      score: '2 - 5',
      result: 'lose',
    })
    expect(buildGameDayHead({ ...none, score: 4, opponentScore: 4 })).toMatchObject({
      score: '4 - 4',
      result: 'draw',
    })
  })

  it('0 - 0 は得点が入っている（引き分け。0 を未入力と読まない）', () => {
    expect(buildGameDayHead({ ...none, score: 0, opponentScore: 0 })).toMatchObject({
      score: '0 - 0',
      result: 'draw',
    })
    expect(buildGameDayHead({ ...none, score: 0, opponentScore: 1 })).toMatchObject({
      result: 'lose',
    })
  })

  it('得点だけ入って失点が空（逆も）: 得点も札も出さない。ほかが無ければ行ごと出さない', () => {
    expect(buildGameDayHead({ ...none, score: 3, opponentScore: null })).toBeNull()
    expect(buildGameDayHead({ ...none, score: null, opponentScore: 3 })).toBeNull()
    expect(
      buildGameDayHead({ ...none, score: 3, opponentScore: '', opponentName: '若尊' }),
    ).toEqual({
      opponent: '若尊',
      score: null,
      result: null,
      homeAway: null,
      dh: null,
      starter: null,
    })
  })

  it('得点が数として読めない値（NaN・文字）は未入力と同じ', () => {
    expect(buildGameDayHead({ ...none, score: 'abc', opponentScore: 1 })).toBeNull()
    expect(buildGameDayHead({ ...none, score: Number.NaN, opponentScore: 1 })).toBeNull()
  })

  it('ノーゲーム: 札は no_game、得点は（入っていても）出さない', () => {
    expect(
      buildGameDayHead({ ...none, noGame: true, opponentName: '小倉', homeAway: 'home' }),
    ).toEqual({
      opponent: '小倉',
      score: null,
      result: 'no_game',
      homeAway: 'home',
      dh: null,
      starter: null,
    })
    expect(buildGameDayHead({ ...none, noGame: true, score: 3, opponentScore: 0 })).toMatchObject({
      score: null,
      result: 'no_game',
    })
  })

  it('相手が未定で予告先発だけある日: 先発だけの行になる', () => {
    expect(buildGameDayHead({ ...none, starterName: '古明地 さとり' })).toEqual({
      opponent: null,
      score: null,
      result: null,
      homeAway: null,
      dh: null,
      starter: '古明地 さとり',
    })
  })

  it('ビジター・DH あり。DH は false（なし）も決まった値として出す（null だけが未定）', () => {
    expect(
      buildGameDayHead({
        ...none,
        opponentName: '若尊',
        homeAway: 'visitor',
        designatedHitter: true,
      }),
    ).toMatchObject({ homeAway: 'visitor', dh: true })
    expect(buildGameDayHead({ ...none, designatedHitter: false })).toMatchObject({ dh: false })
  })

  it('ホーム・ビジターに想定外の値が来たら出さない', () => {
    expect(
      buildGameDayHead({ ...none, opponentName: '若尊', homeAway: 'neutral' as never }),
    ).toMatchObject({
      homeAway: null,
    })
  })
})
