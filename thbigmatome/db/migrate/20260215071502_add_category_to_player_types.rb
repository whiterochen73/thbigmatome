class AddCategoryToPlayerTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :player_types, :category, :string
  end
end
