class SetupManyToManyForPlayerPlayerTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :player_player_types do |t|
      t.references :player, null: false, foreign_key: true
      t.references :player_type, null: false, foreign_key: true

      t.timestamps
    end

    add_index :player_player_types, [:player_id, :player_type_id], unique: true
  end
end
