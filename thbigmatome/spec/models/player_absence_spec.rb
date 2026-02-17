require 'rails_helper'

RSpec.describe PlayerAbsence, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to belong_to(:team_membership) }
    it { is_expected.to belong_to(:season) }
  end

  describe 'バリデーション' do
    describe 'absence_type' do
      it { is_expected.to validate_presence_of(:absence_type) }
      it { is_expected.to define_enum_for(:absence_type).with_values(injury: 0, suspension: 1, reconditioning: 2) }
    end

    describe 'start_date' do
      it { is_expected.to validate_presence_of(:start_date) }
    end

    describe 'duration' do
      it { is_expected.to validate_presence_of(:duration) }
      it { is_expected.to validate_numericality_of(:duration).only_integer }

      it 'duration > 0 のみ有効' do
        absence = build(:player_absence, duration: 0)
        expect(absence).not_to be_valid
        expect(absence.errors[:duration]).to be_present
      end

      it '負の値は無効' do
        absence = build(:player_absence, duration: -1)
        expect(absence).not_to be_valid
      end

      it '正の整数は有効' do
        absence = build(:player_absence, duration: 1)
        expect(absence).to be_valid
      end
    end

    describe 'duration_unit' do
      it { is_expected.to validate_presence_of(:duration_unit) }

      it 'days は有効' do
        absence = build(:player_absence, duration_unit: "days")
        expect(absence).to be_valid
      end

      it 'games は有効' do
        absence = build(:player_absence, duration_unit: "games")
        expect(absence).to be_valid
      end

      it 'その他の値は無効' do
        absence = build(:player_absence, duration_unit: "weeks")
        expect(absence).not_to be_valid
      end
    end
  end

  describe '#effective_end_date' do
    context 'daysベース（duration_unit: days）' do
      it 'start_date + duration日 を返す' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 1), duration: 5, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it 'duration=1 の場合、翌日を返す' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 1), duration: 1, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 2))
      end

      it '月をまたぐケース' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 28), duration: 5, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 5, 3))
      end

      it '年をまたぐケース' do
        absence = build(:player_absence, start_date: Date.new(2026, 12, 29), duration: 5, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2027, 1, 3))
      end

      it '大きなduration値' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 1), duration: 30, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 5, 1))
      end
    end

    context 'gamesベース（duration_unit: games）' do
      let(:team) { create(:team) }
      let(:player) { create(:player) }
      let(:team_membership) { create(:team_membership, team: team, player: player) }
      let(:season) { create(:season, team: team) }

      it '離脱開始日以降のN試合目の翌日を返す' do
        # 4/1, 4/3, 4/5, 4/7, 4/9 にゲームを配置
        [ 1, 3, 5, 7, 9 ].each do |day|
          create(:season_schedule, season: season, date: Date.new(2026, 4, day), date_type: "game_day")
        end

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        # 4/1, 4/3, 4/5 の3試合 → 4/5の翌日 = 4/6
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it 'game_dayとinterleague_game_dayの両方をカウントする' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "interleague_game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 5), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it 'off_day, event_day はカウントしない' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 2), date_type: "off_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "event_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 4), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 5), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        # game_day: 4/1, 4/4, 4/5 → 4/5の翌日 = 4/6
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it '離脱開始日より前のゲームはカウントしない' do
        create(:season_schedule, season: season, date: Date.new(2026, 3, 28), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 3, 30), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 2,
          duration_unit: "games"
        )

        # 4/1, 4/3 の2試合 → 4/3の翌日 = 4/4
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 4))
      end

      it 'スケジュール不足（game_dates < duration）の場合はnilを返す' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 5,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to be_nil
      end

      it 'スケジュールが全くない場合はnilを返す' do
        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to be_nil
      end

      it 'duration=1（1試合離脱）の境界値' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 5), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 5),
          duration: 1,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it '離脱開始日当日が試合日の場合、その試合もカウントに含む' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 2), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 2,
          duration_unit: "games"
        )

        # where("date >= ?", start_date) なので4/1もカウント
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 3))
      end
    end
  end
end
