require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# CardImporter の既存カードへの照合・更新（cmd_1898）。本番の旧行（card_seq なし）を壊さず、2 重化せず、CSV に合わせて直す。
#
# Test Basis:
#   - Operator 裁定（2026-11-14）: 西行寺 幽々子(楼閣)・八雲 藍(WBC2) は本番の形＝基の Player の variant。既存カードの紐づけ直しも行う。
#     PM は「全く別のカードに変更されることがある」ので、card_seq の鍵は版の差し替えにも効く形にする
#   - タスク指示（subtask_1898a）: 4 つの型（variant 改名・variant 後付け・別 Player 化・種別訂正）で既存行に当たる／2 重化しない／中身が更新される／
#     子の行が CSV と同じ集合になる／在籍のある行の id が変わらない／カードなし Player を作らない／2 回流して 0 件
#   - 子の行の id を他の表が参照していない（db/schema.rb の外部キーはカード・Player・定義側のみ）
RSpec.describe CardImporter do
  HEADERS = %w[
    card_seq player_id card_set_id number position name card_source parse_status throwing_hand batting_hand is_pitcher card_type
    speed bunt steal_start steal_end injury_rate is_relief_only starter_stamina relief_stamina batting_style_id pitching_style_id is_closer
    unique_traits injury_traits biorhythm_period biorhythm_date_ranges batting_table pitching_table card_label irc_macro_name irc_display_name
    variant base_player_name official_use_prohibited
  ].freeze
  TABLE = [ [ "H8", "1B", "2B", "G6D" ] ].freeze

  let(:dir) { Dir.mktmpdir }
  after { FileUtils.rm_rf(dir) }

  def card_row(seq:, name:, type: "batter", source: "PM2026", variant: nil, base: nil, macro: "7", table: TABLE, **over)
    h = { "card_seq" => seq.to_s, "number" => macro, "position" => "内野手", "name" => name, "card_source" => source, "parse_status" => "ok",
          "throwing_hand" => "right", "batting_hand" => "right", "is_pitcher" => (type == "pitcher").to_s, "card_type" => type,
          "speed" => "3", "bunt" => "5", "steal_start" => "10", "steal_end" => "10", "injury_rate" => "3", "is_relief_only" => "false",
          "is_closer" => "false", "batting_table" => table.to_json, "irc_macro_name" => macro, "variant" => variant, "base_player_name" => base,
          "official_use_prohibited" => "false" }
    h.merge(over.transform_keys(&:to_s))
  end

  def write(name, headers, rows)
    CSV.open(File.join(dir, name), "w") do |c|
      c << headers
      rows.each { |r| c << headers.map { |h| r[h] } }
    end
  end

  def write_all(cards, defenses: [], traits: [], abilities: [], catchers: [])
    write("player_cards.csv", HEADERS, cards)
    write("player_card_defenses.csv", %w[card_seq position range_value error_rank throwing condition_name], defenses)
    write("player_card_traits.csv", %w[card_seq trait_definition_name condition_name role sort_order], traits)
    write("player_card_abilities.csv", %w[card_seq ability_definition_name condition_name role sort_order], abilities)
    write("player_card_exclusive_catchers.csv", %w[card_seq catcher_name_raw], catchers)
  end

  def run_import(**opts)
    out = StringIO.new
    importer = described_class.new(data_dir: dir, out: out, **opts).run
    [ importer, out.string ]
  end

  let!(:set) { CardSet.create!(name: "PM2026", year: 2026, set_type: "pm2026", series: "original", is_current: true) } # 在籍の検証（現行のカードだけ選べる）を通すため true で作る。取り込みが対応表どおり false に直す

  def legacy(player, type: "batter", variant: nil, macro: "7", table: TABLE, **attrs)
    create(:player_card, card_set: set, player: player, card_type: type, variant: variant, irc_macro_name: macro, batting_table: table, **attrs)
  end

  def member(card)
    create(:team_membership, player: card.player, player_card: card)
  end

  describe "4 つの型で既存行に当たる（在籍のある行の id は変わらない）" do
    it "variant の改名: 本番の旧行の「楼閣」が CSV の「幽冥」に当たる（別名表）。同じ背番号の別の版は別カードのまま" do
      yomu = create(:player, name: "魂魄 妖夢")
      old = legacy(yomu, variant: "楼閣", macro: "34")
      write_all([ card_row(seq: 342, name: "魂魄 妖夢", variant: "幽冥", base: "魂魄 妖夢", macro: "34"),
                  card_row(seq: 349, name: "魂魄 妖夢 (エイプリル)", variant: "エイプリル", base: "魂魄 妖夢", macro: "34", table: [ [ "K", "K", "K", "K" ] ]) ])
      expect { run_import }.to change(PlayerCard, :count).by(1) # 349 だけが新規
      expect(old.reload.variant).to eq("幽冥")
      expect(old.card_seq).to eq(342)
      expect(PlayerCard.find_by(card_seq: 349).id).not_to eq(old.id)
    end

    it "variant の後付け: variant なしの旧行が CSV の variant つきの行に当たる（同じ Player・背番号・打撃表）" do
      rin = create(:player, name: "冴月 麟 (野手)")
      old = legacy(rin, macro: "000")
      mem = member(old)
      write_all([ card_row(seq: 351, name: "冴月 麟 (野手)", variant: "野手", macro: "000") ])
      expect { run_import }.not_to change(PlayerCard, :count)
      expect(old.reload.variant).to eq("野手")
      expect(old.card_seq).to eq(351)
      expect(mem.reload.player_card_id).to eq(old.id)
    end

    it "別 Player 化: 基の Player の variant として付けた旧行に当たり、「名前 (variant)」の Player を作らない" do
      base = create(:player, name: "西行寺 幽々子")
      old = legacy(base, variant: "楼閣", macro: "00")
      write_all([ card_row(seq: 365, name: "西行寺 幽々子(楼閣)", variant: "楼閣", base: "西行寺 幽々子", macro: "00") ])
      expect { run_import }.not_to change { [ Player.count, PlayerCard.count ] }
      expect(old.reload.card_seq).to eq(365)
      expect(Player.where("name LIKE ?", "%楼閣%")).to be_empty
    end

    it "種別の訂正: 在籍のある batter の旧行が CSV の pitcher の行に当たる。id・在籍の付き先・selected_cost_type は変わらず、中身は CSV に直る" do
      ibuki = create(:player, name: "川口 息吹")
      old = legacy(ibuki, type: "batter", macro: "T7", unique_traits: "3 【投手】")
      mem = member(old)
      mem.update_columns(selected_cost_type: "normal_cost")
      write_all([ card_row(seq: 421, name: "川口 息吹", type: "pitcher", macro: "T7", unique_traits: "【投手】 WP", starter_stamina: "6") ])
      importer, = run_import
      expect(PlayerCard.count).to eq(1)
      expect(old.reload.card_type).to eq("pitcher")
      expect([ old.is_pitcher, old.starter_stamina, old.unique_traits ]).to eq([ true, 6, "【投手】 WP" ])
      expect(mem.reload.attributes.slice("player_card_id", "player_id", "selected_cost_type")).to eq("player_card_id" => old.id, "player_id" => ibuki.id, "selected_cost_type" => "normal_cost")
      row = importer.report.find { |r| r["kind"] == "matched_changed_identity" }
      expect([ row["player_card_id"], row["memberships"] ]).to eq([ old.id, 1 ])
    end

    it "どの旧行にも当たらない行は新規作成する（旧行を巻き込まない）" do
      other = create(:player, name: "別の人")
      old = legacy(other, macro: "5")
      write_all([ card_row(seq: 900, name: "新しい人", macro: "99", table: [ [ "K", "K", "K", "K" ] ]) ])
      expect { run_import }.to change(PlayerCard, :count).by(1).and change(Player, :count).by(1)
      expect(old.reload.card_seq).to be_nil
    end

    it "variant 空の行は variant つきの旧行（PM2026 の「UR」カード）に当てず、variant 空のカードを新しく作る（取り違えない）" do
      hanayama = create(:player, name: "花山 栄美")
      ur = legacy(hanayama, variant: "UR", macro: "7")
      write_all([ card_row(seq: 401, name: "花山 栄美", macro: "7") ])
      expect { run_import }.to change(PlayerCard, :count).by(1)
      expect(ur.reload.card_seq).to be_nil
      expect(ur.variant).to eq("UR")
      expect(PlayerCard.find_by(card_seq: 401).variant).to be_nil
    end

    it "背番号・打撃表が同じ旧行の候補が複数なら当てず、新規作成して ambiguous をレポートに出す" do
      p1 = create(:player, name: "二枚持ち")
      legacy(p1, variant: "A", macro: "7")
      legacy(p1, variant: "B", macro: "7")
      write_all([ card_row(seq: 800, name: "二枚持ち", variant: "C", base: "二枚持ち", macro: "7") ])
      importer, = run_import
      expect(PlayerCard.count).to eq(3)
      expect(importer.report.map { |r| r["kind"] }).to include("ambiguous")
    end
  end

  describe "card_seq が鍵になる" do
    it "2 回目は card_seq で当たる。持ち主の名前や variant が変わっても同じ行を更新する（在籍が無い時）" do
      a = create(:player, name: "元の名前")
      old = legacy(a, macro: "7")
      write_all([ card_row(seq: 10, name: "元の名前", macro: "7") ])
      run_import
      expect(old.reload.card_seq).to eq(10)
      write_all([ card_row(seq: 10, name: "全く別の人", macro: "8", table: [ [ "K", "K", "K", "K" ] ]) ])
      expect { run_import }.to change(Player, :count).by(1)
      expect(PlayerCard.count).to eq(1)
      expect(old.reload.player.name).to eq("全く別の人")
      expect(old.irc_macro_name).to eq("8")
    end

    it "在籍のある行の持ち主・種別・背番号が CSV と食い違う時は、更新せず conflict として止める" do
      a = create(:player, name: "在籍あり")
      old = legacy(a, macro: "7")
      write_all([ card_row(seq: 10, name: "在籍あり", macro: "7") ])
      run_import
      member(old)
      write_all([ card_row(seq: 10, name: "在籍あり", type: "pitcher", macro: "7") ])
      importer, out = run_import
      expect(old.reload.card_type).to eq("batter")
      expect(importer.report.map { |r| r["kind"] }).to include("conflict")
      expect(out).to include("referenced")
    end

    it "card_seq が別のカードセットの行に付いている時は更新せず conflict" do
      other_set = create(:card_set, name: "別セット")
      a = create(:player, name: "誰か")
      pc = create(:player_card, card_set: other_set, player: a, card_seq: 10)
      write_all([ card_row(seq: 10, name: "誰か") ])
      importer, = run_import
      expect(pc.reload.card_set_id).to eq(other_set.id)
      expect(importer.report.map { |r| r["kind"] }).to include("conflict")
    end

    it "CSV の card_seq は一意（DB の一意 index）" do
      a = create(:player)
      create(:player_card, player: a, card_seq: 5)
      expect { create(:player_card, card_seq: 5) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "中身の更新と子の行の同期" do
    let!(:trait) { TraitDefinition.find_or_create_by!(name: "対右") { |t| t.description = "t" } }
    let!(:trait2) { TraitDefinition.find_or_create_by!(name: "対左") { |t| t.description = "t" } }
    let(:player) { create(:player, name: "更新される人") }

    it "既存カードの打撃表・走力・特徴欄が CSV に合う" do
      old = legacy(player, speed: 1, unique_traits: "古い")
      write_all([ card_row(seq: 20, name: "更新される人", speed: "5", unique_traits: "新しい", batting_table: [ [ "K", "K", "K", "K" ] ].to_json) ])
      run_import
      expect([ old.reload.speed, old.unique_traits, old.batting_table ]).to eq([ 5, "新しい", [ [ "K", "K", "K", "K" ] ] ])
    end

    it "子の行は CSV と同じ集合になる: 旧行（CSV に無い守備・特徴）は消え、重なる旧行は 1 本に、CSV の行は足される" do
      old = legacy(player)
      d_keep = old.player_card_defenses.create!(position: "SS", range_value: 3, error_rank: "C")
      old.player_card_defenses.create!(position: "OF", range_value: 1, error_rank: "E") # CSV に無い
      t_keep = old.player_card_traits.create!(trait_definition: trait, sort_order: 0)
      old.player_card_traits.create!(trait_definition: trait2, sort_order: 1) # CSV に無い
      write_all([ card_row(seq: 30, name: "更新される人") ],
                defenses: [ { "card_seq" => "30", "position" => "SS", "range_value" => "4", "error_rank" => "B" }, { "card_seq" => "30", "position" => "2B", "range_value" => "2", "error_rank" => "A" } ],
                traits: [ { "card_seq" => "30", "trait_definition_name" => "対右", "sort_order" => "0" } ])
      importer, = run_import
      expect(old.player_card_defenses.reload.pluck(:position, :range_value, :error_rank)).to match_array([ [ "SS", 4, "B" ], [ "2B", 2, "A" ] ])
      expect(old.player_card_defenses.find_by(position: "SS").id).to eq(d_keep.id) # 残る行の id は変わらない
      expect(old.player_card_traits.reload.pluck(:trait_definition_id)).to eq([ trait.id ])
      expect(old.player_card_traits.first.id).to eq(t_keep.id)
      expect(importer.report.count { |r| r["kind"] == "child_removed" }).to eq(2)
    end

    it "CSV の語彙が引けない行（WARN）がある種別は、足りない行を足すだけで旧行を消さない（master_traits 未適用でも既存を失わない）" do
      old = legacy(player)
      old.player_card_traits.create!(trait_definition: trait, sort_order: 0)
      write_all([ card_row(seq: 40, name: "更新される人") ],
                traits: [ { "card_seq" => "40", "trait_definition_name" => "存在しない特徴", "sort_order" => "0" } ])
      run_import
      expect(old.player_card_traits.reload.pluck(:trait_definition_id)).to eq([ trait.id ])
    end
  end

  describe "条件名が引けない行（cmd_1899）" do
    let!(:trait) { TraitDefinition.find_or_create_by!(name: "対右") { |t| t.description = "t" } }
    let!(:ability) { AbilityDefinition.find_or_create_by!(name: "能力A") }
    let!(:cond) { TraitCondition.find_or_create_by!(name: "旧条件") }
    let(:player) { create(:player, name: "条件の人") }

    it "特徴: 条件名が引けない行は WARN を出し、条件なしの行として足さず、その種別の旧行（条件つき）を消さない" do
      old = legacy(player)
      t_old = old.player_card_traits.create!(trait_definition: trait, condition: cond, sort_order: 0)
      write_all([ card_row(seq: 80, name: "条件の人") ],
                traits: [ { "card_seq" => "80", "trait_definition_name" => "対右", "condition_name" => "未登録条件", "sort_order" => "0" } ])
      importer, out = run_import
      expect(out).to match(/WARN:.*未登録条件/)
      expect(old.player_card_traits.reload.map { |t| [ t.id, t.condition_id ] }).to eq([ [ t_old.id, cond.id ] ])
      expect(importer.report.map { |r| r["kind"] }).not_to include("child_removed", "child_added")
    end

    it "能力: 条件名が引けない行は WARN を出し、その種別の旧行を消さない" do
      old = legacy(player)
      a_old = old.player_card_abilities.create!(ability_definition: ability, condition: cond, sort_order: 0)
      write_all([ card_row(seq: 81, name: "条件の人") ],
                abilities: [ { "card_seq" => "81", "ability_definition_name" => "能力A", "condition_name" => "未登録条件", "sort_order" => "0" } ])
      importer, out = run_import
      expect(out).to match(/WARN:.*未登録条件/)
      expect(old.player_card_abilities.reload.map { |t| [ t.id, t.condition_id ] }).to eq([ [ a_old.id, cond.id ] ])
      expect(importer.report.map { |r| r["kind"] }).not_to include("child_removed", "child_added")
    end

    it "条件名が空の行は従来どおり条件なしの行になる（WARN なし）" do
      old = legacy(player)
      write_all([ card_row(seq: 82, name: "条件の人") ],
                traits: [ { "card_seq" => "82", "trait_definition_name" => "対右", "sort_order" => "0" } ])
      _, out = run_import
      expect(out).not_to include("WARN")
      expect(old.player_card_traits.reload.pluck(:trait_definition_id, :condition_id)).to eq([ [ trait.id, nil ] ])
    end
  end

  describe "参照数に team_membership_changes を含める（cmd_1899）" do
    it "変更履歴だけが参照するカードは、持ち主・種別が CSV と違う時に conflict で更新せず飛ばす" do
      ibuki = create(:player, name: "履歴だけの人")
      old = legacy(ibuki, type: "batter", macro: "T8", card_seq: 500)
      create(:team_membership_change, player_card: old)
      expect(TeamMembership.where(player_card_id: old.id)).to be_empty
      write_all([ card_row(seq: 500, name: "履歴だけの人", type: "pitcher", macro: "T8") ])
      importer, = run_import
      expect(old.reload.card_type).to eq("batter")
      expect(importer.report.map { |r| r["kind"] }).to include("conflict")
    end
  end

  describe "macro 照合の行は子の行も触らない（cmd_1899）" do
    it "別名の旧行に結び付いても、その旧行の守備・特徴は CSV の別 Player の行で書き換わらない" do
      trait = TraitDefinition.find_or_create_by!(name: "対右") { |t| t.description = "t" }
      owner = create(:player, name: "旧行の持ち主")
      old = legacy(owner, macro: "9", table: [ [ "K", "K", "K", "K" ] ])
      d = old.player_card_defenses.create!(position: "SS", range_value: 3, error_rank: "C")
      t = old.player_card_traits.create!(trait_definition: trait, sort_order: 0)
      write_all([ card_row(seq: 600, name: "別名の人", macro: "9") ],
                defenses: [ { "card_seq" => "600", "position" => "2B", "range_value" => "2", "error_rank" => "A" } ])
      importer, = run_import
      expect(importer.report.find { |r| r["kind"] == "matched" && r["tier"] == :macro }).to be_present
      expect(old.player_card_defenses.reload.pluck(:id, :position, :range_value)).to eq([ [ d.id, "SS", 3 ] ])
      expect(old.player_card_traits.reload.pluck(:id)).to eq([ t.id ])
      expect(importer.report.map { |r| r["kind"] }).not_to include("orphan_card") # 旧行は照合済みなので orphan に数えない
    end
  end

  describe "カードなし Player を作らない" do
    it "variant つきの行は基の Player に付け、「名前 (variant)」の Player を先に作らない" do
      create(:player, name: "八雲 紫")
      write_all([ card_row(seq: 50, name: "八雲 紫 (飯能)", variant: "飯能", base: "八雲 紫", macro: "18") ])
      expect { run_import }.not_to change(Player, :count)
      expect(Player.left_joins(:player_cards).where(player_cards: { id: nil })).to be_empty
    end

    it "基の Player が見つからない時だけ、行の名前の Player を作り、そのカードを付ける" do
      write_all([ card_row(seq: 51, name: "未知 (版)", variant: "版", base: "未知") ])
      run_import
      expect(Player.find_by(name: "未知 (版)").player_cards.count).to eq(1)
      expect(Player.count).to eq(1)
    end

    it "名前に不可視文字（左→右マーク）が混じる既存の Player にも当たる（本番の 爾子田 里乃）" do
      p = create(:player, name: "‎爾子田 ‎里乃")
      old = legacy(p, type: "pitcher", macro: "121")
      write_all([ card_row(seq: 66, name: "爾子田 里乃", type: "pitcher", macro: "121", source: "PM2026") ])
      expect { run_import }.not_to change { [ Player.count, PlayerCard.count ] }
      expect(old.reload.card_seq).to eq(66)
    end
  end

  describe "冪等と dry-run" do
    it "2 回流すと 2 回目は全行 matched で、更新・追加・削除が 0 件（updated_at も変わらない）" do
      a = create(:player, name: "冪等さん")
      old = legacy(a)
      old.player_card_defenses.create!(position: "SS", range_value: 3, error_rank: "C")
      write_all([ card_row(seq: 60, name: "冪等さん", speed: "4"), card_row(seq: 61, name: "新人", macro: "61", table: [ [ "K", "K", "K", "K" ] ]) ],
                defenses: [ { "card_seq" => "61", "position" => "C", "range_value" => "2", "error_rank" => "B" } ])
      run_import
      stamps = [ PlayerCard, PlayerCardDefense, Player ].map { |m| m.order(:id).pluck(:id, :updated_at) }
      importer, = run_import
      kinds = importer.report.map { |r| r["kind"] }.tally
      expect(kinds).to eq("matched" => 2)
      expect([ PlayerCard, PlayerCardDefense, Player ].map { |m| m.order(:id).pluck(:id, :updated_at) }).to eq(stamps)
    end

    it "dry-run は DB を 1 行も変えず、実適用と同じレポート（どの旧行をどう変えたか）を CSV に出す" do
      a = create(:player, name: "dry さん")
      old = legacy(a, speed: 1)
      write_all([ card_row(seq: 70, name: "dry さん", speed: "5"), card_row(seq: 71, name: "新規", macro: "71", table: [ [ "K", "K", "K", "K" ] ]) ])
      path = File.join(dir, "report.csv")
      before = [ PlayerCard.count, Player.count, old.reload.attributes ]
      importer, out = run_import(dry_run: true, report_path: path)
      expect([ PlayerCard.count, Player.count, old.reload.attributes ]).to eq(before)
      expect(out).to include("DRY RUN")
      report = CSV.read(path, headers: true)
      changed = report.find { |r| r["kind"] == "matched_changed" }
      expect([ changed["player_card_id"].to_i, changed["card_seq"], changed["detail"] ]).to eq([ old.id, "70", "speed: 1 -> 5 | handedness: null -> right_throw/right_bat" ])
      expect(report.map { |r| r["kind"] }).to include("created")
      expect(importer.report.size).to eq(report.size)
    end
  end

  describe "rake" do
    before { Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data") }

    it "CARD_DATA_DIR の既定は db/import（thbig-irc-parser の古い CSV ではない）" do
      ENV.delete("CARD_DATA_DIR")
      captured = nil
      fake = instance_double(described_class, run: nil)
      allow(described_class).to receive(:new) { |**kw| captured = kw; fake }
      Rake::Task["import:card_data"].reenable
      Rake::Task["import:card_data"].invoke
      expect(captured[:data_dir]).to eq(Rails.root.join("db/import").to_s)
    end

    describe "import:orphan_players" do
      def run_task(apply)
        ENV["APPLY"] = apply ? "1" : nil
        Rake::Task["import:orphan_players"].reenable
        out = StringIO.new
        orig = $stdout
        $stdout = out
        Rake::Task["import:orphan_players"].invoke
        out.string
      ensure
        $stdout = orig
        ENV.delete("APPLY")
      end

      it "既定は dry-run で何も消さず、APPLY=1 でカード・在籍・コストの参照が無い Player だけを消す" do
        empty = create(:player, name: "空の人")
        with_card = create(:player, name: "カードの人")
        legacy(with_card)
        mem_player = create(:player, name: "在籍だけの人")
        create(:team_membership, player: mem_player)
        out = run_task(false)
        expect(out).to include("DRY-RUN").and include("空の人")
        expect(Player.where(id: empty.id)).to exist
        run_task(true)
        expect(Player.where(id: empty.id)).not_to exist
        expect(Player.where(id: [ with_card.id, mem_player.id ]).count).to eq(2)
      end

      it "JSON の保存形ごとに、そこにだけ出る Player を消さない: *_ids の配列・入れ子の配列・全体が配列（cmd_1899 再レビュー）" do
        relief, starter_bench, nested, top_array, off, gone = %w[リリーフ 先発ベンチ 入れ子 全体配列 オフ 出ない人].map { |n| create(:player, name: "JSON #{n}") }
        team = create(:team)
        GameLineup.create!(team: team, lineup_data: {
          "dh_enabled" => true, "starting_lineup" => [ { "batting_order" => 1, "player_id" => 900_001, "position" => "RF" } ],
          "bench_players" => [ { "player_id" => nested.id, "position" => "C" } ], "off_players" => [ { "player_id" => off.id } ],
          "relief_pitcher_ids" => [ relief.id ], "starter_bench_pitcher_ids" => [ starter_bench.id ]
        })
        sched = create(:season_schedule)
        sched.update_columns(opponent_starting_lineup: [ { "batting_order" => 1, "player_id" => top_array.id, "position" => "SS" } ])
        run_task(true)
        expect(Player.where(id: [ relief.id, starter_bench.id, nested.id, off.id, top_array.id ]).count).to eq(5)
        expect(Player.where(id: gone.id)).not_to exist
      end

      it "player 系でないキーの整数（batting_order・dh_enabled 以外の数値）では Player を消さない側に倒さない（取りすぎを限定する）" do
        other = create(:player, name: "順番と同じ id の人")
        team = create(:team)
        GameLineup.create!(team: team, lineup_data: { "starting_lineup" => [ { "batting_order" => other.id, "player_id" => 900_001, "position" => "RF" } ] })
        run_task(true)
        expect(Player.where(id: other.id)).not_to exist
      end

      it "JSON の中にだけ出てくる Player（id でも名前でも）は消さない（cmd_1899）" do
        by_id = create(:player, name: "JSON id の人")
        by_name = create(:player, name: "JSON 名前の人")
        empty = create(:player, name: "どこにも出ない人")
        sched = create(:season_schedule)
        sched.update_columns(starting_lineup: [ { "player_id" => by_id.id, "position" => "SS", "order" => 1 } ],
                             scoreboard: { "pitcher" => "JSON 名前の人" })
        out = run_task(true)
        expect(out).to include("JSON の中に出てくる Player: 2 人")
        expect(Player.where(id: [ by_id.id, by_name.id ]).count).to eq(2)
        expect(Player.where(id: empty.id)).not_to exist
      end
    end
  end
end
