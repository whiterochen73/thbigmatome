require "rails_helper"
require "rake"
require "csv"

# カードデータの表の作り（cmd_1892）。能力欄・【特例起用】・登板時の捕手守備を条件で持ち、seeds が 432 枚まで止まらないこと。
#
# Test Basis:
#   - Operator 決定（2026-11-13）: 「4件とも推奨どおり」（context/thbig-card-data-reread-all.md §5.1〜§5.5 の案 A）
#   - 同 §2.6（登板時の捕手 6 枚 + 362）・§2.7（特例起用 8 枚）・§2.11（能力欄 34 枚 38 件と守備欄の注記 3 件）
#   - オープナーの暫定措置の終了は Operator 了承済み（2026-10-27 の暫定措置が定義の投入で終わる）
#   - 値は画像で確かめた（tmp/card_images。件数は subtask_1892a の報告に記録）
CARD_STRUCTURE_DIR = Rails.root.join("db/import").to_s

OPENER_SEQS = [ 10, 13, 35, 91, 119, 146 ].freeze
ABILITY_SEQS = {
  "代打可" => [ 82, 84, 92, 114, 137, 232, 250, 264, 279, 398 ],
  "オープナー可" => OPENER_SEQS,
  "クイック○" => [ 55, 87, 174, 222 ],
  "WPしない" => [ 7, 82, 148, 369 ],
  "クイック×" => [ 39, 92, 148 ],
  "牽制○" => [ 87, 118, 143 ],
  "暴投追加" => [ 141, 271, 353 ],
  "ボークしない" => [ 59, 86 ],
  "要中10日" => [ 285, 303 ],
  "牽制死" => [ 331 ]
}.freeze
# 守備欄の注記（能力欄の一種として持つ）
DEFENSE_NOTES = { "指名打者" => [ 54 ], "代打" => [ 54, 325 ] }.freeze
TOKUREI_SEQS = [ 17, 25, 48, 54, 63, 128, 146, 151 ].freeze
# 登板時の捕手守備: [通常の C 行（範囲・失策・肩）, 登板時の C 行]
BATTERY_CATCHERS = {
  40 => [ [ 1, "B", "0" ], [ 5, "B", "+3" ] ],
  76 => [ [ 1, "E", "-4" ], [ 2, "A", "-2" ] ],
  152 => [ [ 1, "E", "-4" ], [ 4, "A", "-2" ] ],
  153 => [ [ 0, "E", "-5" ], [ 1, "A", "-4" ] ],
  397 => [ [ 1, "B", "0" ], [ 5, "B", "+3" ] ],
  407 => [ [ 4, "A", "+1" ], [ 5, "S", "+1" ] ]
}.freeze

RSpec.shared_examples "カードの構造（能力欄・特例起用・登板時守備）" do
  def cards_csv = @cards_csv ||= CSV.read(File.join(CARD_STRUCTURE_DIR, "player_cards.csv"), headers: true)

  def db_card(seq)
    row = cards_csv.find { |r| r["card_seq"] == seq.to_s }
    set = CardSet.find_by(name: { "2025THBIG" => "2025THBIG", "hachinai6.1" => "ハチナイ6.1", "PM2026" => "PM2026", "tamayomi2" => "球詠2" }[row["card_source"]])
    squash = ->(n) { n.gsub(/[\s　]+/, "") }
    # seeds は variant 列を持ち base_player に付け替える。rake は variant を使わず、印字の名前の別 player に作る
    [ [ row["base_player_name"].presence || row["name"], row["variant"].presence ], [ row["name"], nil ] ].uniq.each do |n, v|
      player = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", squash.(n))
      next unless player
      card = PlayerCard.find_by(player_id: player.id, card_set_id: set.id, card_type: row["card_type"], variant: v)
      return card if card
    end
    nil
  end

  def cond(card, relation)
    card.public_send(relation).includes(:condition).map { |x| x.condition&.name }
  end

  it "432 枚が入る（途中で止まらない）" do
    expect(@import_error).to be_nil
    expect(PlayerCard.count).to eq(432)
    expect(PlayerCard.where(official_use_prohibited: true).count).to eq(23)
  end

  describe "能力欄" do
    it "能力の定義が入る（カードの記載の 10 種 + 守備欄の注記 2 種）" do
      expect(AbilityDefinition.pluck(:name)).to match_array(ABILITY_SEQS.keys + DEFENSE_NOTES.keys)
    end

    it "能力ごとの件数と対象カードが CSV どおり（38 件 + 守備欄の注記 3 件）" do
      expect(PlayerCardAbility.count).to eq(41)
      (ABILITY_SEQS.merge(DEFENSE_NOTES)).each do |name, seqs|
        actual = PlayerCardAbility.joins(:ability_definition).where(ability_definitions: { name: name })
                                  .map { |a| a.player_card_id }.sort
        expect(actual).to eq(seqs.map { |s| db_card(s).id }.sort), name
      end
    end

    it "82・87・92・148 は複数の能力を持つ" do
      expect(PlayerCardAbility.where(player_card_id: [ 82, 87, 92, 148 ].map { |s| db_card(s).id }).group(:player_card_id).count.values.sort).to eq([ 2, 2, 2, 2 ])
    end

    it "オープナー可は 6 枚だけ。暫定措置（リリーフで投げられる全員）は終わる" do
      expect(AbilityDefinition.exists?).to be(true)
      capable = PlayerCard.includes(player_card_abilities: :ability_definition).select(&:opener_capable?)
      expect(capable.map(&:id).sort).to eq(OPENER_SEQS.map { |s| db_card(s).id }.sort)
      relief_only_not_listed = PlayerCard.where(is_relief_only: true).where.not(id: capable.map(&:id))
      expect(relief_only_not_listed.count).to be > 0
      expect(relief_only_not_listed.first.opener_capable?).to be(false)
    end
  end

  describe "【特例起用】" do
    it "条件語彙「特例起用」がある" do
      expect(TraitCondition.where(name: "特例起用").count).to eq(1)
    end

    it "特例側の特徴に条件が付く（17・25・48・63・128・146・151。63・151 は通常側も別行で残る）" do
      tokurei = TraitCondition.find_by!(name: "特例起用")
      expect(PlayerCardTrait.where(condition_id: tokurei.id).count).to eq(7)
      expect(cond(db_card(17), :player_card_traits)).to eq([ "特例起用" ])
      expect(cond(db_card(25), :player_card_traits)).to eq([ "特例起用" ])
      expect(cond(db_card(48), :player_card_traits)).to eq([ "特例起用" ])
      expect(cond(db_card(128), :player_card_traits)).to eq([ "特例起用" ])
      expect(cond(db_card(146), :player_card_traits)).to eq([ "特例起用" ])
    end

    it "63・151 は特例起用つきと通常の同名特徴の 2 件（条件つきが先: 既存の並びの規則）" do
      [ [ 63, "DB" ], [ 151, "対左" ] ].each do |seq, name|
        expect(db_card(seq).player_card_traits.order(:sort_order).map { |t| [ t.trait_definition.name, t.condition&.name, t.sort_order ] })
          .to eq([ [ name, "特例起用", 0 ], [ name, nil, 1 ] ]), "card_seq=#{seq}"
      end
    end

    it "54 は守備側（OF 1E 肩 C）が特例起用の条件付きで、通常の特徴（チャンス）は条件なしのまま" do
      d = db_card(54).player_card_defenses.includes(:condition).to_a
      expect(d.map { |x| [ x.position, x.range_value, x.error_rank, x.throwing, x.condition&.name ] }).to eq([ [ "OF", 1, "E", "C", "特例起用" ] ])
      expect(db_card(54).player_card_traits.map { |t| [ t.trait_definition.name, t.condition&.name ] }).to eq([ [ "チャンス", nil ] ])
    end

    it "特例側でない特徴には付かない（17 のほかの守備は条件なし）" do
      expect(cond(db_card(17), :player_card_defenses)).to all(be_nil)
    end
  end

  describe "登板時の捕手守備" do
    it "条件語彙「専属投手登板時」「専属投手降板後」がある" do
      expect(TraitCondition.where(name: [ "専属投手登板時", "専属投手降板後" ]).pluck(:name)).to match_array(%w[専属投手登板時 専属投手降板後])
    end

    it "40・76・152・153・397・407 は通常の C 行と登板時の C 行の 2 行（画像の値）" do
      BATTERY_CATCHERS.each do |seq, (normal, battery)|
        rows = db_card(seq).player_card_defenses.includes(:condition).where(position: "C").order(:id).to_a
        expect(rows.map { |d| [ d.range_value, d.error_rank, d.throwing, d.condition&.name ] })
          .to eq([ normal + [ nil ], battery + [ "専属投手登板時" ] ]), "card_seq=#{seq}"
      end
    end

    it "ほかの守備（OF など）は条件なしのまま" do
      expect(db_card(40).player_card_defenses.where.not(position: "C").map { |d| d.condition_id }).to all(be_nil)
      expect(db_card(407).player_card_defenses.where(position: "LR").map { |d| [ d.range_value, d.error_rank, d.throwing, d.condition_id ] }).to eq([ [ 3, "C", "A", nil ] ])
    end

    it "362 は C が【早苗登板時】、OF が【早苗降板後】の条件付きだけで、通常の守備は無い（画像どおり）" do
      rows = db_card(362).player_card_defenses.includes(:condition).order(:id).map { |d| [ d.position, d.range_value, d.error_rank, d.throwing, d.condition&.name ] }
      expect(rows).to eq([ [ "C", 5, "B", "+3", "専属投手登板時" ], [ "OF", 2, "E", "B", "専属投手降板後" ] ])
    end

    it "条件付き行の相方の投手は専属表（player_card_exclusive_catchers.csv）の逆引きで決まる" do
      squash = ->(n) { n.gsub(/[\s　]+/, "") }
      exclusive = CSV.read(File.join(CARD_STRUCTURE_DIR, "player_card_exclusive_catchers.csv"), headers: true)
      # 条件付き C 行を持つカード → 相方の投手の card_seq（早苗 35・豊姫 393・紫 142・天 406）
      { 40 => 35, 397 => 35, 362 => 35, 76 => 393, 152 => 142, 153 => 142, 407 => 406 }.each do |seq, partner|
        row = cards_csv.find { |r| r["card_seq"] == seq.to_s }
        names = exclusive.select { |r| r["card_seq"] == partner.to_s }.map { |r| squash.(r["catcher_name_raw"]) }
        expect(names).to include(squash.(row["base_player_name"].presence || row["name"].sub(/\s*\(.*\)\z/, ""))), "card_seq=#{seq}"
      end
    end
  end
end

RSpec.describe "カードの構造（cmd_1892）" do
  describe "CSV の形" do
    let(:abilities) { CSV.read(File.join(CARD_STRUCTURE_DIR, "player_card_abilities.csv"), headers: true) }
    let(:defenses) { CSV.read(File.join(CARD_STRUCTURE_DIR, "player_card_defenses.csv"), headers: true) }

    it "player_card_abilities.csv は 41 行（38 件 + 守備欄の注記 3 件）で、列は既存どおり" do
      expect(abilities.headers).to eq(%w[card_seq ability_definition_name condition_name role sort_order])
      expect(abilities.size).to eq(41)
      expect(abilities.map { |r| r["ability_definition_name"] }.tally).to eq(
        ABILITY_SEQS.transform_values(&:size).merge(DEFENSE_NOTES.transform_values(&:size)).transform_values(&:itself)
      )
    end

    it "オープナーは「オープナー可」の名前で 6 枚だけ" do
      expect(abilities.select { |r| r["ability_definition_name"].start_with?("オープナー") }.map { |r| [ r["ability_definition_name"], r["card_seq"].to_i ] })
        .to eq(OPENER_SEQS.map { |s| [ "オープナー可", s ] })
    end

    it "player_card_defenses.csv に condition_name 列があり、条件付きの行は 6 + 2 + 1 行" do
      expect(defenses.headers).to eq(%w[card_seq position range_value error_rank throwing condition_name])
      expect(defenses.select { |r| r["condition_name"].present? }.map { |r| [ r["card_seq"].to_i, r["position"], r["condition_name"] ] }).to eq(
        [ [ 40, "C", "専属投手登板時" ], [ 54, "OF", "特例起用" ], [ 76, "C", "専属投手登板時" ], [ 152, "C", "専属投手登板時" ],
          [ 153, "C", "専属投手登板時" ], [ 362, "C", "専属投手登板時" ], [ 362, "OF", "専属投手降板後" ],
          [ 397, "C", "専属投手登板時" ], [ 407, "C", "専属投手登板時" ] ]
      )
    end
  end

  describe "PlayerCard の一意性 validation は DB の一意 index（variant を含む）と同じ鍵" do
    it "variant が違えば同じ card_set・player・card_type でも作れ、同じ variant は作れない" do
      base = create(:player_card, variant: "エイプリル")
      other = build(:player_card, card_set: base.card_set, player: base.player, card_type: base.card_type, variant: "最上川")
      same = build(:player_card, card_set: base.card_set, player: base.player, card_type: base.card_type, variant: "エイプリル")
      expect(other).to be_valid
      expect(same).not_to be_valid
      expect(build(:player_card, card_set: base.card_set, player: base.player, card_type: base.card_type, variant: nil)).to be_valid
    end
  end

  describe "rake import:card_data" do
    before(:all) do
      Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data")
      ENV["CARD_DATA_DIR"] = CARD_STRUCTURE_DIR
      load Rails.root.join("db/seeds/master_traits.rb")
      original = $stdout
      $stdout = StringIO.new
      begin
        @import_error = nil
        begin
          Rake::Task["import:card_data"].reenable
          Rake::Task["import:card_data"].invoke
        rescue => e
          @import_error = e
        end
      ensure
        $stdout = original
      end
    end

    after(:all) do
      ENV.delete("CARD_DATA_DIR")
      DatabaseCleaner.clean_with(:truncation)
    end

    include_examples "カードの構造（能力欄・特例起用・登板時守備）"

    it "もう一度流しても件数が増えない（冪等）" do
      before_counts = [ PlayerCardAbility.count, PlayerCardDefense.count, PlayerCardTrait.count, PlayerCard.count ]
      original = $stdout
      $stdout = StringIO.new
      begin
        Rake::Task["import:card_data"].reenable
        Rake::Task["import:card_data"].invoke
      ensure
        $stdout = original
      end
      expect([ PlayerCardAbility.count, PlayerCardDefense.count, PlayerCardTrait.count, PlayerCard.count ]).to eq(before_counts)
    end
  end

  describe "db/seeds/import_cards.rb" do
    def run_seed
      original = $stdout
      $stdout = StringIO.new
      begin
        load Rails.root.join("db/seeds/import_cards.rb")
        nil
      rescue => e
        e
      ensure
        $stdout = original
      end
    end

    before(:all) do
      ENV.delete("CARD_DATA_DIR")
      load Rails.root.join("db/seeds/master_traits.rb")
      @import_error = run_seed
      @counts_after_first = [ PlayerCard.count, PlayerCardAbility.count, PlayerCardDefense.count, PlayerCardTrait.count ]
    end

    after(:all) { DatabaseCleaner.clean_with(:truncation) }

    include_examples "カードの構造（能力欄・特例起用・登板時守備）"

    it "2 回流しても 432 枚・印 23 枚・各件数が変わらない（冪等）" do
      expect(run_seed).to be_nil
      expect([ PlayerCard.count, PlayerCardAbility.count, PlayerCardDefense.count, PlayerCardTrait.count ]).to eq(@counts_after_first)
      expect(PlayerCard.count).to eq(432)
      expect(PlayerCard.where(official_use_prohibited: true).count).to eq(23)
    end
  end
end
