# db/scripts/add_cost_players_506.rb
# cmd_506: PM/完走/UR未登録CostPlayer全件DB登録（約30件）
# 冪等性あり: find_or_create_by使用
#
# 実行方法:
#   docker compose exec rails rails runner db/scripts/add_cost_players_506.rb

cost = Cost.find_by!(name: "2025年12月コスト改定")
puts "対象コスト表: #{cost.name} (id=#{cost.id})"

created_players = 0
created_cost_players = 0
skipped = 0
errors = []

# 次の採番用: 純粋数字のnumberの最大値+1
max_num = Player.where("number ~ ?", '^[0-9]+$').pluck(:number).map(&:to_i).max
next_num = max_num + 1
puts "Player番号採番開始: #{next_num}"

def assign_number(next_num)
  num = next_num[0]
  next_num[0] += 1
  num.to_s
end

def create_or_skip_cost_player(cost, player, normal_cost, label, results)
  cp = CostPlayer.find_or_initialize_by(cost: cost, player: player)
  if cp.new_record?
    cp.normal_cost = normal_cost
    if cp.save
      puts "  [CREATE CostPlayer] #{label}: normal_cost=#{normal_cost}"
      results[:created] += 1
    else
      results[:errors] << "CostPlayer create failed for #{label}: #{cp.errors.full_messages}"
    end
  else
    puts "  [SKIP CostPlayer]  #{label}: already exists (normal_cost=#{cp.normal_cost})"
    results[:skipped] += 1
  end
end

def create_player_and_cost_player(cost, name, number, is_pitcher, normal_cost, label, results)
  player = Player.find_or_initialize_by(name: name)
  if player.new_record?
    player.number = number
    player.is_pitcher = is_pitcher
    player.is_relief_only = false
    player.speed = 1
    player.bunt = 1
    player.steal_start = 1
    player.steal_end = 1
    player.injury_rate = 6
    if player.save
      puts "  [CREATE Player] #{label}: id=#{player.id}, number=#{number}"
      results[:created_players] += 1
    else
      results[:errors] << "Player create failed for #{label}: #{player.errors.full_messages}"
      return
    end
  else
    puts "  [SKIP Player]   #{label}: already exists (id=#{player.id}, number=#{player.number})"
    results[:skipped] += 1
  end
  create_or_skip_cost_player(cost, player, normal_cost, label, results)
end

results = { created: 0, created_players: 0, skipped: 0, errors: [] }
next_num_ref = [ next_num ]

puts ""
puts "=== セクション1: 既存PlayerへのCostPlayer追加 ==="

# ---- PMプレイヤー(既存) ----
puts "-- PMプレイヤー(既存Player) --"

create_or_skip_cost_player(cost, Player.find(586), 10, "ふぁん (#214)", results)
create_or_skip_cost_player(cost, Player.find(567), 15, "マゼラン (#025)", results)
create_or_skip_cost_player(cost, Player.find(560), 8,  "マゼラン2/マゼラン(2) (#007)", results)
create_or_skip_cost_player(cost, Player.find(587), 10, "じょーかー (#208)", results)
create_or_skip_cost_player(cost, Player.find(585), 9,  "ガブリチュウ (#205)", results)
create_or_skip_cost_player(cost, Player.find(569), 5,  "pontiti (#028)", results)
create_or_skip_cost_player(cost, Player.find(561), 4,  "れもん (#008)", results)
create_or_skip_cost_player(cost, Player.find(583), 2,  "takky (#085)", results)
create_or_skip_cost_player(cost, Player.find(573), 4,  "Judah (#037)", results)

# ---- 完走版・UR版(既存Player) ----
puts "-- 完走版・UR版・その他(既存Player) --"

create_or_skip_cost_player(cost, Player.find(618), 7,  "聖 白蓮(佐世保) (#76)", results)
create_or_skip_cost_player(cost, Player.find(619), 1,  "小悪魔(時津) (#91)", results)
create_or_skip_cost_player(cost, Player.find(617), 3,  "洩矢 諏訪子(茨木) (#49)", results)
create_or_skip_cost_player(cost, Player.find(590), 3,  "ナズーリン(厚木) (#71)", results)
create_or_skip_cost_player(cost, Player.find(609), 4,  "近藤 咲(桜木町) (#70)", results)
create_or_skip_cost_player(cost, Player.find(600), 20, "有原 翼(里ヶ浜) (#10)", results)
create_or_skip_cost_player(cost, Player.find(588), 3,  "ひいらぎ (#098)", results)
create_or_skip_cost_player(cost, Player.find(589), 12, "ヘカーティア・L(PDX/ポートランド) (#103)", results)

puts ""
puts "=== セクション2: 新規Player + CostPlayer 作成 ==="

# ---- PMプレイヤー(新規) 5件 ----
puts "-- PMプレイヤー新規 --"

create_player_and_cost_player(cost, "ゆだ2",   assign_number(next_num_ref), true,  12, "ゆだ2",   results)
create_player_and_cost_player(cost, "mori3",   assign_number(next_num_ref), true,  10, "mori3",   results)
create_player_and_cost_player(cost, "けいようし2", assign_number(next_num_ref), true, 6, "けいようし2", results)
create_player_and_cost_player(cost, "ベルン",  assign_number(next_num_ref), true,   5, "ベルン",  results)
create_player_and_cost_player(cost, "cyan2",   assign_number(next_num_ref), false,  6, "cyan2",   results)

# ---- 完走版(新規) 7件 ----
puts "-- 完走版新規 --"

create_player_and_cost_player(cost, "摩多羅 隠岐奈 (天保山)", assign_number(next_num_ref), true,  7, "摩多羅(天保山)", results)
create_player_and_cost_player(cost, "坂田 ネムノ (安曇野)",   assign_number(next_num_ref), true,  1, "坂田ネムノ(安曇野)", results)
create_player_and_cost_player(cost, "永江 衣玖 (最上川)",     assign_number(next_num_ref), false, 5, "衣玖(最上川)", results)
create_player_and_cost_player(cost, "藤原 妹紅 (信楽)",       assign_number(next_num_ref), false, 5, "藤原妹紅(信楽)", results)
create_player_and_cost_player(cost, "今泉 影狼 (下館)",       assign_number(next_num_ref), false, 4, "影狼(下館)", results)
create_player_and_cost_player(cost, "椎名 ゆかり (那珂川)",   assign_number(next_num_ref), false, 2, "椎名ゆかり(那珂川)", results)
create_player_and_cost_player(cost, "菅牧 典 (小牧)",         assign_number(next_num_ref), false, 4, "菅牧典(小牧)", results)

# ---- UR版(新規) 2件 ----
puts "-- UR版新規 --"

create_player_and_cost_player(cost, "中野綾香 (UR)", assign_number(next_num_ref), false, 10, "中野綾香(UR)", results)
create_player_and_cost_player(cost, "小鳥遊柚 (UR)", assign_number(next_num_ref), false,  9, "小鳥遊柚(UR)", results)

# ---- セクションc (新規1件) ----
puts "-- セクションc新規 --"

create_player_and_cost_player(cost, "初瀬麻里安 (UR)", assign_number(next_num_ref), false, 8, "初瀬麻里安(UR)", results)

# ---- 結果サマリー ----
puts ""
puts "=== 登録完了 ==="
puts "新規Player作成: #{results[:created_players]}件"
puts "新規CostPlayer作成: #{results[:created]}件"
puts "スキップ: #{results[:skipped]}件"

if results[:errors].any?
  puts "エラー:"
  results[:errors].each { |e| puts "  - #{e}" }
  raise "スクリプトでエラーが発生しました"
else
  puts "エラーなし"
end
