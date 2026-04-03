class AddNotNullToPlayerCardCardType < ActiveRecord::Migration[8.1]
  def up
    null_count = PlayerCard.where(card_type: nil).count
    raise "card_type nil records exist: #{null_count}" if null_count > 0
    change_column_null :player_cards, :card_type, false
  end

  def down
    change_column_null :player_cards, :card_type, true
  end
end
