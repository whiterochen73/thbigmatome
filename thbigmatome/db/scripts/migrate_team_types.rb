# db/scripts/migrate_team_types.rb
# セカンドチーム team_type 移行スクリプト（実行不要 — 確認・手動設定用）
#
# 使い方: rails runner db/scripts/migrate_team_types.rb

puts "=== Step 1: 複数チームのdirectorを務めるManagerを確認 ==="

multi_team_directors = Manager.joins(:team_managers)
  .where(team_managers: { role: :director })
  .group(:id)
  .having("COUNT(team_managers.id) > 1")

if multi_team_directors.empty?
  puts "複数チームのdirectorなし"
else
  multi_team_directors.each do |manager|
    teams = manager.teams.joins(:team_managers)
      .where(team_managers: { role: :director })
    puts "Manager: #{manager.name} (#{manager.id})"
    teams.each do |t|
      members = t.team_memberships.includes(:player).map { |tm|
        "#{tm.player.name} (#{tm.player.series})"
      }
      puts "  Team: #{t.name} (id: #{t.id}, team_type: #{t.team_type}, user_id: #{t.user_id})"
      puts "  Members: #{members.join(', ')}"
    end
  end
end

puts ""
puts "=== Step 2: 手動でteam_type設定 ==="
puts "# 例:"
puts "# Team.find(XX).update!(team_type: 'hachinai')"
puts "# Team.find(YY).update!(team_type: 'normal')  # default"

puts ""
puts "=== Step 3: 選手排他チェック（同一directorの複数チーム間で選手重複確認） ==="

multi_team_directors.each do |manager|
  director_team_ids = TeamManager.where(manager_id: manager.id, role: :director).pluck(:team_id)
  all_player_ids = TeamMembership.where(team_id: director_team_ids).pluck(:player_id)
  duplicates = all_player_ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  if duplicates.any?
    dup_names = Player.where(id: duplicates).pluck(:name)
    puts "WARNING: Manager #{manager.name} has duplicate players: #{dup_names.join(', ')}"
  else
    puts "Manager #{manager.name}: 選手重複なし"
  end
end

puts ""
puts "=== 全チームの team_type 一覧 ==="
Team.order(:id).each do |t|
  puts "  id=#{t.id} #{t.name}: team_type=#{t.team_type}"
end
