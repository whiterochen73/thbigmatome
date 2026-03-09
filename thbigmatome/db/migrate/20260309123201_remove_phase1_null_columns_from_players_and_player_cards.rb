class RemovePhase1NullColumnsFromPlayersAndPlayerCards < ActiveRecord::Migration[8.1]
  def change
    # players テーブル: 全件NULL確認済みカラム削除 (22カラム)
    remove_column :players, :starter_stamina, :integer
    remove_column :players, :relief_stamina, :integer
    remove_column :players, :batting_style_description, :string
    remove_column :players, :special_defense_c, :string
    remove_column :players, :throwing_c, :integer
    remove_column :players, :defense_p, :string
    remove_column :players, :defense_c, :string
    remove_column :players, :defense_1b, :string
    remove_column :players, :defense_2b, :string
    remove_column :players, :defense_3b, :string
    remove_column :players, :defense_ss, :string
    remove_column :players, :defense_lf, :string
    remove_column :players, :defense_cf, :string
    remove_column :players, :defense_rf, :string
    remove_column :players, :defense_of, :string
    remove_column :players, :throwing_lf, :string
    remove_column :players, :throwing_cf, :string
    remove_column :players, :throwing_rf, :string
    remove_column :players, :throwing_of, :string
    remove_column :players, :batting_style_id, :bigint
    remove_column :players, :pitching_style_id, :bigint
    remove_column :players, :position, :string

    # player_cards テーブル: 全件NULL確認済みカラム削除 (3カラム)
    remove_column :player_cards, :batting_style_description, :string
    remove_column :player_cards, :card_image_path, :string
    remove_column :player_cards, :abilities, :jsonb
  end
end
