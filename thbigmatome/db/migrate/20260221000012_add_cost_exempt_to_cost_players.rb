class AddCostExemptToCostPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :cost_players, :cost_exempt, :boolean, default: false, null: false
  end
end
