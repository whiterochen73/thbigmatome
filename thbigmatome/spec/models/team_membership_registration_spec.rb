require "rails_helper"

# 選手の登録（所属の作成・カードの付け替え）の制限（cmd_1893/subtask_1893e）。
# Test Basis: Operator 裁定（2026-11-14）
#   1. 登録できるのは現行カードセットのカードだけ。公式戦使用不可（official_use_prohibited）も選べない
#   2. 既存の所属は消さない・書き換えない（現行外のカードを持つ既存の所属はそのまま保存できる）
#   3. 同キャラ（Player.character_key が同じ）は同じチームに 2 枚入れられない。数字の添え字は別人
# 規則は誰にでも適用する（コミッショナーも）。裁定に例外が無いため。
RSpec.describe "TeamMembership の登録の制限" do
  around { |example| I18n.with_locale(:ja) { example.run } }

  let(:team) { create(:team) }
  let(:current_set) { create(:card_set) }
  let(:old_set) { create(:card_set, is_current: false) }

  def card(player, set, **attrs) = create(:player_card, player: player, card_set: set, **attrs)

  describe "カードの制限" do
    let(:player) { create(:player) }

    it "現行セットの公式戦で使えるカードは登録できる" do
      expect(TeamMembership.new(team: team, player: player, player_card: card(player, current_set))).to be_valid
    end

    it "カードを付けない登録は受ける（既存の使い方）" do
      expect(TeamMembership.new(team: team, player: player)).to be_valid
    end

    it "現行外のセットのカードは新規登録できない" do
      tm = TeamMembership.new(team: team, player: player, player_card: card(player, old_set))
      expect(tm).not_to be_valid
      expect(tm.errors[:base]).to be_present
    end

    it "公式戦使用不可のカードは新規登録できない（現行セットでも）" do
      tm = TeamMembership.new(team: team, player: player, player_card: card(player, current_set, official_use_prohibited: true))
      expect(tm).not_to be_valid
      expect(tm.errors[:base]).to be_present
    end

    it "コミッショナーの経路（skip_commissioner_validation）でも拒む" do
      tm = TeamMembership.new(team: team, player: player, player_card: card(player, old_set))
      tm.skip_commissioner_validation = true
      expect(tm).not_to be_valid
    end

    it "既存の所属が現行外のカードを持っていても、ほかの値の保存は通る（カードが変わらなければ検査しない）" do
      old_card = card(player, old_set)
      tm = create(:team_membership, team: team, player: player)
      tm.update_columns(player_card_id: old_card.id)
      tm.reload
      tm.selected_cost_type = "normal_cost"
      tm.display_name = "表示名"
      expect(tm).to be_valid
      expect(tm.save).to be(true)
    end

    it "既存の所属のカードを現行外のカードへ替えることは拒む" do
      tm = create(:team_membership, team: team, player: player, player_card: card(player, current_set))
      tm.player_card = card(player, old_set, card_type: "pitcher")
      expect(tm).not_to be_valid
    end

    it "既存の所属のカードを現行のカードへ替えることは通る" do
      old_card = card(player, old_set)
      tm = create(:team_membership, team: team, player: player)
      tm.update_columns(player_card_id: old_card.id)
      tm.reload.player_card = card(player, current_set, card_type: "pitcher")
      expect(tm).to be_valid
    end
  end

  describe "同キャラの制限" do
    def member(team, name)
      create(:team_membership, team: team, player: create(:player, name: name))
    end

    def new_membership(team, name)
      TeamMembership.new(team: team, player: Player.find_by(name: name) || create(:player, name: name))
    end

    it "冴月 麟 (投手) の居るチームに 冴月 麟 (野手) は入れられない（別の Player でも同キャラ）" do
      member(team, "冴月 麟 (投手)")
      tm = new_membership(team, "冴月 麟 (野手)")
      expect(tm).not_to be_valid
      expect(tm.errors[:base]).to be_present
    end

    it "八雲 紫 の居るチームに 八雲 紫 (エイプリル) は入れられない" do
      member(team, "八雲 紫")
      expect(new_membership(team, "八雲 紫 (エイプリル)")).not_to be_valid
    end

    it "Aal の居るチームに Aal (2) は入れられる（数字の添え字は別人）" do
      member(team, "Aal")
      expect(new_membership(team, "Aal (2)")).to be_valid
    end

    it "別のチームなら同キャラでも入れられる" do
      member(create(:team), "冴月 麟 (投手)")
      expect(new_membership(team, "冴月 麟 (野手)")).to be_valid
    end

    it "放出済み（on_team: false）の同キャラは数えない" do
      tm = member(team, "冴月 麟 (投手)")
      tm.update_columns(on_team: false)
      expect(new_membership(team, "冴月 麟 (野手)")).to be_valid
    end

    it "すでに同キャラが 2 人入っているチームの既存の所属は、そのまま保存できる（新しく入れる時だけ拒む）" do
      a = member(team, "冴月 麟 (投手)")
      b = TeamMembership.new(team: team, player: create(:player, name: "冴月 麟 (野手)"), squad: "second", selected_cost_type: "normal_cost")
      b.save!(validate: false)
      a.reload.display_name = "x"
      expect(a).to be_valid
      expect(b.reload).to be_valid
    end

    it "コミッショナーの経路でも拒む" do
      member(team, "冴月 麟 (投手)")
      tm = new_membership(team, "冴月 麟 (野手)")
      tm.skip_commissioner_validation = true
      expect(tm).not_to be_valid
    end
  end
end
