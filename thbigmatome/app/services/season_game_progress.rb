require "digest"

# チームごとの試合数の進み具合（コミッショナーのダッシュボードの「進み具合」。cmd_1794 段3、cmd_1802 段3。Operator 決定 2026-11-02）。
#
# 「雨天中止があっても 143 試合消化するので、143 試合と出す。未振替数がどこかでわかるようにしたい。」
#
# - 総数 regular_total = 日程マスタ（schedule_details）のレギュラー（通常・交流戦）の試合日の数。チームの雨天中止・ノーゲーム・振り替えでは動かさない。
#   マスタはシーズンを作る時の写し元だが、シーズンは元のマスタの id を持たない。そのためシーズンの日付の集合と同じ日付の集合を持つマスタを使う
#   （NoGameDateNormalizer と同じ引き方）。どれとも合わなければ id が最小のマスタで数える。日程が 1 行も無いシーズンは総数も 0
# - 消化 regular_played = 数える日（試合日でノーゲームでない日）のうち結果が入った日。「結果が入った」は得点が自軍・相手とも保存済み
#   （SeasonCurrentRange.result? と同じ。ノーゲームは数えない日なので含まない）
# - 未振替 regular_unrescheduled = 総数のうち、まだ日程に載っていない試合の数 = max(0, 総数 − そのシーズンの数える日)。
#   数える日 = レギュラーの試合日（通常・交流戦）でノーゲームでない日。雨天中止・ノーゲーム・試合日を移動日や予備日へ手で直した日は、どれも
#   数える日が減るので同じく未振替に出る（中止・ノーゲーム・振り替えの種類を数える式は、入力の仕方で取りこぼすため使わない）。
#   予備日などを試合日にして振り替えると数える日が増えて未振替が減る。数える日が総数を超えるチームは 0（超えた数は返さない）
# - プレーオフ日はレギュラーの総数・消化に入れない。プレーオフ日は日程の全チームに同じ日数（開発 DB の複製で 17 日）あり、チームが進出するかで
#   試合数が変わるため総数は意味を持たない。消化したプレーオフ日の数だけ返す
#
# 全チーム分を 4 本の問い合わせ（マスタ・シーズンごとの日付の署名・対象種別の日程・シーズン一覧）で求める。チームごとの問い合わせはしない。
class SeasonGameProgress
  Row = Struct.new(:team_id, :regular_total, :regular_played, :regular_unrescheduled, :playoff_played, keyword_init: true)

  REGULAR_DATE_TYPES = (SeasonSchedule::GAME_DATE_TYPES - [ SeasonSchedule::PLAYOFF_DATE_TYPE ]).freeze

  # シーズン 1 つ分の集計
  class Counter
    attr_reader :counted, :played, :playoff_played

    def initialize
      @counted = 0
      @played = 0
      @playoff_played = 0
    end

    def add(date_type, no_game, result)
      if REGULAR_DATE_TYPES.include?(date_type)
        return if no_game

        @counted += 1
        @played += 1 if result
      elsif date_type == SeasonSchedule::PLAYOFF_DATE_TYPE
        @playoff_played += 1 if result && !no_game
      end
    end
  end

  # { team_id => Row }。シーズンのあるチームすべて（休止中を含む）。日程が 1 行も無いシーズンは 0 / 0 / 0 / 0。シーズンの無いチームは含まない
  def self.by_team_id
    new.by_team_id
  end

  def by_team_id
    masters = master_types_by_schedule
    schedule_by_signature = masters.to_h { |schedule_id, types| [ Digest::MD5.hexdigest(types.keys.sort.map(&:to_s).join(",")), schedule_id ] }
    schedule_of_season = season_signatures.transform_values { |signature| schedule_by_signature.fetch(signature, masters.keys.min) }

    counters = Hash.new { |hash, season_id| hash[season_id] = Counter.new }
    relevant_rows.each { |season_id, date_type, no_game, result| counters[season_id].add(date_type, no_game, result) }

    Season.pluck(:id, :team_id).to_h do |season_id, team_id|
      master = masters[schedule_of_season[season_id]] # 日程が 1 行も無いシーズンは nil（総数 0）
      counter = counters[season_id]
      total = master ? master.values.count { |type| REGULAR_DATE_TYPES.include?(type) } : 0
      [ team_id, Row.new(team_id: team_id, regular_total: total, regular_played: counter.played,
                         regular_unrescheduled: [ total - counter.counted, 0 ].max, playoff_played: counter.playoff_played) ]
    end
  end

  private

  # { schedule_id => { date => date_type } }
  def master_types_by_schedule
    ScheduleDetail.pluck(:schedule_id, :date, :date_type).group_by(&:first)
                  .transform_values { |list| list.to_h { |_, date, type| [ date, type ] } }
  end

  # { season_id => 日付の署名 }（日程が 1 行でもあるシーズンだけ）
  def season_signatures
    SeasonSchedule.group(:season_id).pluck(:season_id, Arel.sql("string_agg(date::text, ',' ORDER BY date)"))
                  .to_h { |season_id, dates| [ season_id, Digest::MD5.hexdigest(dates) ] }
  end

  # 数える対象の種別（レギュラーの試合日・プレーオフ日）の日程。[season_id, date_type, no_game, 結果が入っているか]
  def relevant_rows
    SeasonSchedule.where(date_type: REGULAR_DATE_TYPES + [ SeasonSchedule::PLAYOFF_DATE_TYPE ])
                  .pluck(:season_id, :date_type, :no_game, Arel.sql("score IS NOT NULL AND opponent_score IS NOT NULL"))
  end
end
