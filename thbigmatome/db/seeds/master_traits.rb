# db/seeds/master_traits.rb
# 特徴・条件マスタシードデータ

puts 'Seeding TraitConditions...'
[
  { name: '無走者',   description: '走者なしの状況' },
  { name: '有走者',   description: '走者ありの状況' },
  { name: '専属捕手', description: '専属捕手がマスクを被っている状況' },
  { name: '代打',     description: '代打での打席' },
  { name: '同点',     description: 'スコアが同点の状況' },
  { name: 'リード',   description: '自チームがリードしている状況' },
  { name: 'ビハインド', description: '自チームがビハインドの状況' },
  { name: '満塁',     description: '満塁の状況' }
].each do |attrs|
  record = TraitCondition.find_or_initialize_by(name: attrs[:name])
  record.update!(description: attrs[:description])
end
puts "  #{TraitCondition.count} trait_conditions seeded."

puts 'Seeding TraitDefinitions...'
[
  { name: '対右',       typical_role: 'batter',  description: '右投手に対して有効' },
  { name: '対左',       typical_role: 'batter',  description: '左投手に対して有効' },
  { name: 'DB',         typical_role: nil,        description: 'ダブルプレー関連特徴' },
  { name: 'チャンス',   typical_role: 'batter',  description: '得点圏で発動する特徴' },
  { name: 'WP',         typical_role: 'pitcher', description: 'ワイルドピッチ関連特徴' },
  { name: 'ホームラン', typical_role: 'batter',  description: 'ホームランに関連する特徴' },
  { name: '内野安打',   typical_role: 'batter',  description: '内野安打になりやすい特徴' },
  { name: '三振',       typical_role: nil,        description: '三振に関連する特徴' },
  { name: '三振振り逃げ', typical_role: nil,      description: '三振振り逃げに関連する特徴' },
  { name: 'ボーク',     typical_role: 'pitcher', description: 'ボークに関連する特徴' },
  { name: '1C5',        typical_role: 'batter',  description: 'ランナーあり→投球番号5、ランナーなし→投球番号1で打撃（野手特徴）' },
  { name: '1P5',        typical_role: 'pitcher', description: 'ランナーあり→投球番号5、ランナーなし→投球番号1で投球（投手特徴）' }
].each do |attrs|
  record = TraitDefinition.find_or_initialize_by(name: attrs[:name])
  record.update!(typical_role: attrs[:typical_role], description: attrs[:description])
end
puts "  #{TraitDefinition.count} trait_definitions seeded."
