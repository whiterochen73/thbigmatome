class AddVariantToPlayerCards < ActiveRecord::Migration[8.0]
  def up
    add_column :player_cards, :variant, :string

    remove_index :player_cards, name: "index_player_cards_on_card_set_player_card_type"

    # COALESCE(variant, '') でNULL同士も一意性を保証する関数インデックス
    execute <<~SQL
      CREATE UNIQUE INDEX index_player_cards_on_card_set_player_card_type_variant
      ON player_cards (card_set_id, player_id, card_type, COALESCE(variant, ''))
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_player_cards_on_card_set_player_card_type_variant"

    add_index :player_cards, [ :card_set_id, :player_id, :card_type ],
              name: "index_player_cards_on_card_set_player_card_type",
              unique: true

    remove_column :player_cards, :variant
  end
end
