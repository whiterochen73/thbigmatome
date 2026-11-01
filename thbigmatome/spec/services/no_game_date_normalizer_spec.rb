require "rails_helper"

# Test Basis: cmd_1784 段4。設計書 §4.6「種別 no_game の日を、シーズン作成元の日程マスタ（schedule_details）の種別に戻し、真偽値を真にする。
# 登板の結果区分が no_game に変わる」/ §5.4「データの補正は変更前の値を残し、逆向きに当てられるようにする」/ 台帳 D-11。
# 境界: マスタが無い・マスタの種別が割れる・マスタ自体が no_game なら止める（何も書かない）、2 回目は 0 件。
# Operator 決定 2026-11-02: マスタが予備日（reserve_day / interleague_reserve_day）の日は、予備日ではなく試合日（game_day / interleague_game_day）＋
# no_game 真に戻す（予備日に組まれた試合がノーゲームになったと読む。試合数に数えない・1軍最低人数の検査が掛かる）。予備日以外の試合日でない種別は一覧に出す。
RSpec.describe NoGameDateNormalizer, :pitcher_fatigue do
  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }

  def d(day) = Date.new(2026, 5, day)

  # 日程マスタ: 5/1 通常 / 5/2 通常 / 5/3 予備日 / 5/4 交流戦
  let!(:master) do
    Schedule.create!(name: "マスタ", start_date: d(1), end_date: d(4)).tap do |s|
      { 1 => "game_day", 2 => "game_day", 3 => "reserve_day", 4 => "interleague_game_day" }.each { |day, type| s.schedule_details.create!(date: d(day), date_type: type) }
    end
  end

  # シーズンは作成時にマスタを写す。5/2（通常）と 5/3（予備日）でノーゲームがあり、種別を no_game にしていた状態
  def build_season_rows(target_season)
    { 1 => "game_day", 2 => "no_game", 3 => "no_game", 4 => "interleague_game_day" }.to_h do |day, type|
      [ day, type == "no_game" ? legacy_no_game_schedule(season: target_season, date: d(day)) : create(:season_schedule, season: target_season, date: d(day), date_type: type) ]
    end
  end

  let!(:rows) { build_season_rows(season) }
  let!(:start_on_ng) { create_start(team: team, pitcher: pitcher, date: "2026-05-02", innings: 5.0) }
  let!(:start_on_normal) { create_start(team: team, pitcher: pitcher, date: "2026-05-04", innings: 5.0, game: create(:game)) }

  def run_normalizer(**opts) = described_class.new(**opts).call

  it "試運転: 元の種別を日程マスタから引いて一覧にするだけで、DB は書かない" do
    result = run_normalizer
    expect(result.summary).to eq(restore: 2)
    expect(result.rows.map { |r| [ r.date, r.new_date_type ] }).to eq([ [ d(2), "game_day" ], [ d(3), "game_day" ] ])
    expect(result.rows.map(&:master_types)).to eq([ [ "game_day" ], [ "reserve_day" ] ]) # 元のマスタの種別（予備日）は残す
    expect(result.rows.map(&:pitcher_count)).to eq([ 1, 0 ])
    expect(rows[2].reload).to have_attributes(date_type: "no_game", no_game: false)
  end

  describe "マスタの種別が予備日の日（予備日に組まれた試合がノーゲームになったと読む）" do
    it "予備日（reserve_day）は試合日（game_day）に戻し、試合日でない種別ではないので not_game_type に出さない" do
      result = run_normalizer
      expect(result.rows.find { |r| r.date == d(3) }).to have_attributes(status: :restore, new_date_type: "game_day", new_no_game: true)
      expect(result.not_game_type).to be_empty
    end

    it "交流戦予備日（interleague_reserve_day）は交流戦の試合日（interleague_game_day）に戻す" do
      ScheduleDetail.where(schedule: master, date: d(3)).update_all(date_type: "interleague_reserve_day")
      result = run_normalizer
      expect(result.rows.find { |r| r.date == d(3) }).to have_attributes(status: :restore, new_date_type: "interleague_game_day", new_no_game: true)
      expect(result.not_game_type).to be_empty
    end

    it "予備日以外の試合日でない種別（移動日）に戻る日は、これまで通り not_game_type に出す" do
      ScheduleDetail.where(schedule: master, date: d(3)).update_all(date_type: "travel_day")
      result = run_normalizer
      expect(result.rows.find { |r| r.date == d(3) }).to have_attributes(new_date_type: "travel_day")
      expect(result.not_game_type.map(&:date)).to eq([ d(3) ])
    end

    it "戻した日は試合日だが試合数（counted_games）には数えない。1軍最低人数の検査が掛かる" do
      cost = create(:cost, end_date: nil)
      # 検査は season の日程を new 時に読むので、毎回作り直す
      min_dates = lambda do
        RosterConstraintChecker.new(team: team, season: Season.find(season.id), cost_list: cost)
                               .violations_from(RosterState.new(team), [ d(1), "pre_game" ]).select { |v| v.kind == "first_squad_min" }.map(&:date)
      end
      expect(min_dates.call).to eq([ d(4) ]) # 移行前: 種別 no_game の日は試合日でない。交流戦の 5/4 だけ

      run_normalizer.apply!

      expect(min_dates.call).to eq([ d(2), d(3), d(4) ]) # 試合日（ノーゲーム含む）に戻ったので掛かる
      expect(season.season_schedules.game_days.pluck(:date)).to match_array([ d(1), d(2), d(3), d(4) ])
      expect(season.season_schedules.counted_games.pluck(:date)).to match_array([ d(1), d(4) ])
    end
  end

  describe "apply!" do
    it "種別をマスタの種別に戻し、真偽値を真にする。登板の結果区分は no_game になり、ほかの日の登板は変わらない" do
      run_normalizer.apply!

      expect(rows[2].reload).to have_attributes(date_type: "game_day", no_game: true)
      expect(rows[3].reload).to have_attributes(date_type: "game_day", no_game: true) # マスタが予備日の日も試合日＋ノーゲーム真
      expect(rows[1].reload).to have_attributes(date_type: "game_day", no_game: false)
      expect(rows[4].reload).to have_attributes(date_type: "interleague_game_day", no_game: false)
      expect(start_on_ng.reload.result_category).to eq("no_game")
      expect(start_on_normal.reload.result_category).to eq("normal")
    end

    it "行を増やさず、updated_at を動かさない" do
      before = SeasonSchedule.order(:id).pluck(:id, :updated_at)
      expect { run_normalizer.apply! }.not_to change(SeasonSchedule, :count)
      expect(SeasonSchedule.order(:id).pluck(:id, :updated_at)).to eq(before)
    end

    it "何度流しても同じ結果になる（2 回目は対象 0 件）" do
      run_normalizer.apply!
      second = run_normalizer
      expect(second.rows).to be_empty
      expect { second.apply! }.not_to change { SeasonSchedule.order(:id).pluck(:date_type, :no_game) }
    end

    it "種別 no_game で真偽値がすでに真の日も、種別だけ戻す" do
      rows[2].update_columns(no_game: true)
      run_normalizer.apply!
      expect(rows[2].reload).to have_attributes(date_type: "game_day", no_game: true)
    end

    it "チームを絞れる（他チームの日は触らない）" do
      other_team, other_season = create_team_with_season
      other_rows = build_season_rows(other_season)

      run_normalizer(team_id: other_team.id).apply!

      expect(other_rows[2].reload.date_type).to eq("game_day")
      expect(rows[2].reload.date_type).to eq("no_game")
    end
  end

  describe "止める場合（何も書かない）" do
    it "日付の集合が合うマスタが無いシーズンは unresolved。ほかの戻せる日も書かない" do
      other_team, other_season = create_team_with_season
      legacy_no_game_schedule(season: other_season, date: Date.new(2027, 1, 1))
      result = run_normalizer
      expect(result.summary).to eq(restore: 2, unresolved: 1)
      expect { result.apply! }.to raise_error(NoGameDateNormalizer::Unresolved, /unresolved/)
      expect(rows[2].reload).to have_attributes(date_type: "no_game", no_game: false)
      expect(other_team).to be_present
    end

    it "日付の集合が合うマスタが複数あり、その日の種別が割れるなら ambiguous" do
      other = Schedule.create!(name: "別マスタ", start_date: d(1), end_date: d(4))
      { 1 => "game_day", 2 => "reserve_day", 3 => "reserve_day", 4 => "interleague_game_day" }.each { |day, type| other.schedule_details.create!(date: d(day), date_type: type) }
      result = run_normalizer
      expect(result.rows.map(&:status)).to eq([ :ambiguous, :restore ])
      expect { result.apply! }.to raise_error(NoGameDateNormalizer::Unresolved)
    end

    it "日付の集合が違うマスタ（一部の日付だけ共通）の種別は採らない" do
      partial = Schedule.create!(name: "一部だけのマスタ", start_date: d(1), end_date: d(3))
      { 1 => "game_day", 2 => "reserve_day", 3 => "travel_day" }.each { |day, type| partial.schedule_details.create!(date: d(day), date_type: type) }
      result = run_normalizer
      expect(result.rows.map { |r| [ r.status, r.new_date_type ] }).to eq([ [ :restore, "game_day" ], [ :restore, "game_day" ] ])
    end

    it "割れていても同じ種別になるなら戻せる" do
      other = Schedule.create!(name: "同じ内容のマスタ", start_date: d(1), end_date: d(4))
      { 1 => "game_day", 2 => "game_day", 3 => "reserve_day", 4 => "interleague_game_day" }.each { |day, type| other.schedule_details.create!(date: d(day), date_type: type) }
      expect(run_normalizer.summary).to eq(restore: 2)
    end

    it "マスタの種別自体が no_game なら master_no_game" do
      ScheduleDetail.where(schedule: master, date: d(2)).update_all(date_type: "no_game")
      expect(run_normalizer.rows.map(&:status)).to eq([ :master_no_game, :restore ])
    end
  end

  describe ".revert!（変更前の値の CSV から逆向きに当てる）" do
    def csv_rows(normalizer)
      normalizer.rows.map do |r|
        { "schedule_id" => r.schedule_id.to_s, "old_date_type" => r.old_date_type, "old_no_game" => r.old_no_game.to_s,
          "new_date_type" => r.new_date_type, "new_no_game" => r.new_no_game.to_s }
      end
    end

    it "種別と真偽値を元に戻し、登板の結果区分も元の計算に戻る" do
      normalizer = run_normalizer
      normalizer.apply!
      expect(start_on_ng.reload.result_category).to eq("no_game")

      result = described_class.revert!(csv_rows(normalizer))

      expect(result).to eq(reverted: 2, skipped: [])
      expect(rows[2].reload).to have_attributes(date_type: "no_game", no_game: false)
      expect(rows[3].reload).to have_attributes(date_type: "no_game", no_game: false)
      expect(start_on_ng.reload.result_category).to eq("normal")
    end

    it "今の値が移行後の値と食い違う行（その後に直された日）は戻さず返す" do
      normalizer = run_normalizer
      normalizer.apply!
      rows[3].update!(date_type: "playoff_day") # その後に Operator が直した

      result = described_class.revert!(csv_rows(normalizer))

      expect(result).to eq(reverted: 1, skipped: [ rows[3].id.to_s ])
      expect(rows[3].reload.date_type).to eq("playoff_day")
    end
  end
end
