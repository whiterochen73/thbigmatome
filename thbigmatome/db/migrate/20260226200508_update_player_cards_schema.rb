class UpdatePlayerCardsSchema < ActiveRecord::Migration[8.0]
  def change
    # 追加カラム
    add_column :player_cards, :is_closer, :boolean, default: false, null: false
    add_column :player_cards, :unique_traits, :text
    add_column :player_cards, :injury_traits, :jsonb
    add_column :player_cards, :biorhythm_period, :string
    add_column :player_cards, :biorhythm_date_ranges, :jsonb

    # 削除カラム（守備値は player_card_defenses に移行）
    remove_column :player_cards, :defense_p, :string
    remove_column :player_cards, :defense_c, :string
    remove_column :player_cards, :throwing_c, :integer
    remove_column :player_cards, :defense_1b, :string
    remove_column :player_cards, :defense_2b, :string
    remove_column :player_cards, :defense_3b, :string
    remove_column :player_cards, :defense_ss, :string
    remove_column :player_cards, :defense_of, :string
    remove_column :player_cards, :throwing_of, :string
    remove_column :player_cards, :defense_lf, :string
    remove_column :player_cards, :throwing_lf, :string
    remove_column :player_cards, :defense_cf, :string
    remove_column :player_cards, :throwing_cf, :string
    remove_column :player_cards, :defense_rf, :string
    remove_column :player_cards, :throwing_rf, :string
  end
end
