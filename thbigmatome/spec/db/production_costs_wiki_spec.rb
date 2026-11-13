require "rails_helper"
require "csv"

# コストの初期データを Wiki のコスト一覧に合わせる（cmd_1893 / subtask_1893d）。seeds（import_cards.rb → production_costs.rb）を空 DB で回して確かめる。
#
# Test Basis:
#   - Operator 裁定（2026-11-14）: コストの一次情報は Wiki のコスト一覧。seed と値が違うものは Wiki の数値、Wiki にあって seed に無い選手は足す。
#     你 藍翠は Wiki の行（4）。冴月 麟は 投手と野手が別カード（二刀流不可）で、値は Wiki の行名どおり 冴月麟(野手) 4・冴月麟(投手) 4（投手登録の「冴月麟 9」はどちらにも当てない）。推定で当てた 5 件（AP明羅 12・AP天子 10・てゐ(茨城) 5・こいし(茨城2) 10・ユウゲンマガン 1）は推定どおり。
#     エイプリル・完走カードは年度版と別カードで、Wiki でも別の行にコストが付く
#   - 照合の表 context/thbig-pm2027-costs.csv（PM2027 の 144 枚 × Wiki の行）と context/thbig-pm2027-costs.md §3（食い違い 9・不足 51・seed のみ 2）。
#     spec/fixtures/files/wiki_pm2027_costs.csv はその表に上の裁定を当てたもの（expected_cost が Wiki の数値）
#   - Wiki 未掲載の 18 枚は、取り込み前から引けていた値（unlisted_baseline_cost）のまま変えない（Wiki に無い数値を作らない）
#   - 現行のコスト一覧（end_date が空）は 1 件（costs の一意 index）。コストの引き当ては Player#cost_value_for_card
RSpec.describe "コストの初期データ（production_costs.rb）と Wiki のコスト一覧" do
  SEED_CSV = Rails.root.join("db/import/cost_players_seed.csv")
  FIXTURE_CSV = Rails.root.join("spec/fixtures/files/wiki_pm2027_costs.csv")
  CURRENT_COST_NAME = "2025年12月コスト改定".freeze

  def seed_rows = @seed_rows ||= CSV.read(SEED_CSV, headers: true, encoding: "UTF-8")
  def current_rows = seed_rows.select { |r| r["cost_name"] == CURRENT_COST_NAME }
  def fixture = @fixture ||= CSV.read(FIXTURE_CSV, headers: true, encoding: "UTF-8")
  def current_cost = Cost.current_cost

  # card_seq → PlayerCard（取り込んだ順に card_seq = id にはならないので、出典・種別・variant・持ち主で引く）
  def card_for(seq)
    row = player_card_rows.fetch(seq.to_s)
    set = CardSet.find_by!(name: row["card_source"])
    owner_name = row["variant"].present? && row["base_player_name"].present? ? row["base_player_name"] : row["name"]
    owner = Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", owner_name.gsub(/[\s　]+/, ""))
    type = row["card_type"].presence || (row["is_pitcher"] == "true" ? "pitcher" : "batter")
    scope = PlayerCard.where(card_set: set, player: owner, card_type: type)
    scope = row["variant"].present? ? scope.where(variant: row["variant"]) : scope.where(variant: [ nil, "" ])
    scope.take!
  end

  def player_card_rows
    @player_card_rows ||= CSV.read(Rails.root.join("db/import/player_cards.csv"), headers: true, encoding: "UTF-8").to_h { |r| [ r["card_seq"], r ] }
  end

  def resolved_cost(card) = card.player.cost_value_for_card(card, current_cost)

  def run_quiet
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  before(:all) do
    ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
    load Rails.root.join("db/seeds/master_traits.rb")
    @output = run_quiet do
      load Rails.root.join("db/seeds/import_cards.rb")
      CostPlayerSeedResolver.clear_cache!
      load Rails.root.join("db/seeds/production_costs.rb")
    end
  end
  after(:all) do
    ENV.delete("CARD_DATA_DIR")
    CostPlayerSeedResolver.clear_cache!
    DatabaseCleaner.clean_with(:truncation)
  end

  it "現行のコスト一覧（end_date が空）は 2025年12月コスト改定の 1 件だけ" do
    expect(Cost.where(end_date: nil).pluck(:name)).to eq([ CURRENT_COST_NAME ])
  end

  describe "PM2027 の 144 枚" do
    it "照合の表は 144 枚で、Wiki の数値がある 126 枚と Wiki に行が無い 18 枚に分かれる" do
      expect(fixture.size).to eq(144)
      expect(fixture.count { |r| r["expected_cost"].present? }).to eq(126)
      expect(fixture.count { |r| r["expected_cost"].blank? }).to eq(18)
    end

    it "Wiki に行がある 126 枚は、取り込み後に引けるコストが Wiki の数値と一致する" do
      mismatches = fixture.select { |r| r["expected_cost"].present? }.filter_map do |r|
        got = resolved_cost(card_for(r["card_seq"]))
        "#{r['name']}(seq #{r['card_seq']}): Wiki #{r['expected_cost']} / 実際 #{got}" unless got == r["expected_cost"].to_i
      end
      expect(mismatches).to eq([])
    end

    it "同じ内容の PM2026 のカード（Wiki の行は版を区別しない）も、同じ数値で引ける" do
      mismatches = fixture.select { |r| r["expected_cost"].present? && r["pm2026_card_seq"].present? }.filter_map do |r|
        got = resolved_cost(card_for(r["pm2026_card_seq"]))
        "#{r['name']}(PM2026 seq #{r['pm2026_card_seq']}): Wiki #{r['expected_cost']} / 実際 #{got}" unless got == r["expected_cost"].to_i
      end
      expect(mismatches).to eq([])
    end

    it "Wiki に行が無い 18 枚は、取り込み前から引けていた値のまま（0 になるのは持ち主にコストが無い 5 枚で、既存の扱い）で、そのカード専用の行も作らない" do
      unlisted = fixture.select { |r| r["expected_cost"].blank? }
      changed = unlisted.filter_map do |r|
        card = card_for(r["card_seq"])
        got = resolved_cost(card)
        "#{r['name']}: 取り込み前 #{r['unlisted_baseline_cost']} / 実際 #{got}" unless got == r["unlisted_baseline_cost"].to_i
      end
      expect(changed).to eq([])
      invented = unlisted.select { |r| CostPlayer.where(cost: current_cost, player_card: card_for(r["card_seq"])).exists? }
      expect(invented.map { |r| r["name"] }).to eq([])
      expect(unlisted.count { |r| r["unlisted_baseline_cost"].to_i.zero? }).to eq(5)
    end

    it "你 藍翠は PM2026（野手）も PM2027（投手）も Wiki の行 4、冴月 麟は 野手 4・投手 4（Wiki の行名どおり。投手登録の「冴月麟 9」はどのカードにも当てない）" do
      ni = Player.find_by!(name: "你 藍翠")
      expect(ni.player_cards.map { |c| resolved_cost(c) }).to eq([ 4, 4 ])
      expect(resolved_cost(Player.find_by!(name: "冴月 麟 (野手)").player_cards.first)).to eq(4)
      # Wiki 投手登録の「冴月麟 9」は使われない行。消さずに、どの冴月 麟 のカード・行にも当てていないことを固定する
      cost_rows = Player.where(name: [ "冴月 麟 (野手)", "冴月 麟 (投手)" ]).flat_map { |pl| pl.cost_players.where(cost: current_cost).to_a }
      expect(cost_rows.flat_map { |cp| [ cp.normal_cost, cp.relief_only_cost, cp.pitcher_only_cost, cp.fielder_only_cost, cp.two_way_cost ] }.compact).to all(eq(4))
      expect(Player.find_by!(name: "冴月 麟 (野手)").available_cost_types).to eq([ "normal_cost" ])
      expect(resolved_cost(Player.find_by!(name: "冴月 麟 (投手)").player_cards.first)).to eq(4)
    end

    it "推定で当てた 5 件は推定どおり（AP明羅 12・AP天子 10・てゐ(茨城) 5・こいし(茨城2) 10・ユウゲンマガン 1）" do
      want = { "明羅" => 12, "比那名居 天子" => 10, "因幡 てゐ" => 5, "古明地 こいし" => 10, "ユウゲンマガン" => 1 }
      got = want.keys.to_h do |name|
        r = fixture.find { |f| f["name"].gsub(/[\s　]+/, "").start_with?(name.gsub(/[\s　]+/, "")) && f["kind"] != "" }
        [ name, resolved_cost(card_for(r["card_seq"])) ]
      end
      expect(got).to eq(want)
    end
  end

  describe "Wiki と seed の食い違い・不足（context/thbig-pm2027-costs.md §3）" do
    it "食い違い 9 件が Wiki の数値になる（幽々子(楼閣) 20・千亦(草津) 15・諏訪子(天地人) 10・紫安2 7・とり2 6・かじわら 4・神宮寺(五所) 8・岸楓佳 野 6・高坂椿 野3 投7 両11 中4）" do
      by_entry = fixture.to_h { |r| [ r["wiki_entry"], r ] }
      pm = { "幽々子(楼閣)" => 20, "千亦(草津)" => 15, "諏訪子(天地人)" => 10, "紫安2" => 7, "とり2" => 6, "かじわら" => 4, "神宮寺(五所)" => 8 }
      pm.each { |entry, cost| expect(resolved_cost(card_for(by_entry.fetch(entry)["card_seq"]))).to eq(cost), entry }

      base_row = ->(name) { Player.find_by!(name: name).cost_players.find_by(cost: current_cost, player_card_id: nil) }
      expect(base_row.("岸 楓佳")&.normal_cost).to eq(6)
      kosaka = base_row.("高坂 椿")
      expect(kosaka && [ kosaka.normal_cost, kosaka.relief_only_cost, kosaka.pitcher_only_cost, kosaka.fielder_only_cost, kosaka.two_way_cost ]).to eq([ nil, 4, 7, 3, 11 ])
    end

    it "Wiki にあって seed に無かった選手が入る（コラボのフリーダ・F・アンバー 投6・川口芳乃 1。カードの無いベルン 5 は行だけ）" do
      frida = Player.find_by!("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", "フリーダ・F・アンバー")
      expect(frida.cost_players.find_by(cost: current_cost, player_card_id: nil)&.normal_cost).to eq(6)
      names = current_rows.to_h { |r| [ r["player_name"].unicode_normalize(:nfkc).gsub(/[[:space:]]+/, ""), r ] }
      expect(names.fetch("川口芳乃")["normal_cost"]).to eq("1")
      expect(names.fetch("ベルン")["normal_cost"]).to eq("5")
    end

    it "seed にあって Wiki に無い 2 名（リリーブラック 2・Einzbern 5）は消さずに残す" do
      names = current_rows.to_h { |r| [ r["player_name"], r["normal_cost"] ] }
      expect(names["リリーブラック"]).to eq("2")
      expect(names["Einzbern"]).to eq("5")
    end

    it "2025年12月の行で選手に当たらず読み飛ばされるのは、カードの無い選手の行だけ（PM のカードの行は 0 件）" do
      skipped = current_rows.reject { |r| CostPlayerSeedResolver.assign!(current_cost, r) }.map { |r| r["player_name"] }
      expect(skipped).to match_array(%w[二ツ岩　マミゾウ 駒草　山如 Einzbern 銀河 ナガタ 中二 下神　空 ベルン 川口　芳乃])
    end
  end

  describe "カード単位の行（card_seq 列）" do
    it "card_seq の行はそのカード 1 枚に player_card_id つきで付く" do
      rows = current_rows.select { |r| r["card_seq"].present? }
      expect(rows.size).to be > 0
      rows.each do |r|
        cp = CostPlayerSeedResolver.assign!(current_cost, r)
        expect(cp.player_card).to eq(card_for(r["card_seq"])), "card_seq #{r['card_seq']}"
        expect(cp.player_card.card_set.name).to match(/\APM20(26|27)\z/)
      end
    end

    it "card_seq を持つ行は PM のカード 1 枚につき 1 行まで（重複して別の値が競合しない）" do
      seqs = current_rows.map { |r| r["card_seq"].presence }.compact
      expect(seqs.tally.select { |_, n| n > 1 }.keys).to eq([])
    end
  end
end
