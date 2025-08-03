class AddSpecialCatcherToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :special_defense_c, :string
    add_column :players, :special_throwing_c, :integer
  end
end
