# db/seeds/production_seasons.rb
# 全チームのシーズン「箱」初期化 + SeasonSchedule一括生成
# team_memberships・season_rostersは空のまま（コミッショナーが選手登録を行う）

season_start_date = "2016-03-25"
season_name = "現行シーズン"

puts "Seeding Seasons (initial boxes for all teams)..."

created = 0
skipped = 0
schedules_stamped = 0

schedule = Schedule.find_by!(name: 'ペナント日程表')

Team.find_each do |team|
  season = Season.find_or_initialize_by(team_id: team.id)

  if season.new_record?
    season.assign_attributes(
      name:          season_name,
      current_date:  season_start_date,
      team_type:     team.team_type,
      key_player_id: nil
    )
    season.save!
    created += 1
  else
    skipped += 1
  end

  # SeasonSchedule一括生成（冪等: 既にあればスキップ）
  if season.season_schedules.empty?
    schedule.schedule_details.each do |detail|
      SeasonSchedule.create!(
        season:    season,
        date:      detail.date,
        date_type: detail.date_type
      )
    end
    schedules_stamped += 1
  end
end

puts "  #{created} seasons created, #{skipped} teams already had a season."
puts "  #{schedules_stamped} seasons had SeasonSchedules stamped."
