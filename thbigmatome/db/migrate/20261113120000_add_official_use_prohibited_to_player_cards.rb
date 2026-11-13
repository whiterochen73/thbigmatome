class AddOfficialUseProhibitedToPlayerCards < ActiveRecord::Migration[8.1]
  def change
    # カード画像の注記「※公式戦で使用できません。」の印（全カード取り込み方針、cmd_1891）
    add_column :player_cards, :official_use_prohibited, :boolean, default: false, null: false
  end
end
