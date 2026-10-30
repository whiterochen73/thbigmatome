import { describe, it, expect } from 'vitest'
import {
  calendarDayMark,
  dateKey,
  detectRecordMismatch,
  hasGameDayArrived,
  hasSavedScore,
  mismatchMessageKey,
  pitcherStageState,
  progressMarks,
  resultStageState,
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
