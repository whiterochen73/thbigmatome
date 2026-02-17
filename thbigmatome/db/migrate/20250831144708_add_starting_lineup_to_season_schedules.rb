class AddStartingLineupToSeasonSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :season_schedules, :starting_lineup, :jsonb
  end
end
