class ChangeStadiumIdNullableInGames < ActiveRecord::Migration[8.1]
  def change
    change_column_null :games, :stadium_id, true
  end
end
