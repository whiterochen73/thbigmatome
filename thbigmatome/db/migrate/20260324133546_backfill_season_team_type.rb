class BackfillSeasonTeamType < ActiveRecord::Migration[8.1]
  def up
    Season.where(team_type: nil).find_each do |season|
      season.update_columns(team_type: season.team&.team_type || "normal")
    end
  end

  def down
    # no-op
  end
end
