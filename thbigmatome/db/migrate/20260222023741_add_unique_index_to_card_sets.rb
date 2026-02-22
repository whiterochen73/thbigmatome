class AddUniqueIndexToCardSets < ActiveRecord::Migration[8.1]
  def change
    remove_index :card_sets, [ :year, :set_type ] if index_exists?(:card_sets, [ :year, :set_type ])
    add_index :card_sets, [ :year, :set_type ], unique: true
  end
end
