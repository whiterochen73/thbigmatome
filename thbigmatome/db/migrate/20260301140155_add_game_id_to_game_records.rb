class AddGameIdToGameRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :game_records, :game_id, :bigint, null: true
    add_foreign_key :game_records, :games, on_delete: :nullify
    add_index :game_records, :game_id, unique: true, where: "game_id IS NOT NULL",
              name: "index_game_records_on_game_id_partial"
  end
end
