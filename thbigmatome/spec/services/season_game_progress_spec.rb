require "rails_helper"

# Test Basis: cmd_1794 段3 / cmd_1802 段3（subtask_1802b）。Operator 決定 2026-11-02:
#   - 「雨天中止があっても143試合消化するので、143試合と出す。未振替数がどこかでわかるようにしたい。」
#     → 総数 regular_total は日程マスタ（schedule_details）のレギュラーの試合日数で固定する（チームの雨天中止・振り替えで動かさない）
#     → 未振替数 regular_unrescheduled = max(0, 総数 − そのシーズンの数える日)。数える日 = レギュラーの試合日でノーゲームでない日。
#       雨天中止・ノーゲーム・試合日を移動日や予備日へ手で直した日はどれも数える日が減って未振替に出る（本体判断 2026-11-02。種類を数える式は入力の仕方で取りこぼす）
# 消化 = 数える日（ノーゲームでない試合日）のうち得点が自軍・相手とも入った日（SeasonCurrentRange.result? と同じ）。
RSpec.describe SeasonGameProgress do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }

  def d(day) = Date.new(2026, 5, 1) + (day - 1)

  # マスタ（日程表）を作る。types は 1 日目から順の種別。作ったマスタの schedule を返す
  def master(types, name: "マスタ")
    Schedule.create!(name: name, start_date: d(1), end_date: d(types.size)).tap do |s|
      types.each_with_index { |type, i| s.schedule_details.create!(date: d(i + 1), date_type: type) }
    end
  end

  # マスタと同じ日付・種別でシーズンの日程を作る（シーズン作成と同じ写し）
  def copy_master_to(season, schedule)
    schedule.schedule_details.order(:date).each { |detail| create(:season_schedule, season: season, date: detail.date, date_type: detail.date_type) }
  end

  def at(day, season: self.season) = SeasonSchedule.find_by!(season: season, date: d(day))

  def play(day, season: self.season, score: 3, opponent_score: 1) = at(day, season: season).update!(score: score, opponent_score: opponent_score)

  def row_of(team_id = team.id) = described_class.by_team_id.fetch(team_id)

  # 試合日 5 + 予備日 2 + プレーオフ 1 のマスタ（レギュラーの試合日 = 5）
  let(:regular_master) { master(%w[game_day game_day interleague_game_day game_day game_day reserve_day interleague_reserve_day playoff_day]) }

  before { copy_master_to(season, regular_master) }

  describe "総数（regular_total）はマスタのレギュラーの試合日数で固定する" do
    it "通常と交流戦の試合日だけ数える（予備日・交流戦予備日・プレーオフ日は入れない）" do
      expect(row_of).to have_attributes(regular_total: 5)
    end

    it "雨天中止・ノーゲーム・振り替えがあっても動かさない" do
      at(2).update!(date_type: "postponed")        # 雨天中止
      at(3).update!(no_game: true)                  # ノーゲーム
      at(6).update!(date_type: "game_day")          # 予備日を試合日にして振り替え
      at(7).update!(date_type: "interleague_game_day")

      expect(row_of.regular_total).to eq(5)
    end

    it "マスタを書き換えると、シーズンの日程を触らなくても総数が変わる（マスタの試合日を予備日にすれば減る）" do
      expect { regular_master.schedule_details.find_by!(date: d(5)).update!(date_type: "reserve_day") }
        .to change { row_of.regular_total }.from(5).to(4)
    end

    it "シーズンの日付の集合が一致するマスタを使う（マスタが複数あっても取り違えない）" do
      other = master(%w[game_day game_day game_day], name: "別のマスタ")
      other_season = create(:season, team: create(:team))
      copy_master_to(other_season, other)

      expect(row_of).to have_attributes(regular_total: 5)
      expect(row_of(other_season.team_id)).to have_attributes(regular_total: 3)
    end

    it "どのマスタとも日付の集合が合わないシーズンは、いちばん古い（id が最小の）マスタで数える" do
      create(:season_schedule, season: season, date: d(30), date_type: "game_day") # マスタに無い日が増えて集合が合わない

      expect(row_of.regular_total).to eq(5)
    end

    it "マスタが 1 つも無ければ 0" do
      Schedule.destroy_all

      expect(row_of).to have_attributes(regular_total: 0, regular_unrescheduled: 0)
    end
  end

  describe "消化（regular_played）" do
    it "結果が入った試合日を数える。0 対 0 も数える" do
      play(1)
      play(2, score: 0, opponent_score: 0)

      expect(row_of).to have_attributes(regular_played: 2)
    end

    it "片方の得点だけの日・未入力の日は数えない" do
      at(1).update!(score: 3)
      at(2).update!(opponent_score: 3)

      expect(row_of).to have_attributes(regular_played: 0)
    end

    it "ノーゲームの日は得点が入っていても数えない" do
      play(1)
      at(2).update!(no_game: true, score: 5, opponent_score: 5)

      expect(row_of).to have_attributes(regular_played: 1)
    end

    it "予備日・移動日・雨天中止・休日・廃止した種別 no_game は、得点が入っていても数えない" do
      %w[reserve_day travel_day postponed no_game_day].each_with_index do |type, i|
        create(:season_schedule, season: season, date: d(20 + i), date_type: type, score: 1, opponent_score: 0)
      end
      legacy_no_game_schedule(season: season, date: d(30))

      expect(row_of).to have_attributes(regular_played: 0, playoff_played: 0)
    end
  end

  describe "未振替数（regular_unrescheduled = max(0, 総数 − 数える日)）" do
    it "何もなければ 0（結果が未入力の試合日があっても日程に載っているので未振替ではない）" do
      expect(row_of.regular_unrescheduled).to eq(0)
    end

    it "雨天中止 1・振り替え 0 → 1" do
      at(2).update!(date_type: "postponed")

      expect(row_of.regular_unrescheduled).to eq(1)
    end

    it "雨天中止 1・振り替え 1 → 0（予備日を試合日にした）" do
      at(2).update!(date_type: "postponed")
      at(6).update!(date_type: "game_day")

      expect(row_of.regular_unrescheduled).to eq(0)
    end

    it "交流戦の予備日を交流戦の試合日にしても振り替えになる" do
      at(2).update!(date_type: "postponed")
      at(7).update!(date_type: "interleague_game_day")

      expect(row_of.regular_unrescheduled).to eq(0)
    end

    it "ノーゲーム 1・振り替え 0 → 1" do
      at(2).update!(no_game: true)

      expect(row_of.regular_unrescheduled).to eq(1)
    end

    it "雨天中止 1 とノーゲーム 1 は足し合わせて 2。振り替え 1 で 1 になる" do
      at(2).update!(date_type: "postponed")
      at(3).update!(no_game: true)
      expect(row_of.regular_unrescheduled).to eq(2)

      at(6).update!(date_type: "game_day")
      expect(row_of.regular_unrescheduled).to eq(1)
    end

    # チーム 45・46 型: 雨天中止を postponed にせず、試合日を移動日・予備日へ手で直した（日程から試合が消えた）
    it "試合日を移動日へ手で直したら未振替 1（postponed でなくても数える）" do
      at(2).update!(date_type: "travel_day")

      expect(row_of.regular_unrescheduled).to eq(1)
    end

    it "試合日を予備日へ手で直したら未振替 1。交流戦の試合日を交流戦予備日へ直しても 1" do
      at(2).update!(date_type: "reserve_day")
      expect(row_of.regular_unrescheduled).to eq(1)

      at(3).update!(date_type: "interleague_reserve_day")
      expect(row_of.regular_unrescheduled).to eq(2)
    end

    it "手で直した日と、予備日を試合日にした振り替えは相殺する（試合日を予備日へ直し、別の予備日を試合日にしたら 0）" do
      at(2).update!(date_type: "reserve_day")
      at(6).update!(date_type: "game_day")

      expect(row_of.regular_unrescheduled).to eq(0)
    end

    it "振り替えた試合がノーゲームになったら、振り替え分は数えない（中止分が未振替に残る）" do
      at(2).update!(date_type: "postponed")
      at(6).update!(date_type: "game_day", no_game: true)

      expect(row_of.regular_unrescheduled).to eq(1)
    end

    it "数える日が総数を超えるチームは 0（負にしない。超えた数は返さない）" do
      at(6).update!(date_type: "game_day")
      at(7).update!(date_type: "interleague_game_day")
      create(:season_schedule, season: season, date: d(30), date_type: "game_day") # マスタに無い日の試合日

      expect(row_of).to have_attributes(regular_total: 5, regular_unrescheduled: 0)
    end

    it "数える日がちょうど総数なら 0（境界）。1 つ減ると 1" do
      expect(row_of.regular_unrescheduled).to eq(0)

      at(5).update!(date_type: "postponed")
      expect(row_of.regular_unrescheduled).to eq(1)
    end

    it "予備日が雨天中止になっただけなら未振替に数えない（失われた試合ではない）" do
      at(6).update!(date_type: "postponed")

      expect(row_of.regular_unrescheduled).to eq(0)
    end

    it "予備日を試合日にして振り替えたあと、その日がまた雨天中止になったら、中止分が 1 つ未振替に残る" do
      at(2).update!(date_type: "postponed")
      at(6).update!(date_type: "postponed")

      expect(row_of.regular_unrescheduled).to eq(1)
    end

    it "プレーオフ日の雨天中止・ノーゲームは数えない" do
      at(8).update!(date_type: "postponed")
      expect(row_of.regular_unrescheduled).to eq(0)

      at(8).update!(date_type: "playoff_day", no_game: true)
      expect(row_of.regular_unrescheduled).to eq(0)
    end

    it "マスタを書き換えて総数が変わると未振替も変わる（試合日を 1 日予備日にすれば、数える日が総数を超えて 0 に下がる）" do
      at(2).update!(date_type: "postponed")
      expect(row_of.regular_unrescheduled).to eq(1)

      regular_master.schedule_details.find_by!(date: d(5)).update!(date_type: "reserve_day")
      expect(row_of).to have_attributes(regular_total: 4, regular_unrescheduled: 0)
    end
  end

  describe "プレーオフ日" do
    it "レギュラーの総数・消化には入れず、消化したプレーオフ日の数だけ別に返す（総数は返さない）" do
      play(1)
      play(8)
      extra = create(:season_schedule, season: season, date: d(9), date_type: "playoff_day", no_game: true, score: 1, opponent_score: 0)
      create(:season_schedule, season: season, date: d(10), date_type: "playoff_day", score: 1) # 片方の得点だけは消化にしない

      expect(row_of).to have_attributes(regular_total: 5, regular_played: 1, playoff_played: 1)
      expect(row_of.to_h.keys).to contain_exactly(:team_id, :regular_total, :regular_played, :regular_unrescheduled, :playoff_played)
      expect(extra).to be_persisted
    end
  end

  describe "チームの範囲" do
    it "休止中のチームも含める" do
      inactive = create(:team, is_active: false)
      other = create(:season, team: inactive)
      copy_master_to(other, regular_master)
      play(1, season: other)

      expect(row_of(inactive.id)).to have_attributes(regular_total: 5, regular_played: 1)
    end

    it "日程が 1 行も無いシーズンは 0 / 0 / 0 / 0 で返す（行は残す。マスタがあっても総数を出さない）" do
      empty_team = create(:team)
      create(:season, team: empty_team)

      expect(row_of(empty_team.id)).to have_attributes(team_id: empty_team.id, regular_total: 0, regular_played: 0, regular_unrescheduled: 0, playoff_played: 0)
    end

    it "シーズンの無いチームは返さない" do
      no_season = create(:team)

      expect(described_class.by_team_id).not_to have_key(no_season.id)
    end

    it "チームごとに別々に数える（他チームの日程を混ぜない）" do
      play(1)
      at(2).update!(date_type: "postponed")
      other = create(:season, team: create(:team))
      copy_master_to(other, regular_master)
      play(1, season: other)
      play(2, season: other)
      at(3, season: other).update!(no_game: true)

      expect(row_of).to have_attributes(regular_played: 1, regular_unrescheduled: 1)
      expect(row_of(other.team_id)).to have_attributes(regular_played: 2, regular_unrescheduled: 1)
    end
  end

  describe "問い合わせ回数" do
    def queries
      count = 0
      callback = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/) }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      count
    end

    it "チームの数に依らない（5 チームも 1 チームも同じ本数）" do
      one_team = queries { described_class.by_team_id }

      4.times do
        s = create(:season, team: create(:team))
        copy_master_to(s, regular_master)
        play(1, season: s)
      end
      five_teams = queries { described_class.by_team_id }

      expect(one_team).to be <= 5
      expect(five_teams).to eq(one_team)
    end
  end
end
