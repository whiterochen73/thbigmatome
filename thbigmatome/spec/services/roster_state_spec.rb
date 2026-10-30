require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §4.1（時点 = 日付 + 区分）・§4.3（RosterState.at）・末尾の追記（同区分の連続記録は畳む）、
# 裁定台帳 AMB-24（昇降格は日による制限なし。クールダウン 10 日だけ）
RSpec.describe RosterState do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team, current_date: Date.new(2026, 5, 15)) }
  let!(:membership) { create(:team_membership, team: team, squad: "second") }

  def record(squad, on, phase: "pre_game", tm: membership, created_at: nil)
    attrs = { season: season, team_membership: tm, squad: squad, registered_on: on, phase: phase }
    attrs[:created_at] = created_at if created_at
    create(:season_roster, **attrs)
  end

  def squad_at(date, phase = "pre_game", tm: membership)
    described_class.at(team, Date.parse(date), phase).fetch(tm.id).squad
  end

  def cooldown_at(date, phase = "pre_game")
    described_class.at(team, Date.parse(date), phase).fetch(membership.id)
  end

  describe ".at の時点の境界" do
    it "記録が無い選手は 2軍（写しが first でも倒さない）" do
      membership.update!(squad: "first")
      expect(squad_at("2026-05-01")).to eq("second")
    end

    it "試合前の記録は、その日の試合前から効く。前日の試合後はまだ効かない" do
      record("first", Date.new(2026, 5, 10))
      expect(squad_at("2026-05-09", "post_game")).to eq("second")
      expect(squad_at("2026-05-10", "pre_game")).to eq("first")
      expect(squad_at("2026-05-10", "in_game")).to eq("first")
      expect(squad_at("2026-05-10", "post_game")).to eq("first")
    end

    it "試合後の記録は、同じ日の試合前・試合中にはまだ効かず、試合後から効く" do
      record("first", Date.new(2026, 5, 10), phase: "post_game")
      expect(squad_at("2026-05-10", "pre_game")).to eq("second")
      expect(squad_at("2026-05-10", "in_game")).to eq("second")
      expect(squad_at("2026-05-10", "post_game")).to eq("first")
      expect(squad_at("2026-05-11", "pre_game")).to eq("first")
    end

    it "同じ日の試合前に昇格して試合後に抹消すると、区分で状態が分かれる" do
      record("first", Date.new(2026, 5, 10), phase: "pre_game")
      record("second", Date.new(2026, 5, 10), phase: "post_game")
      expect(squad_at("2026-05-10", "pre_game")).to eq("first")
      expect(squad_at("2026-05-10", "post_game")).to eq("second")
    end

    it "同じ時点の記録は作成順（後に作ったものが勝つ）" do
      record("first", Date.new(2026, 5, 10), created_at: Time.zone.parse("2026-05-10 09:00"))
      record("second", Date.new(2026, 5, 10), created_at: Time.zone.parse("2026-05-10 09:01"))
      expect(squad_at("2026-05-10")).to eq("second")
    end

    it "作成順が日付順と逆（過去日に後から差し込み）でも、日付順に畳む" do
      record("first", Date.new(2026, 5, 10))
      record("second", Date.new(2026, 5, 1)) # 後から差し込んだ過去日の記録
      expect(squad_at("2026-05-05")).to eq("second")
      expect(squad_at("2026-05-10")).to eq("first")
    end

    it "区分を省略すると pre_game として読む" do
      record("first", Date.new(2026, 5, 10), phase: "post_game")
      expect(described_class.at(team, Date.new(2026, 5, 10)).fetch(membership.id).squad).to eq("second")
    end

    it "不正な区分は ArgumentError" do
      expect { described_class.at(team, Date.new(2026, 5, 10), "midnight") }.to raise_error(ArgumentError, /invalid phase/)
      expect { described_class.parse_phase("midnight") }.to raise_error(ArgumentError)
      expect(described_class.parse_phase(nil)).to eq("pre_game")
      expect(described_class.parse_phase("")).to eq("pre_game")
      expect(described_class.parse_phase("post_game")).to eq("post_game")
    end

    it "選手ごとに独立して導く" do
      other = create(:team_membership, team: team, squad: "second")
      record("first", Date.new(2026, 5, 10))
      expect(squad_at("2026-05-10")).to eq("first")
      expect(squad_at("2026-05-10", tm: other)).to eq("second")
    end
  end

  describe "同区分の連続記録は畳む" do
    it "連続する first は最初の 1 件だけ残す（昇格日は最初の記録）" do
      record("first", Date.new(2026, 4, 1))
      record("first", Date.new(2026, 4, 5))
      record("second", Date.new(2026, 5, 1))
      records = described_class.new(team).collapsed_records(membership.id)
      expect(records.map { |r| [ r.squad, r.registered_on.to_s ] }).to eq([ [ "first", "2026-04-01" ], [ "second", "2026-05-01" ] ])
    end

    it "連続する second は最初の 1 件を降格日とする（再登録不可の終わりを後ろへ延ばさない）" do
      record("first", Date.new(2026, 4, 1))
      record("second", Date.new(2026, 5, 1))
      record("second", Date.new(2026, 5, 6)) # 状態が変わらない重複
      expect(cooldown_at("2026-05-10").cooldown_until).to eq(Date.new(2026, 5, 11))
      expect(cooldown_at("2026-05-11").cooldown_until).to be_nil
    end

    it "同日の昇格と降格は、降格より前の昇格が同じ日なら免除" do
      record("first", Date.new(2026, 5, 1), phase: "pre_game")
      record("second", Date.new(2026, 5, 1), phase: "post_game")
      info = cooldown_at("2026-05-05")
      expect(info.cooldown_until).to eq(Date.new(2026, 5, 11))
      expect(info.same_day_exempt).to be true
    end

    it "昇格が重複して前の日に打たれていると、同日の免除にならない（畳んだ昇格日で数える）" do
      record("first", Date.new(2026, 4, 30))
      record("first", Date.new(2026, 5, 1)) # 重複
      record("second", Date.new(2026, 5, 1))
      expect(cooldown_at("2026-05-05").same_day_exempt).to be false
    end
  end

  describe "クールダウン（降格から 10 日）の境界" do
    before do
      record("first", Date.new(2026, 4, 1))
      record("second", Date.new(2026, 5, 1))
    end

    it "降格から 9 日目（5/10）はまだ再登録できない" do
      info = cooldown_at("2026-05-10")
      expect(info.cooldown_until).to eq(Date.new(2026, 5, 11))
      expect(info.demotion_date).to eq(Date.new(2026, 5, 1))
      expect(info.same_day_exempt).to be false
    end

    it "降格から 10 日目（5/11）は再登録できる" do
      expect(cooldown_at("2026-05-11").cooldown_until).to be_nil
    end

    it "降格した日の試合前（降格の記録が試合後）ならまだ降格していない" do
      expect(cooldown_at("2026-04-20").cooldown_until).to be_nil
    end

    it "降格の前に昇格が無い選手（最初から 2軍）にはクールダウンが無い" do
      other = create(:team_membership, team: team, squad: "second")
      record("second", Date.new(2026, 5, 1), tm: other)
      expect(described_class.at(team, Date.new(2026, 5, 2), "pre_game").fetch(other.id).cooldown_until).to be_nil
    end
  end

  describe "#first_memberships / #latest_squads / #record_points" do
    it "時点の 1軍だけを返す" do
      other = create(:team_membership, team: team, squad: "second")
      record("first", Date.new(2026, 5, 10))
      state = described_class.new(team)
      expect(state.first_memberships(Date.new(2026, 5, 10)).map(&:id)).to eq([ membership.id ])
      expect(state.first_memberships(Date.new(2026, 5, 9))).to be_empty
      expect(state.first_memberships(Date.new(2026, 5, 10), "post_game").map(&:id)).not_to include(other.id)
    end

    it "latest_squads は日付・区分を問わず最後の記録。記録の無い選手は second" do
      other = create(:team_membership, team: team, squad: "first")
      record("first", Date.new(2026, 5, 10))
      record("second", Date.new(2026, 6, 20)) # 現在日カーソル(5/15)より後の日付
      record("first", Date.new(2026, 5, 20), tm: other)
      state = described_class.new(team)
      expect(state.latest_squads).to eq(membership.id => "second", other.id => "first")
    end

    it "record_points は重複なしの日付・区分の昇順" do
      record("first", Date.new(2026, 5, 10), phase: "post_game")
      record("second", Date.new(2026, 5, 10), phase: "pre_game")
      record("first", Date.new(2026, 5, 3))
      points = described_class.new(team).record_points
      expect(points).to eq([ [ Date.new(2026, 5, 3), "pre_game" ], [ Date.new(2026, 5, 10), "pre_game" ], [ Date.new(2026, 5, 10), "post_game" ] ])
    end
  end

  describe "#rebuild_squad_cache!" do
    it "写しを最新の変更記録に合わせ、変わった行だけ返す" do
      other = create(:team_membership, team: team, squad: "first") # 記録が無いのに first
      same = create(:team_membership, team: team, squad: "first")
      record("first", Date.new(2026, 5, 10))
      record("first", Date.new(2026, 4, 1), tm: same)
      changed = described_class.rebuild_squad_cache!(team)
      expect(changed.map { |tm, old, new| [ tm.id, old, new ] }).to contain_exactly([ membership.id, "second", "first" ], [ other.id, "first", "second" ])
      expect(membership.reload.squad).to eq("first")
      expect(other.reload.squad).to eq("second")
      expect(same.reload.squad).to eq("first")
    end
  end

  describe "#cooldown_violations" do
    it "降格から 9 日後の昇格は違反、10 日後は違反でない" do
      record("first", Date.new(2026, 4, 1))
      record("second", Date.new(2026, 5, 1))
      record("first", Date.new(2026, 5, 10))
      violations = described_class.new(team).cooldown_violations
      expect(violations.keys).to eq([ [ membership.id, Date.new(2026, 5, 10), "pre_game" ] ])
      expect(violations.values.first).to include(days_short: 1, demotion_date: Date.new(2026, 5, 1))

      other = create(:team_membership, team: team, squad: "second")
      record("first", Date.new(2026, 4, 1), tm: other)
      record("second", Date.new(2026, 5, 1), tm: other)
      record("first", Date.new(2026, 5, 11), tm: other)
      expect(described_class.new(team).cooldown_violations.keys.map(&:first)).to eq([ membership.id ])
    end

    it "同日の昇降格のあとの昇格は免除。重複した昇格は畳むので免除にならない" do
      record("first", Date.new(2026, 5, 1))
      record("second", Date.new(2026, 5, 1), phase: "post_game")
      record("first", Date.new(2026, 5, 3))
      expect(described_class.new(team).cooldown_violations).to be_empty

      record("first", Date.new(2026, 4, 1)) # 過去日に昇格を差し込むと、5/3 の昇格が違反になる
      expect(described_class.new(team).cooldown_violations.keys).to eq([ [ membership.id, Date.new(2026, 5, 3), "pre_game" ] ])
    end
  end
end
