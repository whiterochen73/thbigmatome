class AddPlayerCardIdToCostPlayersV2 < ActiveRecord::Migration[8.1]
  def up
    add_column :cost_players, :player_card_id, :bigint, null: true
    add_foreign_key :cost_players, :player_cards
    add_index :cost_players, :player_card_id, name: "index_cost_players_on_player_card_id"

    # Remove old non-unique index on (cost_id, player_id)
    remove_index :cost_players, name: "index_cost_players_on_cost_id_and_player_id"

    # Partial unique index for base entries (player_card_id IS NULL)
    add_index :cost_players, [ :cost_id, :player_id ],
              unique: true,
              where: "player_card_id IS NULL",
              name: "index_cost_players_base_unique"

    # Partial unique index for variant entries (player_card_id IS NOT NULL)
    add_index :cost_players, [ :cost_id, :player_id, :player_card_id ],
              unique: true,
              where: "player_card_id IS NOT NULL",
              name: "index_cost_players_variant_unique"
  end

  def down
    remove_index :cost_players, name: "index_cost_players_variant_unique"
    remove_index :cost_players, name: "index_cost_players_base_unique"
    remove_index :cost_players, name: "index_cost_players_on_player_card_id"
    remove_foreign_key :cost_players, :player_cards
    remove_column :cost_players, :player_card_id

    # Restore original non-unique index
    add_index :cost_players, [ :cost_id, :player_id ],
              name: "index_cost_players_on_cost_id_and_player_id"
  end
end
