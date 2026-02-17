class AddScoreboardToSeasonSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :season_schedules, :scoreboard, :jsonb
  end
end
