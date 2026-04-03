class RemoveSpeedBuntStealInjuryFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :speed, :integer
    remove_column :players, :bunt, :integer
    remove_column :players, :steal_start, :integer
    remove_column :players, :steal_end, :integer
    remove_column :players, :injury_rate, :integer
  end
end
