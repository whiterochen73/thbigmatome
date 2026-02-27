class AddHandednessAndFlagsToPlayerCards < ActiveRecord::Migration[8.1]
  def change
    add_column :player_cards, :handedness, :string
    add_column :player_cards, :is_switch_hitter, :boolean, default: false, null: false
    add_column :player_cards, :is_dual_wielder, :boolean, default: false, null: false
  end
end
