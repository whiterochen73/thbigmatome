class CreatePlayerCardPlayerTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :player_card_player_types do |t|
      t.references :player_card, null: false, foreign_key: true
      t.references :player_type, null: false, foreign_key: true

      t.timestamps
    end

    add_index :player_card_player_types, [ :player_card_id, :player_type_id ], unique: true
  end
end
