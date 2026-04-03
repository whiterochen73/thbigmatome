# db/scripts/restore_cost_players.rb
# Wikiコストデータ(2025年12月27日版)からCost+CostPlayer全件復元
# fix_cost_2025dec.rbの修正値を統合済み
# 冪等性あり
#
# 実行方法:
#   docker compose exec rails rails runner db/scripts/restore_cost_players.rb

puts "=== restore_cost_players.rb 開始 ==="

results = { ok: 0, skip: 0, created_players: 0, errors: [] }

def upsert_cp(cost, player, attrs, label, results)
  if player.nil?
    results[:errors] << "Player not found: #{label}"
    return
  end
  cp = CostPlayer.find_or_initialize_by(cost: cost, player: player)
  is_new = cp.new_record?
  attrs.each { |k, v| cp.send(:"#{k}=", v) }
  if is_new || cp.changed?
    if cp.save
      puts "  [#{is_new ? 'CREATE' : 'UPDATE'}] #{label}"
      results[:ok] += 1
    else
      results[:errors] << "Save failed #{label}: #{cp.errors.full_messages}"
    end
  else
    results[:skip] += 1
  end
end

def find_player_by_name(name)
  Player.find_by(name: name)
end

def find_or_create_player(name, number, is_pitcher, results)
  player = Player.find_by(name: name)
  if player
    results[:skip] += 1
    return player
  end
  player = Player.new(
    name: name, number: number, is_pitcher: is_pitcher,
    is_relief_only: false, speed: 1, bunt: 1,
    steal_start: 1, steal_end: 1, injury_rate: 6
  )
  if player.save
    puts "  [CREATE Player] #{name} (#{number}): id=#{player.id}"
    results[:created_players] += 1
  else
    results[:errors] << "Player create failed #{name}: #{player.errors.full_messages}"
    return nil
  end
  player
end

# ===== Step 1: Cost =====
puts "\n=== Step 1: Cost ==="
cost = Cost.find_or_initialize_by(name: "2025年12月コスト改定")
if cost.new_record?
  cost.start_date = Date.new(2025, 12, 27)
  cost.save!
  puts "  [CREATE] #{cost.name} (id=#{cost.id})"
else
  puts "  [SKIP] #{cost.name} (id=#{cost.id})"
end

# ===== Step 2: 基本東方キャラ =====
puts "\n=== Step 2: 基本東方キャラ ==="

thbig_data = [
  # 投手野手両用 (two_way + pitcher_only + fielder_only)
  [ "霧雨 魔理沙",   { two_way_cost: 12, pitcher_only_cost: 10, fielder_only_cost: 4 } ],
  [ "飯綱丸 龍",     { two_way_cost: 9,  pitcher_only_cost: 6,  fielder_only_cost: 3 } ],
  # 先発+中継ぎ両対応
  [ "博麗 霊夢",       { pitcher_only_cost: 8, relief_only_cost: 4 } ],
  [ "村紗 水蜜",       { pitcher_only_cost: 8, relief_only_cost: 5 } ],
  [ "宮出口 瑞霊",     { pitcher_only_cost: 8, relief_only_cost: 5 } ],
  [ "蘇我 屠自古",     { pitcher_only_cost: 7, relief_only_cost: 5 } ],
  [ "稀神 サグメ",     { pitcher_only_cost: 7, relief_only_cost: 3 } ],
  [ "本居 小鈴",       { pitcher_only_cost: 6, relief_only_cost: 4 } ],
  [ "封獣 チミ",       { pitcher_only_cost: 6, relief_only_cost: 4 } ],
  [ "古明地 さとり",   { pitcher_only_cost: 5, relief_only_cost: 2 } ],
  [ "サリエル",        { pitcher_only_cost: 5, relief_only_cost: 3 } ],
  [ "駒草 山如(太夫)", { pitcher_only_cost: 5, relief_only_cost: 4 } ],
  [ "矢田寺 成美",     { pitcher_only_cost: 5, relief_only_cost: 3 } ],
  [ "三頭 慧ノ子",     { pitcher_only_cost: 4, relief_only_cost: 3 } ],
  [ "坂田 ネムノ",     { pitcher_only_cost: 3, relief_only_cost: 3 } ],
  [ "稗田 阿求",       { pitcher_only_cost: 3, relief_only_cost: 3 } ],
  [ "マイ",            { pitcher_only_cost: 2, relief_only_cost: 1 } ],
  [ "秋 静葉",         { pitcher_only_cost: 1, relief_only_cost: 1 } ],
  # 先発専用
  [ "四季映姫・ヤマザナドゥ", { pitcher_only_cost: 9 } ],
  [ "茨木 華扇",   { pitcher_only_cost: 8 } ],
  [ "八意 永琳",   { pitcher_only_cost: 8 } ],
  [ "依神 紫苑",   { pitcher_only_cost: 8 } ],
  [ "姫虫 百々世", { pitcher_only_cost: 8 } ],
  [ "魅魔",        { pitcher_only_cost: 7 } ],
  [ "宇佐見 菫子", { pitcher_only_cost: 7 } ],
  [ "依神 女苑",   { pitcher_only_cost: 7 } ],
  [ "聖 白蓮",     { pitcher_only_cost: 6 } ],
  [ "朝倉 理香子", { pitcher_only_cost: 6 } ],
  [ "玉造 魅須丸", { pitcher_only_cost: 6 } ],
  [ "綿月 豊姫",   { pitcher_only_cost: 5 } ],
  [ "少名 針妙丸", { pitcher_only_cost: 5 } ],
  [ "奥野田 美宵", { pitcher_only_cost: 5 } ],
  [ "風見 幽香",   { pitcher_only_cost: 4 } ],
  [ "庭渡 久侘歌", { pitcher_only_cost: 4 } ],
  [ "メルラン・プリズムリバー", { pitcher_only_cost: 3 } ],
  [ "比那名居 天子", { pitcher_only_cost: 2 } ],
  [ "メディスン・メランコリー", { pitcher_only_cost: 2 } ],
  [ "赤蛮奇",      { pitcher_only_cost: 2 } ],
  [ "戎 瓔花",     { pitcher_only_cost: 2 } ],
  [ "ユキ",        { pitcher_only_cost: 1 } ],
  [ "水橋 パルスィ", { pitcher_only_cost: 1 } ],
  # 中継ぎ専用
  [ "摩多羅 隠岐奈",      { relief_only_cost: 9 } ],
  [ "クラウンピース",      { relief_only_cost: 9 } ],
  [ "アリス・マーガトロイド", { relief_only_cost: 8 } ],
  [ "天火人 ちやり",       { relief_only_cost: 8 } ],
  [ "リリカ・プリズムリバー", { relief_only_cost: 7 } ],
  [ "東風谷 早苗",         { relief_only_cost: 7 } ],
  [ "八雲 紫",             { relief_only_cost: 6 } ],
  [ "古明地 こいし",       { relief_only_cost: 6 } ],
  [ "埴安神 袿姫",         { relief_only_cost: 6 } ],
  [ "丁礼田 舞",           { relief_only_cost: 6 } ],
  [ "磐永 阿梨夜",         { relief_only_cost: 6 } ],
  [ "神綺",                { relief_only_cost: 4 } ],
  [ "牛崎 潤美",           { relief_only_cost: 4 } ],
  [ "日白 残無",           { relief_only_cost: 4 } ],
  [ "朱鷺子",              { relief_only_cost: 3 } ],
  [ "九十九 八橋",         { relief_only_cost: 3 } ],
  [ "九十九 弁々",         { relief_only_cost: 3 } ],
  [ "パチュリー・ノーレッジ", { relief_only_cost: 3 } ],
  [ "秦 こころ",           { relief_only_cost: 3 } ],
  [ "マエリベリー・ハーン", { relief_only_cost: 3 } ],
  [ "ルナサ・プリズムリバー", { relief_only_cost: 2 } ],
  [ "雲居 一輪",           { relief_only_cost: 2 } ],
  [ "秋 穣子",             { relief_only_cost: 2 } ],
  [ "ミスティア・ローレライ", { relief_only_cost: 2 } ],
  [ "宇佐見 蓮子",         { relief_only_cost: 2 } ],
  [ "カナ・アナベラル",    { relief_only_cost: 2 } ],
  [ "エレン",              { relief_only_cost: 2 } ],
  [ "スターサファイア",    { relief_only_cost: 1 } ],
  [ "ルナチャイルド",      { relief_only_cost: 1 } ],
  [ "サニーミルク",        { relief_only_cost: 1 } ],
  [ "エリス",              { relief_only_cost: 1 } ],
  [ "エリー",              { relief_only_cost: 1 } ],
  [ "小悪魔",              { relief_only_cost: 1 } ],
  # 捕手
  [ "蓬莱山 輝夜",    { fielder_only_cost: 9 } ],
  [ "純狐",           { fielder_only_cost: 8 } ],
  [ "封獣 ぬえ",      { fielder_only_cost: 5 } ],
  [ "八坂 神奈子",    { fielder_only_cost: 5 } ],
  [ "鈴瑚",           { fielder_only_cost: 4 } ],
  [ "道神 馴子",      { fielder_only_cost: 4 } ],
  [ "山城 たかね",    { fielder_only_cost: 3 } ],
  [ "吉弔 八千慧",    { fielder_only_cost: 3 } ],
  [ "レティ・ホワイトロック", { fielder_only_cost: 2 } ],
  [ "幽谷 響子",      { fielder_only_cost: 2 } ],
  [ "キスメ",         { fielder_only_cost: 1 } ],
  [ "里香",           { fielder_only_cost: 1 } ],
  [ "キクリ",         { fielder_only_cost: 1 } ],
  # 内野手
  [ "岡崎 夢美",      { fielder_only_cost: 12 } ],
  [ "ヘカーティア・ラピスラズリ", { fielder_only_cost: 10 } ],
  [ "星熊 勇儀",      { fielder_only_cost: 9 } ],
  [ "八雲 藍",        { fielder_only_cost: 9 } ],
  [ "十六夜 咲夜",    { fielder_only_cost: 9 } ],
  [ "堀川 雷鼓",      { fielder_only_cost: 9 } ],
  [ "杖刀偶 磨弓",    { fielder_only_cost: 9 } ],
  [ "姫海棠 はたて",  { fielder_only_cost: 7 } ],
  [ "天弓 千亦",      { fielder_only_cost: 7 } ],
  [ "渡里 ニナ",      { fielder_only_cost: 7 } ],
  [ "物部 布都",      { fielder_only_cost: 6 } ],
  [ "夢子",           { fielder_only_cost: 6 } ],
  [ "寅丸 星",        { fielder_only_cost: 5 } ],
  [ "藤原 妹紅",      { fielder_only_cost: 5 } ],
  [ "菅牧 典",        { fielder_only_cost: 5 } ],
  [ "豫母都 日狭美",  { fielder_only_cost: 5 } ],
  [ "犬走 椛",        { fielder_only_cost: 4 } ],
  [ "永江 衣玖",      { fielder_only_cost: 4 } ],
  [ "霍 青娥",        { fielder_only_cost: 4 } ],
  [ "夢月",           { fielder_only_cost: 4 } ],
  [ "鬼人 正邪",      { fielder_only_cost: 4 } ],
  [ "ドレミー・スイート", { fielder_only_cost: 4 } ],
  [ "北白河 ちゆり",  { fielder_only_cost: 3 } ],
  [ "幻月",           { fielder_only_cost: 3 } ],
  [ "高麗野 あうん",  { fielder_only_cost: 3 } ],
  [ "今泉 影狼",      { fielder_only_cost: 3 } ],
  [ "西行寺 幽々子",  { fielder_only_cost: 2 } ],
  [ "河城 にとり",    { fielder_only_cost: 2 } ],
  [ "上白沢 慧音",    { fielder_only_cost: 2 } ],
  [ "鈴仙・優曇華院・イナバ", { fielder_only_cost: 2 } ],
  [ "因幡 てゐ",      { fielder_only_cost: 2 } ],
  [ "ナズーリン",     { fielder_only_cost: 2 } ],
  [ "鍵山 雛",        { fielder_only_cost: 2 } ],
  [ "レイセン",       { fielder_only_cost: 1 } ],
  [ "橙",             { fielder_only_cost: 1 } ],
  [ "リグル・ナイトバグ", { fielder_only_cost: 1 } ],
  [ "サラ",           { fielder_only_cost: 1 } ],
  [ "豪徳寺 ミケ",    { fielder_only_cost: 1 } ],
  # 外野手
  [ "レミリア・スカーレット", { fielder_only_cost: 12 } ],
  [ "豊聡耳 神子",    { fielder_only_cost: 10 } ],
  [ "射命丸 文",      { fielder_only_cost: 10 } ],
  [ "驪駒 早鬼",      { fielder_only_cost: 10 } ],
  [ "綿月 依姫",      { fielder_only_cost: 9 } ],
  [ "多々良 小傘",    { fielder_only_cost: 8 } ],
  [ "フランドール・スカーレット", { fielder_only_cost: 8 } ],
  [ "霊烏路 空",      { fielder_only_cost: 7 } ],
  [ "饕餮 尤魔",      { fielder_only_cost: 6 } ],
  [ "ユイマン・浅間", { fielder_only_cost: 6 } ],
  [ "明羅",           { fielder_only_cost: 5 } ],
  [ "火焔猫 燐",      { fielder_only_cost: 5 } ],
  [ "紅 美鈴",        { fielder_only_cost: 4 } ],
  [ "二ッ岩 マミゾウ", { fielder_only_cost: 4 } ],
  [ "伊吹 萃香",      { fielder_only_cost: 3 } ],
  [ "大妖精",         { fielder_only_cost: 3 } ],
  [ "宮古 芳香",      { fielder_only_cost: 3 } ],
  [ "小野塚 小町",    { fielder_only_cost: 3 } ],
  [ "小兎姫",         { fielder_only_cost: 3 } ],
  [ "黒谷 ヤマメ",    { fielder_only_cost: 3 } ],
  [ "清蘭",           { fielder_only_cost: 3 } ],
  [ "孫 美天",        { fielder_only_cost: 3 } ],
  [ "ルーミア",       { fielder_only_cost: 2 } ],
  [ "魂魄 妖夢",      { fielder_only_cost: 2 } ],
  [ "洩矢 諏訪子",    { fielder_only_cost: 2 } ],
  [ "コンガラ",       { fielder_only_cost: 2 } ],
  [ "くるみ",         { fielder_only_cost: 2 } ],
  [ "塵塚 ウバメ",    { fielder_only_cost: 2 } ],
  [ "チルノ",         { fielder_only_cost: 1 } ],
  [ "ルイズ",         { fielder_only_cost: 1 } ],
  [ "エタニティラルバ", { fielder_only_cost: 1 } ],
  [ "オレンジ",       { fielder_only_cost: 1 } ],
  [ "わかさぎ姫",     { fielder_only_cost: 1 } ],
  [ "ユウゲンマガン", { fielder_only_cost: 1 } ]
]

thbig_data.each do |name, attrs|
  p = find_player_by_name(name)
  upsert_cp(cost, p, attrs, name, results)
end

# 爾子田里乃: 不可視文字あり → number指定
p_eriko = Player.where("number = '121'").detect { |pl| pl.name.include?("里乃") }
upsert_cp(cost, p_eriko, { relief_only_cost: 6 }, "爾子田里乃(#121)", results)

# リリーホワイト: DB名が fix前後で異なる可能性 → number指定
p_lily = Player.where(number: "86").detect { |pl| !pl.name.match?(/[（(]/) }
upsert_cp(cost, p_lily, { relief_only_cost: 2 }, "リリーホワイト(#86)", results)

# ===== Step 3: ハチナイコラボ =====
puts "\n=== Step 3: ハチナイコラボ ==="
# fix_cost_2025dec.rbの修正値統合済み
hachi_data = [
  [ "有原 翼",     { fielder_only_cost: 7,  pitcher_only_cost: 7,  two_way_cost: 15, relief_only_cost: 4 } ],
  [ "野崎 夕姫",   { fielder_only_cost: 7,  pitcher_only_cost: 7,  two_way_cost: 15, relief_only_cost: 4 } ],
  [ "竹富 亜矢",   { fielder_only_cost: 3,  pitcher_only_cost: 1,  two_way_cost: 4  } ],
  [ "鈴木 和香",   { fielder_only_cost: 5,  pitcher_only_cost: 3,  two_way_cost: 8  } ],
  [ "花山 栄美",   { fielder_only_cost: 3,  pitcher_only_cost: 2,  two_way_cost: 5  } ],
  [ "中野 綾香",   { fielder_only_cost: 7,  pitcher_only_cost: 5,  two_way_cost: 12 } ],
  [ "直江 太結",   { fielder_only_cost: 6,  pitcher_only_cost: 6,  two_way_cost: 13 } ],
  [ "本庄 千景",   { fielder_only_cost: 5,  pitcher_only_cost: 5,  two_way_cost: 11, relief_only_cost: 3 } ],
  [ "近藤 咲",     { fielder_only_cost: 6,  pitcher_only_cost: 3,  two_way_cost: 9  } ],
  [ "永井 加奈子", { fielder_only_cost: 7,  pitcher_only_cost: 5,  two_way_cost: 13 } ],
  [ "新田 美奈子", { fielder_only_cost: 2,  pitcher_only_cost: 1,  two_way_cost: 3  } ],
  [ "岩城 良美",   { fielder_only_cost: 5,  pitcher_only_cost: 4,  two_way_cost: 9  } ],
  [ "九十九 伽奈", { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9,  relief_only_cost: 3 } ],
  [ "坂上 芽衣",   { fielder_only_cost: 3,  pitcher_only_cost: 3,  two_way_cost: 6  } ],
  [ "宇喜多 茜",   { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9  } ],
  [ "倉敷 舞子",   { fielder_only_cost: 4,  pitcher_only_cost: 7,  two_way_cost: 12, relief_only_cost: 4 } ],
  [ "阿佐田 あおい", { fielder_only_cost: 2, pitcher_only_cost: 5, two_way_cost: 7  } ],
  [ "天草 琴音",   { fielder_only_cost: 2,  pitcher_only_cost: 1,  two_way_cost: 3,  relief_only_cost: 1 } ],
  [ "東雲 龍",     { fielder_only_cost: 6,  pitcher_only_cost: 7,  two_way_cost: 14 } ],
  [ "初瀬 麻里安", { fielder_only_cost: 1,  pitcher_only_cost: 1,  two_way_cost: 2  } ],
  [ "泉田 京香",   { fielder_only_cost: 6,  pitcher_only_cost: 3,  two_way_cost: 9  } ],
  [ "朝比奈 いろは", { fielder_only_cost: 7, pitcher_only_cost: 3, two_way_cost: 11, relief_only_cost: 2 } ],
  [ "仙波 綾子",   { fielder_only_cost: 5,  pitcher_only_cost: 1,  two_way_cost: 6  } ],
  [ "柊 琴葉",     { fielder_only_cost: 3,  pitcher_only_cost: 2,  two_way_cost: 5  } ],
  [ "秋乃 小麦",   { fielder_only_cost: 3,  pitcher_only_cost: 5,  two_way_cost: 8  } ],
  [ "椎名 ゆかり", { fielder_only_cost: 2,  pitcher_only_cost: 3,  two_way_cost: 5  } ],
  [ "逢坂 ここ",   { fielder_only_cost: 7,  pitcher_only_cost: 4,  two_way_cost: 12 } ],
  [ "月島 結衣",   { fielder_only_cost: 3,  pitcher_only_cost: 2,  two_way_cost: 5  } ],
  [ "河北 智恵",   { fielder_only_cost: 8,  pitcher_only_cost: 3,  two_way_cost: 12 } ],
  [ "塚原 雫",     { fielder_only_cost: 4,  pitcher_only_cost: 5,  two_way_cost: 9  } ],
  [ "我妻 天",     { fielder_only_cost: 1,  pitcher_only_cost: 5,  two_way_cost: 6  } ],
  [ "桜田 千代",   { fielder_only_cost: 6,  pitcher_only_cost: 1,  two_way_cost: 7  } ],
  [ "小鳥遊 柚",   { fielder_only_cost: 4,  pitcher_only_cost: 1,  two_way_cost: 5  } ],
  [ "リン・レイファ", { fielder_only_cost: 4, pitcher_only_cost: 1, two_way_cost: 5 } ],
  [ "草刈 ルナ",   { fielder_only_cost: 4,  pitcher_only_cost: 1,  two_way_cost: 5  } ],
  [ "エレナ・スタルヒン", { fielder_only_cost: 4, pitcher_only_cost: 5, two_way_cost: 9 } ],
  [ "條島 もも",   { fielder_only_cost: 3,  pitcher_only_cost: 1,  two_way_cost: 4  } ],
  [ "水原 碧澄",   { fielder_only_cost: 5,  pitcher_only_cost: 6,  two_way_cost: 12, relief_only_cost: 5 } ],
  [ "琴宮 千寿",   { fielder_only_cost: 1,  pitcher_only_cost: 1,  two_way_cost: 2  } ],
  [ "掛橋 桃子",   { fielder_only_cost: 1  } ],
  [ "キズナ アイ", { fielder_only_cost: 6  } ],
  [ "アメリア・サンダース", { fielder_only_cost: 5 } ],
  [ "有原 ゆい",   { pitcher_only_cost: 8  } ],
  [ "椎名 じゅり", { fielder_only_cost: 6  } ],
  [ "フリーダ・F・アンバー", { pitcher_only_cost: 6 } ],
  [ "涼宮 ハルヒ", { fielder_only_cost: 12, pitcher_only_cost: 12 } ],
  [ "長門 有希",   { fielder_only_cost: 12 } ],
  [ "朝比奈 みくる", { fielder_only_cost: 2 } ],
  [ "鶴屋 さん",   { fielder_only_cost: 2  } ],
  [ "神宮寺 小也香", { pitcher_only_cost: 9 } ],
  [ "牧野 花",     { fielder_only_cost: 3  } ],
  [ "一二三 ゆり", { fielder_only_cost: 4,  pitcher_only_cost: 2,  two_way_cost: 6  } ],
  [ "藤堂 たいら", { fielder_only_cost: 6  } ],
  [ "西宮 アリス", { fielder_only_cost: 5,  pitcher_only_cost: 5,  two_way_cost: 11, relief_only_cost: 3 } ],
  [ "高坂 椿",     { fielder_only_cost: 3,  pitcher_only_cost: 7,  two_way_cost: 11, relief_only_cost: 4 } ],
  [ "潮見 凪沙",   { pitcher_only_cost: 6,  relief_only_cost: 5  } ],
  [ "風祭 せりな", { fielder_only_cost: 5  } ],
  [ "岸 楓佳",     { fielder_only_cost: 6  } ],
  [ "森 ベロニカ 奈緒子", { fielder_only_cost: 5 } ],
  [ "各務原 なでしこ", { pitcher_only_cost: 5 } ],
  [ "志摩 リン",   { fielder_only_cost: 7  } ],
  [ "大垣 千明",   { fielder_only_cost: 3  } ],
  [ "犬山 あおい", { fielder_only_cost: 4  } ],
  [ "斉藤 恵那",   { fielder_only_cost: 3  } ],
  [ "紗倉 ひびき", { fielder_only_cost: 4  } ],
  [ "奏流院 朱美", { fielder_only_cost: 5  } ],
  [ "夏葉 舞",     { pitcher_only_cost: 7,  relief_only_cost: 4  } ],
  [ "鬼塚 桐",     { fielder_only_cost: 5  } ],
  [ "樫野 亜沙",   { fielder_only_cost: 3  } ],
  [ "大咲 みよ",   { fielder_only_cost: 3  } ],
  [ "芹澤 結",     { fielder_only_cost: 3  } ],
  [ "乾 ケイ",     { fielder_only_cost: 6  } ],
  [ "今田 杏珠",   { fielder_only_cost: 4  } ],
  [ "宮井 都子",   { pitcher_only_cost: 4  } ],
  [ "水浦 七瀬",   { fielder_only_cost: 7  } ],
  [ "光田 つばめ", { fielder_only_cost: 2  } ],
  [ "草刈 レナ",   { fielder_only_cost: 10 } ],
  [ "鎌部 千秋",   { pitcher_only_cost: 7  } ],
  [ "奈良 胡桃",   { fielder_only_cost: 3  } ],
  [ "大和田 沙智", { fielder_only_cost: 7  } ],
  [ "相良 吉乃",   { fielder_only_cost: 6  } ],
  [ "真白 玲",     { pitcher_only_cost: 7  } ]
]

hachi_data.each do |name, attrs|
  p = find_player_by_name(name)
  upsert_cp(cost, p, attrs, "#{name}(ハチナイ)", results)
end

# ===== Step 4: 球詠コラボ =====
puts "\n=== Step 4: 球詠コラボ ==="
tamayomi_data = [
  [ "武田 詠深",   { normal_cost: 6  } ],
  [ "山崎 珠姫",   { normal_cost: 4  } ],
  [ "中村 希",     { normal_cost: 6  } ],
  [ "藤田 菫",     { normal_cost: 1  } ],
  [ "藤原 理沙",   { normal_cost: 6  } ],
  [ "川崎 稜",     { normal_cost: 1  } ],
  [ "川口 息吹",   { normal_cost: 3  } ],
  [ "岡田 怜",     { normal_cost: 8  } ],
  [ "大村 白菊",   { normal_cost: 1  } ],
  [ "川口 芳乃",   { normal_cost: 1  } ],
  [ "川原 光",     { normal_cost: 10 } ],
  [ "渡邊 詩織",   { normal_cost: 2  } ],
  [ "斉藤 小町",   { normal_cost: 3, relief_only_cost: 2 } ],
  [ "長谷川 美咲", { normal_cost: 1  } ],
  [ "東條 蘭々",   { normal_cost: 1  } ],
  [ "野村 瑞帆",   { normal_cost: 2  } ],
  [ "村松 京子",   { normal_cost: 1  } ],
  [ "川崎 稜 (1年)", { normal_cost: 1 } ],
  [ "中田 奈緒",   { normal_cost: 4  } ]
]

tamayomi_data.each do |name, attrs|
  p = find_player_by_name(name)
  upsert_cp(cost, p, attrs, "#{name}(球詠)", results)
end

# ===== Step 5: PM/完走/UR 既存Player =====
puts "\n=== Step 5: PM/完走/UR 既存Player ==="
pm_existing = [
  [ "霧雨 魔理沙 (宮崎)",         { normal_cost: 10 } ],
  [ "サリエル (浜宮2)",            { normal_cost: 10 } ],
  [ "スターサファイア (妖精)",     { normal_cost: 15 } ],
  [ "ふぁん",                      { normal_cost: 10 } ],
  [ "少名 針妙丸 (霧島)",          { normal_cost: 8  } ],
  [ "蘇我 屠自古 (下関)",          { normal_cost: 8  } ],
  [ "碧石",                        { normal_cost: 7  } ],
  [ "タイカ",                      { normal_cost: 7  } ],
  [ "Aal",                         { normal_cost: 7  } ],
  [ "聖 白蓮 (佐世保)",            { normal_cost: 7  } ],
  [ "けいようし",                  { normal_cost: 6  } ],
  [ "けいようし (2)",              { normal_cost: 6  } ],
  [ "とり (2)",                    { normal_cost: 6  } ],
  [ "カナ・アナベラル (WBC)",      { normal_cost: 5  } ],
  [ "植田",                        { normal_cost: 5  } ],
  [ "badferd (2)",                 { normal_cost: 4  } ],
  [ "近藤 咲(桜木町)",             { normal_cost: 4  } ],
  [ "つばると (2)",                { normal_cost: 3  } ],
  [ "エリス (大和)",               { normal_cost: 2  } ],
  [ "小悪魔 (時津)",               { normal_cost: 1  } ],
  [ "MiyaK",                       { normal_cost: 9  } ],
  [ "西行寺 幽々子(楼閣)",         { normal_cost: 20 } ],
  [ "有原 翼 (里ヶ浜)",            { normal_cost: 20 } ],
  [ "天弓 千亦 (草津)",            { normal_cost: 15 } ],
  [ "マゼラン",                    { normal_cost: 15 } ],
  [ "ヘカーティア・L (ポートランド)", { normal_cost: 12 } ],
  [ "紫安",                        { normal_cost: 10 } ],
  [ "mori (2)",                    { normal_cost: 10 } ],
  [ "純狐 (浜宮)",                 { normal_cost: 10 } ],
  [ "八雲 藍 (WBC2)",              { normal_cost: 10 } ],
  [ "じょーかー",                  { normal_cost: 10 } ],
  [ "mori",                        { normal_cost: 9  } ],
  [ "河城 みとり",                 { normal_cost: 9  } ],
  [ "ガブリチュウ",                { normal_cost: 9  } ],
  [ "初瀬 麻里安 (町田)",          { normal_cost: 8  } ],
  [ "マゼラン (2)",                { normal_cost: 8  } ],
  [ "上白沢 慧音(Ex)",             { normal_cost: 7  } ],
  [ "紫安 (2)",                    { normal_cost: 7  } ],
  [ "こりゆの (2)",                { normal_cost: 7  } ],
  [ "夢子 (柴又)",                 { normal_cost: 6  } ],
  [ "レミリア・スカーレット (都城)", { normal_cost: 6 } ],
  [ "badferd",                     { normal_cost: 5  } ],
  [ "智夜 (2)",                    { normal_cost: 5  } ],
  [ "とり",                        { normal_cost: 5  } ],
  [ "你 藍翠 (2)",                 { normal_cost: 5  } ],
  [ "cyan",                        { normal_cost: 5  } ],
  [ "pontiti",                     { normal_cost: 5  } ],
  [ "Marshal",                     { normal_cost: 4  } ],
  [ "Judah",                       { normal_cost: 4  } ],
  [ "WERG",                        { normal_cost: 4  } ],
  [ "ゴリアテ人形",                { normal_cost: 4  } ],
  [ "かじわら",                    { normal_cost: 4  } ],
  [ "れもん",                      { normal_cost: 4  } ],
  [ "Aal (2)",                     { normal_cost: 4  } ],
  [ "こりゆの",                    { normal_cost: 3  } ],
  [ "つばると",                    { normal_cost: 3  } ],
  [ "智夜",                        { normal_cost: 3  } ],
  [ "洩矢 諏訪子(茨木)",           { normal_cost: 3  } ],
  [ "ひいらぎ",                    { normal_cost: 3  } ],
  [ "ナズーリン (厚木)",           { normal_cost: 3  } ],
  [ "つばると (3)",                { normal_cost: 2  } ],
  [ "ナズーリン (多摩)",           { normal_cost: 2  } ],
  [ "初瀬 麻里安 (湘南)",          { normal_cost: 2  } ],
  [ "takky",                       { normal_cost: 2  } ],
  [ "mori (3)",                    { normal_cost: 10 } ]
]

pm_existing.each do |name, attrs|
  p = find_player_by_name(name)
  upsert_cp(cost, p, attrs, "#{name}(PM既存)", results)
end

# 冴月麟: 投手カード
p_s_pitcher = Player.find_by(number: "000", name: "冴月 麟 (投手)")
upsert_cp(cost, p_s_pitcher, { two_way_cost: 9, pitcher_only_cost: 4 }, "冴月麟(投手)", results)

p_s_fielder = Player.find_by(number: "000", name: "冴月 麟 (野手)")
upsert_cp(cost, p_s_fielder, { fielder_only_cost: 4 }, "冴月麟(野手)", results)

# ===== Step 6: PM新規Player作成 + CostPlayer =====
puts "\n=== Step 6: PM新規Player作成 ==="

max_num = Player.where("number ~ ?", '^[0-9]+$').pluck(:number).map(&:to_i).max
next_num = [ max_num + 1 ]
def next_number(ref)
  n = ref[0]
  ref[0] += 1
  n.to_s
end

pm_new = [
  # cmd_506 セクション2 の15件
  [ "ゆだ2",                  true,  { normal_cost: 12 } ],
  [ "mori3",                  true,  { normal_cost: 10 } ],
  [ "けいようし2",            true,  { normal_cost: 6  } ],
  [ "ベルン",                 true,  { normal_cost: 5  } ],
  [ "cyan2",                  false, { normal_cost: 6  } ],
  [ "摩多羅 隠岐奈 (天保山)", true,  { normal_cost: 7  } ],
  [ "坂田 ネムノ (安曇野)",   true,  { normal_cost: 1  } ],
  [ "永江 衣玖 (最上川)",     false, { normal_cost: 5  } ],
  [ "藤原 妹紅 (信楽)",       false, { normal_cost: 5  } ],
  [ "今泉 影狼 (下館)",       false, { normal_cost: 4  } ],
  [ "椎名 ゆかり (那珂川)",   false, { normal_cost: 2  } ],
  [ "菅牧 典 (小牧)",         false, { normal_cost: 4  } ],
  [ "中野綾香 (UR)",          false, { normal_cost: 10 } ],
  [ "小鳥遊柚 (UR)",          false, { normal_cost: 9  } ],
  [ "初瀬麻里安 (UR)",        false, { normal_cost: 8  } ],
  # wiki追加分（DB未存在）
  [ "博麗 霊夢 (S&F)",        true,  { normal_cost: 20 } ],
  [ "AP魅魔",                 true,  { normal_cost: 15 } ],
  [ "AP比那名居 天子",        true,  { normal_cost: 10 } ],
  [ "古明地 こいし (茨城2)",  true,  { normal_cost: 10 } ],
  [ "潮見 凪沙 (伏見)",       true,  { normal_cost: 10 } ],
  [ "八雲 紫 (筑紫野)",       true,  { normal_cost: 10 } ],
  [ "AP鬼人 正邪",            true,  { normal_cost: 7  } ],
  [ "鎌部 千秋 (東ベ)",       true,  { normal_cost: 7  } ],
  [ "依神 紫苑 (雨晴)",       true,  { normal_cost: 7  } ],
  [ "植田2",                  true,  { normal_cost: 6  } ],
  [ "銀河",                   true,  { normal_cost: 4  } ],
  [ "下神空",                 true,  { normal_cost: 4  } ],
  [ "綿月 豊姫 (須弥山)",     true,  { normal_cost: 4  } ],
  [ "AP鈴仙",                 true,  { normal_cost: 2  } ],
  [ "野崎 夕姫 (筑波)",       true,  { normal_cost: 2  } ],
  [ "霊烏路 空 (地底)",       false, { normal_cost: 20 } ],
  [ "AP明羅",                 false, { normal_cost: 12 } ],
  [ "杖刀偶 磨弓 (北堀江)",   false, { normal_cost: 10 } ],
  [ "射命丸 文 (博多)",       false, { normal_cost: 10 } ],
  [ "洩矢 諏訪子 (天地人)",   false, { normal_cost: 10 } ]
]

pm_new.each do |name, is_pitcher, attrs|
  p = find_or_create_player(name, next_number(next_num), is_pitcher, results)
  upsert_cp(cost, p, attrs, "#{name}(PM新規)", results)
end

# ===== 結果サマリー =====
puts "\n=== 完了 ==="
puts "CostPlayer 作成/更新: #{results[:ok]}件"
puts "CostPlayer スキップ: #{results[:skip]}件"
puts "Player 新規作成: #{results[:created_players]}件"

if results[:errors].any?
  puts "\nエラー (#{results[:errors].size}件):"
  results[:errors].each { |e| puts "  - #{e}" }
else
  puts "エラーなし"
end

puts "\n=== DB最終状態 ==="
puts "Cost.count: #{Cost.count}"
puts "CostPlayer.count: #{CostPlayer.count}"
puts "Player.count: #{Player.count}"
