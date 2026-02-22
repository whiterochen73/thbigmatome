# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Sync master data from YAML config files (5 types)
master_data_dir = Rails.root.join("config", "master_data")
master_data_models = {
  batting_styles: { model: BattingStyle, fields: %i[name description] },
  pitching_styles: { model: PitchingStyle, fields: %i[name description] },
  batting_skills: { model: BattingSkill, fields: %i[name description skill_type] },
  pitching_skills: { model: PitchingSkill, fields: %i[name description skill_type] },
  player_types: { model: PlayerType, fields: %i[name description category] }
}

master_data_models.each do |key, config|
  puts "Seeding #{key} from YAML..."
  file_path = master_data_dir.join("#{key}.yml")
  unless File.exist?(file_path)
    puts "  SKIP: #{file_path} not found"
    next
  end

  data = YAML.load_file(file_path)
  entries = data[key.to_s] || []
  entries.each do |entry|
    record = config[:model].find_or_initialize_by(name: entry["name"])
    attrs = config[:fields].each_with_object({}) do |field, hash|
      hash[field] = entry[field.to_s] if entry.key?(field.to_s)
    end
    record.update!(attrs)
  end
  puts "  #{entries.size} #{key} seeded."
end

puts 'Seeding Biorhythms...'
[
  { name: '春分', start_date: '2025-03-20', end_date: '2025-04-03' },
  { name: '清明', start_date: '2025-04-04', end_date: '2025-04-20' },
  { name: '穀雨', start_date: '2025-04-21', end_date: '2025-05-04' },
  { name: '立夏', start_date: '2025-05-05', end_date: '2025-05-20' },
  { name: '小満', start_date: '2025-05-21', end_date: '2025-06-04' },
  { name: '芒種', start_date: '2025-06-05', end_date: '2025-06-20' },
  { name: '夏至', start_date: '2025-06-21', end_date: '2025-07-06' },
  { name: '小暑', start_date: '2025-07-07', end_date: '2025-07-18' },
  { name: '大暑', start_date: '2025-07-19', end_date: '2025-08-06' },
  { name: '立秋', start_date: '2025-08-07', end_date: '2025-08-22' },
  { name: '処暑', start_date: '2025-08-23', end_date: '2025-09-06' },
  { name: '白露', start_date: '2025-09-07', end_date: '2025-09-22' },
  { name: '秋分', start_date: '2025-09-23', end_date: '2025-10-07' },
  { name: '春の土用', start_date: '2025-04-17', end_date: '2025-05-04' },
  { name: '夏の土用', start_date: '2025-07-19', end_date: '2025-08-06' },
  { name: '秋の土用', start_date: '2025-10-20', end_date: '2025-11-06' }
].each do |biorhythm_attrs|
  biorhythm = Biorhythm.find_or_initialize_by(name: biorhythm_attrs[:name])
  biorhythm.update!(biorhythm_attrs)
end
puts 'Biorhythms seeded.'


puts 'Seeding Schedules...'
[
  { name: 'ペナント日程表', start_date: '2016-03-25', end_date: '2016-11-01', effective_date: '2025-01-01' }
].each do |schedule_attrs|
  schedule = Schedule.find_or_initialize_by(name: schedule_attrs[:name])
  schedule.update!(
    start_date: schedule_attrs[:start_date],
    end_date: schedule_attrs[:end_date],
    effective_date: schedule_attrs[:effective_date]
  )
end
puts 'Schedules seeded.'

puts 'Seeding Schedule Details...'
[
  # 3月
  { schedule_id: 1, date: '2016-03-25', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-03-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-03-27', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-03-28', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-03-29', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-03-30', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-03-31', date_type: 'game_day', priority: 1 },
  # 4月
  { schedule_id: 1, date: '2016-04-01', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-02', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-03', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-04', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-05', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-06', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-07', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-08', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-09', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-10', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-11', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-12', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-13', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-14', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-15', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-16', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-17', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-18', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-19', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-20', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-21', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-22', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-23', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-24', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-25', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-27', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-28', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-29', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-04-30', date_type: 'game_day', priority: 1 },
  # 5月
  { schedule_id: 1, date: '2016-05-01', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-02', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-03', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-04', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-05', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-06', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-07', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-08', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-09', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-10', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-11', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-12', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-13', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-14', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-15', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-16', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-17', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-18', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-19', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-20', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-21', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-22', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-23', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-24', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-25', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-27', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-28', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-29', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-30', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-05-31', date_type: 'interleague_game_day', priority: 1 },
  # 6月
  { schedule_id: 1, date: '2016-06-01', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-02', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-03', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-04', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-05', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-06', date_type: 'interleague_reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-07', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-08', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-09', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-10', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-11', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-12', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-13', date_type: 'interleague_reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-14', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-15', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-16', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-17', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-18', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-19', date_type: 'interleague_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-20', date_type: 'interleague_reserve_day', priority: 2 },
  { schedule_id: 1, date: '2016-06-21', date_type: 'interleague_reserve_day', priority: 3 },
  { schedule_id: 1, date: '2016-06-22', date_type: 'interleague_reserve_day', priority: 4 },
  { schedule_id: 1, date: '2016-06-23', date_type: 'no_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-24', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-25', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-27', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-28', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-29', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-06-30', date_type: 'game_day', priority: 1 },
  # 7月
  { schedule_id: 1, date: '2016-07-01', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-02', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-03', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-04', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-05', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-06', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-07', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-08', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-09', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-10', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-11', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-12', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-13', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-14', date_type: 'no_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-15', date_type: 'no_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-16', date_type: 'no_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-17', date_type: 'no_game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-18', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-19', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-20', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-21', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-22', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-23', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-24', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-25', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-27', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-28', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-29', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-30', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-07-31', date_type: 'game_day', priority: 1 },
  # 8月
  { schedule_id: 1, date: '2016-08-01', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-02', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-03', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-04', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-05', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-06', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-07', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-08', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-09', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-10', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-11', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-12', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-13', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-14', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-15', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-16', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-17', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-18', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-19', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-20', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-21', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-22', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-23', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-24', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-25', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-27', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-28', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-29', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-30', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-08-31', date_type: 'game_day', priority: 1 },
  # 9月
  { schedule_id: 1, date: '2016-09-01', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-02', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-03', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-04', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-05', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-06', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-07', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-08', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-09', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-10', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-11', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-12', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-13', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-14', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-15', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-16', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-17', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-18', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-19', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-20', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-21', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-22', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-23', date_type: 'reserve_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-24', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-25', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-26', date_type: 'game_day', priority: 1 },
  { schedule_id: 1, date: '2016-09-27', date_type: 'reserve_day', priority: 11 },
  { schedule_id: 1, date: '2016-09-28', date_type: 'reserve_day', priority: 2 },
  { schedule_id: 1, date: '2016-09-29', date_type: 'reserve_day', priority: 3 },
  { schedule_id: 1, date: '2016-09-30', date_type: 'reserve_day', priority: 4 },
  # 10月
  { schedule_id: 1, date: '2016-10-01', date_type: 'reserve_day', priority: 5 },
  { schedule_id: 1, date: '2016-10-02', date_type: 'reserve_day', priority: 6 },
  { schedule_id: 1, date: '2016-10-03', date_type: 'reserve_day', priority: 7 },
  { schedule_id: 1, date: '2016-10-04', date_type: 'reserve_day', priority: 12 },
  { schedule_id: 1, date: '2016-10-05', date_type: 'reserve_day', priority: 8 },
  { schedule_id: 1, date: '2016-10-06', date_type: 'reserve_day', priority: 9 },
  { schedule_id: 1, date: '2016-10-07', date_type: 'reserve_day', priority: 10 },
  { schedule_id: 1, date: '2016-10-08', date_type: 'reserve_day', priority: 13 },
  { schedule_id: 1, date: '2016-10-09', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-10', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-11', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-12', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-13', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-14', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-15', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-16', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-17', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-18', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-19', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-20', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-21', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-22', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-23', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-24', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-25', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-26', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-27', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-28', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-29', date_type: 'travel_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-30', date_type: 'playoff_day', priority: 1 },
  { schedule_id: 1, date: '2016-10-31', date_type: 'playoff_day', priority: 1 },

  { schedule_id: 1, date: '2016-11-01', date_type: 'playoff_day', priority: 1 }
].each do |detail_attrs|
  detail = ScheduleDetail.find_or_initialize_by(schedule_id: detail_attrs[:schedule_id], date: detail_attrs[:date])
  detail.update!(
    date_type: detail_attrs[:date_type],
    priority: detail_attrs[:priority]
  )
end

puts 'Seeding Competition: 幻想郷ペナントレースR...'
competition = Competition.find_or_initialize_by(name: '幻想郷ペナントレースR', year: 2026)
competition.update!(competition_type: 'league_pennant')
puts '  幻想郷ペナントレースR seeded.'

puts 'Seeding Team: 若尊バレーナ...'
team = Team.find_or_initialize_by(name: '若尊バレーナ')
team.update!(short_name: '若尊', is_active: true, user_id: User.find_by(role: :commissioner)&.id || User.first&.id)
puts '  若尊バレーナ seeded.'

puts 'Seeding CompetitionEntry: 幻想郷ペナントレースR × 若尊バレーナ...'
CompetitionEntry.find_or_create_by!(competition: competition, team: team)
puts '  CompetitionEntry seeded.'

# =============================================================================
# cmd_310: Lペナ 全チーム+監督シードデータ
# =============================================================================
puts 'Seeding Lペナ managers and teams (cmd_310)...'

# 監督ユーザー作成（playerロール、moriはcommissionerのまま除外）
lpena_manager_names = %w[
  紫安 こりゆの 智夜 藍翠 badferd
  植田 Marshal MiyaK けいようし Trippy
  cyan かじわら ゆだ マゼラン Aal
  れもん pontiti ふぁん takky werg
]
lpena_manager_names.each do |manager_name|
  user = User.find_or_initialize_by(name: manager_name)
  user.update!(role: :player, display_name: manager_name, password: 'password123')
end
puts "  #{lpena_manager_names.size} managers seeded."

# チームデータ（若尊バレーナは既存seedで処理済み → 除外）
lpena_teams_data = [
  # アクティブチーム (is_active: true)
  { name: 'ZERO～輝く夜に',           short_name: 'ZEROライツ',     is_active: true,  manager: '紫安' },
  { name: '足立ストレイドッグス',       short_name: '足立ドッグス',   is_active: true,  manager: 'こりゆの' },
  { name: '小倉ダークペガサス',         short_name: '小倉ペガサス',   is_active: true,  manager: '智夜' },
  { name: '姫路グランフェスタシクサーズ', short_name: '姫路シクサーズ', is_active: true,  manager: '藍翠' },
  { name: '川崎ダイス',               short_name: '川崎ダイス',     is_active: true,  manager: 'badferd' },
  { name: '森ノ宮スイートネイルズ',     short_name: '森ノ宮ネイルズ', is_active: true,  manager: '植田' },
  { name: '厚木パフォーマーズ',         short_name: '厚木パフォーマーズ', is_active: true, manager: 'Marshal' },
  { name: 'MiyaKコブラズ',            short_name: 'MiyaKコブラズ',  is_active: true,  manager: 'MiyaK' },
  { name: '飯能レポランタ',             short_name: '飯能レポランタ', is_active: true,  manager: 'けいようし' },
  { name: '水元アルシオネ',             short_name: '水元アルシオネ', is_active: true,  manager: 'Trippy' },
  { name: '永山アストライア',           short_name: '永山アストライア', is_active: true, manager: 'cyan' },
  { name: '下灘ムーンライツ',           short_name: '下灘ムーンライツ', is_active: true, manager: 'かじわら' },
  { name: 'PADAK',                   short_name: 'PADAK',          is_active: true,  manager: 'ゆだ' },
  { name: '前橋ファランクス',           short_name: '前橋ファランクス', is_active: true, manager: 'マゼラン' },
  { name: '墨染アルヘナ',              short_name: '墨染アルヘナ',   is_active: true,  manager: 'Aal' },
  { name: '星港ロアーズ',              short_name: '星港ロアーズ',   is_active: true,  manager: 'れもん' },
  { name: '大勝ビクトリーズ',           short_name: '大勝ビクトリーズ', is_active: true, manager: 'pontiti' },
  { name: '幻奏ファントムスター',        short_name: '幻奏ファントム',  is_active: true,  manager: 'ふぁん' },
  { name: '下館トリトニス',             short_name: '下館トリトニス', is_active: true,  manager: 'takky' },
  # セカンダリーチーム (is_active: true)
  { name: '東京渋谷ファンタジー',        short_name: '渋谷ファンタジー', is_active: true, manager: '紫安' },
  { name: '全越谷',                   short_name: '全越谷',          is_active: true,  manager: 'けいようし' },
  { name: '亀有アイアンカップス',        short_name: '亀有カップス',   is_active: true,  manager: 'Trippy' },
  # 休止中チーム (is_active: false、CompetitionEntry不要)
  { name: '時安スプリングス',           short_name: '時安スプリングス', is_active: false, manager: 'werg' },
  { name: '粟生ダウンヒルズ',           short_name: '粟生ダウンヒルズ', is_active: false, manager: nil }
]

lpena_teams_data.each do |data|
  user_id = data[:manager] ? User.find_by(name: data[:manager])&.id : nil
  team = Team.find_or_initialize_by(name: data[:name])
  team.update!(short_name: data[:short_name], is_active: data[:is_active], user_id: user_id)
end
puts "  #{lpena_teams_data.size} teams seeded."

# Lペナ CompetitionEntries（アクティブ+セカンダリーのみ、若尊バレーナを含む）
lpena_competition = Competition.find_or_initialize_by(name: '幻想郷ペナントレースR', year: 2026)
lpena_competition.update!(competition_type: 'league_pennant')

active_team_names = lpena_teams_data.select { |d| d[:is_active] }.map { |d| d[:name] }
active_team_names << '若尊バレーナ'  # 既存seedで作成済み

active_team_names.each do |team_name|
  team = Team.find_by(name: team_name)
  next unless team
  CompetitionEntry.find_or_create_by!(competition: lpena_competition, team: team)
end
puts "  #{active_team_names.size} competition entries seeded."
puts 'Lペナ teams and managers seeded.'

# テスト環境専用シードデータ
load Rails.root.join('db/seeds/test.rb') if Rails.env.test?
