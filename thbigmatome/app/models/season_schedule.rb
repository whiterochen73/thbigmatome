class SeasonSchedule < ApplicationRecord
  belongs_to :season
  belongs_to :announced_starter, class_name: "TeamMembership", optional: true
  belongs_to :opponent_team, class_name: "Team", foreign_key: "opponent_team_id", optional: true
  belongs_to :winning_pitcher, class_name: "Player", optional: true
  belongs_to :losing_pitcher, class_name: "Player", optional: true
  belongs_to :save_pitcher, class_name: "Player", optional: true

  validates :home_away, inclusion: { in: [ "home", "visitor" ] }, allow_blank: true

  # 得点が保存・変更されたら、その試合の自チーム先発の result_category を作り直す（E2）。
  # 区分は登板記録の保存時にだけ計算されていたため、得点を後から直しても長イニング敗戦・KO が残っていた。
  # 得点が消された（未入力に戻った）時は「負けではない」として作り直す。
  after_save :rebuild_pitcher_result_categories, if: -> { saved_change_to_score? || saved_change_to_opponent_score? }

  def calculated_game_number
    game_number || season.season_schedules
      .where(date_type: [ "game_day", "interleague_game_day" ])
      .where("date < ?", date)
      .count + 1
  end

  def game_result_hash
    return nil if score.blank? || opponent_score.blank?

    result = if score > opponent_score then "win"
    elsif score < opponent_score then "lose"
    else "draw"
    end

    {
      opponent_short_name: opponent_team&.short_name,
      score: "#{score} - #{opponent_score}",
      result: result
    }
  end

  private

  def rebuild_pitcher_result_categories
    PitcherResultCategoryRebuilder.new(apply: true, unscored: :not_loss).rebuild_for_schedule(self)
  end
end
