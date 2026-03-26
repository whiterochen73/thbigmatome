# db/seeds/production_seasons.rb
# 全チームのシーズン「箱」初期化
# team_memberships・season_rostersは空のまま（各チームオーナーが選手登録を行う）

season_start_date = "2016-03-25"
season_name = "シーズン1"

puts "Seeding Seasons (initial boxes for all teams)..."

created = 0
skipped = 0

Team.find_each do |team|
  # 既存シーズンがあればスキップ（冪等）
  if Season.exists?(team_id: team.id)
    skipped += 1
    next
  end

  Season.create!(
    team_id:      team.id,
    name:         season_name,
    current_date: season_start_date,
    team_type:    team.team_type,
    key_player_id: nil
  )
  created += 1
end

puts "  #{created} seasons created, #{skipped} teams already had a season."
