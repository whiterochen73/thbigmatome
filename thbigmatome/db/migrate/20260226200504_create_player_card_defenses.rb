class CreatePlayerCardDefenses < ActiveRecord::Migration[8.0]
  def change
    create_table :player_card_defenses do |t|
      t.references :player_card, null: false, foreign_key: true
      t.string :position, null: false
      t.integer :range_value, null: false
      t.string :error_rank, null: false
      t.string :throwing
      t.references :condition, foreign_key: { to_table: :trait_conditions }

      t.timestamps
    end

    add_index :player_card_defenses, [ :player_card_id, :position, :condition_id ], unique: true,
              name: "index_player_card_defenses_on_card_position_condition"
  end
end
