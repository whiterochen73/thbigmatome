require "rails_helper"

RSpec.describe RosterChangeService, type: :service do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }
  let(:since_date) { Date.new(2025, 6, 1) }

  def create_membership_with_player(name: "選手", number: "10")
    player = create(:player, name: name, number: number)
    create(:team_membership, team: team, player: player, squad: "first")
  end

  describe "#call" do
    context "変更なしの場合" do
      it "空配列とempty textを返す" do
        result = described_class.new(team, season.id, since_date).call
        expect(result[:changes]).to be_empty
        expect(result[:text]).to eq("")
      end
    end

    context "since以前の変更は含まれない" do
      it "registered_on <= since_dateのレコードを除外する" do
        tm = create_membership_with_player(name: "古い選手", number: "99")
        create(:season_roster, team_membership: tm, season: season, squad: "first", registered_on: since_date)
        result = described_class.new(team, season.id, since_date).call
        expect(result[:changes]).to be_empty
      end
    end

    context "promoteが検出される場合 (squad='first')" do
      it "typeがpromoteのchangeを返す" do
        tm = create_membership_with_player(name: "ユキ", number: "78")
        create(:season_roster, team_membership: tm, season: season, squad: "first",
               registered_on: since_date + 3)
        result = described_class.new(team, season.id, since_date).call
        expect(result[:changes].length).to eq(1)
        change = result[:changes].first
        expect(change[:type]).to eq("promote")
        expect(change[:player_name]).to eq("ユキ")
        expect(change[:number]).to eq("78")
      end

      it "textに「登録：」を含む" do
        tm = create_membership_with_player(name: "ユキ", number: "78")
        create(:season_roster, team_membership: tm, season: season, squad: "first",
               registered_on: since_date + 3)
        result = described_class.new(team, season.id, since_date).call
        expect(result[:text]).to include("登録：78 ユキ")
      end
    end

    context "demoteが検出される場合 (squad='second')" do
      it "typeがdemoteのchangeを返す" do
        tm = create_membership_with_player(name: "エタニティラルバ", number: "107")
        create(:season_roster, team_membership: tm, season: season, squad: "second",
               registered_on: since_date + 3)
        result = described_class.new(team, season.id, since_date).call
        expect(result[:changes].length).to eq(1)
        change = result[:changes].first
        expect(change[:type]).to eq("demote")
        expect(change[:player_name]).to eq("エタニティラルバ")
      end

      it "textに「抹消：」を含む" do
        tm = create_membership_with_player(name: "エタニティラルバ", number: "107")
        create(:season_roster, team_membership: tm, season: season, squad: "second",
               registered_on: since_date + 3)
        result = described_class.new(team, season.id, since_date).call
        expect(result[:text]).to include("抹消：107 エタニティラルバ")
      end
    end

    context "promote + demote両方ある場合" do
      it "登録が先に表示される" do
        tm_promote = create_membership_with_player(name: "ユキ", number: "78")
        tm_demote  = create_membership_with_player(name: "エタニティラルバ", number: "107")
        create(:season_roster, team_membership: tm_promote, season: season, squad: "first",
               registered_on: since_date + 3)
        create(:season_roster, team_membership: tm_demote, season: season, squad: "second",
               registered_on: since_date + 3)

        result = described_class.new(team, season.id, since_date).call
        expect(result[:changes].length).to eq(2)
        lines = result[:text].split("\n")
        expect(lines.first).to start_with("登録：")
        expect(lines.last).to start_with("抹消：")
      end
    end

    context "別チームの変更は含まれない" do
      it "他チームのseason_rostersをスキップする" do
        other_team = create(:team)
        other_player = create(:player, name: "他チーム選手", number: "1")
        other_tm = create(:team_membership, team: other_team, player: other_player, squad: "first")
        create(:season_roster, team_membership: other_tm, season: season, squad: "first",
               registered_on: since_date + 1)

        result = described_class.new(team, season.id, since_date).call
        expect(result[:changes]).to be_empty
      end
    end

    context "since_dateが文字列の場合" do
      it "正しくパースして処理する" do
        tm = create_membership_with_player(name: "ユキ", number: "78")
        create(:season_roster, team_membership: tm, season: season, squad: "first",
               registered_on: since_date + 1)
        result = described_class.new(team, season.id, "2025-06-01").call
        expect(result[:changes].length).to eq(1)
      end
    end
  end
end
