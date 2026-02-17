# db/seeds/test.rb
# E2Eテスト用シードデータ（テスト環境専用）

puts 'Seeding test data...'

# User
user = User.find_or_initialize_by(name: 'testuser')
user.update!(display_name: 'テストユーザー', password: 'testpassword', role: :general)
puts "  User: #{user.name} (id=#{user.id})"

# Manager
manager = Manager.find_or_initialize_by(name: 'testmgr')
manager.update!(role: :director)
puts "  Manager: #{manager.name} (id=#{manager.id})"

# Team
team = Team.find_or_initialize_by(name: 'テストチーム')
team.update!(short_name: 'テスト', is_active: true)
puts "  Team: #{team.name} (id=#{team.id})"

# TeamManager (director紐付け)
TeamManager.find_or_create_by!(team_id: team.id, manager_id: manager.id, role: :director)
puts "  TeamManager: #{team.name} <-> #{manager.name}"

# Players（ロスター画面表示確認用: 最低2名）
[
  { name: 'テスト投手1', number: '1', speed: 3, bunt: 5, steal_start: 11, steal_end: 11, injury_rate: 4 },
  { name: 'テスト野手2', number: '2', speed: 3, bunt: 5, steal_start: 11, steal_end: 11, injury_rate: 4 }
].each do |attrs|
  player = Player.find_or_initialize_by(name: attrs[:name])
  player.update!(attrs)
  puts "  Player: #{player.name}"
end

# TeamMembership（選手-チーム所属）
players = Player.where(name: [ 'テスト投手1', 'テスト野手2' ])
players.each do |player|
  tm = TeamMembership.find_or_initialize_by(team_id: team.id, player_id: player.id)
  tm.update!(squad: 'second', selected_cost_type: 'normal_cost', excluded_from_team_total: false)
  puts "  TeamMembership: #{team.name} <-> #{player.name}"
end

# Cost（コスト設定: end_date: nil = 現在有効なコスト）
cost = Cost.find_or_initialize_by(name: 'テストコスト設定')
cost.update!(start_date: '2025-01-01', end_date: nil)
puts "  Cost: #{cost.name} (id=#{cost.id})"

# CostPlayer（選手ごとのコスト値）
players.each do |player|
  cp = CostPlayer.find_or_initialize_by(cost_id: cost.id, player_id: player.id)
  cp.update!(normal_cost: 5, relief_only_cost: 4, pitcher_only_cost: 3, fielder_only_cost: 4, two_way_cost: 6)
  puts "  CostPlayer: #{cost.name} <-> #{player.name}"
end

# Season（テストチームのシーズン: team_idはunique）
season = Season.find_or_initialize_by(team_id: team.id)
season.update!(name: 'テストシーズン', current_date: '2025-04-01')
puts "  Season: #{season.name} (id=#{season.id}, team=#{team.name})"

puts 'Test seed data complete.'
