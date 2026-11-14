class AddCardSeqToPlayerCards < ActiveRecord::Migration[8.1]
  # 取り込み CSV の通し番号（card_seq）を既存カードの安定した鍵にする（cmd_1898）。
  # 既存の行は NULL のまま。取り込みの最初の 1 回が、セット・Player・背番号・別名表・打撃表の一致で照合して書き込む。
  def change
    add_column :player_cards, :card_seq, :integer
    add_index :player_cards, :card_seq, unique: true, where: "card_seq IS NOT NULL", name: "index_player_cards_on_card_seq"
  end
end
