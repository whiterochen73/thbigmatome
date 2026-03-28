# db/seeds/production_users.rb
# 本番用ユーザー初期データ（commissioner 4名 + player 30名）
# パスワードは環境変数 INITIAL_PASSWORD から取得（ハードコード禁止）
# commissioner: 未設定時は raise（本番での事故防止）
# player:       未設定時は開発用デフォルト 'password123' にフォールバック

commissioner_password = ENV.fetch("INITIAL_PASSWORD") do
  raise "INITIAL_PASSWORD environment variable is required for seeding commissioner users."
end
player_password = ENV.fetch("INITIAL_PASSWORD", "password123")

# ── コミッショナー 4名 ─────────────────────────────────────────
commissioner_users = [
  { name: "mori",       display_name: "mori" },
  { name: "sian",       display_name: "sian" },
  { name: "tomoya",     display_name: "tomoya" },
  { name: "ni_lan_cui", display_name: "ni_lan_cui" }
]

puts "Seeding commissioner users..."
commissioner_users.each do |attrs|
  user = User.find_or_initialize_by(name: attrs[:name])
  is_new = user.new_record?
  user.display_name = attrs[:display_name]
  user.role         = :commissioner
  user.password     = commissioner_password if is_new
  user.save!
  puts "  #{is_new ? 'Created' : 'Found'}: #{user.name} (role=#{user.role})"
end
puts "  #{commissioner_users.size} commissioner users seeded."

# ── プレイヤー（チームオーナー）30名 ──────────────────────────
player_users = %w[
  紫安 こりゆの 智夜 藍翠 badferd
  植田 Marshal MiyaK けいようし Trippy
  cyan かじわら ゆだ マゼラン Aal
  れもん pontiti ふぁん takky werg
  黒坂 蒼真 タイカ ひいらぎ るぅ
  ピーちゃん 鈴鹿 ガブリチュウ つばると じょーかー
]

puts "Seeding player users (#{player_users.size})..."
player_users.each do |uname|
  user = User.find_or_initialize_by(name: uname)
  is_new = user.new_record?
  user.display_name = uname
  user.role         = :player
  user.password     = player_password if is_new
  user.save!
  puts "  #{is_new ? 'Created' : 'Found'}: #{user.name}"
end
puts "  #{player_users.size} player users seeded."
