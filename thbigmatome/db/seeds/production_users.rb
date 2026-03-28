# db/seeds/production_users.rb
# 本番用コミッショナーユーザー初期データ
# パスワードは環境変数 INITIAL_PASSWORD から取得（ハードコード禁止）

initial_password = ENV.fetch("INITIAL_PASSWORD") do
  raise "INITIAL_PASSWORD environment variable is required for seeding commissioner users."
end

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
  user.password     = initial_password if is_new
  user.save!
  puts "  #{is_new ? 'Created' : 'Found'}: #{user.name} (role=#{user.role})"
end
puts "  #{commissioner_users.size} commissioner users seeded."
