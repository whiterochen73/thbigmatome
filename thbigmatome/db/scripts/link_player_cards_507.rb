# db/scripts/link_player_cards_507.rb
# cmd_507: CostPlayerへのPlayerCard紐づけ（PM2026カードセット）
# sec2の新規Player15件についてresult_pm2026.yamlからPlayerCardを作成・登録
# 冪等性あり: find_or_initialize_by使用
#
# 実行方法:
#   docker compose exec rails rails runner db/scripts/link_player_cards_507.rb

require "yaml"

cost  = Cost.find_by!(name: "2025年12月コスト改定")
pm2026 = CardSet.find_by!(name: "PM2026")

yaml_path = File.join(__dir__, "result_pm2026.yaml")
puts "YAML読み込み: #{yaml_path}"
yaml_data = YAML.load_file(yaml_path, permitted_classes: [ Symbol ])
cards = yaml_data["cards"]
puts "YAMLカード数: #{cards.count}"
puts ""

# ---------------------------------------------------------------------------
# 名前正規化: スペース除去 + 括弧表記を数字サフィックス変換
# 例: "けいようし (2)" → "けいようし2"
#     "摩多羅 隠岐奈 (天保山)" → "摩多羅隠岐奈"  (地名は除去)
# ---------------------------------------------------------------------------
def normalize_name(name)
  s = name.to_s.strip
  # "(2)"→"2", "(3)"→"3" のみ数字に変換
  s = s.gsub(/\s*[（(](\d+)[）)]\s*$/) { $1 }
  # 残りの括弧内(地名・UR等)を除去
  s = s.gsub(/\s*[（(][^）)]+[）)]\s*/, "")
  # スペース除去
  s.gsub(/\s+/, "")
end

# YAMLカードを正規化名でインデックス（複数ある場合は最初を使用）
yaml_by_norm_name = {}
cards.each do |c|
  next unless c["name"]
  key = normalize_name(c["name"])
  yaml_by_norm_name[key] ||= c
end
# 特定カードの明示的上書き (辞書順序問題の回避)
# 初瀬麻里安 number=5 (UR対応の無印版)
hatsu_card = cards.find { |c| c["number"].to_s == "5" && c["name"].to_s.include?("麻里安") }
yaml_by_norm_name["初瀬麻里安"] = hatsu_card if hatsu_card

# ---------------------------------------------------------------------------
# 明示的マッピング: Player.id → YAMLカードをどの正規化名で引き当てるか
# (自動引き当てでは衝突・誤マッチが起きるケース)
# ---------------------------------------------------------------------------
EXPLICIT_YAML_NAME = {
  # 初瀬麻里安(UR): normalize_nameだと"湘南"版が先に入るため明示指定
  657 => "初瀬麻里安"  # yaml: number=5 (接尾辞なし版)
}.freeze

# ---------------------------------------------------------------------------
# sec2: 新規Player 15件 (Player.id=643〜657)
# cmd_506で作成された順: ゆだ2, mori3, けいようし2, ベルン, cyan2,
#   摩多羅..., 坂田..., 永江..., 藤原..., 今泉..., 椎名..., 菅牧...,
#   中野..., 小鳥遊..., 初瀬...
# ---------------------------------------------------------------------------
sec2_player_ids = [ 643, 644, 645, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657 ]

created_count = 0
skipped_count = 0
errors        = []

def parse_steal(steal_str)
  return { steal_start: 1, steal_end: 1 } unless steal_str
  parts = steal_str.to_s.split
  { steal_start: parts[0].to_i, steal_end: (parts[1] || parts[0]).to_i }
end

def parse_handedness(str)
  return { handedness: nil, is_switch_hitter: false } unless str
  is_sw = str.include?("スイッチ") || str.include?("両")
  { handedness: str, is_switch_hitter: is_sw }
end

# fatigue_p: '6'→starter_stamina=6, '1R'→is_relief_only=true, '1'(4未満)→nil
def parse_fatigue(fatigue_p)
  return { starter_stamina: nil, is_relief_only: false } unless fatigue_p
  str = fatigue_p.to_s.strip
  if str.upcase.include?("R")
    { starter_stamina: nil, is_relief_only: true }
  else
    val = str.to_i
    { starter_stamina: (4..9).include?(val) ? val : nil, is_relief_only: false }
  end
end

Player.where(id: sec2_player_ids).order(:id).each do |player|
  # 明示的マッピングを優先、なければ自動正規化
  norm = EXPLICIT_YAML_NAME[player.id] || normalize_name(player.name)
  yaml_card = yaml_by_norm_name[norm]

  unless yaml_card
    msg = "NOT FOUND in YAML: id=#{player.id} ##{player.number} #{player.name} (norm=#{norm})"
    errors << msg
    puts "  [SKIP] #{msg}"
    skipped_count += 1
    next
  end

  puts "  [MATCH] #{player.name} → yaml: #{yaml_card["name"]} (##{yaml_card["number"]})"

  pc = PlayerCard.find_or_initialize_by(card_set: pm2026, player: player)

  if pc.new_record?
    handedness_info = parse_handedness(yaml_card["handedness"])
    steal_info      = parse_steal(yaml_card["steal"])
    fatigue_info    = parse_fatigue(yaml_card["fatigue_p"])
    batting_table   = yaml_card["batting_results"]&.to_json

    pc.assign_attributes(
      card_type:        yaml_card["card_type"],
      handedness:       handedness_info[:handedness],
      is_switch_hitter: handedness_info[:is_switch_hitter],
      is_pitcher:       yaml_card["card_type"] == "pitcher",
      speed:            yaml_card["run_speed"].to_i,
      bunt:             yaml_card["bunt"].to_i,
      steal_start:      steal_info[:steal_start],
      steal_end:        steal_info[:steal_end],
      injury_rate:      yaml_card["injury_level"].to_i,
      is_relief_only:   fatigue_info[:is_relief_only],
      starter_stamina:  fatigue_info[:starter_stamina],
      batting_table:    batting_table
    )

    unless pc.save
      err = "SAVE FAILED: #{player.name}: #{pc.errors.full_messages.join(', ')}"
      errors << err
      puts "  [ERR] #{err}"
      skipped_count += 1
      next
    end

    puts "    → PlayerCard##{pc.id} 作成"

    # PlayerCardDefense
    (yaml_card["defense"] || {}).each do |pos, data|
      next unless data
      defense = PlayerCardDefense.find_or_initialize_by(player_card: pc, position: pos)
      if defense.new_record?
        defense.range_value = data["range"].to_i
        defense.error_rank  = data["error"]
        defense.throwing    = data["T"]
        defense.save!
        puts "    → Defense[#{pos}] 作成"
      end
    end

    # PlayerCardTrait
    traits_raw = yaml_card["traits"] || []
    current_condition = nil
    sort = 0
    traits_raw.each do |t|
      t_str = t.to_s
      # "(無走者)" 等の条件マーカー
      if t_str.match?(/\A[（(].+[）)]\z/)
        cond_name = t_str.gsub(/[（(）)]/, "")
        current_condition = TraitCondition.find_by(name: cond_name)
        next
      end
      td = TraitDefinition.find_by(name: t_str)
      if td
        PlayerCardTrait.find_or_create_by!(player_card: pc, trait_definition: td, sort_order: sort) do |pct|
          pct.condition_id = current_condition&.id
        end
        sort += 1
      else
        puts "    [WARN] TraitDefinition not found: '#{t_str}'"
      end
      current_condition = nil
    end

    created_count += 1
  else
    puts "    → PlayerCard##{pc.id} 既存（スキップ）"
    skipped_count += 1
  end

  # CostPlayer.player_card_id を更新 (マイグレーション20260308001000で追加)
  cp = CostPlayer.find_by(cost: cost, player: player)
  if cp && cp.player_card_id != pc.id
    cp.update!(player_card_id: pc.id)
    puts "    → CostPlayer##{cp.id}.player_card_id = #{pc.id} 更新"
  end
end

# ---------------------------------------------------------------------------
# sec1 CostPlayer.player_card_id 更新 (PlayerCardは既存)
# ---------------------------------------------------------------------------
puts ""
puts "=== sec1 CostPlayer.player_card_id 更新 ==="
sec1_player_ids = [ 586, 567, 560, 587, 585, 569, 561, 583, 573, 618, 619, 617, 590, 609, 600, 588, 589 ]
sec1_updated = 0
Player.where(id: sec1_player_ids).each do |player|
  pc = PlayerCard.find_by(card_set: pm2026, player: player)
  next unless pc
  cp = CostPlayer.find_by(cost: cost, player: player)
  next unless cp
  if cp.player_card_id != pc.id
    cp.update!(player_card_id: pc.id)
    puts "  #{player.name}: player_card_id=#{pc.id} 更新"
    sec1_updated += 1
  else
    puts "  #{player.name}: 既に紐づき済み (pc##{pc.id})"
  end
end
puts "sec1 更新: #{sec1_updated}件"

puts ""
puts "=== 完了 ==="
puts "PlayerCard新規作成: #{created_count}件"
puts "スキップ（既存/未マッチ）: #{skipped_count}件"
if errors.any?
  puts "未マッチ/エラー:"
  errors.each { |e| puts "  - #{e}" }
else
  puts "エラーなし"
end
