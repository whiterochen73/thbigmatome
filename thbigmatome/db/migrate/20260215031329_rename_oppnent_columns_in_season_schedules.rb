class RenameOppnentColumnsInSeasonSchedules < ActiveRecord::Migration[8.0]
  def change
    rename_column :season_schedules, :oppnent_score, :opponent_score
    rename_column :season_schedules, :oppnent_team_id, :opponent_team_id
  end
end
