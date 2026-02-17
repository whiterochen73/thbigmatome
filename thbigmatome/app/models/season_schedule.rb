class SeasonSchedule < ApplicationRecord
  belongs_to :season
  belongs_to :announced_starter, class_name: "TeamMembership", optional: true
  belongs_to :opponent_team, class_name: "Team", foreign_key: "opponent_team_id", optional: true
  belongs_to :winning_pitcher, class_name: "Player", optional: true
  belongs_to :losing_pitcher, class_name: "Player", optional: true
  belongs_to :save_pitcher, class_name: "Player", optional: true

  validates :home_away, inclusion: { in: [ "home", "visitor" ] }, allow_blank: true

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
end
