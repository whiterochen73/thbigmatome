class AddPlayerCardIdToCostPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :cost_players, :player_card, null: true, foreign_key: true
  end
end
