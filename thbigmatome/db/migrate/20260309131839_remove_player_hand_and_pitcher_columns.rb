class RemovePlayerHandAndPitcherColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :throwing_hand, :string
    remove_column :players, :batting_hand, :string
    remove_column :players, :is_pitcher, :boolean
    remove_column :players, :is_relief_only, :boolean
  end
end
