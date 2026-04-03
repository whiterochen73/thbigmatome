class RemovePlayerCardIdFromCostPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :cost_players, :player_card_id, :bigint
  end
end
