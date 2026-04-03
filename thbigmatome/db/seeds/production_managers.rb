# db/seeds/production_managers.rb
# Manager 31レコード + TeamManager 34件
#
# Manager は人物単位（セカンドチーム持ちでも1レコード）
# TeamManager は team-manager リンク（セカンドチーム持ちは2件）
#
# 前提: production_teams.rb / production_users.rb 実行済みであること

# ── Manager データ定義 ────────────────────────────────────────
# teams: このManagerが担当するチーム名リスト（director）
managers_data = [
  { name: 'mori',       short_name: 'mori',       irc_name: 'mori',
    teams: [ '若尊バレーナ' ] },
  { name: '紫安',        short_name: '紫安',        irc_name: 'sian',
    teams: [ 'ZERO～輝く夜に', '東京渋谷ファンタジー' ] },
  { name: 'こりゆの',    short_name: 'こりゆの',    irc_name: 'koriyuno',
    teams: [ '足立ストレイドッグス' ] },
  { name: '智夜',        short_name: '智夜',        irc_name: 'tomoya',
    teams: [ '小倉ダークペガサス' ] },
  { name: '藍翠',        short_name: '藍翠',        irc_name: 'ni_lan_cui',
    teams: [ '姫路グランフェスタシクサーズ' ] },
  { name: 'badferd',    short_name: 'badferd',    irc_name: 'badferd',
    teams: [ '川崎ダイス' ] },
  { name: '植田',        short_name: '植田',        irc_name: 'uedabird',
    teams: [ '森ノ宮スイートネイルズ' ] },
  { name: 'Marshal',    short_name: 'Marshal',    irc_name: 'Marshal',
    teams: [ '厚木パフォーマーズ' ] },
  { name: 'MiyaK',      short_name: 'MiyaK',      irc_name: 'MiyaK',
    teams: [ 'MiyaKコブラズ' ] },
  { name: 'けいようし',  short_name: 'けいようし',  irc_name: 'Kei84',
    teams: [ '飯能レポランタ', '全越谷' ] },
  { name: 'Trippy',     short_name: 'Trippy',     irc_name: 'Trippy',
    teams: [ '水元アルシオネ', '亀有アイアンカップス' ] },
  { name: 'cyan',       short_name: 'cyan',       irc_name: 'cyan',
    teams: [ '永山アストライア' ] },
  { name: 'かじわら',    short_name: 'かじわら',    irc_name: 'kajiwara',
    teams: [ '下灘ムーンライツ' ] },
  { name: 'ゆだ',        short_name: 'ゆだ',        irc_name: 'judah',
    teams: [ 'PADAK' ] },
  { name: 'マゼラン',    short_name: 'マゼラン',    irc_name: 'Magellan',
    teams: [ '前橋ファランクス' ] },
  { name: 'Aal',        short_name: 'Aal',        irc_name: 'Aal',
    teams: [ '墨染アルヘナ' ] },
  { name: 'れもん',      short_name: 'れもん',      irc_name: 'lemon',
    teams: [ '星港ロアーズ' ] },
  { name: 'pontiti',    short_name: 'pontiti',    irc_name: 'pontiti',
    teams: [ '大勝ビクトリーズ' ] },
  { name: 'ふぁん',      short_name: 'ふぁん',      irc_name: 'fan',
    teams: [ '幻奏ファントムスター' ] },
  { name: 'takky',      short_name: 'takky',      irc_name: 'takky',
    teams: [ '洗苫ヘリアンタス' ] },
  { name: 'werg',       short_name: 'werg',       irc_name: 'werg',
    teams: [ '時安スプリングス' ] },
  { name: 'じょーかー',  short_name: 'じょーかー',  irc_name: 'joker32',
    teams: [ '粟生ダウンヒルズ' ] },
  { name: '黒坂',        short_name: '黒坂',        irc_name: '',
    teams: [ '小名浜ハーバーラークス' ] },
  { name: '蒼真',        short_name: '蒼真',        irc_name: 'Souma',
    teams: [ '偏蘇兒フリーデルクラフツ' ] },
  { name: 'タイカ',      short_name: 'タイカ',      irc_name: 'taica',
    teams: [ '名護スクガラス' ] },
  { name: 'ひいらぎ',    short_name: 'ひいらぎ',    irc_name: 'hiiragi',
    teams: [ '汐止セイレンス' ] },
  { name: 'るぅ',        short_name: 'るぅ',        irc_name: '',
    teams: [ '爆裂野球倶楽部' ] },
  { name: 'ピーちゃん',  short_name: 'ピーちゃん',  irc_name: 'piichan',
    teams: [ '対馬ストロングキャッツ' ] },
  { name: '鈴鹿',        short_name: '鈴鹿',        irc_name: 'suzukabird',
    teams: [ '南都シルクロード' ] },
  { name: 'ガブリチュウ', short_name: 'ガブリチュウ', irc_name: 'gaburi',
    teams: [ '筋肉マッスルパワーズ' ] },
  { name: 'つばると',    short_name: 'つばると',    irc_name: 'tsubalto',
    teams: [ '尾張スワローズ' ] }
]

puts "Seeding Managers and TeamManagers..."
manager_created    = 0
manager_found      = 0
team_manager_count = 0

managers_data.each do |data|
  # Manager レコード（人物単位）
  manager = Manager.find_or_initialize_by(name: data[:name])
  is_new  = manager.new_record?
  manager.short_name = data[:short_name]
  manager.irc_name   = data[:irc_name]
  manager.role       = :director
  manager.save!
  is_new ? manager_created += 1 : manager_found += 1

  # TeamManager レコード（チーム紐づけ）
  data[:teams].each do |team_name|
    team = Team.find_by(name: team_name)
    unless team
      puts "  WARN: Team '#{team_name}' not found — skipping TeamManager."
      next
    end
    unless TeamManager.exists?(team: team, manager: manager, role: :director)
      TeamManager.create!(team: team, manager: manager, role: :director)
      team_manager_count += 1
    end
  end
end

puts "  #{manager_created} managers created, #{manager_found} already existed."
puts "  #{team_manager_count} team_managers created."
puts "  Total managers: #{managers_data.size} (expected 31)"

expected_team_managers = managers_data.sum { |d| d[:teams].size }
puts "  Total team_manager links: #{expected_team_managers} (expected 34)"
