class AddIrcFieldsToPlayerCards < ActiveRecord::Migration[8.1]
  def change
    add_column :player_cards, :card_label, :string
    add_column :player_cards, :irc_macro_name, :string
    add_column :player_cards, :irc_display_name, :string
  end
end
