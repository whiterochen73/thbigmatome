class AllowNullCompetitionIdInGames < ActiveRecord::Migration[8.1]
  def change
    change_column_null :games, :competition_id, true
  end
end
