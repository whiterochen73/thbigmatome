class AddEarnedRunsAndDecisionToPitcherGameStates < ActiveRecord::Migration[8.1]
  def change
    add_column :pitcher_game_states, :earned_runs, :integer, default: 0, null: false
    add_column :pitcher_game_states, :decision, :string, null: true
    add_index :pitcher_game_states, :decision
  end
end
