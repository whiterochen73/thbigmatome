class AllowNullCompetitionIdInPitcherGameStates < ActiveRecord::Migration[8.1]
  def change
    change_column_null :pitcher_game_states, :competition_id, true
  end
end
