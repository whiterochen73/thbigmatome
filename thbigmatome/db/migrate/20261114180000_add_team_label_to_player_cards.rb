class AddTeamLabelToPlayerCards < ActiveRecord::Migration[8.1]
  # カード上部の帯に出ているチーム名・印のうち、variant に入っていないもの（cmd_1901）。
  # variant は取り込みの鍵（一意 index・照合・付け替え・コストの行分け）なので触らず、画面の表示用に別の列で持つ。
  def change
    add_column :player_cards, :team_label, :string
  end
end
