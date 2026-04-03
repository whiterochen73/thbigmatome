class CreatePlayerCardTraits < ActiveRecord::Migration[8.0]
  def change
    create_table :player_card_traits do |t|
      t.references :player_card, null: false, foreign_key: true
      t.references :trait_definition, null: false, foreign_key: true
      t.references :condition, foreign_key: { to_table: :trait_conditions }
      t.string :role
      t.integer :sort_order, default: 0

      t.timestamps
    end
  end
end
