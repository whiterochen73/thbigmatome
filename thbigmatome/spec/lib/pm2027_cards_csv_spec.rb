require "rails_helper"
require "csv"
require "json"
require "digest"

# PM2027（オリジナル選手カードの更新版）144 枚の CSV 行（cmd_1893 / subtask_1893a）。
#
# Test Basis:
#   - Operator 決定（2026-11-14）: 「新たなカードセットが追加される形」。案 A（新しい出典 PM2027 として全 144 枚を足す）。PM2026 の行は変えない
#   - context/thbig-pm2027-diff.md §2（変更 6 枚）・§3（追加 15・削除 6）・§1（対応 129）
#   - 構造化データ db/import/pm2027/（PDF の文字層。差分調査 2026-11-13）
#   - card_seq = 433 + (ページ-1)*9 + (行*3+列)
#   - 命名: 同名カードは印字の添え字を名前に付け、添え字が無い時だけ「(2)」（PM2026 の 永江 衣玖 (エイプリル) と同じ扱い）
RSpec.describe "PM2027 の CSV 行" do
  PM27_IMPORT_DIR = Rails.root.join("db/import")
  PM2026_SEQS = (280..414).freeze
  # PM2026 の 135 行と子表（265・149・7・3 行）の指紋。1 行でも変えると変わる。
  # cmd_1898 で 365 西行寺 幽々子(楼閣)・368 八雲 藍 (WBC2) の base_player_name・variant を埋めた（Operator 裁定 2026-11-14: 本番の形＝基の Player の variant）。それ以前の指紋は 8ed40797…
  PM2026_DIGEST = "a0d4f8eb375a5a29a342cffea605f99258e2d469155f9849d1aaf7b3fc3edc35".freeze

  def table(name) = CSV.read(PM27_IMPORT_DIR.join("#{name}.csv"), headers: true, encoding: "UTF-8")
  def pm2027_json(name) = JSON.parse(File.read(PM27_IMPORT_DIR.join("pm2027/#{name}")))

  let(:cards) { table("player_cards") }
  let(:pm27) { cards.select { |r| r["card_source"] == "PM2027" } }
  let(:pm26) { cards.select { |r| r["card_source"] == "PM2026" } }
  let(:summary) { pm2027_json("pm2027_diff_summary.json") }
  let(:matches) { summary["matches"].to_h { |k, v| [ k.to_i, v ] } } # PM2027 の並び(0 始まり) => PM2026 の card_seq
  let(:changed) { summary["content_changed"].keys.map(&:to_i) }
  let(:children) { %w[player_card_defenses player_card_traits player_card_abilities player_card_exclusive_catchers] }

  def child_rows(name, seq) = table(name).select { |r| r["card_seq"] == seq.to_s }.map(&:to_h)
  def strip_seq(h) = h.reject { |k, _| %w[card_seq card_source].include?(k) }

  it "PM2027 は 144 枚で card_seq は 433〜576 が 1 枚ずつ（ページ・位置順）" do
    expect(pm27.size).to eq(144)
    expect(pm27.map { |r| r["card_seq"].to_i }).to eq((433..576).to_a)
  end

  it "ページ・位置から card_seq が決まる（433 + (ページ-1)*9 + 行*3 + 列）" do
    pm2027_json("PM2027_cards.json").each do |c|
      r, col = c["pos_in_page"]
      expect(c["idx"]).to eq((c["page"] - 1) * 9 + r * 3 + col)
    end
  end

  it "PM2026 の 135 行と子表の行は、cmd_1898 の 2 行（365・368 の持ち主と variant）以外変わっていない" do
    files = %w[player_cards player_card_defenses player_card_traits player_card_abilities player_card_exclusive_catchers]
    parts = files.map { |f| table(f).select { |r| PM2026_SEQS.cover?(r["card_seq"].to_i) }.map { |r| JSON.generate(r.to_h.except("team_label").to_a) } }
    expect(parts.map(&:size)).to eq([ 135, 265, 149, 7, 3 ])
    expect(Digest::SHA256.hexdigest(parts.flatten.join("\n"))).to eq(PM2026_DIGEST)
  end

  # cmd_1901: カード上部の帯のチーム名・印を team_label に持つ。variant が空で帯が GLADIATS 以外の行だけ。出どころは PDF の文字層
  #   （PM2027.pdf・PM2026.pdf の各カードの帯。位置は card_seq = 先頭 + (ページ-1)*9 + (行*3+列)）
  TEAM_LABELS = {
    331 => "戦犯番付", 332 => "戦犯番付", 333 => "戦犯番付", 338 => "ハチナイ", 339 => "戦犯番付",
    340 => "東方PROJECT", 341 => "東方PROJECT", 343 => "東方PROJECT", 345 => "東方PROJECT", 350 => "東方PROJECT",
    353 => "東方PROJECT", 358 => "東方PROJECT", 392 => "北堀江",
    478 => "東方PROJECT", 480 => "東方PROJECT", 485 => "東方PROJECT", 488 => "東方PROJECT", 493 => "東方PROJECT",
    503 => "北堀江", 539 => "永山", 556 => "東方PROJECT", 557 => "東方PROJECT", 559 => "戦犯番付", 560 => "戦犯番付", 561 => "戦犯番付"
  }.freeze

  it "team_label は variant が空で帯が GLADIATS 以外の 25 行にだけ入っている（variant は鍵なので触っていない）" do
    expect(cards.headers).to include("team_label")
    labelled = cards.select { |r| r["team_label"].present? }
    expect(labelled.to_h { |r| [ r["card_seq"].to_i, r["team_label"] ] }).to eq(TEAM_LABELS)
    expect(labelled.map { |r| r["variant"].to_s }.uniq).to eq([ "" ]) # variant のある行には入れない（表示は variant が先）
  end

  it "帯が GLADIATS の通常カードと UR・エイプリルなど variant つきの行には team_label が無い（例: 563 花山 栄美・567 小鳥遊 柚・571 草刈 ルナ）" do
    by_seq = cards.to_h { |r| [ r["card_seq"].to_i, r ] }
    [ 433, 555, 558, 563, 567, 571, 562, 479, 513, 526 ].each { |seq| expect(by_seq[seq]["team_label"]).to be_blank, "card_seq=#{seq}" }
  end

  it "全行が出典 PM2027・parse_status ok で、投打・走力・けがなど取込が要る値が空でない" do
    expect(pm27.map { |r| r["parse_status"] }.uniq).to eq([ "ok" ])
    %w[name number position speed bunt steal_start steal_end injury_rate card_type].each do |col|
      expect(pm27.select { |r| r[col].blank? }.map { |r| [ r["card_seq"], col ] }).to eq([]), "#{col} が空のカードがある"
    end
  end

  describe "PM2026 と対応が付いた 129 枚" do
    it "変更の無い 123 枚は、PM2026 の行・守備・特徴・能力・専属捕手との差が card_seq と出典だけ" do
      unchanged = matches.reject { |_, old| changed.include?(old) }
      expect(unchanged.size).to eq(123)
      unchanged.each do |idx, old|
        new_seq = 433 + idx
        a = pm26.find { |r| r["card_seq"].to_i == old }.to_h
        b = pm27.find { |r| r["card_seq"].to_i == new_seq }.to_h
        expect(strip_seq(b)).to eq(strip_seq(a)), "card_seq #{old} -> #{new_seq} の行が違う"
        expect(b["card_source"]).to eq("PM2027")
        children.each do |name|
          expect(child_rows(name, new_seq).map { |h| strip_seq(h) }).to eq(child_rows(name, old).map { |h| strip_seq(h) }), "#{name} #{old} -> #{new_seq}"
        end
      end
    end

    it "305 は守備 OF が 5A・肩 A に変わり、ほかは PM2026 と同じ" do
      old = pm26.find { |r| r["card_seq"] == "305" }.to_h
      new = pm27.find { |r| r["card_seq"].to_i == 433 + matches.key(305) }.to_h
      expect(strip_seq(new)).to eq(strip_seq(old))
      defs = child_rows("player_card_defenses", new["card_seq"])
      expect(defs.map { |d| d.values_at("position", "range_value", "error_rank", "throwing") }).to eq([ [ "OF", "5", "A", "A" ] ])
    end

    it "330 ひいらぎ は打撃表 56 マス・バント 4・盗塁 10/13・けが 5・守備 SS 4B に変わる" do
      seq = 433 + matches.key(330)
      old = pm26.find { |r| r["card_seq"] == "330" }.to_h
      new = pm27.find { |r| r["card_seq"].to_i == seq }.to_h
      expect(new.values_at("bunt", "steal_start", "steal_end", "injury_rate")).to eq(%w[4 10 13 5])
      expect(new.values_at("speed", "name", "number", "throwing_hand", "batting_hand")).to eq(old.values_at("speed", "name", "number", "throwing_hand", "batting_hand"))
      diff = JSON.parse(new["batting_table"]).flatten.zip(JSON.parse(old["batting_table"]).flatten).count { |x, y| x != y }
      expect(diff).to eq(56)
      expect(child_rows("player_card_defenses", seq).map { |d| d.values_at("position", "range_value", "error_rank") }).to eq([ %w[SS 4 B] ])
    end

    it "341 エーリッヒ は右投左打になり、打撃表は 2 マス（HR8→HR7、HR9→HR8）だけ違う" do
      seq = 433 + matches.key(341)
      old = pm26.find { |r| r["card_seq"] == "341" }.to_h
      new = pm27.find { |r| r["card_seq"].to_i == seq }.to_h
      expect(new.values_at("throwing_hand", "batting_hand")).to eq(%w[right left])
      expect(strip_seq(new).except("throwing_hand", "batting_table")).to eq(strip_seq(old).except("throwing_hand", "batting_table"))
      pairs = JSON.parse(new["batting_table"]).flatten.zip(JSON.parse(old["batting_table"]).flatten).reject { |x, y| x == y }
      expect(pairs).to eq([ %w[HR7 HR8], %w[HR8 HR9] ])
    end

    it "362 と 388 は CSV に列の無い上部の行だけの変更なので、行は PM2026 と同じ" do
      [ 362, 388 ].each do |old|
        seq = 433 + matches.key(old)
        a = pm26.find { |r| r["card_seq"].to_i == old }.to_h
        b = pm27.find { |r| r["card_seq"].to_i == seq }.to_h
        expect(strip_seq(b)).to eq(strip_seq(a))
      end
    end

    it "321 你 藍翠 は PM2027 では投手カード。暴言退場・1C5・野手の守備を持ち越さない" do
      seq = 433 + matches.key(321)
      new = pm27.find { |r| r["card_seq"].to_i == seq }.to_h
      expect(new.values_at("name", "number", "position", "card_type", "is_pitcher")).to eq([ "你 藍翠", "088", "投手", "pitcher", "true" ])
      expect(new.values_at("speed", "steal_start", "steal_end", "injury_rate", "starter_stamina")).to eq(%w[1 1 1 5 7])
      expect(new["unique_traits"]).to be_nil
      expect(child_rows("player_card_defenses", seq).map { |d| d.values_at("position", "range_value", "error_rank") }).to eq([ %w[P 4 A] ])
      expect(child_rows("player_card_traits", seq).map { |t| t["trait_definition_name"] }).to eq([ "対右" ])
      expect(JSON.parse(new["pitching_table"]).size).to eq(20)
    end
  end

  describe "追加の 15 枚" do
    let(:added_seqs) { summary["added"].map { |a| 433 + a["idx"] } }
    let(:added) { pm27.select { |r| added_seqs.include?(r["card_seq"].to_i) } }

    it "15 枚で、名前は PM2026 の同名カードと同じ表記ルール（同名は印字の添え字を付ける）" do
      expect(added.size).to eq(15)
      by_seq = added.to_h { |r| [ r["card_seq"].to_i, r ] }
      yukari = by_seq.values.select { |r| r["base_player_name"] == "八雲 紫" }
      expect(yukari.map { |r| r["name"] }.sort).to eq([ "八雲 紫 (エイプリル)", "八雲 紫 (飯能)" ])
      expect(yukari.map { |r| r["variant"] }.sort).to eq(%w[エイプリル 飯能])
      sagume = added.find { |r| r["number"] == "108" }
      expect(sagume.values_at("name", "variant", "base_player_name")).to eq([ "稀神 サグメ", "前橋", "稀神 サグメ" ])
      nagisa = added.find { |r| r["number"] == "62" }
      expect(nagisa.values_at("name", "variant", "base_player_name")).to eq([ "潮見 凪沙 (UR)", "UR", "潮見 凪沙" ])
    end

    it "PM2027 の中で (名前, 種別) も (元の名前, 種別, variant) も重複しない（取込が黙って 1 枚にまとめる事故の防止）" do
      names = pm27.map { |r| [ r["name"].gsub(/[\s　]+/, ""), r["card_type"] ] }
      expect(names.tally.select { |_, n| n > 1 }.keys).to eq([])
      keys = pm27.map { |r| [ (r["base_player_name"].presence || r["name"]).gsub(/[\s　]+/, ""), r["card_type"], r["variant"].to_s ] }
      expect(keys.tally.select { |_, n| n > 1 }.keys).to eq([])
    end

    it "専属捕手の名前は既存の Player 名と一致する（空白の違いで取込が飛ばさない）" do
      known = cards.flat_map { |r| [ r["name"], r["base_player_name"] ] }.compact.map { |n| n.sub(/\s*[（(][^()（）]+[）)]\z/, "") }.uniq
      names = table("player_card_exclusive_catchers").select { |r| r["card_seq"].to_i >= 433 && added_seqs.include?(r["card_seq"].to_i) }.map { |r| r["catcher_name_raw"] }
      expect(names).to match_array([ "八雲 藍", "橙", "乾 ケイ", "山崎 珠姫" ])
      expect(names - known).to eq([])
    end

    it "公式戦で使用できない印は PDF の注記どおり（PM2027 全体で 18 枚。追加では 潮見 凪沙 UR だけ）" do
      expect(pm27.count { |r| r["official_use_prohibited"] == "true" }).to eq(18)
      expect(added.select { |r| r["official_use_prohibited"] == "true" }.map { |r| r["name"] }).to eq([ "潮見 凪沙 (UR)" ])
    end

    it "語彙に無い記述（代打専門・要代走・【中4日可】・4/22~）は勝手に定義せず unique_traits に生テキストで残す" do
      texts = added.map { |r| r["unique_traits"] }.compact.join("\n")
      %w[代打専門 要代走 【中4日可】 4/22~].each { |t| expect(texts).to include(t) }
      expect(table("player_card_traits").map { |r| r["trait_definition_name"] }.uniq - %w[対右 対左 DB チャンス WP ホームラン 内野安打 三振 三振振り逃げ ボーク 1C5 1P5]).to eq([])
      expect(table("player_card_abilities").map { |r| r["ability_definition_name"] }.uniq - %w[代打可 オープナー可 クイック○ WPしない クイック× 牽制○ 暴投追加 ボークしない 要中10日 牽制死 指名打者 代打]).to eq([])
    end
  end
end
