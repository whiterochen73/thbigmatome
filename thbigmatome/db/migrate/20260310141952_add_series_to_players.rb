class AddSeriesToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :series, :string, null: true, default: nil
  end
end
