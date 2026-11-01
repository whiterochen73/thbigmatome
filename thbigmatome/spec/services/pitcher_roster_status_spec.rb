require "rails_helper"

# Test Basis: cmd_1784 段3。設計書 §1.3 S7・§4.4 の 6・§7 判断 5（1軍でない投手の登板は警告して保存する）。
# 時点は（試合日, in_game）。同日の試合前の公示は含み、試合後の公示は含まない。
# 境界: 記録が無い投手（2軍）・移動日に登録された投手・放出→再登録の投手・登録前・チームの登録が無い投手。
RSpec.describe PitcherRosterStatus, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let(:membership) { TeamMembership.find_by!(team: team, player: pitcher) }

  def roster(squad, on, phase: "pre_game")
    create(:season_roster, season: season, team_membership: membership, squad: squad, registered_on: on, phase: phase)
  end

  def change(kind, on, phase: "pre_game")
    create(:team_membership_change, team_membership: membership, season: season, kind: kind, effective_on: on, phase: phase)
  end

  def status_on(date)
    described_class.for(team: team, date: Date.parse(date), pitcher_ids: [ pitcher.id ])[pitcher.id]
  end

  it "昇降格の記録が無い投手は 2軍" do
    expect(status_on("2026-06-10")).to eq("second")
  end

  it "1軍の記録（試合前）があれば、その日の試合中は 1軍" do
    roster("first", Date.new(2026, 6, 10))
    expect(status_on("2026-06-10")).to eq("first")
    expect(status_on("2026-06-09")).to eq("second")
  end

  it "移動日に登録した投手は、翌日の試合では 1軍" do
    create(:season_schedule, season: season, date: "2026-06-09", date_type: "travel_day")
    roster("first", Date.new(2026, 6, 9))
    expect(status_on("2026-06-10")).to eq("first")
  end

  it "試合後の抹消（post_game）は、その日の試合中の登板に影響しない" do
    roster("first", Date.new(2026, 6, 1))
    roster("second", Date.new(2026, 6, 10), phase: "post_game")
    expect(status_on("2026-06-10")).to eq("first")
    expect(status_on("2026-06-11")).to eq("second")
  end

  it "試合中（in_game）の昇格は、その日の試合中の登板から 1軍として数える（時点は in_game）" do
    roster("first", Date.new(2026, 6, 10), phase: "in_game")
    expect(status_on("2026-06-10")).to eq("first")
    expect(status_on("2026-06-09")).to eq("second")
  end

  it "試合前の抹消（pre_game）は、その日の試合中の登板に影響する" do
    roster("first", Date.new(2026, 6, 1))
    roster("second", Date.new(2026, 6, 10), phase: "pre_game")
    expect(status_on("2026-06-10")).to eq("second")
  end

  it "登板の翌日付けで登録した投手（日付の合わせ違い）は 2軍と出る" do
    roster("first", Date.new(2026, 6, 11))
    expect(status_on("2026-06-10")).to eq("second")
  end

  it "チーム編成の記録がある投手は、登録（join）より前の日は在籍なし" do
    change("join", Date.new(2026, 6, 5))
    roster("first", Date.new(2026, 6, 5))
    expect(status_on("2026-06-04")).to eq("not_on_team")
    expect(status_on("2026-06-05")).to eq("first")
  end

  it "放出→再登録: 放出後は在籍なし、再登録後は 2軍（放出が降格を伴うため）、昇格すれば 1軍" do
    change("join", Date.new(2026, 6, 1))
    roster("first", Date.new(2026, 6, 1))
    roster("second", Date.new(2026, 6, 10))
    change("release", Date.new(2026, 6, 10))
    change("join", Date.new(2026, 6, 15))
    expect(status_on("2026-06-09")).to eq("first")
    expect(status_on("2026-06-12")).to eq("not_on_team")
    expect(status_on("2026-06-15")).to eq("second")
    roster("first", Date.new(2026, 6, 20))
    expect(status_on("2026-06-20")).to eq("first")
  end

  it "チームの登録（team_memberships の行）が無い投手は no_membership" do
    stranger = create(:player, :pitcher)
    result = described_class.for(team: team, date: Date.new(2026, 6, 10), pitcher_ids: [ stranger.id ])
    expect(result).to eq(stranger.id => "no_membership")
  end

  it "別のチームの 1軍の記録は影響しない" do
    other_team, other_season = create_team_with_season
    other_membership = create(:team_membership, team: other_team, player: pitcher)
    create(:season_roster, season: other_season, team_membership: other_membership, squad: "first", registered_on: Date.new(2026, 6, 1))
    expect(status_on("2026-06-10")).to eq("second")
  end

  it "投手が空なら問い合わせず空のハッシュ" do
    expect(described_class.for(team: team, date: Date.new(2026, 6, 10), pitcher_ids: [])).to eq({})
    expect(described_class.for(team: team, date: Date.new(2026, 6, 10), pitcher_ids: [ nil ])).to eq({})
  end

  it "重複した ID は 1 件にまとめる" do
    roster("first", Date.new(2026, 6, 1))
    result = described_class.for(team: team, date: Date.new(2026, 6, 10), pitcher_ids: [ pitcher.id, pitcher.id ])
    expect(result).to eq(pitcher.id => "first")
  end

  describe ".off_roster?" do
    it "first 以外は要確認" do
      expect(%w[first second not_on_team no_membership].map { |s| described_class.off_roster?(s) }).to eq([ false, true, true, true ])
      expect(described_class.off_roster?(nil)).to be(false)
    end
  end

  describe ".warning_message" do
    it "名前・日付・理由を含み、保存したことを伝える" do
      message = described_class.warning_message(pitcher_name: "東風谷早苗", date: "2026-06-10", status: "second")
      expect(message).to include("東風谷早苗", "2026-06-10", "2軍", "保存しました")
    end
  end
end
