class AddAppearanceOrderToPitcherGameStates < ActiveRecord::Migration[7.1]
  def change
    add_column :pitcher_game_states, :appearance_order, :integer, null: false, default: 0
  end
end
