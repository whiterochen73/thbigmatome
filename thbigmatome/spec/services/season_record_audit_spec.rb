require "rails_helper"

# Test Basis: context/thbig-dugout-season-record-restructure-design.md §1.3 S1・S2・S7・S8・S10・S11 / §5.1 段0 / §5.3、
# 裁定台帳 AMB-24（試合日の昇降格は違反にしない。クールダウン 10 日だけ残る）・D-11（ノーゲーム）
RSpec.describe SeasonRecordAudit, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }

  def audit(**opts) = described_class.new(**opts).call
  def found(item, **opts) = audit(**opts).findings.select { |f| f.item == item }

  def record(membership, squad, on, season: self.season, **attrs)
    create(:season_roster, season: season, team_membership: membership, squad: squad, registered_on: on, **attrs)
  end

  describe "S1: 写しと変更記録が合わない選手" do
    let!(:tm) { create(:team_membership, team: team, squad: "second") }

    it "最後の記録が写しと違えば数える（現在日カーソル時点でも違う: at_current_date）" do
      season.update!(current_date: "2026-06-30")
      record(tm, "first", "2026-05-01")
      f = found("S1")
      expect(f.size).to eq(1)
      expect(f.first).to have_attributes(category: "at_current_date", team_id: team.id, player_id: tm.player_id)
    end

    it "写しと最後の記録が同じなら数えない（境界）" do
      tm.update!(squad: "first")
      record(tm, "first", "2026-05-01")
      expect(found("S1")).to be_empty
    end

    it "記録が無い選手は数えない（写しがそのまま状態）" do
      expect(found("S1")).to be_empty
    end

    it "現在日カーソルより後の日付の記録のせいで違うだけなら future_record_only" do
      season.update!(current_date: "2026-04-01")
      record(tm, "second", "2026-03-25")
      record(tm, "first", "2026-05-01")
      expect(found("S1").map(&:category)).to eq([ "future_record_only" ])
    end

    it "過去日に差し込まれた記録で、日付の最後と作成の最後が違う場合は日付の最後を使う（ロスター画面と同じ）" do
      season.update!(current_date: "2026-06-30")
      tm.update!(squad: "second")
      record(tm, "first", "2026-05-01")
      record(tm, "second", "2026-03-25") # 後から作られたが日付は前
      expect(found("S1").size).to eq(1)
    end
  end

  describe "S2a: 日付順と逆に差し込まれた記録" do
    let!(:tm) { create(:team_membership, team: team) }

    it "後から前の日付を差し込むと、差し込んだ側と追い越された側の 2 件を数える" do
      older = record(tm, "first", "2026-05-01")
      newer = record(tm, "second", "2026-03-25")
      f = found("S2a")
      expect(f.map { |x| [ x.ref, x.category ] }).to contain_exactly([ newer.id, "inserted_later" ], [ older.id, "overtaken" ])
    end

    it "日付順に入力されていれば 0 件（同じ日付も逆転ではない）" do
      record(tm, "first", "2026-03-25")
      record(tm, "second", "2026-05-01")
      record(tm, "first", "2026-05-01")
      expect(found("S2a")).to be_empty
    end

    it "別の選手の記録とは比べない" do
      other = create(:team_membership, team: team)
      record(tm, "first", "2026-05-01")
      record(other, "first", "2026-03-25")
      expect(found("S2a")).to be_empty
    end
  end

  describe "S2b: 1軍人数が規定を外れた日" do
    let(:minimum) { Team.first_squad_minimum_players }
    let(:max) { SeasonRecordAudit::FIRST_SQUAD_MAX }

    it "上限 29 人ちょうどは数えず、30 人は over_max（試合日でない種別の日も見る）" do
      members = create_list(:team_membership, max + 1, team: team)
      create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
      create(:season_schedule, season: season, date: "2026-04-02", date_type: "reserve_day")
      members.first(max).each { |m| record(m, "first", "2026-04-01") }
      expect(found("S2b")).to be_empty
      record(members.last, "first", "2026-04-02")
      f = found("S2b")
      expect(f.map { |x| [ x.category, x.date ] }).to eq([ [ "over_max", "2026-04-02" ] ])
      expect(f.first.evidence).to include("#{max + 1} 人")
    end

    it "最低人数ちょうどは数えず、1 人少ない試合日は under_min（初日・試合日でない種別・最初の記録より前は数えない）" do
      members = create_list(:team_membership, minimum, team: team)
      create(:season_schedule, season: season, date: "2026-03-30", date_type: "travel_day") # シーズン初日
      create(:season_schedule, season: season, date: "2026-03-31", date_type: "game_day") # 初日ではないが最初の記録より前
      create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
      create(:season_schedule, season: season, date: "2026-04-02", date_type: "game_day")
      create(:season_schedule, season: season, date: "2026-04-03", date_type: "travel_day")
      create(:season_schedule, season: season, date: "2026-04-04", date_type: "interleague_game_day")
      members.each { |m| record(m, "first", "2026-04-01") }
      expect(found("S2b")).to be_empty
      record(members.first, "second", "2026-04-03") # 4/3 の移動日と 4/4 の交流戦で 1 人足りない
      f = found("S2b")
      expect(f.map { |x| [ x.category, x.date ] }).to eq([ [ "under_min", "2026-04-04" ] ])
    end

    it "シーズン初日は最低人数未満でも数えない（初期登録の途中。コントローラと同じ免除）" do
      members = create_list(:team_membership, 3, team: team)
      create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
      create(:season_schedule, season: season, date: "2026-04-02", date_type: "game_day")
      members.each { |m| record(m, "first", "2026-04-01") }
      expect(found("S2b").map(&:date)).to eq([ "2026-04-02" ])
    end

    it "記録が無い選手は 2軍とみなす（写しには倒さない）" do
      create_list(:team_membership, max + 1, :first_squad, team: team)
      create(:season_schedule, season: season, date: "2026-04-01", date_type: "game_day")
      expect(found("S2b")).to be_empty
    end
  end

  describe "S2c: クールダウン違反" do
    let!(:tm) { create(:team_membership, team: team) }

    before do
      record(tm, "first", "2026-04-01")
      record(tm, "second", "2026-05-01")
    end

    it "降格の 9 日後の昇格は違反" do
      promo = record(tm, "first", "2026-05-10")
      expect(found("S2c").map(&:ref)).to eq([ promo.id ])
    end

    it "降格の 10 日後の昇格は違反でない（境界）" do
      record(tm, "first", "2026-05-11")
      expect(found("S2c")).to be_empty
    end

    it "降格と同じ日の昇格に先立つ昇格があれば免除（同日の昇格＋降格）" do
      other = create(:team_membership, team: team)
      record(other, "first", "2026-05-01")
      record(other, "second", "2026-05-01")
      record(other, "first", "2026-05-05")
      expect(found("S2c")).to be_empty
    end

    it "一度も 1軍にならなかった選手の最初の昇格は対象外" do
      fresh = create(:team_membership, team: team)
      record(fresh, "second", "2026-05-01")
      record(fresh, "first", "2026-05-03")
      expect(found("S2c")).to be_empty
    end

    it "状態が変わらない重複の 2軍の記録は降格に数えない（昇格の後から差し込まれた場合）" do
      record(tm, "first", "2026-05-12")
      record(tm, "second", "2026-05-08") # 後から差し込まれた重複。降格は 5/1 のまま
      expect(found("S2c")).to be_empty
    end

    it "試合日の昇降格そのものは違反にしない（AMB-24）" do
      create(:season_schedule, season: season, date: "2026-05-11", date_type: "game_day")
      create(:season_schedule, season: season, date: "2026-05-01", date_type: "game_day")
      record(tm, "first", "2026-05-11")
      expect(found("S2c")).to be_empty
    end
  end

  describe "S7: 1軍でない日の登板" do
    let!(:pitcher_and_membership) { create_card_pitcher(team: team, starter_stamina: 7) }
    let(:pitcher) { pitcher_and_membership[0] }
    let(:membership) { pitcher_and_membership[1] }

    def pitch_on(date)
      create(:season_schedule, season: season, date: date, date_type: "game_day")
      create_start(team: team, pitcher: pitcher, date: date, innings: 5.0)
    end

    it "1軍の日の登板は数えない" do
      record(membership, "first", "2026-06-01")
      pitch_on("2026-06-05")
      expect(found("S7")).to be_empty
    end

    it "2軍の日の登板は second/other" do
      record(membership, "first", "2026-06-01")
      record(membership, "second", "2026-06-03")
      pitch_on("2026-06-10")
      expect(found("S7").map(&:category)).to eq([ "second/other" ])
    end

    it "同じ日に抹消の記録があれば second/same_day_demoted" do
      record(membership, "first", "2026-06-01")
      record(membership, "second", "2026-06-05")
      pitch_on("2026-06-05")
      expect(found("S7").map(&:category)).to eq([ "second/same_day_demoted" ])
    end

    it "翌日に昇格の記録があれば promoted_next_day（2 日後は other）" do
      record(membership, "second", "2026-06-01")
      record(membership, "first", "2026-06-06")
      pitch_on("2026-06-05")
      expect(found("S7").map(&:category)).to eq([ "second/promoted_next_day" ])
      pitch_on("2026-06-03")
      expect(found("S7").map(&:category)).to contain_exactly("second/promoted_next_day", "second/other")
    end

    it "試合日以前に記録が無ければ unregistered（翌日に昇格なら unregistered/promoted_next_day）" do
      record(membership, "first", "2026-06-06")
      pitch_on("2026-06-05")
      expect(found("S7").map(&:category)).to eq([ "unregistered/promoted_next_day" ])
    end

    it "昇格の日当日の登板は 1軍扱い（境界）" do
      record(membership, "first", "2026-06-05")
      pitch_on("2026-06-05")
      expect(found("S7")).to be_empty
    end

    it "記録が 1 件も無い選手の登板は unregistered/other" do
      pitch_on("2026-06-05")
      expect(found("S7").map(&:category)).to eq([ "unregistered/other" ])
    end
  end

  describe "S8: 日付順より後に入力された登板" do
    let!(:pitcher_and_membership) { create_card_pitcher(team: team, starter_stamina: 7) }
    let(:pitcher) { pitcher_and_membership[0] }

    def pitch(date, role: "starter", created_at:)
      create(:season_schedule, season: season, date: date) unless SeasonSchedule.exists?(season: season, date: date)
      state = create_start(team: team, pitcher: pitcher, date: date, innings: 5.0, role: role)
      state.update_columns(created_at: created_at)
      state
    end

    it "前の日付を後から入れると、その試合日(S8a)とその登板(S8b)を数える" do
      pitch("2026-06-10", created_at: "2026-07-01 10:00")
      late = pitch("2026-06-01", role: "reliever", created_at: "2026-07-02 10:00")
      expect(found("S8a").map(&:date)).to eq([ "2026-06-01" ])
      expect(found("S8b").map { |f| [ f.ref, f.category ] }).to eq([ [ late.id, "reliever" ] ])
    end

    it "日付順に入力されていれば 0 件（境界）" do
      pitch("2026-06-01", created_at: "2026-07-01 10:00")
      pitch("2026-06-10", created_at: "2026-07-02 10:00")
      expect(found("S8a")).to be_empty
      expect(found("S8b")).to be_empty
    end

    it "別の投手の登板は S8b で比べない（S8a はチーム単位で見る）" do
      other, = create_card_pitcher(team: team, starter_stamina: 7)
      pitch("2026-06-10", created_at: "2026-07-01 10:00")
      create(:season_schedule, season: season, date: "2026-06-01")
      state = create_start(team: team, pitcher: other, date: "2026-06-01", innings: 5.0)
      state.update_columns(created_at: "2026-07-02 10:00")
      expect(found("S8b")).to be_empty
      expect(found("S8a").size).to eq(1)
    end
  end

  describe "S8c: 保存値が今の再計算と食い違う先発登板" do
    let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

    before { create_schedule(season, "2026-06-01", score: 0, opponent_score: 1) }

    it "保存された区分が再計算と違えば changed" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      f = found("S8c")
      expect(f.map(&:category)).to eq([ "changed" ])
      expect(f.first.evidence).to include("long_loss→normal")
    end

    it "再計算と同じ保存値なら数えない（境界）" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "normal", fatigue_p_used: 7)
      expect(found("S8c")).to be_empty
    end

    it "recompute: false なら再計算を省く" do
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      expect(found("S8c", recompute: false)).to be_empty
    end
  end

  describe "S10: ノーゲームの表し方" do
    it "種別だけ no_game の日を数え、その日の登板件数を evidence に出す" do
      pitcher, = create_card_pitcher(team: team, starter_stamina: 7)
      create(:season_schedule, season: season, date: "2026-06-01", date_type: "no_game", no_game: false)
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 3.0)
      f = found("S10")
      expect(f.map(&:category)).to eq([ "type_no_game_flag_false" ])
      expect(f.first.evidence).to include("登板 1 件")
    end

    it "真偽値だけ真の日は flag_true_type_other" do
      create(:season_schedule, season: season, date: "2026-06-01", date_type: "game_day", no_game: true)
      expect(found("S10").map(&:category)).to eq([ "flag_true_type_other" ])
    end

    it "種別も真偽値も一致する日は数えない（境界）" do
      create(:season_schedule, season: season, date: "2026-06-01", date_type: "no_game", no_game: true)
      create(:season_schedule, season: season, date: "2026-06-02", date_type: "game_day", no_game: false)
      expect(found("S10")).to be_empty
    end
  end

  describe "S11: 試合日でない種別の日の登板" do
    let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

    it "試合日の種別（game_day / interleague_game_day / playoff_day）の登板は数えない" do
      %w[game_day interleague_game_day playoff_day].each_with_index do |type, i|
        date = Date.new(2026, 6, 1) + i
        create(:season_schedule, season: season, date: date, date_type: type)
        create_start(team: team, pitcher: pitcher, date: date, innings: 3.0)
      end
      expect(found("S11")).to be_empty
    end

    it "移動日・雨天中止・ノーゲームの種別の登板は種別ごとに数える。日程が無い日は no_schedule" do
      { "travel_day" => "2026-06-01", "postponed" => "2026-06-02", "no_game" => "2026-06-03" }.each do |type, date|
        create(:season_schedule, season: season, date: date, date_type: type)
        create_start(team: team, pitcher: pitcher, date: date, innings: 3.0)
      end
      create_start(team: team, pitcher: pitcher, date: "2026-06-09", innings: 3.0)
      expect(found("S11").map(&:category)).to contain_exactly("travel_day", "postponed", "no_game", "no_schedule")
    end
  end

  describe "範囲と並び" do
    it "team_id を指定すれば他チームの食い違いを含めない" do
      other_team, other_season = create_team_with_season
      create(:season_schedule, season: season, date: "2026-06-01", date_type: "no_game")
      create(:season_schedule, season: other_season, date: "2026-06-01", date_type: "no_game")
      expect(found("S10").map(&:team_id)).to contain_exactly(team.id, other_team.id)
      expect(found("S10", team_id: other_team.id).map(&:team_id)).to eq([ other_team.id ])
    end

    it "並びは項目・チーム・日付の順で、同じデータなら何度回しても同じ" do
      create(:season_schedule, season: season, date: "2026-06-05", date_type: "no_game")
      create(:season_schedule, season: season, date: "2026-06-02", date_type: "no_game")
      first = audit.findings.map(&:to_a)
      expect(first.map { |r| r[4] }).to eq(%w[2026-06-02 2026-06-05])
      expect(audit.findings.map(&:to_a)).to eq(first)
    end

    it "summary は項目ごとの件数・チーム数・選手数・分類別件数を返す" do
      create(:season_schedule, season: season, date: "2026-06-05", date_type: "no_game")
      s = audit.summary
      expect(s.keys).to eq(SeasonRecordAudit::ITEMS.keys)
      expect(s["S10"]).to include(count: 1, teams: 1, players: 0, categories: { "type_no_game_flag_false" => 1 })
      expect(s["S1"][:count]).to eq(0)
    end
  end

  describe "DB へ書かない" do
    it "全項目が該当する状態で回しても、INSERT/UPDATE/DELETE を発行せず、件数・updated_at が変わらない" do
      pitcher, membership = create_card_pitcher(team: team, starter_stamina: 7)
      create_schedule(season, "2026-06-01", score: 0, opponent_score: 1)
      create(:season_schedule, season: season, date: "2026-06-02", date_type: "no_game")
      create_start(team: team, pitcher: pitcher, date: "2026-06-01", innings: 8.0, category: "long_loss")
      create_start(team: team, pitcher: pitcher, date: "2026-06-02", innings: 3.0)
      record(membership, "first", "2026-05-01")
      record(membership, "second", "2026-03-25")
      membership.update!(squad: "second")
      benched, benched_membership = create_card_pitcher(team: team, starter_stamina: 7)
      record(benched_membership, "second", "2026-05-01")
      create_start(team: team, pitcher: benched, date: "2026-06-01", innings: 2.0, role: "reliever")

      tables = %w[season_rosters team_memberships pitcher_game_states season_schedules seasons players]
      snapshot = -> { tables.to_h { |t| [ t, ActiveRecord::Base.connection.select_rows("SELECT count(*), max(updated_at) FROM #{t}").first ] } }
      before_state = snapshot.call

      writes = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        writes << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE|TRUNCATE|ALTER|DROP|CREATE)\b/i)
      end
      result = audit
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(result.findings.map(&:item).uniq).to include("S1", "S2a", "S7", "S8c", "S10", "S11")
      expect(writes).to be_empty
      expect(snapshot.call).to eq(before_state)
    end
  end
end
