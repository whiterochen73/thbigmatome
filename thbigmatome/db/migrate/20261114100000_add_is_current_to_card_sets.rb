class AddIsCurrentToCardSets < ActiveRecord::Migration[8.1]
  def up
    # 現行カードセットの印（cmd_1893/subtask_1893e）。選手の登録画面で選べるのは現行のカードだけ。既存の行は現行、PM2026 だけ外す。
    # 印の更新は取り込みの対応表（config/card_set_definitions.yml）から行う。ここは PM2026 を外す一回限りの更新
    add_column :card_sets, :is_current, :boolean, default: true, null: false
    execute "UPDATE card_sets SET is_current = FALSE WHERE set_type = 'pm2026'"
  end

  def down
    remove_column :card_sets, :is_current
  end
end
