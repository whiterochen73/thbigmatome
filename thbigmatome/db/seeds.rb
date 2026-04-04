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


# 日程表マスタ（Schedule + ScheduleDetail）
load Rails.root.join('db/seeds/production_schedules.rb')


# =============================================================================
# 本番用コミッショナーユーザー (mori, sian, tomoya, ni_lan_cui)
# パスワードは環境変数 INITIAL_PASSWORD で指定する（ハードコード禁止）
# =============================================================================
load Rails.root.join('db/seeds/production_users.rb')

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
# 全チーム（34チーム）・ユーザー（30名）・Manager/TeamManager
# 詳細は各 seeds/ ファイルを参照
# =============================================================================

# チーム・CompetitionEntry（34チーム完全版）
load Rails.root.join('db/seeds/production_teams.rb')

# Manager 31レコード + TeamManager 34件
load Rails.root.join('db/seeds/production_managers.rb')

# 特徴・条件マスタシードデータ
load Rails.root.join('db/seeds/master_traits.rb')

# 選手カード・選手データ（db/import/から読み込み）
puts "=== Importing Card Data ==="
load Rails.root.join('db/seeds/import_cards.rb')

# コストマスタ・コストプレイヤー（選手データ投入後に実行）
load Rails.root.join('db/seeds/production_costs.rb')

# 全チームシーズン初期化（チームデータ投入後に実行）
load Rails.root.join('db/seeds/production_seasons.rb')

# テスト環境専用シードデータ
load Rails.root.join('db/seeds/test.rb') if Rails.env.test?
