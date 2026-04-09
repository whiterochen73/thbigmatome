class AddNoOutExitToPitcherGameStates < ActiveRecord::Migration[8.1]
  def change
    add_column :pitcher_game_states, :no_out_exit, :boolean, default: false, null: false
  end
end
