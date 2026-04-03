# subtask_523b_fix: cost_players fielder_only/pitcher_only 分離修正
#
# 背景:
# 1. subtask_523b の F/P Player 統合時に P版 cost_players を destroy! したため
#    pitcher_only_cost が失われた（ケースB）
# 2. restore_cost_players.rb が全角スペースのPlayer名を半角で検索したため
#    cost_id=3 の fielder/pitcher/two_way 値が未設定のまま（名前不一致でスキップ）
#
# 修正内容:
# - cost_id=3: hachi_data 値で完全修正（fielder/pitcher/two_way/relief/normal=nil）
# - cost_id=1: fielder_only_cost = 現 normal_cost に設定、normal_cost = nil
#   ※ pitcher_only_cost は P版削除済みで回復不可（nil のまま / karoに報告）
#
# 対象: 41選手（ハチナイ35 + 球詠1 + 高坂椿1 + 新規4）
#
# Usage:
#   DRY_RUN=true  docker compose exec rails rails runner scripts/fix_cost_players_merge.rb
#   DRY_RUN=false docker compose exec rails rails runner scripts/fix_cost_players_merge.rb

dry_run = (ENV['DRY_RUN'] != 'false')
puts "=== fix_cost_players_merge.rb ==="
puts "DRY_RUN: #{dry_run}"
puts

# cost_id=3 の二刀流データ (restore_cost_players.rb hachi_data + fix_cost_2025dec.rb 適用済み)
# player_id => attrs
COST3_DATA = {
  156 => { fielder_only_cost: 7,  pitcher_only_cost: 7,  two_way_cost: 15, relief_only_cost: 4  },  # 有原翼
  158 => { fielder_only_cost: 7,  pitcher_only_cost: 7,  two_way_cost: 15, relief_only_cost: 4  },  # 野崎夕姫
  160 => { fielder_only_cost: 3,  pitcher_only_cost: 1,  two_way_cost: 4                         },  # 竹富亜矢
  162 => { fielder_only_cost: 5,  pitcher_only_cost: 3,  two_way_cost: 8                         },  # 鈴木和香
  164 => { fielder_only_cost: 3,  pitcher_only_cost: 2,  two_way_cost: 5                         },  # 花山栄美
  166 => { fielder_only_cost: 7,  pitcher_only_cost: 5,  two_way_cost: 12                        },  # 中野綾香
  168 => { fielder_only_cost: 6,  pitcher_only_cost: 6,  two_way_cost: 13                        },  # 直江太結 (fix:11→13)
  170 => { fielder_only_cost: 5,  pitcher_only_cost: 5,  two_way_cost: 11, relief_only_cost: 3  },  # 本庄千景
  172 => { fielder_only_cost: 6,  pitcher_only_cost: 3,  two_way_cost: 9                         },  # 近藤咲
  174 => { fielder_only_cost: 7,  pitcher_only_cost: 5,  two_way_cost: 13                        },  # 永井加奈子
  176 => { fielder_only_cost: 2,  pitcher_only_cost: 1,  two_way_cost: 3                         },  # 新田美奈子
  178 => { fielder_only_cost: 5,  pitcher_only_cost: 4,  two_way_cost: 9                         },  # 岩城良美
  180 => { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9,  relief_only_cost: 3  },  # 九十九伽奈
  182 => { fielder_only_cost: 3,  pitcher_only_cost: 3,  two_way_cost: 6                         },  # 坂上芽衣 (fix:5→6)
  184 => { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9                         },  # 宇喜多茜 (fix:8→9)
  186 => { fielder_only_cost: 4,  pitcher_only_cost: 7,  two_way_cost: 12, relief_only_cost: 4  },  # 倉敷舞子
  188 => { fielder_only_cost: 2,  pitcher_only_cost: 5,  two_way_cost: 7                         },  # 阿佐田あおい (fix:nil→7)
  190 => { fielder_only_cost: 2,  pitcher_only_cost: 1,  two_way_cost: 3,  relief_only_cost: 1  },  # 天草琴音
  192 => { fielder_only_cost: 6,  pitcher_only_cost: 7,  two_way_cost: 14                        },  # 東雲龍
  194 => { fielder_only_cost: 1,  pitcher_only_cost: 1,  two_way_cost: 2                         },  # 初瀬麻里安
  196 => { fielder_only_cost: 6,  pitcher_only_cost: 3,  two_way_cost: 9                         },  # 泉田京香
  198 => { fielder_only_cost: 7,  pitcher_only_cost: 3,  two_way_cost: 11, relief_only_cost: 2  },  # 朝比奈いろは
  200 => { fielder_only_cost: 5,  pitcher_only_cost: 1,  two_way_cost: 6                         },  # 仙波綾子
  202 => { fielder_only_cost: 3,  pitcher_only_cost: 2,  two_way_cost: 5                         },  # 柊琴葉
  204 => { fielder_only_cost: 3,  pitcher_only_cost: 5,  two_way_cost: 8                         },  # 秋乃小麦
  206 => { fielder_only_cost: 2,  pitcher_only_cost: 3,  two_way_cost: 5                         },  # 椎名ゆかり
  208 => { fielder_only_cost: 7,  pitcher_only_cost: 4,  two_way_cost: 12                        },  # 逢坂ここ
  210 => { fielder_only_cost: 3,  pitcher_only_cost: 2,  two_way_cost: 5                         },  # 月島結衣
  212 => { fielder_only_cost: 8,  pitcher_only_cost: 3,  two_way_cost: 12                        },  # 河北智恵 (fix:11→12)
  214 => { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9                         },  # 塚原雫
  216 => { fielder_only_cost: 1,  pitcher_only_cost: 5,  two_way_cost: 6                         },  # 我妻天
  217 => { fielder_only_cost: 6,  pitcher_only_cost: 1,  two_way_cost: 7                         },  # 桜田千代
  218 => { fielder_only_cost: 4,  pitcher_only_cost: 1,  two_way_cost: 5                         },  # 小鳥遊柚
  219 => { fielder_only_cost: 4,  pitcher_only_cost: 1,  two_way_cost: 5                         },  # リン・レイファ
  220 => { fielder_only_cost: 4,  pitcher_only_cost: 1,  two_way_cost: 5                         },  # 草刈ルナ
  222 => { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9                         },  # エレナ・スタルヒン (fix:nil→9)
  223 => { fielder_only_cost: 3,  pitcher_only_cost: 1,  two_way_cost: 4                         },  # 條島もも (fix:nil→4)
  225 => { fielder_only_cost: 5,  pitcher_only_cost: 6,  two_way_cost: 12, relief_only_cost: 5  },  # 水原碧澄 (fix:nil→12)
  226 => { fielder_only_cost: 1,  pitcher_only_cost: 1,  two_way_cost: 2                         },  # 琴宮千寿 (fix:nil→2)
  239 => { fielder_only_cost: 4,  pitcher_only_cost: 2,  two_way_cost: 6                         },  # 一二三ゆり
  242 => { fielder_only_cost: 5,  pitcher_only_cost: 5,  two_way_cost: 11, relief_only_cost: 3  }  # 西宮アリス
}.freeze

cost3 = Cost.find(3)
cost1 = Cost.find(1)

c3_updated = 0
c3_tw_fixed = 0
c1_updated = 0
error_count = 0
cost1_no_pitcher = []

ActiveRecord::Base.transaction do
  # === cost_id=3: hachi_data で完全修正 ===
  puts "--- cost_id=3 修正 (#{COST3_DATA.size}件) ---"
  COST3_DATA.each do |player_id, attrs|
    player = Player.find_by(id: player_id)
    unless player
      puts "  [ERROR] Player##{player_id} not found"
      error_count += 1
      next
    end

    cp = CostPlayer.find_by(cost: cost3, player: player)
    unless cp
      puts "  [ERROR] CostPlayer(cost_id=3) not found for #{player.name}"
      error_count += 1
      next
    end

    tw_changed = cp.two_way_cost != attrs[:two_way_cost]
    c3_tw_fixed += 1 if tw_changed

    new_attrs = attrs.merge(normal_cost: nil)
    puts "  [#{dry_run ? 'DRY' : 'UPDATE'}] #{player.name}: fielder=#{new_attrs[:fielder_only_cost]} pitcher=#{new_attrs[:pitcher_only_cost]} two_way=#{new_attrs[:two_way_cost]}#{tw_changed ? " (tw:#{cp.two_way_cost}→#{attrs[:two_way_cost]})" : ''} relief=#{new_attrs[:relief_only_cost]}"

    unless dry_run
      cp.assign_attributes(new_attrs)
      cp.save!
    end
    c3_updated += 1
  end

  # === cost_id=1: fielder_only = normal_cost, normal_cost = nil ===
  puts "\n--- cost_id=1 修正 (fielder_only のみ / pitcher 不明) ---"
  cost1_cps = cost1.cost_players.joins(:player)
                   .where(player_id: COST3_DATA.keys)
                   .where.not(normal_cost: nil)
  cost1_cps.each do |cp|
    player = cp.player
    fielder_val = cp.normal_cost
    puts "  [#{dry_run ? 'DRY' : 'UPDATE'}] #{player.name}: fielder=#{fielder_val} pitcher=nil(不明) two_way=#{cp.two_way_cost}"
    cost1_no_pitcher << "#{player.name}(#{player.id})"

    unless dry_run
      cp.fielder_only_cost = fielder_val
      cp.normal_cost       = nil
      cp.save!
    end
    c1_updated += 1
  end

  # cost_id=1 で two_way_cost も nil だった選手を two_way 設定
  puts "\n--- cost_id=1 two_way_cost nil → 修正 (hachi_data の two_way 値を使用) ---"
  cost1_tw_nil = cost1.cost_players.where(player_id: COST3_DATA.keys, two_way_cost: nil)
  cost1_tw_nil.each do |cp|
    player = cp.player
    tw_val = COST3_DATA[player.id]&.dig(:two_way_cost)
    next unless tw_val
    puts "  [#{dry_run ? 'DRY' : 'UPDATE'}] #{player.name}: two_way=nil→#{tw_val}"
    unless dry_run
      cp.two_way_cost = tw_val
      cp.save!
    end
  end

  raise ActiveRecord::Rollback if dry_run
end

puts "\n=== 結果 ==="
puts "cost_id=3 更新: #{c3_updated}件 (うちtwo_way修正: #{c3_tw_fixed}件)"
puts "cost_id=1 更新: #{c1_updated}件"
puts "エラー: #{error_count}件"
puts "DRY_RUN: #{dry_run} → #{dry_run ? 'ロールバック済み（DB変更なし）' : 'コミット済み'}"

if cost1_no_pitcher.any?
  puts "\n[WARN] cost_id=1 pitcher_only_cost が未設定（P版削除済み）:"
  puts "  #{cost1_no_pitcher.join(', ')}"
end
