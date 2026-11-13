class AddCharacterKeyToPlayers < ActiveRecord::Migration[8.1]
  # 規則は Player.character_key_for と同じ（移行は後の変更に左右されないよう、ここに書き写してある）
  SUFFIX = /[（(]([^()（）]+)[）)]\z/
  DIGITS = /\A[0-9０-９]+\z/

  def up
    # 同じキャラクターのカードを持つ Player を同じ鍵で束ねる（cmd_1893/subtask_1893e）。チームに同じ鍵の選手を 2 人入れられない。
    # 既存の行は名前からしか作れない（取り込みの base_player_name は DB に残っていない）。
    add_column :players, :character_key, :string
    add_index :players, :character_key

    select_rows("SELECT id, name FROM players").each do |id, name|
      execute "UPDATE players SET character_key = #{quote(key_for(name))} WHERE id = #{id.to_i}"
    end
  end

  def down
    remove_index :players, :character_key
    remove_column :players, :character_key
  end

  private

  def key_for(name)
    squeezed = name.to_s.gsub(/[[:space:]　]+/, "")
    m = SUFFIX.match(squeezed)
    return squeezed if m.nil? || DIGITS.match?(m[1])

    squeezed[0...m.begin(0)]
  end
end
