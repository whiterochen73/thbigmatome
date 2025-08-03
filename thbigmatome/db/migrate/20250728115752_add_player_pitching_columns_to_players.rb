class AddPlayerPitchingColumnsToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :is_pitcher, :boolean, default: false
    add_column :players, :is_relief_only, :boolean, default: false
    add_column :players, :starter_stamina, :integer
    add_column :players, :relief_stamina, :integer
    add_reference :players, :pitching_skill, null: true, foreign_key: true
  end
end
