class AddColumnsToPitcherGameStates < ActiveRecord::Migration[8.1]
  def change
    add_column :pitcher_game_states, :is_opener, :boolean, default: false, null: false
    add_column :pitcher_game_states, :consecutive_short_rest_count, :integer, default: 0, null: false
    add_column :pitcher_game_states, :pre_injury_days_excluded, :integer, default: 0, null: false
  end
end
