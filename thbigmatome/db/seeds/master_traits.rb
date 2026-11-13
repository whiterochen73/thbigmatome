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
  { name: '満塁',     description: '満塁の状況' },
  { name: '特例起用', description: '【特例起用】: けが・出場不可の時に使う特徴・守備（rulebook 03 §3.7・09 §9.2）' },
  { name: '専属投手登板時', description: '専属捕手として組む投手（専属捕手表の逆引き）が登板している間の捕手守備' },
  { name: '専属投手降板後', description: '専属捕手として組む投手が降板した後の守備' }
].each do |attrs|
  record = TraitCondition.find_or_initialize_by(name: attrs[:name])
  record.update!(description: attrs[:description])
end
puts "  #{TraitCondition.count} trait_conditions seeded."

# 能力欄（カードの「守備力」欄に載る能力）。取込の player_card_abilities.csv が名前で引く。
# 定義が 1 件でも入ると PlayerCard#opener_capable? はカードの記載どおり（「オープナー可」を持つ 6 枚だけ）になる。
# 効果の説明は rulebook に書かれているものだけ入れる（書かれていないものは空）。
# 「指名打者」「代打」は守備欄の注記（位置を持たないカードの欄）で、能力の一種として持つ。
puts 'Seeding AbilityDefinitions...'
[
  { name: '代打可',       typical_role: 'batter',  effect_description: nil },
  { name: 'オープナー可', typical_role: 'pitcher', effect_description: 'オープナーとして使える（rulebook 08 §8.4.1。「オープナー可」アビリティ保有選手のみ）' },
  { name: 'クイック○',    typical_role: 'pitcher', effect_description: '盗塁されにくい。盗塁st値出目+2、捕手肩+2' },
  { name: 'WPしない',     typical_role: 'pitcher', effect_description: 'あらゆる暴投を防ぐ。UP表の暴投は投球から振り直し。パスボールは防げない' },
  { name: 'クイック×',    typical_role: 'pitcher', effect_description: '盗塁されやすい。盗塁st値出目−2、捕手肩−2' },
  { name: '牽制○',        typical_role: 'pitcher', effect_description: nil },
  { name: '暴投追加',     typical_role: 'pitcher', effect_description: '投球番号5・出目19でも暴投が発生する（rulebook 05 §5.7.4）' },
  { name: 'ボークしない', typical_role: 'pitcher', effect_description: 'ボークを防ぐ。UP表のボークは投球から振り直し' },
  { name: '要中10日',     typical_role: 'pitcher', effect_description: nil },
  { name: '牽制死',       typical_role: 'pitcher', effect_description: '盗塁スタートの出目20は牽制死' },
  { name: '指名打者',     typical_role: 'batter',  effect_description: '守備欄の注記（位置を持たないカード）' },
  { name: '代打',         typical_role: 'batter',  effect_description: '守備欄の注記（位置を持たないカード）' }
].each do |attrs|
  record = AbilityDefinition.find_or_initialize_by(name: attrs[:name])
  record.update!(typical_role: attrs[:typical_role], effect_description: attrs[:effect_description])
end
puts "  #{AbilityDefinition.count} ability_definitions seeded."

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
