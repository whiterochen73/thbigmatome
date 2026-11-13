require "rails_helper"
require "rake"
require "csv"

# 現行カードセットの印と、同キャラの制限（cmd_1893/subtask_1893e）。rake（import:card_data）と seeds（db/seeds/import_cards.rb）の両方で確かめる。
#
# Test Basis:
#   - Operator 裁定（2026-11-14）: 現行は PM2027・2025THBIG・hachinai6.1・tamayomi2。PM2026 は現行から外れる。印は取り込みの対応表で持つ
#   - 同キャラ: 八雲 紫 と 八雲 紫（エイプリル）、冴月 麟 (投手) と (野手) は止まる。Aal と Aal (2) は別人のカードで止めない
#   - 取り込みの 2 経路は、変種を持ち主の Player に付け替える形で同じになる（rake を seeds にそろえた）
RSpec.describe "現行カードセットの印と同キャラ（取り込み）" do
  def csv_rows = @csv_rows ||= CSV.read(Rails.root.join("db/import/player_cards.csv"), headers: true)

  def run_quiet
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def member_into(team, player) = TeamMembership.new(team: team, player: player, squad: "second", selected_cost_type: "normal_cost")

  def owner_of(seq)
    row = csv_rows.find { |r| r["card_seq"] == seq.to_s }
    base = (row["base_player_name"].presence || row["name"]).gsub(/[\s　]+/, "")
    Player.find_by("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", base)
  end

  shared_examples "現行の印と同キャラ" do
    it "現行の印は PM2026 だけ外れ、ほかの 4 セットは現行" do
      expect(CardSet.pluck(:name, :is_current).to_h).to eq(
        "2025THBIG" => true, "ハチナイ6.1" => true, "PM2026" => false, "PM2027" => true, "球詠2" => true
      )
    end

    it "現行セットのカードだけが registrable（PM2026 のカードは含まれない）" do
      pm26 = CardSet.find_by(name: "PM2026")
      expect(PlayerCard.registrable.where(card_set: pm26)).to be_empty
      expect(PlayerCard.registrable.where(card_set: CardSet.find_by(name: "PM2027")).count).to eq(
        PlayerCard.where(card_set: CardSet.find_by(name: "PM2027"), official_use_prohibited: false).count
      )
      expect(PlayerCard.registrable.where(official_use_prohibited: true)).to be_empty
    end

    it "八雲 紫: エイプリル（494）・飯能（513）・筑紫野（526）のカードは同じ Player に付く（同じチームに 2 枚入れられない）" do
      yakumo = Player.find_by!(name: "八雲 紫")
      expect([ 494, 513, 526 ].map { |s| owner_of(s)&.id }.uniq).to eq([ yakumo.id ])
      team = create(:team)
      member_into(team, yakumo).save!
      # 取り込みが変種の付け替えより先に作った「八雲 紫 (エイプリル)」の Player が残っていても、同キャラとして止まる
      Player.where(name: "八雲 紫 (エイプリル)").each { |stray| expect(member_into(team, stray)).not_to be_valid }
      expect(yakumo.character_key).to eq("八雲紫")
    end

    it "冴月 麟 (投手) と (野手) は別の Player のまま、同キャラとして同じチームに入れられない" do
      p_pitcher = Player.find_by!(name: "冴月 麟 (投手)")
      p_fielder = Player.find_by!(name: "冴月 麟 (野手)")
      expect(p_pitcher.id).not_to eq(p_fielder.id)
      expect(p_pitcher.character_key).to eq(p_fielder.character_key)
      team = create(:team)
      member_into(team, p_pitcher).save!
      expect(member_into(team, p_fielder)).not_to be_valid
      expect(member_into(create(:team), p_fielder)).to be_valid
    end

    it "Aal と Aal (2) は別人のカードで、同じチームに入れられる" do
      aal = Player.find_by!(name: "Aal")
      aal2 = Player.find_by!(name: "Aal (2)")
      expect(aal.character_key).not_to eq(aal2.character_key)
      team = create(:team)
      member_into(team, aal).save!
      expect(member_into(team, aal2)).to be_valid
    end

    it "別 Player のまま残る同キャラ（鍵が同じ）は、規則どおりの 4 組だけ（冴月 麟・西行寺 幽々子・八雲 藍・川崎 稜）" do
      groups = Player.all.group_by(&:character_key).select { |_, v| v.map(&:id).size > 1 }
      # 添え字つきの名前で importer が先に作った、カードを持たない Player は数えない
      groups = groups.transform_values { |v| v.select { |pl| pl.player_cards.exists? } }.select { |_, v| v.size > 1 }
      expect(groups.keys).to match_array(%w[冴月麟 西行寺幽々子 八雲藍 川崎稜])
    end

    it "同じ取り込みをもう一度回しても、現行の印・Player・カードの数は変わらず、印の食い違いは対応表に合わせて直る" do
      counts = [ Player.count, PlayerCard.count, CardSet.count ]
      CardSet.find_by!(name: "PM2026").update_columns(is_current: true)
      CardSet.find_by!(name: "PM2027").update_columns(is_current: false)
      rerun
      expect([ Player.count, PlayerCard.count, CardSet.count ]).to eq(counts)
      expect(CardSet.find_by!(name: "PM2026").is_current).to be(false)
      expect(CardSet.find_by!(name: "PM2027").is_current).to be(true)
    end
  end

  context "rake import:card_data" do
    def rerun
      Rake::Task["import:card_data"].reenable
      run_quiet { Rake::Task["import:card_data"].invoke }
    end

    before(:all) do
      Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_data")
      ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
      load Rails.root.join("db/seeds/master_traits.rb")
      Rake::Task["import:card_data"].reenable
      original = $stdout
      $stdout = StringIO.new
      Rake::Task["import:card_data"].invoke
      $stdout = original
    end
    after(:all) do
      ENV.delete("CARD_DATA_DIR")
      DatabaseCleaner.clean_with(:truncation)
    end
    include_examples "現行の印と同キャラ"
  end

  context "db/seeds/import_cards.rb" do
    def rerun = run_quiet { load Rails.root.join("db/seeds/import_cards.rb") }

    before(:all) do
      ENV["CARD_DATA_DIR"] = Rails.root.join("db/import").to_s
      load Rails.root.join("db/seeds/master_traits.rb")
      original = $stdout
      $stdout = StringIO.new
      load Rails.root.join("db/seeds/import_cards.rb")
      $stdout = original
    end
    after(:all) do
      ENV.delete("CARD_DATA_DIR")
      DatabaseCleaner.clean_with(:truncation)
    end
    include_examples "現行の印と同キャラ"
  end
end
