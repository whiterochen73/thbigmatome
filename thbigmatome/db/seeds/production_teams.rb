# db/seeds/production_teams.rb
# 全34チーム初期データ
# - 既存チームの short_name / team_type / is_active / user_id 更新
# - 下館トリトニス → 洗苫ヘリアンタス リネーム
# - 新規9チーム追加
# - 全チーム is_active: true
# - CompetitionEntry 作成（幻想郷ペナントレースR 2026）

# ── チームデータ定義 ──────────────────────────────────────────
# old_name: DB内の旧名称（リネーム対象のみ指定。nilなら name で検索）
teams_data = [
  # ── 既存チーム（short_name 修正・team_type / is_active 確定） ──
  { name: '若尊バレーナ',             short_name: '若尊',  team_type: 'normal',  manager: 'mori' },
  { name: 'ZERO～輝く夜に',           short_name: '零輝',  team_type: 'normal',  manager: '紫安' },
  { name: '足立ストレイドッグス',       short_name: '足立',  team_type: 'normal',  manager: 'こりゆの' },
  { name: '小倉ダークペガサス',         short_name: '小倉',  team_type: 'normal',  manager: '智夜' },
  { name: '姫路グランフェスタシクサーズ', short_name: '姫路',  team_type: 'normal',  manager: '藍翠' },
  { name: '川崎ダイス',               short_name: '川崎',  team_type: 'normal',  manager: 'badferd' },
  { name: '森ノ宮スイートネイルズ',     short_name: '森ノ宮', team_type: 'normal',  manager: '植田' },
  { name: '厚木パフォーマーズ',         short_name: '厚木',  team_type: 'normal',  manager: 'Marshal' },
  { name: 'MiyaKコブラズ',            short_name: 'MiyaK', team_type: 'normal',  manager: 'MiyaK' },
  { name: '飯能レポランタ',             short_name: '飯能',  team_type: 'normal',  manager: 'けいようし' },
  { name: '水元アルシオネ',             short_name: '水元',  team_type: 'normal',  manager: 'Trippy' },
  { name: '永山アストライア',           short_name: '永山',  team_type: 'normal',  manager: 'cyan' },
  { name: '下灘ムーンライツ',           short_name: '下灘',  team_type: 'normal',  manager: 'かじわら' },
  { name: 'PADAK',                   short_name: 'PADAK', team_type: 'normal',  manager: 'ゆだ' },
  { name: '前橋ファランクス',           short_name: '前橋',  team_type: 'normal',  manager: 'マゼラン' },
  { name: '墨染アルヘナ',              short_name: '墨染',  team_type: 'normal',  manager: 'Aal' },
  { name: '星港ロアーズ',              short_name: '星港',  team_type: 'normal',  manager: 'れもん' },
  { name: '大勝ビクトリーズ',           short_name: '大勝',  team_type: 'normal',  manager: 'pontiti' },
  { name: '幻奏ファントムスター',        short_name: '幻奏',  team_type: 'normal',  manager: 'ふぁん' },
  # リネーム: 下館トリトニス → 洗苫ヘリアンタス
  { name: '洗苫ヘリアンタス', old_name: '下館トリトニス', short_name: '洗苫', team_type: 'normal', manager: 'takky' },
  # セカンドチーム
  { name: '東京渋谷ファンタジー',       short_name: '渋谷',  team_type: 'normal',  manager: '紫安' },
  { name: '全越谷',                   short_name: '越谷',  team_type: 'hachinai', manager: 'けいようし' },
  { name: '亀有アイアンカップス',        short_name: '亀有',  team_type: 'normal',  manager: 'Trippy' },
  # 復帰チーム（is_active: true に変更）
  { name: '時安スプリングス',           short_name: '時安',  team_type: 'normal',  manager: 'werg' },
  { name: '粟生ダウンヒルズ',           short_name: '粟生',  team_type: 'normal',  manager: 'じょーかー' },
  # ── 新規追加チーム 9件 ──
  { name: '小名浜ハーバーラークス',      short_name: '小名浜', team_type: 'normal', manager: '黒坂' },
  { name: '偏蘇兒フリーデルクラフツ',    short_name: '偏蘇兒', team_type: 'normal', manager: '蒼真' },
  { name: '名護スクガラス',             short_name: '名護',  team_type: 'normal',  manager: 'タイカ' },
  { name: '汐止セイレンス',             short_name: '汐止',  team_type: 'normal',  manager: 'ひいらぎ' },
  { name: '爆裂野球倶楽部',             short_name: '爆裂',  team_type: 'normal',  manager: 'るぅ' },
  { name: '対馬ストロングキャッツ',      short_name: '対馬',  team_type: 'normal',  manager: 'ピーちゃん' },
  { name: '南都シルクロード',           short_name: '南都',  team_type: 'normal',  manager: '鈴鹿' },
  { name: '筋肉マッスルパワーズ',        short_name: '筋肉',  team_type: 'normal',  manager: 'ガブリチュウ' },
  { name: '尾張スワローズ',             short_name: '尾張',  team_type: 'normal',  manager: 'つばると' }
]

puts "Seeding teams (#{teams_data.size} teams)..."
teams_data.each do |data|
  # リネーム対応: old_name で既存レコードを検索、なければ name で
  if data[:old_name]
    team = Team.find_by(name: data[:old_name]) || Team.find_or_initialize_by(name: data[:name])
    team.name = data[:name]
  else
    team = Team.find_or_initialize_by(name: data[:name])
  end

  user = data[:manager] ? User.find_by(name: data[:manager]) : nil
  team.short_name = data[:short_name]
  team.team_type  = data[:team_type]
  team.is_active  = true
  team.user_id    = user&.id
  team.save!
  puts "  #{team.previously_new_record? ? 'Created' : 'Updated'}: #{team.name} (#{team.short_name}/#{team.team_type})"
end
puts "  #{teams_data.size} teams seeded."

# ── CompetitionEntry ──────────────────────────────────────────
lpena = Competition.find_by(name: '幻想郷ペナントレースR', year: 2026)
unless lpena
  puts "  WARN: Competition '幻想郷ペナントレースR 2026' not found — skipping CompetitionEntry."
else
  puts "Seeding CompetitionEntries for '幻想郷ペナントレースR 2026'..."
  team_names = teams_data.map { |d| d[:name] }
  created = 0
  skipped = 0
  team_names.each do |tname|
    team = Team.find_by(name: tname)
    next unless team
    if CompetitionEntry.exists?(competition: lpena, team: team)
      skipped += 1
    else
      CompetitionEntry.create!(competition: lpena, team: team)
      created += 1
    end
  end
  puts "  #{created} entries created, #{skipped} already existed."
end
