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
