# frozen_string_literal: true

# PM2027 のカード 144 枚の CSV 行を生成して db/import/*.csv の末尾に足す（cmd_1893 / subtask_1893a）。
#
# 使い方（thbigmatome/ で）:
#   ruby scripts/generate_pm2027_cards.rb            # 5 本の CSV に PM2027 の行を書く（何度流しても同じ結果。PM2027 の行は毎回作り直す）
#   ruby scripts/generate_pm2027_cards.rb --report   # 書かずに、語彙に無かった特徴・能力・空欄などの一覧だけ出す
#
# 入力: db/import/pm2027/（PDF の文字層から作った構造化データ。README.md 参照）と、現行の db/import/*.csv の PM2026 行。
#
# 作り方:
#   - PM2026 と対応が付いた 129 枚: 現行の PM2026 の CSV 行を写し、card_seq と card_source だけ変える。
#     読み直しで直した値を失わないため、PDF からは作り直さない。
#   - 変更 6 枚（PM2026 の 305・321・330・341・362・388）: 差分を当てる。321 は別カード（投手）なので JSON から作る。
#   - 追加 15 枚: JSON から CSV の語彙で作る。語彙に無い記述は unique_traits に生テキストで残し、--report に出す。
#   - card_seq = 433 + (ページ-1)*9 + (行*3+列)。

require "csv"
require "json"

module Pm2027
  ROOT = File.expand_path("..", __dir__)
  IMPORT_DIR = File.join(ROOT, "db/import")
  DATA_DIR = File.join(IMPORT_DIR, "pm2027")
  SOURCE = "PM2027"
  BASE_SEQ = 433

  FILES = {
    cards: "player_cards.csv",
    defenses: "player_card_defenses.csv",
    traits: "player_card_traits.csv",
    abilities: "player_card_abilities.csv",
    catchers: "player_card_exclusive_catchers.csv"
  }.freeze

  # db/seeds/master_traits.rb の語彙
  TRAIT_NAMES = %w[対右 対左 DB チャンス WP ホームラン 内野安打 三振 三振振り逃げ ボーク 1C5 1P5].freeze
  ABILITY_NAMES = %w[代打可 オープナー可 クイック○ WPしない クイック× 牽制○ 暴投追加 ボークしない 要中10日 牽制死 指名打者 代打].freeze
  CONDITIONS = {
    "(無走者)" => "無走者", "(走者なし)" => "無走者",
    "(有走者)" => "有走者", "(走者あり)" => "有走者",
    "(同点時)" => "同点", "(リード時)" => "リード", "(ビハインド時)" => "ビハインド"
  }.freeze
  # PM2026 でも CSV に持たずに落としている記述（フルイニング）。語彙に無いが、既存の扱いに合わせる
  IGNORED_LINES = %w[フルイニング].freeze
  # 打撃表・投球表を JSON 配列文字列にする時の区切り（既存 CSV と同じ ", " 区切り）
  def self.json_table(rows)
    "[" + rows.map { |r| r.is_a?(Array) ? "[" + r.map(&:to_json).join(", ") + "]" : r.to_json }.join(", ") + "]"
  end

  def self.load_json(name) = JSON.parse(File.read(File.join(DATA_DIR, name)))

  def self.read_csv(key)
    CSV.read(File.join(IMPORT_DIR, FILES[key]), headers: true)
  end

  # nil 以外は文字列。空文字は nil にして CSV の空欄に揃える
  def self.blank_nil(v)
    s = v.nil? ? nil : v.to_s
    s.nil? || s.empty? ? nil : s
  end

  # ---- 新カード（JSON から作る）--------------------------------------------------
  class Builder
    attr_reader :unknown, :notes

    def initialize(known_names)
      @known_names = known_names # 空白つきの正式名の集合（現行 CSV の名前・base_player_name から）
      @unknown = []
      @notes = []
    end

    def hands(card)
      m = card["info"][0].match(/\(利\)(右|左)投(右|左|両)打/)
      raise "利き手が読めない: idx=#{card['idx']}" unless m
      throwing = m[1] == "右" ? "right" : "left"
      batting = { "右" => "right", "左" => "left", "両" => "switch" }.fetch(m[2])
      [ throwing, batting ]
    end

    def batting_table(card)
      rows = card["batting_table"]
      if card["kind"] == "pitcher" && rows.all? { |r| r.size > 4 && r[4].to_s.empty? }
        rows = rows.map { |r| r[0, 4] }
      end
      rows
    end

    def pitching_table(card)
      card["pitching_table"] || Array.new(20)
    end

    # 4 つの値を持つ基本行（card_seq / name / variant 等は呼び出し側で入れる）
    def base_row(card)
      throwing, batting = hands(card)
      pitcher = card["kind"] == "pitcher"
      fat = card["fatigue"] || {}
      {
        "number" => card["number"], "position" => card["position"],
        "parse_status" => "ok", "throwing_hand" => throwing, "batting_hand" => batting,
        "is_pitcher" => pitcher.to_s, "card_type" => pitcher ? "pitcher" : "batter",
        "speed" => card["speed"], "bunt" => card["bunt"],
        "steal_start" => card["steal"][0], "steal_end" => card["steal"][1],
        "injury_rate" => card["injury_rate"],
        "is_relief_only" => (fat["relief_only"] ? true : false).to_s,
        "starter_stamina" => fat["starter"], "relief_stamina" => fat["relief"],
        "is_closer" => (fat["closer"] ? true : false).to_s,
        "batting_table" => Pm2027.json_table(batting_table(card)),
        "pitching_table" => Pm2027.json_table(pitching_table(card)),
        "irc_macro_name" => card["number"]
      }
    end

    def defenses(card)
      card["defense"].map do |d|
        { "position" => d["position"], "range_value" => d["range_value"] || d["range"], "error_rank" => d["error_rank"],
          "throwing" => d["throwing"], "condition_name" => nil }
      end
    end

    # trait_lines / other_lines を語彙に当てる。戻り値: {traits:, abilities:, catchers:, unique:}
    def traits_of(card)
      traits = []         # [name, condition, block]  block: :general / :exclusive
      abilities = []
      catchers = []
      unique = []
      cond = nil
      mode = nil
      other_first = [] # 【それ以外】以降の特徴（既存の並びに合わせ、条件なしを先頭に置く）

      lines = card["trait_lines"] + card["other_lines"]
      lines.each do |line|
        l = line.strip
        if mode == :catcher_names
          catchers.concat(l.split("or"))
          mode = nil
          next
        end
        if (c = CONDITIONS[l])
          cond = c
          next
        end
        if l == "【専属捕手】"
          mode = :catcher_names
          next
        end
        if l == "【それ以外】" || l =~ /\A【捕手.+】\z/
          unique << l
          if l == "【それ以外】"
            mode = :other
          else
            catchers << l[/【捕手(.+)】/, 1]
          end
          cond = nil
          next
        end
        if IGNORED_LINES.include?(l)
          @notes << "idx=#{card['idx']}: 「#{l}」は PM2026 の既存行と同じく CSV に持たない"
          next
        end
        if ABILITY_NAMES.include?(l)
          abilities << l
        elsif TRAIT_NAMES.include?(l)
          entry = [ l, cond, nil ]
          if mode == :other
            other_first << entry
          else
            traits << entry
          end
          cond = nil
        elsif l =~ /\A[~\d\/]+~?\z/ || l =~ /\A\d+\/\d+~\z/
          unique << l # 日付つきの限定（PM2026 の 378 の「5/1~」と同じ扱い）
          @unknown << [ card["idx"], l, "日付限定" ]
        else
          unique << l
          @unknown << [ card["idx"], l, "語彙に無い記述" ]
        end
      end
      { traits: other_first + traits, abilities: abilities, catchers: catchers, unique: unique }
    end

    def resolve_catcher(raw)
      return raw if @known_names.include?(raw)
      cand = @known_names.select { |n| n.delete(" ") == raw.delete(" ") || n.end_with?(" #{raw}") || n == raw }
      cand = @known_names.select { |n| n.end_with?(raw) && n.size > raw.size } if cand.empty?
      if cand.size == 1
        cand.first
      else
        @unknown << [ nil, raw, "専属捕手の名前が Player 名に一意に当たらない(#{cand.inspect})" ]
        raw
      end
    end
  end

  # ---- 生成本体 -----------------------------------------------------------------
  class Generator
    attr_reader :rows, :defenses, :traits, :abilities, :catchers, :builder, :report

    def initialize
      @cards = Pm2027.load_json("PM2027_cards.json")
      @summary = Pm2027.load_json("pm2027_diff_summary.json")
      @curated = Pm2027.load_json("pm2027_changes_curated.json")
      @old = Pm2027::FILES.keys.to_h { |k| [ k, Pm2027.read_csv(k).reject { |r| r["card_source"] == SOURCE && k == :cards } ] }
      @old_cards = @old[:cards]
      @pm26 = @old_cards.select { |r| r["card_source"] == "PM2026" }.to_h { |r| [ r["card_seq"].to_i, r ] }
      known = @old_cards.flat_map { |r| [ r["name"], r["base_player_name"] ] }.compact
      known += @old_cards.map { |r| r["name"].to_s.sub(/\s*[（(][^()（）]+[）)]\z/, "") }
      @builder = Pm2027::Builder.new(known.uniq)
      @report = []
      @rows = []
      @defenses = []
      @traits = []
      @abilities = []
      @catchers = []
      @matches = @summary["matches"].to_h { |k, v| [ k.to_i, v ] }
      @added = @summary["added"].to_h { |a| [ a["idx"], a ] }
    end

    def seq_of(card)
      page = card["page"]
      r, c = card["pos_in_page"]
      idx = (page - 1) * 9 + r * 3 + c
      raise "idx 不一致 #{card['idx']} != #{idx}" unless idx == card["idx"]
      BASE_SEQ + idx
    end

    def sub_rows(key, old_seq) = @old[key].select { |r| r["card_seq"] == old_seq.to_s }

    def copy_children(old_seq, new_seq)
      %i[defenses traits abilities catchers].each do |k|
        sub_rows(k, old_seq).each do |r|
          h = r.to_h
          h["card_seq"] = new_seq.to_s
          instance_variable_get("@#{k}") << h
        end
      end
    end

    def normalize(name) = name.to_s.gsub(/[\s　]+/, "")

    def base_name_of(row)
      Pm2027.blank_nil(row["base_player_name"]) || row["name"].to_s.sub(/\s*[（(][^()（）]+[）)]\z/, "")
    end

    def spaced_name(added)
      plain = added["name"]
      cand = @builder.instance_variable_get(:@known_names).select { |n| normalize(n) == plain }.uniq
      cand = cand.reject { |n| n =~ /[（(]/ }
      if cand.size >= 1
        cand.first
      else
        @report << [ added["idx"], plain, "Player 名の空白つき表記が既存 CSV に無い（head_rest から補う）" ]
        nil
      end
    end

    def run
      pm27_base_names = Hash.new(0)
      @cards.each do |card|
        seq = seq_of(card)
        if (old = @matches[card["idx"]])
          pm27_base_names[normalize(base_name_of(@pm26.fetch(old)))] += 1
        elsif (a = @added[card["idx"]])
          nm = spaced_name(a)
          pm27_base_names[normalize(nm || a["name"])] += 1
        else
          raise "対応表に無いカード idx=#{card['idx']}"
        end
      end

      @cards.each do |card|
        seq = seq_of(card)
        old = @matches[card["idx"]]
        if old && !@curated.key?(old.to_s)
          build_copied(card, seq, old)
        elsif old
          build_changed(card, seq, old)
        else
          build_added(card, seq, pm27_base_names)
        end
      end
      self
    end

    def build_copied(_card, seq, old)
      row = @pm26.fetch(old).to_h
      row["card_seq"] = seq.to_s
      row["card_source"] = SOURCE
      @rows << row
      copy_children(old, seq)
    end

    def assert_pre_image(old, field, expected, actual, label)
      return if expected == actual
      raise "現行 CSV が差分調査の PM2026 側と食い違う: card_seq=#{old} #{field} #{label} 調査=#{expected.inspect} CSV=#{actual.inspect}"
    end

    def build_changed(card, seq, old)
      return build_321(card, seq, old) if old == 321

      row = @pm26.fetch(old).to_h
      row["card_seq"] = seq.to_s
      row["card_source"] = SOURCE
      table = JSON.parse(row["batting_table"])
      defs = sub_rows(:defenses, old).map(&:to_h)
      new_defs = nil
      applied = []
      @curated.fetch(old.to_s).each do |e|
        f = e["field"]
        case f
        when "print", /\Aheader/
          applied << "#{f}（CSV に列が無い。変更なし）"
        when "bunt"
          assert_pre_image(old, f, e["pm2026_csv"], row["bunt"].to_i, "")
          row["bunt"] = e["pm2027"].to_s
        when "speed"
          assert_pre_image(old, f, e["pm2026_csv"], row["speed"].to_i, "")
          row["speed"] = e["pm2027"].to_s
        when "injury"
          assert_pre_image(old, f, e["pm2026_csv"], row["injury_rate"].to_i, "")
          row["injury_rate"] = e["pm2027"].to_s
        when "steal"
          assert_pre_image(old, f, e["pm2026_csv"], [ row["steal_start"].to_i, row["steal_end"].to_i ], "")
          row["steal_start"], row["steal_end"] = e["pm2027"].map(&:to_s)
        when "hands"
          assert_pre_image(old, f, e["pm2026_csv"], [ row["throwing_hand"], row["batting_hand"] ], "")
          row["throwing_hand"], row["batting_hand"] = e["pm2027"]
        when "defense"
          cur = defs.map { |d| [ d["position"], d["range_value"].to_i, d["error_rank"], Pm2027.blank_nil(d["throwing"]) ] }
          assert_pre_image(old, f, e["pm2026_csv"], cur, "")
          new_defs = e["pm2027"]
        when /\Abatting r(\d+)c(\d+)\z/
          r = Regexp.last_match(1).to_i - 1
          c = Regexp.last_match(2).to_i - 1
          assert_pre_image(old, f, e["pm2026_csv"], table[r][c], "")
          table[r][c] = e["pm2027"]
        else
          raise "未対応の差分項目: #{old} #{f}"
        end
        applied << f
      end
      row["batting_table"] = Pm2027.json_table(table)
      @rows << row
      @defenses.concat(
        if new_defs
          new_defs.map { |p, rg, er, th| { "card_seq" => seq.to_s, "position" => p, "range_value" => rg.to_s, "error_rank" => er, "throwing" => th, "condition_name" => nil } }
        else
          defs.map { |d| d.merge("card_seq" => seq.to_s) }
        end
      )
      %i[traits abilities catchers].each do |k|
        sub_rows(k, old).each { |r| instance_variable_get("@#{k}") << r.to_h.merge("card_seq" => seq.to_s) }
      end
      @report << [ card["idx"], old, "変更適用: #{applied.join(', ')}" ]
    end

    # 321 你 藍翠: PM2027 では別カード（投手）。名前・背番号・出典以外は JSON から作る（暴言退場・1C5・野手の守備を持ち越さない）
    def build_321(card, seq, old)
      prev = @pm26.fetch(old)
      row = builder_row(card, seq)
      row["name"] = prev["name"]
      row["number"] = prev["number"]
      row["irc_macro_name"] = prev["irc_macro_name"]
      row["variant"] = nil
      row["base_player_name"] = nil
      row["official_use_prohibited"] = "false"
      attach(row, card, seq)
      @report << [ card["idx"], old, "321 は JSON から作り直し（野手→投手）" ]
    end

    def build_added(card, seq, name_counts)
      a = @added.fetch(card["idx"])
      base = spaced_name(a) || a["name"]
      tag = a["tag"].to_a.first
      row = builder_row(card, seq)
      collided = name_counts[normalize(base)] > 1
      row["name"] = tag && collided ? "#{base} (#{tag})" : base
      row["variant"] = tag
      row["base_player_name"] = tag ? base : nil
      row["official_use_prohibited"] = prohibited?(card) ? "true" : "false"
      attach(row, card, seq)
    end

    # 公式戦使用不可の注記は PDF の版の印字の欄（version）に入っている
    def prohibited?(card) = card["version"].to_s.include?("公式戦で使用できません")

    def builder_row(card, seq)
      row = Pm2027::CSV_COLUMNS.to_h { |c| [ c, nil ] }
      row.merge!(@builder.base_row(card))
      row["card_seq"] = seq.to_s
      row["card_source"] = SOURCE
      if row["injury_rate"].nil?
        # PDF のカードにけがの数字が印字されていない。PM2026 でも印字の無い 9 枚は CSV が 7（要点は --report）
        row["injury_rate"] = "7"
        @report << [ card["idx"], nil, "けがの数字の印字なし → 7（PM2026 で印字の無い 9 枚と同じ扱い）" ]
      end
      row
    end

    def attach(row, card, seq)
      t = @builder.traits_of(card)
      row["unique_traits"] = t[:unique].empty? ? nil : t[:unique].join("\n")
      @rows << row
      @builder.defenses(card).each { |d| @defenses << d.merge("card_seq" => seq.to_s) }
      t[:traits].each_with_index do |(name, cond, _), i|
        @traits << { "card_seq" => seq.to_s, "trait_definition_name" => name, "condition_name" => cond, "role" => nil, "sort_order" => i.to_s }
      end
      t[:abilities].each_with_index do |name, i|
        @abilities << { "card_seq" => seq.to_s, "ability_definition_name" => name, "condition_name" => nil, "role" => nil, "sort_order" => i.to_s }
      end
      t[:catchers].each do |raw|
        @catchers << { "card_seq" => seq.to_s, "catcher_name_raw" => @builder.resolve_catcher(raw) }
      end
    end
  end

  CSV_COLUMNS = %w[card_seq player_id card_set_id number position name card_source parse_status throwing_hand batting_hand is_pitcher card_type speed bunt steal_start steal_end injury_rate is_relief_only starter_stamina relief_stamina batting_style_id pitching_style_id is_closer unique_traits injury_traits biorhythm_period biorhythm_date_ranges batting_table pitching_table card_label irc_macro_name irc_display_name variant base_player_name official_use_prohibited].freeze

  DEFENSE_COLUMNS = %w[card_seq position range_value error_rank throwing condition_name].freeze
  TRAIT_COLUMNS = %w[card_seq trait_definition_name condition_name role sort_order].freeze
  ABILITY_COLUMNS = %w[card_seq ability_definition_name condition_name role sort_order].freeze
  CATCHER_COLUMNS = %w[card_seq catcher_name_raw].freeze

  COLUMNS = { cards: CSV_COLUMNS, defenses: DEFENSE_COLUMNS, traits: TRAIT_COLUMNS, abilities: ABILITY_COLUMNS, catchers: CATCHER_COLUMNS }.freeze

  def self.line(cols, hash, row_sep = "\n")
    CSV.generate_line(cols.map { |c| blank_nil(hash[c]) }, row_sep: row_sep)
  end

  # 生成する範囲（初版の 144 枚）。年の途中で足したカード（card_seq 577 以降）は、この範囲の外なので再生成で消さない
  GENERATED_SEQS = (BASE_SEQ..(BASE_SEQ + 143)).freeze

  # 現行の CSV の行のうち生成範囲（433〜576）を作り直した行に差し替えた本文を返す。
  # 先に「全体を CSV で往復すると元と一致する」ことを確かめる（一致しないなら既存行を壊す恐れがあるので止まる）
  def self.merged_text(key, recs)
    path = File.join(IMPORT_DIR, FILES[key])
    text = File.read(path)
    cols = COLUMNS[key]
    sep = text.include?("\r\n") ? "\r\n" : "\n" # 子表は CRLF、player_cards.csv は LF（元のまま保つ）
    all = read_csv(key).map(&:to_h)
    roundtrip = CSV.generate_line(cols, row_sep: sep) + all.map { |r| line(cols, r, sep) }.join
    raise "#{FILES[key]}: 既存行を CSV で往復すると元と一致しない（再引用で既存行を壊す恐れ）" unless roundtrip == text

    kept = all.reject { |r| GENERATED_SEQS.cover?(r["card_seq"].to_i) }
    merged = (kept + recs).each_with_index.sort_by { |r, i| [ r["card_seq"].to_i, i ] }.map(&:first)
    CSV.generate_line(cols, row_sep: sep) + merged.map { |r| line(cols, r, sep) }.join
  end

  def self.main(argv)
    gen = Generator.new.run
    if argv.include?("--report")
      gen.report.each { |r| puts r.inspect }
      gen.builder.unknown.each { |r| puts "UNKNOWN #{r.inspect}" }
      gen.builder.notes.each { |n| puts "NOTE #{n}" }
      puts "rows=#{gen.rows.size} defenses=#{gen.defenses.size} traits=#{gen.traits.size} abilities=#{gen.abilities.size} catchers=#{gen.catchers.size}"
      return
    end
    outputs = { cards: gen.rows, defenses: gen.defenses, traits: gen.traits, abilities: gen.abilities, catchers: gen.catchers }.to_h do |key, recs|
      [ key, merged_text(key, recs) ] # 5 本とも組み立てて確かめてから書く（途中で止まって半端な状態を残さない）
    end
    outputs.each { |key, text| File.write(File.join(IMPORT_DIR, FILES[key]), text) }
    puts "wrote: cards=#{gen.rows.size} defenses=#{gen.defenses.size} traits=#{gen.traits.size} abilities=#{gen.abilities.size} catchers=#{gen.catchers.size}"
  end
end

Pm2027.main(ARGV) if $PROGRAM_NAME == __FILE__
