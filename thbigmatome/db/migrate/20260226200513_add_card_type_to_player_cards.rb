class AddCardTypeToPlayerCards < ActiveRecord::Migration[8.1]
  def up
    add_column :player_cards, :card_type, :string

    # Backfill: derive card_type from is_pitcher for existing records
    PlayerCard.reset_column_information
    PlayerCard.where(is_pitcher: true).update_all(card_type: "pitcher")
    PlayerCard.where(is_pitcher: false).update_all(card_type: "batter")

    # Replace unique index with one that includes card_type
    remove_index :player_cards, name: "index_player_cards_on_card_set_id_and_player_id"
    add_index :player_cards, [ :card_set_id, :player_id, :card_type ],
              unique: true,
              name: "index_player_cards_on_card_set_player_card_type"
  end

  def down
    remove_index :player_cards, name: "index_player_cards_on_card_set_player_card_type"
    add_index :player_cards, [ :card_set_id, :player_id ],
              unique: true,
              name: "index_player_cards_on_card_set_id_and_player_id"
    remove_column :player_cards, :card_type
  end
end
