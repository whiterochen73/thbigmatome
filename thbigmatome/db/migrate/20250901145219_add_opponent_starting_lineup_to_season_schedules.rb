class AddOpponentStartingLineupToSeasonSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :season_schedules, :opponent_starting_lineup, :jsonb
  end
end
