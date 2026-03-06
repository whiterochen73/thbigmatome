# db/scripts/fix_cost_2025dec.rb
# 2025年12月コスト改定のコスト値不一致・追加・修正 計26件を修正するスクリプト
# 冪等性あり: 2回実行しても同じ結果
#
# 実行方法:
#   docker compose exec rails rails runner db/scripts/fix_cost_2025dec.rb
#   または: bundle exec rails runner db/scripts/fix_cost_2025dec.rb

cost = Cost.find_by!(name: "2025年12月コスト改定")
puts "対象コスト表: #{cost.name} (id=#{cost.id})"

updated = 0
errors = []

def update_cp(cp, attrs, player_name, errors)
  if cp.nil?
    errors << "CostPlayer not found for #{player_name}"
    return 0
  end
  before = cp.slice(*attrs.keys.map(&:to_s))
  cp.assign_attributes(attrs)
  if cp.changed?
    if cp.save
      puts "  [UPDATE] #{player_name}: #{before} -> #{cp.slice(*attrs.keys.map(&:to_s))}"
      1
    else
      errors << "Save failed for #{player_name}: #{cp.errors.full_messages}"
      0
    end
  else
    puts "  [SKIP]   #{player_name}: already correct"
    0
  end
end

# ---- ハチナイ (card_set: ハチナイ6.1) ----

# 1. 阿佐田あおい(#F17): fielder_only_cost=2, pitcher_only_cost=5, two_way_cost=7, normal_cost=nil
p_f17 = Player.find_by!(number: "F17")
cp = CostPlayer.find_by!(cost: cost, player: p_f17)
updated += update_cp(cp, {
  normal_cost: nil,
  fielder_only_cost: 2,
  pitcher_only_cost: 5,
  two_way_cost: 7
}, "阿佐田あおい(#F17)", errors)

# 2. 岸楓佳(#F64): normal_cost 3->6
p_f64 = Player.find_by!(number: "F64")
cp = CostPlayer.find_by!(cost: cost, player: p_f64)
updated += update_cp(cp, { normal_cost: 6 }, "岸楓佳(#F64)", errors)

# 3. 直江太結(#F7): two_way_cost 11->13
p_f7 = Player.find_by!(number: "F7")
cp = CostPlayer.find_by!(cost: cost, player: p_f7)
updated += update_cp(cp, { two_way_cost: 13 }, "直江太結(#F7)", errors)

# 4. 坂上芽衣(#F14): two_way_cost 5->6
p_f14 = Player.find_by!(number: "F14")
cp = CostPlayer.find_by!(cost: cost, player: p_f14)
updated += update_cp(cp, { two_way_cost: 6 }, "坂上芽衣(#F14)", errors)

# 5. 宇喜多茜(#F15): two_way_cost 8->9
p_f15 = Player.find_by!(number: "F15")
cp = CostPlayer.find_by!(cost: cost, player: p_f15)
updated += update_cp(cp, { two_way_cost: 9 }, "宇喜多茜(#F15)", errors)

# 6. 河北智恵(#F29): two_way_cost 11->12
p_f29 = Player.find_by!(number: "F29")
cp = CostPlayer.find_by!(cost: cost, player: p_f29)
updated += update_cp(cp, { two_way_cost: 12 }, "河北智恵(#F29)", errors)

# 7. 條島もも(#F37): two_way_cost=4 を新規登録
p_f37 = Player.find_by!(number: "F37")
cp = CostPlayer.find_by!(cost: cost, player: p_f37)
updated += update_cp(cp, { two_way_cost: 4 }, "條島もも(#F37)", errors)

# 8. 琴宮千寿(#F39): two_way_cost=2 を新規登録
p_f39 = Player.find_by!(number: "F39")
cp = CostPlayer.find_by!(cost: cost, player: p_f39)
updated += update_cp(cp, { two_way_cost: 2 }, "琴宮千寿(#F39)", errors)

# ---- 球詠 (card_set: 球詠) ----

# 9. 斉藤小町(中)(#T13): relief_only_cost=2 (既に設定済みの可能性あり)
p_t13 = Player.find_by!(number: "T13")
cp = CostPlayer.find_by!(cost: cost, player: p_t13)
updated += update_cp(cp, { relief_only_cost: 2 }, "斉藤小町(中)(#T13)", errors)

# ---- PM/オリジナル ----

# 10. とり2(#040): normal_cost 5->6
p_040 = Player.find_by!(number: "040")
cp = CostPlayer.find_by!(cost: cost, player: p_040)
updated += update_cp(cp, { normal_cost: 6 }, "とり2(#040)", errors)

# 11. 冴月麟(#000): 投手カードと野手カードが別エントリ
#   投手: pitcher_only_cost=4, two_way_cost=9, normal_cost=nil
#   野手: fielder_only_cost=4, normal_cost=nil
p_000_pitcher = Player.find_by!(number: "000", name: "冴月　麟（投手）")
cp_pitcher = CostPlayer.find_by!(cost: cost, player: p_000_pitcher)
updated += update_cp(cp_pitcher, {
  normal_cost: nil,
  pitcher_only_cost: 4,
  two_way_cost: 9
}, "冴月麟（投手）(#000)", errors)

p_000_fielder = Player.find_by!(number: "000", name: "冴月　麟（野手）")
cp_fielder = CostPlayer.find_by!(cost: cost, player: p_000_fielder)
updated += update_cp(cp_fielder, {
  normal_cost: nil,
  fielder_only_cost: 4
}, "冴月麟（野手）(#000)", errors)

# 12. 幽々子(楼閣)(#O00): normal_cost 15->20
p_o00 = Player.find_by!(number: "O00")
cp = CostPlayer.find_by!(cost: cost, player: p_o00)
updated += update_cp(cp, { normal_cost: 20 }, "幽々子(楼閣)(#O00)", errors)

# 13. 千亦(草津)(#O129): normal_cost 12->15
p_o129 = Player.find_by!(number: "O129")
cp = CostPlayer.find_by!(cost: cost, player: p_o129)
updated += update_cp(cp, { normal_cost: 15 }, "千亦(草津)(#O129)", errors)

# 14. 諏訪子(天地人)(#O48): normal_cost 8->10
p_o48 = Player.find_by!(number: "O48")
cp = CostPlayer.find_by!(cost: cost, player: p_o48)
updated += update_cp(cp, { normal_cost: 10 }, "諏訪子(天地人)(#O48)", errors)

# 15. 紫安2(#009): normal_cost 6->7
p_009 = Player.find_by!(number: "009")
cp = CostPlayer.find_by!(cost: cost, player: p_009)
updated += update_cp(cp, { normal_cost: 7 }, "紫安2(#009)", errors)

# 16. かじわら(#058): normal_cost 3->4
p_058 = Player.find_by!(number: "058")
cp = CostPlayer.find_by!(cost: cost, player: p_058)
updated += update_cp(cp, { normal_cost: 4 }, "かじわら(#058)", errors)

# ---- ハチナイ: 投手エントリ追加 (pitcher_only_cost=1) ----
# ※野手カードだがWikiに投手コスト記載あり → 同一CostPlayerにpitcher_only_cost追加

# 17. 桜田千代(#32)
p_f32 = Player.find_by!(number: "F32")
cp = CostPlayer.find_by!(cost: cost, player: p_f32)
updated += update_cp(cp, { pitcher_only_cost: 1 }, "桜田千代(#F32)", errors)

# 18. 小鳥遊柚(#33)
p_f33 = Player.find_by!(number: "F33")
cp = CostPlayer.find_by!(cost: cost, player: p_f33)
updated += update_cp(cp, { pitcher_only_cost: 1 }, "小鳥遊柚(#F33)", errors)

# 19. リン・レイファ(#34)
p_f34 = Player.find_by!(number: "F34")
cp = CostPlayer.find_by!(cost: cost, player: p_f34)
updated += update_cp(cp, { pitcher_only_cost: 1 }, "リン・レイファ(#F34)", errors)

# 20. 草刈ルナ(#35)
p_f35 = Player.find_by!(number: "F35")
cp = CostPlayer.find_by!(cost: cost, player: p_f35)
updated += update_cp(cp, { pitcher_only_cost: 1 }, "草刈ルナ(#F35)", errors)

# 21. 條島もも(#37): pitcher_only_cost=1 (#7 two_way=4とは別コスト種別)
updated += update_cp(CostPlayer.find_by!(cost: cost, player: Player.find_by!(number: "F37")),
  { pitcher_only_cost: 1 }, "條島もも pitcher_only(#F37)", errors)

# 22. 琴宮千寿(#39): pitcher_only_cost=1 (同上)
updated += update_cp(CostPlayer.find_by!(cost: cost, player: Player.find_by!(number: "F39")),
  { pitcher_only_cost: 1 }, "琴宮千寿 pitcher_only(#F39)", errors)

# ---- 接頭辞修正 F→P (2件) ----
# ※投手なのにF接頭辞で登録 → player.numberをP接頭辞に変更

# 23. 各務原なでしこ(#71): F71→P71
if Player.exists?(number: "P71")
  puts "  [SKIP]   各務原なでしこ: already P71"
elsif (p71 = Player.find_by(number: "F71"))
  p71.update!(number: "P71")
  puts "  [UPDATE] 各務原なでしこ: number F71 -> P71"
  updated += 1
else
  errors << "Player F71/P71 (各務原なでしこ) not found"
end

# 24. 真白玲(#96): F96→P96
if Player.exists?(number: "P96")
  puts "  [SKIP]   真白玲: already P96"
elsif (p96 = Player.find_by(number: "F96"))
  p96.update!(number: "P96")
  puts "  [UPDATE] 真白玲: number F96 -> P96"
  updated += 1
else
  errors << "Player F96/P96 (真白玲) not found"
end

# ---- 表記揺れ修正 (2件) ----

# 25. リリーホワイト(#86): DB名を「リリー・ホワイト」に統一
begin
  p86 = Player.find_by!(number: "86")
  if p86.name != "リリー・ホワイト"
    old_name = p86.name
    p86.update!(name: "リリー・ホワイト")
    puts "  [UPDATE] #86 name: #{old_name} -> リリー・ホワイト"
    updated += 1
  else
    puts "  [SKIP]   #86 リリー・ホワイト: already correct"
  end
rescue ActiveRecord::RecordNotFound
  errors << "Player #86 (リリーホワイト) not found"
end

# 26. 藤堂たいら(#F54): number末尾空白除去 "F54 " -> "F54"
begin
  p54 = Player.where("number LIKE ?", "F54%").where.not(number: "F54").first
  if p54
    old_num = p54.number
    p54.update!(number: "F54")
    puts "  [UPDATE] 藤堂たいら: number #{old_num.inspect} -> \"F54\""
    updated += 1
  else
    puts "  [SKIP]   藤堂たいら(#F54): number already correct"
  end
rescue => e
  errors << "藤堂たいら number fix failed: #{e.message}"
end

# ---- 結果サマリー ----
puts ""
puts "=== 修正完了 ==="
puts "更新件数: #{updated}"

if errors.any?
  puts "エラー:"
  errors.each { |e| puts "  - #{e}" }
  raise "修正スクリプトでエラーが発生しました"
else
  puts "エラーなし"
end
