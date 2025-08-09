# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts 'Seeding Pitching Styles...'
[
  { name: 'ＷＰ', description: '暴投。各ランナーは１進塁' },
  { name: 'ＤＢ', description: '死球' },
  { name: 'ボーク', description: 'ボーク' },
  { name: 'ホームラン', description: 'ホームランを打たれる' },
  { name: 'けが', description: '負傷チェックを行う。日数が指定されている場合はその日数負傷する。' },
  { name: '対右', description: '右打者に対しては投球ナンバー５、左打者に対しては投球ナンバー１として打ち直し' },
  { name: '対左', description: '右打者に対しては投球ナンバー１、左打者に対しては投球ナンバー５として打ち直し' }
].each do |style_attrs|
  style = PitchingStyle.find_or_initialize_by(name: style_attrs[:name])
  style.update!(description: style_attrs[:description])
end
puts 'Pitching Styles seeded.'

puts 'Seeding Batting Styles...'
[
  { name: 'ＤＢ', description: '死球' },
  { name: 'けが', description: '負傷チェックを行う。日数が指定されている場合はその日数負傷する。' },
  { name: '１Ｃ５', description: '走者がいる場合は投球ナンバー５、いる場合は投球ナンバー１として打ち直し' },
  { name: 'チャンス', description: '走者がいる場合は投球ナンバー１、いる場合は投球ナンバー５として打ち直し' },
  { name: '内野安打', description: '内野安打を打つ。ただし、１塁走者がいれば２塁フォースアウト、前進守備なら３塁走者がタッチアウトになる。' },
  { name: '対左', description: '右投手に対しては投球ナンバー５、左投手に対しては投球ナンバー１として打ち直し' },
  { name: '対右', description: '右投手に対しては投球ナンバー１、左投手に対しては投球ナンバー５として打ち直し' }
].each do |style_attrs|
  style = BattingStyle.find_or_initialize_by(name: style_attrs[:name])
  style.update!(description: style_attrs[:description])
end
puts 'Batting Styles seeded.'

puts 'Seeding Pitching Skills...'
[
  { name: 'ＷＰしない', description: 'あらゆる暴投を防ぐ。捕逸は防げない', skill_type: 'positive' },
  { name: 'ボークしない', description: 'ボークを防ぐ。', skill_type: 'positive' },
  { name: '精神疲労', description: '失点すると疲労状態になる。', skill_type: 'negative' },
  { name: 'クイック○', description: '登板中に盗塁されたとき、盗塁のst値が+2され、捕手のT値が+2される。', skill_type: 'positive' },
  { name: 'クイック×', description: '登板中に盗塁されたとき、盗塁のst値が-2され、捕手のT値が-2される。', skill_type: 'negative' },
  { name: '牽制○', description: '盗塁スタート時に出目20が出たとき、その走者を確定でアウトにする。', skill_type: 'positive' },
  { name: '暴投追加', description: '２死以外で投球ナンバー５、打撃出目１９で三振になったとき、暴投として走者が１進塁する。', skill_type: 'negative' },
  { name: '代打可', description: '通常投手は代打起用できないが、代打可の選手は代打で出場できる。', skill_type: 'neutral' },
  { name: 'オープナー', description: 'オープナーとして起用できる。', skill_type: 'neutral' },
].each do |skill_attrs|
  skill = PitchingSkill.find_or_initialize_by(name: skill_attrs[:name])
  skill.update!(
    description: skill_attrs[:description],
    skill_type: skill_attrs[:skill_type]
  )
end
puts 'Pitching Skills seeded.'

puts 'Seeding Batting Skills...'
[
  { name: '風神少女', description: '走塁表の出目を-2する。', skill_type: 'positive' },
  { name: '代打○', description: '代打で出場した打席で打者特徴が出た場合、本来の特徴を無視して投球ナンバー１で打ち直す', skill_type: 'positive' },
].each do |skill_attrs|
  skill = BattingSkill.find_or_initialize_by(name: skill_attrs[:name])
  skill.update!(
    description: skill_attrs[:description],
    skill_type: skill_attrs[:skill_type]
  )
end
puts 'Batting Skills seeded.'

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
  { name: '秋の土用', start_date: '2025-10-20', end_date: '2025-11-06' },
].each do |biorhythm_attrs|
  biorhythm = Biorhythm.find_or_initialize_by(name: biorhythm_attrs[:name])
  biorhythm.update!(biorhythm_attrs)
end
puts 'Biorhythms seeded.'

puts 'Seeding Player Types...'
[
  { name: '東方', description: '東方キャラ。このゲームの中心となる選手。' },
  { name: 'ハチナイ', description: 'ハチナイコラボで使用可能になった選手' },
  { name: '球詠', description: '球詠コラボで使用可能になった選手' },
  { name: 'ＰＭ', description: 'プレイングマネージャー。IRCである程度遊ぶと作成されることがある' },
  { name: 'ＡＰ', description: '毎年エイプリルフールに作成されることがあるネタカード。公式化されることもある' },
  { name: 'オリジナル', description: 'ペナントを１シーズン完了させた記念に作成されたカード' },
  { name: '横綱', description: '伝説の戦犯として、ファンサービスを兼ねて作成された記念カード（公式戦使用不可）' }
].each do |style_attrs|
  style = PlayerType.find_or_initialize_by(name: style_attrs[:name])
  style.update!(description: style_attrs[:description])
end
puts 'Player Types seeded.'


puts 'Seeding Schedules...'
[
  { name: 'ペナント日程表', start_date: '2016-03-25', end_date: '2016-11-01', effective_date: '2025-01-01' },
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

  { schedule_id: 1, date: '2016-11-01', date_type: 'playoff_day', priority: 1 },
].each do |detail_attrs|
  detail = ScheduleDetail.find_or_initialize_by(schedule_id: detail_attrs[:schedule_id], date: detail_attrs[:date])
  detail.update!(
    date_type: detail_attrs[:date_type],
    priority: detail_attrs[:priority]
  )
end
