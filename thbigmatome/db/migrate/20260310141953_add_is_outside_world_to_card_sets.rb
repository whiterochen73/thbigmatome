class AddIsOutsideWorldToCardSets < ActiveRecord::Migration[8.1]
  def change
    add_column :card_sets, :is_outside_world, :boolean, null: false, default: false
  end
end
