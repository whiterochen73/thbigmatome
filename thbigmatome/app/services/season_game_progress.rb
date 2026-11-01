# チームごとの試合数の進み具合（コミッショナーのダッシュボードの「進み具合」。cmd_1794 段3、Operator 決定 2026-11-02）。
#
# - 総数 = 日程の「試合数に数える日」（SeasonSchedule.counted_games = 試合日かつノーゲームでない日）。ノーゲームの日は数えず、
#   振り替えた日（予備日などを試合日にした日）が 1 試合として増える。日程が組み替わればそのまま総数に出る（143 のような定数は持たない）
# - 消化 = 数える日のうち結果が入った日。「結果が入った」は得点が自軍・相手とも保存済み（SeasonCurrentRange.result? と同じ。ノーゲームは数えない日なので含まない）
# - プレーオフ日はレギュラーの総数・消化に入れない。プレーオフ日は日程の全チームに同じ日数（開発 DB の複製で 17 日）あり、チームが進出するかで
#   試合数が変わるため総数は意味を持たない。消化したプレーオフ日の数だけ返す
#
# 全チーム分を 2 本の集計（日程のグループ集計・シーズンの一覧）で求める。チームごとの問い合わせはしない。
class SeasonGameProgress
  Row = Struct.new(:team_id, :regular_total, :regular_played, :playoff_played, keyword_init: true)

  REGULAR_DATE_TYPES = (SeasonSchedule::GAME_DATE_TYPES - [ SeasonSchedule::PLAYOFF_DATE_TYPE ]).freeze

  # { team_id => Row }。シーズンのあるチームすべて（休止中を含む）。日程が 1 行も無いシーズンは 0 / 0 / 0。シーズンの無いチームは含まない
  def self.by_team_id
    counts = SeasonSchedule.counted_games.joins(:season).group("seasons.team_id").pluck(
      "seasons.team_id",
      sql_count("date_type IN (:regular)"),
      sql_count("date_type IN (:regular) AND score IS NOT NULL AND opponent_score IS NOT NULL"),
      sql_count("date_type = :playoff AND score IS NOT NULL AND opponent_score IS NOT NULL")
    ).to_h { |team_id, total, played, playoff_played| [ team_id, [ total, played, playoff_played ] ] }

    Season.pluck(:team_id).to_h do |team_id|
      total, played, playoff_played = counts.fetch(team_id, [ 0, 0, 0 ])
      [ team_id, Row.new(team_id: team_id, regular_total: total, regular_played: played, playoff_played: playoff_played) ]
    end
  end

  def self.sql_count(condition)
    Arel.sql(SeasonSchedule.sanitize_sql_array([ "COUNT(*) FILTER (WHERE #{condition})", { regular: REGULAR_DATE_TYPES, playoff: SeasonSchedule::PLAYOFF_DATE_TYPE } ]))
  end
  private_class_method :sql_count
end
