import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { ref } from 'vue'

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    put: vi.fn(),
  },
}))

import axios from 'axios'
import { useSquadTextGenerator } from '../useSquadTextGenerator'
import { useSquadTextStore } from '@/stores/squadText'
import type { RosterPlayer } from '@/types/rosterPlayer'

function makePlayer(overrides: Partial<RosterPlayer>): RosterPlayer {
  return {
    team_membership_id: 1,
    player_id: 1,
    number: 'F01',
    player_name: 'テスト選手',
    squad: 'first',
    cost: 0,
    selected_cost_type: 'normal',
    position: 'RF',
    throwing_hand: 'right_throw',
    batting_hand: 'right_bat',
    player_types: [],
    is_absent: false,
    ...overrides,
  }
}

describe('useSquadTextGenerator', () => {
  let store: ReturnType<typeof useSquadTextStore>

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useSquadTextStore()
    vi.clearAllMocks()
    vi.mocked(axios.get).mockRejectedValue(new Error('Not found'))
    vi.mocked(axios.put).mockResolvedValue({ data: {} })
  })

  describe('init: プレイヤーデータとAPI取得', () => {
    it('APIが失敗してもinitは正常終了する', async () => {
      const teamId = ref(5)
      const { init, loading } = useSquadTextGenerator(teamId)
      const player = makePlayer({ player_id: 1 })
      await expect(init([player])).resolves.not.toThrow()
      expect(loading.value).toBe(false)
    })

    it('fetchSettings成功時に設定が適用される', async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: {
          position_format: 'japanese',
          handedness_format: 'kanji',
          section_header_format: 'none',
          show_number_prefix: false,
          batting_stats_config: {
            avg: true,
            hr: false,
            rbi: false,
            sb: false,
            obp: false,
            ops: false,
          },
          pitching_stats_config: {
            w_l: false,
            games: false,
            era: true,
            so: false,
            ip: false,
            hold: false,
            save: false,
          },
        },
      })

      const teamId = ref(5)
      const { init, settings } = useSquadTextGenerator(teamId)
      await init([])

      expect(settings.value.position_format).toBe('japanese')
      expect(settings.value.handedness_format).toBe('kanji')
    })
  })

  describe('starterText: スタメンテキスト生成', () => {
    it('スタメンがない場合は空文字', async () => {
      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([])
      expect(starterText.value).toBe('')
    })

    it('スタメンを正しく生成する（デフォルト設定）', async () => {
      const player = makePlayer({
        player_id: 42,
        number: 'F72',
        player_name: '志摩リン',
        position: 'RF',
        throwing_hand: 'right_throw',
        batting_hand: 'right_bat',
      })
      store.startingLineup = [{ battingOrder: 1, playerId: 42, position: 'RF' }]

      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(starterText.value).toContain('【スタメン】')
      expect(starterText.value).toContain('1 RF F72 志摩リン RR')
    })

    it('成績データがない場合は - を表示する', async () => {
      const player = makePlayer({ player_id: 1, number: 'F01', player_name: '選手A' })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]

      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      // stats API fails → shows "-"
      expect(starterText.value).toContain('- - -')
    })

    it('成績データがある場合は成績を表示する', async () => {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if ((url as string).includes('imported_stats')) {
          return Promise.resolve({
            data: [{ player_id: 1, stat_type: 'batting', stats: { avg: 0.312, hr: 5, rbi: 20 } }],
          })
        }
        return Promise.reject(new Error('Not found'))
      })

      const player = makePlayer({ player_id: 1, number: 'F01', player_name: '選手A' })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]

      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(starterText.value).toContain('.312')
      expect(starterText.value).toContain('5本')
      expect(starterText.value).toContain('20打点')
    })
  })

  describe('ポジション表記フォーマット', () => {
    it('japanese設定でポジションを漢字表示する', async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: {
          position_format: 'japanese',
          handedness_format: 'alphabet',
          section_header_format: 'bracket',
          show_number_prefix: true,
          batting_stats_config: {
            avg: false,
            hr: false,
            rbi: false,
            sb: false,
            obp: false,
            ops: false,
          },
          pitching_stats_config: {
            w_l: false,
            games: false,
            era: false,
            so: false,
            ip: false,
            hold: false,
            save: false,
          },
        },
      })

      const player = makePlayer({
        player_id: 1,
        number: 'F10',
        player_name: '選手B',
        position: 'RF',
      })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]

      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(starterText.value).toContain('右')
      expect(starterText.value).not.toContain(' RF ')
    })
  })

  describe('投打表記フォーマット', () => {
    it('kanji設定で投打を漢字表示する', async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: {
          position_format: 'english',
          handedness_format: 'kanji',
          section_header_format: 'bracket',
          show_number_prefix: true,
          batting_stats_config: {
            avg: false,
            hr: false,
            rbi: false,
            sb: false,
            obp: false,
            ops: false,
          },
          pitching_stats_config: {
            w_l: false,
            games: false,
            era: false,
            so: false,
            ip: false,
            hold: false,
            save: false,
          },
        },
      })

      const player = makePlayer({
        player_id: 1,
        number: 'F01',
        player_name: '選手C',
        throwing_hand: 'left_throw',
        batting_hand: 'right_bat',
      })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'CF' }]

      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(starterText.value).toContain('左右')
    })
  })

  describe('benchHitterText: 控え野手テキスト', () => {
    it('benchPlayersが空なら空文字', async () => {
      const teamId = ref(5)
      const { benchHitterText, init } = useSquadTextGenerator(teamId)
      await init([])
      expect(benchHitterText.value).toBe('')
    })

    it('控え野手テキストを生成する', async () => {
      const player = makePlayer({
        player_id: 10,
        number: 'F10',
        player_name: '夢美',
        position: '1B',
        throwing_hand: 'right_throw',
        batting_hand: 'left_bat',
      })
      store.benchPlayers = [10]

      const teamId = ref(5)
      const { benchHitterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(benchHitterText.value).toContain('【控え野手】')
      expect(benchHitterText.value).toContain('F10 夢美 RL')
    })
  })

  describe('reliefPitcherText: 中継ぎテキスト', () => {
    it('reliefPitcherIdsが空なら空文字', async () => {
      const teamId = ref(5)
      const { reliefPitcherText, init } = useSquadTextGenerator(teamId)
      await init([])
      expect(reliefPitcherText.value).toBe('')
    })

    it('中継ぎ契約投手に(中継)マークを付ける', async () => {
      const pitcher = makePlayer({
        player_id: 20,
        number: 'F20',
        player_name: '水着投手',
        position: 'P',
        player_types: ['中継ぎ契約'],
        throwing_hand: 'right_throw',
        batting_hand: 'right_bat',
      })
      store.reliefPitcherIds = [20]

      const teamId = ref(5)
      const { reliefPitcherText, init } = useSquadTextGenerator(teamId)
      await init([pitcher])

      expect(reliefPitcherText.value).toContain('【中継ぎ】')
      expect(reliefPitcherText.value).toContain('(中継)F20')
    })

    it('非中継ぎ契約投手には(中継)マークなし', async () => {
      const pitcher = makePlayer({
        player_id: 21,
        number: 'F21',
        player_name: '先発投手',
        position: 'P',
        player_types: [],
        throwing_hand: 'right_throw',
        batting_hand: 'right_bat',
      })
      store.reliefPitcherIds = [21]

      const teamId = ref(5)
      const { reliefPitcherText, init } = useSquadTextGenerator(teamId)
      await init([pitcher])

      expect(reliefPitcherText.value).not.toContain('(中継)')
      expect(reliefPitcherText.value).toContain('F21')
    })
  })

  describe('starterBenchText: 先発ベンチテキスト', () => {
    it('先発ベンチテキストを生成する', async () => {
      const pitcher = makePlayer({
        player_id: 30,
        number: 'F30',
        player_name: '先発A',
        position: 'P',
        throwing_hand: 'right_throw',
        batting_hand: 'right_bat',
      })
      store.starterBenchPitcherIds = [30]

      const teamId = ref(5)
      const { starterBenchText, init } = useSquadTextGenerator(teamId)
      await init([pitcher])

      expect(starterBenchText.value).toContain('【先発ベンチ】')
      expect(starterBenchText.value).toContain('F30 先発A RR')
    })
  })

  describe('offText: オフテキスト', () => {
    it('オフテキストを生成する（野手）', async () => {
      const player = makePlayer({
        player_id: 40,
        number: 'F40',
        player_name: 'オフ野手',
        position: '3B',
        throwing_hand: 'right_throw',
        batting_hand: 'right_bat',
      })
      store.offPlayers = [40]

      const teamId = ref(5)
      const { offText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(offText.value).toContain('【オフ】')
      expect(offText.value).toContain('F40 オフ野手 RR')
    })
  })

  describe('generatedText: 全体テキスト', () => {
    it('全セクションを結合する', async () => {
      const hitter = makePlayer({
        player_id: 1,
        number: 'F01',
        player_name: 'スタメン',
        position: 'RF',
      })
      const benchPlayer = makePlayer({
        player_id: 2,
        number: 'F02',
        player_name: 'ベンチ',
        position: '1B',
      })
      const reliever = makePlayer({
        player_id: 3,
        number: 'F03',
        player_name: '中継ぎ',
        position: 'P',
      })

      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]
      store.benchPlayers = [2]
      store.reliefPitcherIds = [3]

      const teamId = ref(5)
      const { generatedText, init } = useSquadTextGenerator(teamId)
      await init([hitter, benchPlayer, reliever])

      expect(generatedText.value).toContain('【スタメン】')
      expect(generatedText.value).toContain('【控え野手】')
      expect(generatedText.value).toContain('【中継ぎ】')
    })

    it('セクションが空の場合はスキップされる', async () => {
      const player = makePlayer({
        player_id: 1,
        number: 'F01',
        player_name: 'スタメン',
        position: 'RF',
      })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]

      const teamId = ref(5)
      const { generatedText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(generatedText.value).not.toContain('【控え野手】')
      expect(generatedText.value).not.toContain('【中継ぎ】')
      expect(generatedText.value).not.toContain('【先発ベンチ】')
      expect(generatedText.value).not.toContain('【オフ】')
    })
  })

  describe('headerText: ヘッダー', () => {
    it('今日の日付を含む', async () => {
      const teamId = ref(5)
      const { headerText, init } = useSquadTextGenerator(teamId)
      await init([])

      const today = new Date()
      const year = today.getFullYear()
      expect(headerText.value).toContain(String(year))
    })
  })

  describe('init: 投手初期振り分け', () => {
    it('is_starter_pitcher=trueの投手はstarterBenchPitcherIdsに振り分けられる', async () => {
      const starterPitcher = makePlayer({
        player_id: 50,
        position: 'pitcher',
        is_starter_pitcher: true,
      })
      const reliefPitcher = makePlayer({
        player_id: 51,
        position: 'pitcher',
        is_starter_pitcher: false,
      })

      const teamId = ref(5)
      const { init } = useSquadTextGenerator(teamId)
      await init([starterPitcher, reliefPitcher])

      expect(store.starterBenchPitcherIds).toContain(50)
      expect(store.reliefPitcherIds).not.toContain(50)
      expect(store.reliefPitcherIds).toContain(51)
      expect(store.starterBenchPitcherIds).not.toContain(51)
    })

    it('position=pitcherでない選手は振り分け対象外', async () => {
      const hitter = makePlayer({ player_id: 60, position: 'RF' })

      const teamId = ref(5)
      const { init } = useSquadTextGenerator(teamId)
      await init([hitter])

      expect(store.reliefPitcherIds).not.toContain(60)
      expect(store.starterBenchPitcherIds).not.toContain(60)
    })

    it('既に振り分け済みの場合は初期化しない', async () => {
      store.reliefPitcherIds = [99]
      const pitcher = makePlayer({ player_id: 50, position: 'pitcher', is_starter_pitcher: true })

      const teamId = ref(5)
      const { init } = useSquadTextGenerator(teamId)
      await init([pitcher])

      // 既存の振り分けは保持される（初期化されない）
      expect(store.reliefPitcherIds).toContain(99)
      expect(store.starterBenchPitcherIds).not.toContain(50)
    })
  })

  describe('offText: 投手のstatライン判定', () => {
    it('position=pitcherの選手はpitchingLineを使用する', async () => {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if ((url as string).includes('pitcher_game_states')) {
          return Promise.resolve({
            data: [{ player_id: 70, stats: { era: 2.5, so: 30 } }],
          })
        }
        return Promise.reject(new Error('Not found'))
      })

      const pitcher = makePlayer({
        player_id: 70,
        number: 'F70',
        player_name: '投手テスト',
        position: 'pitcher',
        throwing_hand: 'right_throw',
        batting_hand: 'right_bat',
      })
      store.offPlayers = [70]

      const teamId = ref(5)
      const { offText, init } = useSquadTextGenerator(teamId)
      await init([pitcher])

      expect(offText.value).toContain('F70 投手テスト')
    })
  })

  describe('fetchRosterChanges: 公示テキスト取得', () => {
    it('changesがある場合rosterChangesTextがセットされる', async () => {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if ((url as string).includes('roster_changes')) {
          return Promise.resolve({
            data: {
              changes: [
                {
                  type: 'promote',
                  player_id: 78,
                  player_name: 'ユキ',
                  number: '78',
                  date: '2025-06-04',
                },
              ],
              text: '登録：78 ユキ',
            },
          })
        }
        return Promise.reject(new Error('Not found'))
      })

      const teamId = ref(5)
      const { rosterChangesText, fetchRosterChanges, init } = useSquadTextGenerator(teamId)
      await init([])
      await fetchRosterChanges('2025-06-01', 1)
      expect(rosterChangesText.value).toBe('登録：78 ユキ')
    })

    it('changesなしの場合rosterChangesTextが空文字になる', async () => {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if ((url as string).includes('roster_changes')) {
          return Promise.resolve({ data: { changes: [], text: '' } })
        }
        return Promise.reject(new Error('Not found'))
      })

      const teamId = ref(5)
      const { rosterChangesText, fetchRosterChanges, init } = useSquadTextGenerator(teamId)
      await init([])
      await fetchRosterChanges('2025-06-01', 1)
      expect(rosterChangesText.value).toBe('')
    })

    it('APIエラーの場合rosterChangesTextが空文字になる', async () => {
      vi.mocked(axios.get).mockRejectedValue(new Error('Network Error'))

      const teamId = ref(5)
      const { rosterChangesText, fetchRosterChanges, init } = useSquadTextGenerator(teamId)
      await init([])
      await fetchRosterChanges('2025-06-01', 1)
      expect(rosterChangesText.value).toBe('')
    })

    it('rosterChangesTextがgeneratedTextのheaderTextの次に挿入される', async () => {
      vi.mocked(axios.get).mockImplementation((url: string) => {
        if ((url as string).includes('roster_changes')) {
          return Promise.resolve({ data: { changes: [], text: '登録：78 ユキ' } })
        }
        return Promise.reject(new Error('Not found'))
      })

      const player = makePlayer({ player_id: 1, number: 'F01', player_name: 'スタメン' })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]

      const teamId = ref(5)
      const { generatedText, fetchRosterChanges, init } = useSquadTextGenerator(teamId)
      await init([player])
      await fetchRosterChanges('2025-06-01', 1)

      const lines = generatedText.value.split('\n\n')
      expect(lines[0]).toContain('/') // headerText (date)
      expect(lines[1]).toContain('登録：78 ユキ') // rosterChangesText
      expect(lines[2]).toContain('【スタメン】')
    })
  })

  describe('saveAsGameLineup: 自動保存', () => {
    it('PUT /game_lineup を正しく呼び出す', async () => {
      vi.mocked(axios.put).mockResolvedValue({ data: {} })
      vi.mocked(axios.get).mockRejectedValue(new Error('Not found'))

      store.startingLineup = [{ battingOrder: 1, playerId: 42, position: 'RF' }]
      store.benchPlayers = [10]
      store.reliefPitcherIds = [20]
      store.dhEnabled = true
      store.opponentPitcherHand = 'right'

      const teamId = ref(5)
      const { saveAsGameLineup, init } = useSquadTextGenerator(teamId)
      await init([])
      await saveAsGameLineup()

      expect(axios.put).toHaveBeenCalledWith('/teams/5/game_lineup', {
        game_lineup: {
          lineup_data: expect.objectContaining({
            dh_enabled: true,
            opponent_pitcher_hand: 'right',
            starting_lineup: [{ batting_order: 1, player_id: 42, position: 'RF' }],
            bench_players: [10],
            relief_pitcher_ids: [20],
          }),
        },
      })
    })
  })

  describe('show_number_prefix: 背番号接頭辞', () => {
    it('show_number_prefix=falseのとき背番号の接頭辞を除去する', async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: {
          position_format: 'english',
          handedness_format: 'alphabet',
          section_header_format: 'bracket',
          show_number_prefix: false,
          batting_stats_config: {
            avg: false,
            hr: false,
            rbi: false,
            sb: false,
            obp: false,
            ops: false,
          },
          pitching_stats_config: {
            w_l: false,
            games: false,
            era: false,
            so: false,
            ip: false,
            hold: false,
            save: false,
          },
        },
      })

      const player = makePlayer({ player_id: 1, number: 'F72', player_name: '志摩リン' })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]

      const teamId = ref(5)
      const { starterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(starterText.value).toContain('72')
      expect(starterText.value).not.toContain('F72')
    })
  })

  describe('section_header_format: セクションヘッダー形式', () => {
    it('none設定でヘッダーに括弧をつけない', async () => {
      vi.mocked(axios.get).mockResolvedValue({
        data: {
          position_format: 'english',
          handedness_format: 'alphabet',
          section_header_format: 'none',
          show_number_prefix: true,
          batting_stats_config: {
            avg: false,
            hr: false,
            rbi: false,
            sb: false,
            obp: false,
            ops: false,
          },
          pitching_stats_config: {
            w_l: false,
            games: false,
            era: false,
            so: false,
            ip: false,
            hold: false,
            save: false,
          },
        },
      })

      const player = makePlayer({ player_id: 1, number: 'F01', player_name: '選手A' })
      store.startingLineup = [{ battingOrder: 1, playerId: 1, position: 'RF' }]
      store.benchPlayers = [1]

      const teamId = ref(5)
      const { benchHitterText, init } = useSquadTextGenerator(teamId)
      await init([player])

      expect(benchHitterText.value).toContain('控え野手')
      expect(benchHitterText.value).not.toContain('【控え野手】')
    })
  })
})
