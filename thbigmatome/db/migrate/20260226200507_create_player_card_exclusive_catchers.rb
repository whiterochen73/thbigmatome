class CreatePlayerCardExclusiveCatchers < ActiveRecord::Migration[8.0]
  def change
    create_table :player_card_exclusive_catchers, primary_key: [ :player_card_id, :catcher_player_id ] do |t|
      t.bigint :player_card_id, null: false
      t.bigint :catcher_player_id, null: false
    end

    add_foreign_key :player_card_exclusive_catchers, :player_cards, column: :player_card_id
    add_foreign_key :player_card_exclusive_catchers, :players, column: :catcher_player_id
  end
end
