require "rails_helper"

# Test Basis: cmd_1794 段3。Operator 決定 2026-11-02「進み具合に試合数を出す。消化数／総数。総数は日程から数える（ノーゲームの振り替えで日程が増える分も正しく数える）。
# 試合数に数える日の定義は cmd_1784 段4 のもの」（SeasonSchedule.counted_games）。消化 = 数える日のうち結果（得点が自軍・相手とも）が入った日（SeasonCurrentRange.result? と同じ）。
RSpec.describe SeasonGameProgress do
  let(:team) { create(:team) }
  let(:season) { create(:season, team: team) }

  def d(day) = Date.new(2026, 5, 1) + (day - 1)

  def schedule(day, type = "game_day", season: self.season, **attrs)
    create(:season_schedule, season: season, date: d(day), date_type: type, **attrs)
  end

  def won(day, type = "game_day", **attrs) = schedule(day, type, score: 3, opponent_score: 1, **attrs)

  def row_of(team_id = team.id) = described_class.by_team_id.fetch(team_id)

  it "通常と交流戦の試合日を総数に数え、結果が入った日を消化に数える" do
    won(1)
    won(2, "interleague_game_day")
    schedule(3)
    schedule(4, "interleague_game_day")

    expect(row_of).to have_attributes(regular_total: 4, regular_played: 2, playoff_played: 0)
  end

  describe "ノーゲーム" do
    it "ノーゲームの日は総数にも消化にも数えない（得点が入っていても消化にしない）" do
      won(1)
      schedule(2, no_game: true)
      schedule(3, no_game: true, score: 5, opponent_score: 5)

      expect(row_of).to have_attributes(regular_total: 1, regular_played: 1)
    end

    it "振り替えて日程が増えたチームは、振り替えた日の分だけ総数が増える（ノーゲームの日は数えないので二重にならない）" do
      won(1)
      schedule(2, no_game: true)
      schedule(3, "reserve_day")
      expect(row_of).to have_attributes(regular_total: 1) # 予備日のままなら総数は増えない

      SeasonSchedule.find_by!(season: season, date: d(3)).update!(date_type: "game_day") # 予備日を試合日にする
      expect(row_of).to have_attributes(regular_total: 2, regular_played: 1)

      SeasonSchedule.find_by!(season: season, date: d(3)).update!(score: 2, opponent_score: 0)
      expect(row_of).to have_attributes(regular_total: 2, regular_played: 2)
    end

    it "ノーゲームを外す（真偽値を戻す）と数えに戻る" do
      s = schedule(1, no_game: true)
      expect(row_of).to have_attributes(regular_total: 0)
      s.update!(no_game: false)
      expect(row_of).to have_attributes(regular_total: 1, regular_played: 0)
    end
  end

  describe "結果の入り方" do
    it "結果が未入力の試合日は総数に入り、消化に入らない。片方の得点だけの日も消化にしない" do
      schedule(1)
      schedule(2, score: 3)
      schedule(3, opponent_score: 3)

      expect(row_of).to have_attributes(regular_total: 3, regular_played: 0)
    end

    it "0 対 0 は結果が入った日として消化に数える（得点 0 を未入力と取り違えない）" do
      schedule(1, score: 0, opponent_score: 0)

      expect(row_of).to have_attributes(regular_total: 1, regular_played: 1)
    end
  end

  describe "試合日でない種別" do
    it "予備日・移動日・雨天中止・休日・廃止した種別 no_game は、得点が入っていても数えない" do
      %w[reserve_day interleague_reserve_day travel_day postponed no_game_day].each_with_index do |type, i|
        schedule(i + 1, type, score: 1, opponent_score: 0)
      end
      legacy_no_game_schedule(season: season, date: d(9))

      expect(row_of).to have_attributes(regular_total: 0, regular_played: 0, playoff_played: 0)
    end
  end

  describe "プレーオフ日" do
    it "レギュラーの総数・消化には入れず、消化したプレーオフ日の数だけ別に返す（総数は返さない）" do
      won(1)
      schedule(2)
      won(3, "playoff_day")
      schedule(4, "playoff_day")
      schedule(5, "playoff_day", no_game: true, score: 1, opponent_score: 0)
      schedule(6, "playoff_day", score: 1) # 片方の得点だけの日は消化にしない

      expect(row_of).to have_attributes(regular_total: 2, regular_played: 1, playoff_played: 1)
      expect(row_of.to_h.keys).to contain_exactly(:team_id, :regular_total, :regular_played, :playoff_played)
    end
  end

  describe "チームの範囲" do
    it "休止中のチームも含める" do
      inactive = create(:team, is_active: false)
      other = create(:season, team: inactive)
      won(1, season: other)

      expect(row_of(inactive.id)).to have_attributes(regular_total: 1, regular_played: 1)
    end

    it "日程が 1 行も無いシーズンは 0 / 0 で返す（行は残す）" do
      season # 作るだけ

      expect(row_of).to have_attributes(team_id: team.id, regular_total: 0, regular_played: 0, playoff_played: 0)
    end

    it "シーズンの無いチームは返さない" do
      no_season = create(:team)
      season

      expect(described_class.by_team_id).not_to have_key(no_season.id)
    end

    it "チームごとに別々に数える（他チームの日程を混ぜない）" do
      won(1)
      schedule(2)
      other_team = create(:team)
      other_season = create(:season, team: other_team)
      won(1, season: other_season)
      won(2, season: other_season)
      schedule(3, season: other_season)

      expect(row_of).to have_attributes(regular_total: 2, regular_played: 1)
      expect(row_of(other_team.id)).to have_attributes(regular_total: 3, regular_played: 2)
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
      won(1)
      one_team = queries { described_class.by_team_id }

      4.times do
        s = create(:season, team: create(:team))
        won(1, season: s)
        schedule(2, season: s)
      end
      five_teams = queries { described_class.by_team_id }

      expect(one_team).to be <= 3
      expect(five_teams).to eq(one_team)
    end
  end
end
